"""
Authentication Service.
Handles OTP lifecycle, session management, user creation.
All OTP security rules enforced here.
"""
import structlog
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.utils import (
    normalize_phone, PhoneValidationError,
    generate_otp, hash_otp, verify_otp,
    create_access_token, create_refresh_token, hash_token,
    log_action,
)
from app.services.whatsapp import get_whatsapp_service

settings = get_settings()
logger = structlog.get_logger()


class AuthError(Exception):
    """Domain error for auth operations."""
    def __init__(self, message: str, code: str = "auth_error"):
        super().__init__(message)
        self.code = code


# ---------------------------------------------------------------------------
# Send OTP
# ---------------------------------------------------------------------------

async def send_otp(
    db: AsyncSession,
    phone: str,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> dict:
    """
    Normalize phone, check rate limits, generate and send OTP.
    Returns: {"success": bool, "masked_phone": str, "resend_after": int}

    Security rules:
    - Normalize to E.164
    - Max OTP_MAX_SEND_PER_DAY sends per number per day
    - Resend cooldown OTP_RESEND_COOLDOWN_SECONDS
    - Invalidate any previous unused OTP
    - Hash OTP — never store plaintext
    """
    # 1. Normalize phone
    try:
        phone_normalized = normalize_phone(phone)
    except PhoneValidationError as exc:
        raise AuthError(str(exc), code="invalid_phone")

    # 2. Check if account is banned/suspended
    result = await db.execute(
        text("SELECT account_status FROM users WHERE phone_normalized = :phone AND deleted_at IS NULL"),
        {"phone": phone_normalized},
    )
    user_row = result.fetchone()
    if user_row and user_row.account_status in ("banned", "suspended"):
        raise AuthError(
            f"This account is {user_row.account_status}. Contact support.",
            code="account_restricted",
        )

    # 3. Rate limit: too many sends today
    today_start = datetime.now(tz=timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    count_result = await db.execute(
        text("""
            SELECT COUNT(*) as cnt FROM otp_codes
            WHERE phone_normalized = :phone AND created_at >= :today
        """),
        {"phone": phone_normalized, "today": today_start},
    )
    daily_count = count_result.fetchone().cnt
    if daily_count >= settings.otp_max_send_per_day:
        raise AuthError(
            "Too many OTP requests today. Try again tomorrow.",
            code="daily_limit_exceeded",
        )

    # 4. Resend cooldown: check most recent OTP
    recent_result = await db.execute(
        text("""
            SELECT created_at FROM otp_codes
            WHERE phone_normalized = :phone
              AND invalidated_at IS NULL
              AND is_used = FALSE
            ORDER BY created_at DESC
            LIMIT 1
        """),
        {"phone": phone_normalized},
    )
    recent = recent_result.fetchone()
    if recent:
        elapsed = (datetime.now(tz=timezone.utc) - recent.created_at.replace(tzinfo=timezone.utc)).total_seconds()
        if elapsed < settings.otp_resend_cooldown_seconds:
            remaining = int(settings.otp_resend_cooldown_seconds - elapsed)
            raise AuthError(
                f"Please wait {remaining} seconds before requesting a new OTP.",
                code="resend_cooldown",
            )

    # 5. Invalidate all previous active OTPs for this number
    await db.execute(
        text("""
            UPDATE otp_codes
            SET invalidated_at = NOW()
            WHERE phone_normalized = :phone
              AND invalidated_at IS NULL
              AND is_used = FALSE
        """),
        {"phone": phone_normalized},
    )

    # 6. Generate OTP and hash it
    otp = generate_otp(settings.otp_length)
    otp_hash = hash_otp(otp)
    expires_at = datetime.now(tz=timezone.utc) + timedelta(minutes=settings.otp_expire_minutes)

    # 7. Store hashed OTP
    await db.execute(
        text("""
            INSERT INTO otp_codes (phone_normalized, otp_hash, expires_at, ip_address, user_agent)
            VALUES (:phone, :otp_hash, :expires_at, :ip, :ua)
        """),
        {
            "phone": phone_normalized,
            "otp_hash": otp_hash,
            "expires_at": expires_at,
            "ip": ip_address,
            "ua": user_agent,
        },
    )

    # 8. Send via WhatsApp
    wa_service = get_whatsapp_service()
    send_result = await wa_service.send_otp(phone_normalized, otp)

    if not send_result.success:
        # Invalidate the OTP we just created since it wasn't delivered
        await db.execute(
            text("""
                UPDATE otp_codes SET invalidated_at = NOW()
                WHERE phone_normalized = :phone AND invalidated_at IS NULL AND is_used = FALSE
            """),
            {"phone": phone_normalized},
        )
        raise AuthError(
            "Could not send OTP via WhatsApp. Please try again.",
            code="whatsapp_unavailable",
        )

    await db.commit()

    logger.info("otp_sent", phone=phone_normalized[:6] + "***", provider=send_result.provider)

    from app.utils.phone import mask_phone
    return {
        "success": True,
        "masked_phone": mask_phone(phone_normalized),
        "resend_after": settings.otp_resend_cooldown_seconds,
        "expires_in_minutes": settings.otp_expire_minutes,
    }


# ---------------------------------------------------------------------------
# Verify OTP
# ---------------------------------------------------------------------------

async def verify_otp_and_login(
    db: AsyncSession,
    phone: str,
    otp: str,
    device_info: Optional[str] = None,
    ip_address: Optional[str] = None,
) -> dict:
    """
    Verify OTP and create/retrieve user session.
    Returns tokens + user info.

    Security rules:
    - Fetch most recent active OTP for this phone
    - Check expiry
    - Check attempt count
    - Verify hash
    - Mark as used
    - Create session
    - Create user if new
    """
    # 1. Normalize phone
    try:
        phone_normalized = normalize_phone(phone)
    except PhoneValidationError as exc:
        raise AuthError(str(exc), code="invalid_phone")

    # 2. Fetch most recent valid OTP
    result = await db.execute(
        text("""
            SELECT id, otp_hash, expires_at, attempts, max_attempts, is_used
            FROM otp_codes
            WHERE phone_normalized = :phone
              AND invalidated_at IS NULL
              AND is_used = FALSE
            ORDER BY created_at DESC
            LIMIT 1
        """),
        {"phone": phone_normalized},
    )
    otp_record = result.fetchone()

    if otp_record is None:
        raise AuthError("No active OTP found. Please request a new one.", code="no_active_otp")

    # 3. Check expiry
    now = datetime.now(tz=timezone.utc)
    otp_expires = otp_record.expires_at.replace(tzinfo=timezone.utc)
    if now > otp_expires:
        raise AuthError("OTP has expired. Please request a new one.", code="otp_expired")

    # 4. Check attempt limit
    if otp_record.attempts >= otp_record.max_attempts:
        raise AuthError(
            "Too many incorrect attempts. Please request a new OTP.",
            code="max_attempts_exceeded",
        )

    # 5. Verify OTP (constant-time via bcrypt)
    is_valid = verify_otp(otp, otp_record.otp_hash)

    # Increment attempts regardless of result
    await db.execute(
        text("UPDATE otp_codes SET attempts = attempts + 1 WHERE id = :id"),
        {"id": otp_record.id},
    )

    if not is_valid:
        remaining = otp_record.max_attempts - (otp_record.attempts + 1)
        raise AuthError(
            f"Incorrect OTP. {remaining} attempt(s) remaining.",
            code="invalid_otp",
        )

    # 6. Mark OTP as used
    await db.execute(
        text("UPDATE otp_codes SET is_used = TRUE, used_at = NOW() WHERE id = :id"),
        {"id": otp_record.id},
    )

    # 7. Get or create user
    user_result = await db.execute(
        text("""
            SELECT id, account_status, onboarding_completed
            FROM users
            WHERE phone_normalized = :phone AND deleted_at IS NULL
        """),
        {"phone": phone_normalized},
    )
    user_row = user_result.fetchone()

    is_new_user = user_row is None

    if is_new_user:
        # Create new user
        user_insert = await db.execute(
            text("""
                INSERT INTO users (phone, phone_country_code, phone_normalized, account_status)
                VALUES (:phone, :cc, :phone_normalized, 'pending_verification')
                RETURNING id, account_status, onboarding_completed
            """),
            {
                "phone": phone_normalized,
                "cc": phone_normalized[:3],  # +91, +1 etc
                "phone_normalized": phone_normalized,
            },
        )
        user_row = user_insert.fetchone()
        logger.info("new_user_created", user_id=str(user_row.id))

    user_id = user_row.id
    account_status = user_row.account_status

    if account_status in ("banned", "suspended"):
        raise AuthError(
            f"Account is {account_status}. Contact support.",
            code="account_restricted",
        )

    # 8. Create tokens
    access_token = create_access_token(user_id)
    raw_refresh, hashed_refresh = create_refresh_token()
    refresh_expires = datetime.now(tz=timezone.utc) + timedelta(days=settings.jwt_refresh_token_expire_days)

    # 9. Create session
    await db.execute(
        text("""
            INSERT INTO sessions (user_id, refresh_token_hash, device_info, ip_address, expires_at)
            VALUES (:user_id, :token_hash, :device, :ip, :expires)
        """),
        {
            "user_id": user_id,
            "token_hash": hashed_refresh,
            "device": device_info,
            "ip": ip_address,
            "expires": refresh_expires,
        },
    )

    # 10. Update last_active
    await db.execute(
        text("UPDATE users SET last_active_at = NOW() WHERE id = :user_id"),
        {"user_id": user_id},
    )

    await db.commit()

    await log_action(
        db, "user", user_id, "login",
        details={"is_new_user": is_new_user, "ip": ip_address}
    )

    logger.info("user_logged_in", user_id=str(user_id), is_new=is_new_user)

    return {
        "access_token": access_token,
        "refresh_token": raw_refresh,
        "token_type": "Bearer",
        "user_id": str(user_id),
        "is_new_user": is_new_user,
        "onboarding_completed": user_row.onboarding_completed,
        "account_status": account_status,
    }


# ---------------------------------------------------------------------------
# Refresh Token
# ---------------------------------------------------------------------------

async def refresh_access_token(
    db: AsyncSession,
    refresh_token: str,
) -> dict:
    """Exchange a valid refresh token for a new access token."""
    token_hash = hash_token(refresh_token)

    result = await db.execute(
        text("""
            SELECT s.id, s.user_id, s.expires_at, s.revoked_at,
                   u.account_status
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.refresh_token_hash = :hash
              AND s.revoked_at IS NULL
        """),
        {"hash": token_hash},
    )
    session = result.fetchone()

    if session is None:
        raise AuthError("Invalid refresh token", code="invalid_refresh_token")

    expires_at = session.expires_at.replace(tzinfo=timezone.utc)
    if datetime.now(tz=timezone.utc) > expires_at:
        raise AuthError("Refresh token expired", code="refresh_token_expired")

    if session.account_status in ("banned", "suspended"):
        raise AuthError("Account restricted", code="account_restricted")

    new_access_token = create_access_token(session.user_id)

    # Rotate refresh token
    new_raw, new_hash = create_refresh_token()
    new_expires = datetime.now(tz=timezone.utc) + timedelta(days=settings.jwt_refresh_token_expire_days)

    await db.execute(
        text("UPDATE sessions SET revoked_at = NOW(), revoked_reason = 'rotated' WHERE id = :id"),
        {"id": session.id},
    )
    await db.execute(
        text("""
            INSERT INTO sessions (user_id, refresh_token_hash, expires_at)
            VALUES (:user_id, :hash, :expires)
        """),
        {"user_id": session.user_id, "hash": new_hash, "expires": new_expires},
    )
    await db.commit()

    return {
        "access_token": new_access_token,
        "refresh_token": new_raw,
        "token_type": "Bearer",
    }


# ---------------------------------------------------------------------------
# Logout
# ---------------------------------------------------------------------------

async def logout(
    db: AsyncSession,
    user_id: UUID,
    refresh_token: Optional[str] = None,
) -> None:
    """Revoke session. If refresh_token provided, revoke specific session; else revoke all."""
    if refresh_token:
        token_hash = hash_token(refresh_token)
        await db.execute(
            text("""
                UPDATE sessions SET revoked_at = NOW(), revoked_reason = 'logout'
                WHERE user_id = :user_id AND refresh_token_hash = :hash
            """),
            {"user_id": user_id, "hash": token_hash},
        )
    else:
        await db.execute(
            text("""
                UPDATE sessions SET revoked_at = NOW(), revoked_reason = 'logout_all'
                WHERE user_id = :user_id AND revoked_at IS NULL
            """),
            {"user_id": user_id},
        )
    await db.commit()
