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
    privacy_policy_accepted: bool = False,
    terms_accepted: bool = False,
) -> dict:
    """
    Ensure a users row exists for the given Supabase Auth user.
    Called after every successful Supabase sign-in/sign-up.
    Idempotent — safe to call multiple times.

    user_id  = Supabase Auth UID (JWT "sub"), used as our users.id PK.
    email    = from the validated JWT claim; never from untrusted client body.

    Returns:
        is_new_user               bool
        onboarding_completed      bool
        account_status            str
        member_id                 str | None
        privacy_policy_accepted   bool
        terms_accepted            bool
        onboarding_step           str | None
    """
    # Look up existing user
    result = await db.execute(
        text("""
            SELECT id, account_status, onboarding_completed, member_id,
                   privacy_policy_accepted, terms_accepted, onboarding_step
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

        # Update email and consent fields if provided on re-login
        update_fields = ["last_active_at = NOW()"]
        params: dict = {"uid": user_id}
        if email:
            update_fields.append("email = :email")
            params["email"] = email
        # Only update consent flags if newly accepted (never downgrade to False)
        if privacy_policy_accepted and not row.privacy_policy_accepted:
            update_fields.append("privacy_policy_accepted = TRUE, privacy_policy_accepted_at = NOW()")
        if terms_accepted and not row.terms_accepted:
            update_fields.append("terms_accepted = TRUE, terms_accepted_at = NOW()")

        await db.execute(
            text(f"UPDATE users SET {', '.join(update_fields)} WHERE id = :uid"),
            params,
        )
        await db.commit()

        return {
            "is_new_user": False,
            "onboarding_completed": row.onboarding_completed,
            "account_status": row.account_status,
            "member_id": row.member_id,
            "privacy_policy_accepted": row.privacy_policy_accepted or privacy_policy_accepted,
            "terms_accepted": row.terms_accepted or terms_accepted,
            "onboarding_step": row.onboarding_step,
        }

    # New user — create the row using the Supabase Auth UUID as the PK.
    # account_status starts as 'pending_verification' (matches existing flow).
    new_user = await db.execute(
        text("""
            INSERT INTO users (
                id, email, account_status, supabase_uid,
                privacy_policy_accepted, privacy_policy_accepted_at,
                terms_accepted, terms_accepted_at
            )
            VALUES (
                :uid, :email, 'pending_verification', :suid,
                :ppa, CASE WHEN :ppa THEN NOW() ELSE NULL END,
                :ta,  CASE WHEN :ta  THEN NOW() ELSE NULL END
            )
            ON CONFLICT (id) DO UPDATE
                SET email = EXCLUDED.email,
                    last_active_at = NOW()
            RETURNING id, account_status, onboarding_completed, member_id,
                      privacy_policy_accepted, terms_accepted, onboarding_step
        """),
        {"uid": user_id, "email": email, "suid": user_id,
         "ppa": privacy_policy_accepted, "ta": terms_accepted},
    )
    new_row = new_user.fetchone()
    await db.commit()

    logger.info("new_user_created", user_id=str(user_id))

    return {
        "is_new_user": True,
        "onboarding_completed": new_row.onboarding_completed,
        "account_status": new_row.account_status,
        "member_id": new_row.member_id,
        "privacy_policy_accepted": new_row.privacy_policy_accepted,
        "terms_accepted": new_row.terms_accepted,
        "onboarding_step": new_row.onboarding_step,
    }
