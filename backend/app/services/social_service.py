"""
Social Service — Interests, Shortlist, Messaging, Block, Report.
"""
import structlog
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.utils import log_action

logger = structlog.get_logger()


class SocialError(Exception):
    def __init__(self, message: str, code: str = "error"):
        super().__init__(message)
        self.code = code


# ---------------------------------------------------------------------------
# Interests
# ---------------------------------------------------------------------------

async def send_interest(db: AsyncSession, sender_id: UUID, receiver_id: UUID) -> dict:
    """Send interest to another user."""
    if sender_id == receiver_id:
        raise SocialError("Cannot send interest to yourself.", code="self_interest")

    # Check receiver exists and is active
    result = await db.execute(
        text("""
            SELECT u.account_status, u.deleted_at
            FROM users u WHERE u.id = :uid
        """),
        {"uid": receiver_id},
    )
    receiver = result.fetchone()
    if not receiver or receiver.deleted_at or receiver.account_status in ("banned", "suspended"):
        raise SocialError("This profile is not available.", code="profile_unavailable")

    # Check block
    block_check = await db.execute(
        text("""
            SELECT 1 FROM blocks
            WHERE (blocker_id = :a AND blocked_id = :b) OR (blocker_id = :b AND blocked_id = :a)
            LIMIT 1
        """),
        {"a": sender_id, "b": receiver_id},
    )
    if block_check.fetchone():
        raise SocialError("Cannot send interest to this user.", code="blocked")

    # Check if already exists
    existing = await db.execute(
        text("""
            SELECT id, status FROM interests
            WHERE sender_id = :sender AND receiver_id = :receiver
        """),
        {"sender": sender_id, "receiver": receiver_id},
    )
    existing_row = existing.fetchone()
    if existing_row:
        if existing_row.status == "sent":
            raise SocialError("Interest already sent.", code="duplicate_interest")
        elif existing_row.status == "declined":
            raise SocialError("Your previous interest was declined.", code="previously_declined")
        elif existing_row.status == "accepted":
            raise SocialError("Interest already accepted. You can message this person.", code="already_connected")
        elif existing_row.status == "withdrawn":
            # Allow re-send after withdrawal
            await db.execute(
                text("""
                    UPDATE interests SET status = 'sent', sent_at = NOW(), updated_at = NOW()
                    WHERE id = :id
                """),
                {"id": existing_row.id},
            )
            await db.commit()
            return {"interest_id": str(existing_row.id), "status": "sent"}

    # Insert new interest
    insert_result = await db.execute(
        text("""
            INSERT INTO interests (sender_id, receiver_id, status)
            VALUES (:sender, :receiver, 'sent')
            RETURNING id
        """),
        {"sender": sender_id, "receiver": receiver_id},
    )
    interest_id = insert_result.fetchone().id

    await db.commit()

    # Queue notification (fire and forget)
    await _notify_interest(db, sender_id, receiver_id, str(interest_id))

    logger.info("interest_sent", sender=str(sender_id), receiver=str(receiver_id))
    return {"interest_id": str(interest_id), "status": "sent"}


async def accept_interest(db: AsyncSession, interest_id: UUID, user_id: UUID) -> dict:
    """
    Accept an interest.
    After acceptance both parties can communicate directly on WhatsApp.
    Returns the other user's phone number (E.164) for the WhatsApp deep-link.
    Phone is only disclosed after verified mutual acceptance — never before.
    """
    result = await db.execute(
        text("""
            SELECT i.id, i.sender_id, i.receiver_id, i.status,
                   u_sender.phone_normalized as sender_phone,
                   u_receiver.phone_normalized as receiver_phone
            FROM interests i
            JOIN users u_sender   ON u_sender.id   = i.sender_id
            JOIN users u_receiver ON u_receiver.id = i.receiver_id
            WHERE i.id = :iid
        """),
        {"iid": interest_id},
    )
    interest = result.fetchone()

    if not interest:
        raise SocialError("Interest not found.", code="not_found")
    if interest.receiver_id != user_id:
        raise SocialError("You cannot accept this interest.", code="unauthorized")
    if interest.status != "sent":
        raise SocialError(f"Interest is already {interest.status}.", code="invalid_state")

    await db.execute(
        text("""
            UPDATE interests SET status = 'accepted', accepted_at = NOW(), updated_at = NOW()
            WHERE id = :iid
        """),
        {"iid": interest_id},
    )

    await db.commit()

    await _notify_interest_accepted(db, user_id, interest.sender_id, str(interest_id))

    # Determine which phone belongs to the OTHER party from each user's perspective.
    # The receiver (user_id) accepted — so the other party is the sender.
    other_phone = interest.sender_phone

    return {
        "interest_id": str(interest_id),
        "status": "accepted",
        # Stripped of + for wa.me URL: wa.me/919876543210
        "whatsapp_number": other_phone.lstrip("+"),
        "whatsapp_url": f"https://wa.me/{other_phone.lstrip('+')}",
    }


async def get_whatsapp_contact(
    db: AsyncSession,
    interest_id: UUID,
    requesting_user_id: UUID,
) -> dict:
    """
    Returns the WhatsApp link for the other party in an accepted interest.
    Callable by either the sender or receiver after acceptance.
    Security: verifies the requesting user is a party to the interest
              and that the interest status is 'accepted'.
    """
    result = await db.execute(
        text("""
            SELECT i.sender_id, i.receiver_id, i.status,
                   u_sender.phone_normalized   as sender_phone,
                   u_receiver.phone_normalized as receiver_phone,
                   ps.full_name as sender_name,
                   pr.full_name as receiver_name
            FROM interests i
            JOIN users u_sender   ON u_sender.id   = i.sender_id
            JOIN users u_receiver ON u_receiver.id = i.receiver_id
            LEFT JOIN profiles ps ON ps.user_id = i.sender_id
            LEFT JOIN profiles pr ON pr.user_id = i.receiver_id
            WHERE i.id = :iid
        """),
        {"iid": interest_id},
    )
    row = result.fetchone()

    if not row:
        raise SocialError("Interest not found.", code="not_found")

    # Must be a party to this interest
    if requesting_user_id not in (row.sender_id, row.receiver_id):
        raise SocialError("Access denied.", code="unauthorized")

    # Must be accepted
    if row.status != "accepted":
        raise SocialError(
            "WhatsApp contact is only available after the interest is accepted.",
            code="not_accepted",
        )

    # Return the OTHER party's details
    if requesting_user_id == row.sender_id:
        other_phone = row.receiver_phone
        other_name  = row.receiver_name
    else:
        other_phone = row.sender_phone
        other_name  = row.sender_name

    stripped = other_phone.lstrip("+")
    return {
        "full_name": other_name,
        "whatsapp_number": stripped,
        "whatsapp_url": f"https://wa.me/{stripped}",
    }


async def decline_interest(db: AsyncSession, interest_id: UUID, user_id: UUID) -> dict:
    result = await db.execute(
        text("SELECT receiver_id, status FROM interests WHERE id = :iid"),
        {"iid": interest_id},
    )
    interest = result.fetchone()

    if not interest or interest.receiver_id != user_id:
        raise SocialError("Interest not found.", code="not_found")
    if interest.status != "sent":
        raise SocialError("Interest cannot be declined in its current state.", code="invalid_state")

    await db.execute(
        text("""
            UPDATE interests SET status = 'declined', declined_at = NOW(), updated_at = NOW()
            WHERE id = :iid
        """),
        {"iid": interest_id},
    )
    await db.commit()
    return {"interest_id": str(interest_id), "status": "declined"}


async def withdraw_interest(db: AsyncSession, interest_id: UUID, user_id: UUID) -> dict:
    result = await db.execute(
        text("SELECT sender_id, status FROM interests WHERE id = :iid"),
        {"iid": interest_id},
    )
    interest = result.fetchone()

    if not interest or interest.sender_id != user_id:
        raise SocialError("Interest not found.", code="not_found")
    if interest.status not in ("sent",):
        raise SocialError("Interest cannot be withdrawn in its current state.", code="invalid_state")

    await db.execute(
        text("""
            UPDATE interests SET status = 'withdrawn', withdrawn_at = NOW(), updated_at = NOW()
            WHERE id = :iid
        """),
        {"iid": interest_id},
    )
    await db.commit()
    return {"interest_id": str(interest_id), "status": "withdrawn"}


async def get_interests_sent(db: AsyncSession, user_id: UUID, limit: int = 20, offset: int = 0) -> list:
    result = await db.execute(
        text("""
            SELECT i.id, i.receiver_id, i.status, i.sent_at,
                   p.full_name, p.date_of_birth,
                   ph.storage_path as photo_path,
                   cl.city, cl.state
            FROM interests i
            JOIN profiles p ON p.user_id = i.receiver_id
            LEFT JOIN photos ph ON ph.user_id = i.receiver_id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
            LEFT JOIN current_locations cl ON cl.user_id = i.receiver_id
            WHERE i.sender_id = :uid
            ORDER BY i.sent_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"uid": user_id, "limit": limit, "offset": offset},
    )
    return [_format_interest_row(row) for row in result.fetchall()]


async def get_interests_received(db: AsyncSession, user_id: UUID, limit: int = 20, offset: int = 0) -> list:
    result = await db.execute(
        text("""
            SELECT i.id, i.sender_id, i.status, i.sent_at,
                   p.full_name, p.date_of_birth,
                   ph.storage_path as photo_path,
                   cl.city, cl.state
            FROM interests i
            JOIN profiles p ON p.user_id = i.sender_id
            LEFT JOIN photos ph ON ph.user_id = i.sender_id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
            LEFT JOIN current_locations cl ON cl.user_id = i.sender_id
            WHERE i.receiver_id = :uid
            ORDER BY i.sent_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"uid": user_id, "limit": limit, "offset": offset},
    )
    return [_format_interest_row(row) for row in result.fetchall()]


def _format_interest_row(row) -> dict:
    from datetime import date
    dob = row.date_of_birth
    age = date.today().year - dob.year - (
        (date.today().month, date.today().day) < (dob.month, dob.day)
    ) if dob else None

    other_id = getattr(row, "receiver_id", None) or getattr(row, "sender_id", None)
    return {
        "interest_id": str(row.id),
        "user_id": str(other_id),
        "full_name": row.full_name,
        "age": age,
        "location": f"{row.city}, {row.state}" if row.city and row.state else (row.state or ""),
        "status": row.status,
        "sent_at": row.sent_at,
    }


# ---------------------------------------------------------------------------
# Shortlist
# ---------------------------------------------------------------------------

async def add_to_shortlist(db: AsyncSession, user_id: UUID, target_id: UUID, notes: Optional[str] = None) -> dict:
    if user_id == target_id:
        raise SocialError("Cannot shortlist yourself.", code="self_shortlist")

    # Check target exists
    exists_result = await db.execute(
        text("SELECT 1 FROM users WHERE id = :uid AND deleted_at IS NULL"),
        {"uid": target_id},
    )
    if not exists_result.fetchone():
        raise SocialError("User not found.", code="not_found")

    # Upsert
    await db.execute(
        text("""
            INSERT INTO shortlists (user_id, target_user_id, private_notes)
            VALUES (:uid, :target, :notes)
            ON CONFLICT (user_id, target_user_id) DO UPDATE SET private_notes = EXCLUDED.private_notes
        """),
        {"uid": user_id, "target": target_id, "notes": notes},
    )
    await db.commit()
    return {"success": True, "target_user_id": str(target_id)}


async def remove_from_shortlist(db: AsyncSession, user_id: UUID, target_id: UUID) -> dict:
    await db.execute(
        text("DELETE FROM shortlists WHERE user_id = :uid AND target_user_id = :target"),
        {"uid": user_id, "target": target_id},
    )
    await db.commit()
    return {"success": True}


async def get_shortlist(db: AsyncSession, user_id: UUID, limit: int = 20, offset: int = 0) -> list:
    result = await db.execute(
        text("""
            SELECT s.target_user_id, s.private_notes, s.created_at,
                   p.full_name, p.date_of_birth,
                   ph.storage_path as photo_path,
                   cl.city, cl.state, u.verification_status
            FROM shortlists s
            JOIN users u ON u.id = s.target_user_id AND u.deleted_at IS NULL
            JOIN profiles p ON p.user_id = s.target_user_id
            LEFT JOIN photos ph ON ph.user_id = s.target_user_id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
            LEFT JOIN current_locations cl ON cl.user_id = s.target_user_id
            WHERE s.user_id = :uid
            ORDER BY s.created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"uid": user_id, "limit": limit, "offset": offset},
    )
    rows = result.fetchall()
    items = []
    from datetime import date
    for row in rows:
        dob = row.date_of_birth
        age = date.today().year - dob.year - (
            (date.today().month, date.today().day) < (dob.month, dob.day)
        ) if dob else None
        items.append({
            "user_id": str(row.target_user_id),
            "full_name": row.full_name,
            "age": age,
            "location": f"{row.city}, {row.state}" if row.city and row.state else (row.state or ""),
            "is_verified": row.verification_status == "verified",
            "private_notes": row.private_notes,  # ONLY visible to owner
            "shortlisted_at": row.created_at,
        })
    return items


# ---------------------------------------------------------------------------
# Block
# ---------------------------------------------------------------------------

async def block_user(db: AsyncSession, blocker_id: UUID, blocked_id: UUID) -> dict:
    if blocker_id == blocked_id:
        raise SocialError("Cannot block yourself.", code="self_block")

    await db.execute(
        text("""
            INSERT INTO blocks (blocker_id, blocked_id)
            VALUES (:blocker, :blocked)
            ON CONFLICT (blocker_id, blocked_id) DO NOTHING
        """),
        {"blocker": blocker_id, "blocked": blocked_id},
    )
    await db.commit()
    await log_action(db, "user", blocker_id, "block_user", "user", blocked_id)
    return {"success": True, "blocked_user_id": str(blocked_id)}


async def unblock_user(db: AsyncSession, blocker_id: UUID, blocked_id: UUID) -> dict:
    await db.execute(
        text("DELETE FROM blocks WHERE blocker_id = :blocker AND blocked_id = :blocked"),
        {"blocker": blocker_id, "blocked": blocked_id},
    )
    await db.commit()
    return {"success": True}


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

VALID_REPORT_REASONS = {
    "fake_profile", "fraud", "harassment", "impersonation",
    "offensive_content", "financial_solicitation", "suspicious_behavior", "other"
}


async def report_user(
    db: AsyncSession,
    reporter_id: UUID,
    reported_id: UUID,
    reason: str,
    description: Optional[str] = None,
) -> dict:
    if reporter_id == reported_id:
        raise SocialError("Cannot report yourself.", code="self_report")

    if reason not in VALID_REPORT_REASONS:
        raise SocialError(f"Invalid reason. Valid: {', '.join(VALID_REPORT_REASONS)}", code="invalid_reason")

    # Check reported user exists
    exists = await db.execute(
        text("SELECT 1 FROM users WHERE id = :uid AND deleted_at IS NULL"),
        {"uid": reported_id},
    )
    if not exists.fetchone():
        raise SocialError("User not found.", code="not_found")

    insert_result = await db.execute(
        text("""
            INSERT INTO reports (reporter_id, reported_id, reason, description)
            VALUES (:reporter, :reported, :reason, :desc)
            RETURNING id
        """),
        {"reporter": reporter_id, "reported": reported_id, "reason": reason, "desc": description},
    )
    report_id = insert_result.fetchone().id
    await db.commit()

    logger.info("user_reported", reporter=str(reporter_id), reported=str(reported_id), reason=reason)
    return {"report_id": str(report_id), "status": "submitted"}


# ---------------------------------------------------------------------------
# Notification helpers (simple DB-based notifications)
# ---------------------------------------------------------------------------

async def _notify_interest(db: AsyncSession, sender_id: UUID, receiver_id: UUID, interest_id: str):
    sender_profile = await db.execute(
        text("SELECT full_name FROM profiles WHERE user_id = :uid"),
        {"uid": sender_id},
    )
    row = sender_profile.fetchone()
    name = row.full_name if row else "Someone"

    await db.execute(
        text("""
            INSERT INTO notifications (user_id, type, title, body, actor_user_id, entity_type, entity_id)
            VALUES (:uid, 'interest_received', :title, :body, :actor, 'interest', :eid)
        """),
        {
            "uid": receiver_id,
            "title": "New Interest",
            "body": f"{name} is interested in your profile.",
            "actor": sender_id,
            "eid": interest_id,
        },
    )


async def _notify_interest_accepted(db: AsyncSession, accepter_id: UUID, sender_id: UUID, interest_id: str):
    profile_result = await db.execute(
        text("SELECT full_name FROM profiles WHERE user_id = :uid"),
        {"uid": accepter_id},
    )
    row = profile_result.fetchone()
    name = row.full_name if row else "Someone"

    await db.execute(
        text("""
            INSERT INTO notifications (user_id, type, title, body, actor_user_id, entity_type, entity_id)
            VALUES (:uid, 'interest_accepted', :title, :body, :actor, 'interest', :eid)
        """),
        {
            "uid": sender_id,
            "title": "Interest Accepted! 🎉",
            "body": f"{name} accepted your interest. Open the app to connect on WhatsApp.",
            "actor": accepter_id,
            "eid": interest_id,
        },
    )


async def _notify_new_message(db, sender_id, receiver_id, conv_id):
    # Retained as no-op stub — messaging is now handled on WhatsApp
    pass