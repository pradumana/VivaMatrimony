"""
Authentication Service — Phase 5 update: Firebase UID + user_identity_map.

Supabase Auth is no longer used for identity. Firebase Auth provides the UID.
This service manages:
  - Looking up the internal users.id UUID from a Firebase UID string
  - Creating new users rows with a fresh UUID PK
  - Populating user_identity_map for the firebase_uid ↔ users.id mapping
  - Keeping users rows up to date (email, consent, last_active_at)
"""
import structlog
from typing import Optional
from uuid import UUID, uuid4

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
    firebase_uid: str,           # Firebase UID string from JWT sub
    email: Optional[str],
    privacy_policy_accepted: bool = False,
    terms_accepted: bool = False,
) -> dict:
    """
    Ensure a users row and user_identity_map entry exist for the given Firebase UID.
    Called after every successful Firebase sign-in/sign-up.
    Idempotent — safe to call multiple times.

    firebase_uid = Firebase UID string (JWT "sub"). NOT a UUID.
    email        = from the validated JWT claim; never from untrusted client body.

    Returns:
        is_new_user               bool
        onboarding_completed      bool
        account_status            str
        member_id                 str | None
        privacy_policy_accepted   bool
        terms_accepted            bool
        onboarding_step           str | None
    """
    # Step 1: Look up existing mapping firebase_uid → users.id
    mapping = await db.execute(
        text("""
            SELECT uim.supabase_user_id, u.account_status,
                   u.onboarding_completed, u.member_id,
                   u.privacy_policy_accepted, u.terms_accepted,
                   u.onboarding_step
            FROM user_identity_map uim
            JOIN users u ON u.id = uim.supabase_user_id
            WHERE uim.firebase_uid = :fuid
              AND u.deleted_at IS NULL
        """),
        {"fuid": firebase_uid},
    )
    row = mapping.fetchone()

    if row is not None:
        # Existing user — check account status
        if row.account_status in ("banned", "suspended"):
            raise AuthError(
                f"Account is {row.account_status}. Contact support.",
                code="account_restricted",
            )

        # Update mutable fields on re-login
        update_fields = ["last_active_at = NOW()"]
        params: dict = {"uid": row.supabase_user_id}
        if email:
            update_fields.append("email = :email")
            params["email"] = email
        if privacy_policy_accepted and not row.privacy_policy_accepted:
            update_fields.append(
                "privacy_policy_accepted = TRUE, privacy_policy_accepted_at = NOW()"
            )
        if terms_accepted and not row.terms_accepted:
            update_fields.append(
                "terms_accepted = TRUE, terms_accepted_at = NOW()"
            )

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

    # Step 2: New user — create users row with a fresh UUID PK, then
    # insert into user_identity_map.
    new_uuid = uuid4()

    await db.execute(
        text("""
            INSERT INTO users (
                id, email, firebase_uid, account_status,
                privacy_policy_accepted, privacy_policy_accepted_at,
                terms_accepted, terms_accepted_at
            )
            VALUES (
                :uid, :email, :fuid, 'pending_verification',
                :ppa, CASE WHEN :ppa THEN NOW() ELSE NULL END,
                :ta,  CASE WHEN :ta  THEN NOW() ELSE NULL END
            )
            ON CONFLICT (id) DO NOTHING
        """),
        {
            "uid": new_uuid,
            "email": email,
            "fuid": firebase_uid,
            "ppa": privacy_policy_accepted,
            "ta": terms_accepted,
        },
    )

    # Insert identity map entry
    await db.execute(
        text("""
            INSERT INTO user_identity_map (supabase_user_id, firebase_uid, email)
            VALUES (:uid, :fuid, :email)
            ON CONFLICT (firebase_uid) DO NOTHING
        """),
        {"uid": new_uuid, "fuid": firebase_uid, "email": email},
    )
    await db.commit()

    # Fetch the freshly created row
    new_row = await db.execute(
        text("""
            SELECT id, account_status, onboarding_completed, member_id,
                   privacy_policy_accepted, terms_accepted, onboarding_step
            FROM users WHERE id = :uid
        """),
        {"uid": new_uuid},
    )
    created = new_row.fetchone()

    logger.info("new_user_created", firebase_uid=firebase_uid, user_id=str(new_uuid))

    return {
        "is_new_user": True,
        "onboarding_completed": created.onboarding_completed,
        "account_status": created.account_status,
        "member_id": created.member_id,
        "privacy_policy_accepted": created.privacy_policy_accepted,
        "terms_accepted": created.terms_accepted,
        "onboarding_step": created.onboarding_step,
    }
