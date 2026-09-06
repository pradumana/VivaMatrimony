"""
Authentication Service.
Supabase Auth handles credentials and sessions.
This service only manages the VIVA users table row lifecycle.
"""
import structlog
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.utils.audit import log_action

logger = structlog.get_logger()


class AuthError(Exception):
    """Domain error for auth operations."""
    def __init__(self, message: str, code: str = "auth_error"):
        super().__init__(message)
        self.code = code


async def get_or_create_user(
    db: AsyncSession,
    user_id: UUID,
    email: Optional[str],
) -> dict:
    """
    Ensure a users row exists for the given Supabase Auth user.
    Called after every successful Supabase sign-in/sign-up.
    Idempotent — safe to call multiple times.

    user_id  = Supabase Auth UID (JWT "sub"), used as our users.id PK.
    email    = from the validated JWT claim; never from untrusted client body.

    Returns:
        is_new_user          bool
        onboarding_completed bool
        account_status       str
        member_id            str | None
    """
    # Look up existing user
    result = await db.execute(
        text("""
            SELECT id, account_status, onboarding_completed, member_id
            FROM users
            WHERE id = :uid AND deleted_at IS NULL
        """),
        {"uid": user_id},
    )
    row = result.fetchone()

    if row is not None:
        # User exists — check account status
        if row.account_status in ("banned", "suspended"):
            raise AuthError(
                f"Account is {row.account_status}. Contact support.",
                code="account_restricted",
            )

        # Update email if it changed (e.g. user updated email in Supabase dashboard)
        if email:
            await db.execute(
                text("UPDATE users SET email = :email, last_active_at = NOW() WHERE id = :uid"),
                {"email": email, "uid": user_id},
            )
            await db.commit()

        return {
            "is_new_user": False,
            "onboarding_completed": row.onboarding_completed,
            "account_status": row.account_status,
            "member_id": row.member_id,
        }

    # New user — create the row using the Supabase Auth UUID as the PK.
    # account_status starts as 'pending_verification' (matches existing flow).
    new_user = await db.execute(
        text("""
            INSERT INTO users (id, email, account_status, supabase_uid)
            VALUES (:uid, :email, 'pending_verification', :suid)
            ON CONFLICT (id) DO UPDATE
                SET email = EXCLUDED.email,
                    last_active_at = NOW()
            RETURNING id, account_status, onboarding_completed, member_id
        """),
        {"uid": user_id, "email": email, "suid": user_id},
    )
    new_row = new_user.fetchone()
    await db.commit()

    logger.info("new_user_created", user_id=str(user_id))

    return {
        "is_new_user": True,
        "onboarding_completed": new_row.onboarding_completed,
        "account_status": new_row.account_status,
        "member_id": new_row.member_id,
    }
