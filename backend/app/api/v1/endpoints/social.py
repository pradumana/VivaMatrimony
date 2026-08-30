"""
Social endpoints: Interests, Shortlist, Conversations, Messages, Block, Report.
"""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware import get_current_user, AuthenticatedUser
from app.services.social_service import (
    SocialError,
    send_interest, accept_interest, decline_interest, withdraw_interest,
    get_interests_sent, get_interests_received,
    get_whatsapp_contact,
    add_to_shortlist, remove_from_shortlist, get_shortlist,
    block_user, unblock_user,
    report_user,
)

router = APIRouter(tags=["Social"])


def _handle_social_error(exc: SocialError) -> HTTPException:
    code_map = {
        "self_interest": 400, "duplicate_interest": 409,
        "profile_unavailable": 404, "blocked": 403,
        "not_found": 404, "unauthorized": 403, "invalid_state": 409,
        "previously_declined": 409, "already_connected": 409,
        "self_shortlist": 400, "self_block": 400,
        "self_report": 400, "invalid_reason": 422,
        "empty_message": 422, "message_too_long": 422,
        "error": 400,
    }
    return HTTPException(
        status_code=code_map.get(exc.code, 400),
        detail=str(exc),
    )


# ---------------------------------------------------------------------------
# Interests
# ---------------------------------------------------------------------------

@router.post("/interests/{user_id}", status_code=status.HTTP_201_CREATED)
async def send_interest_endpoint(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Send interest to a user."""
    try:
        return await send_interest(db, current_user.user_id, user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.post("/interests/{interest_id}/accept")
async def accept_interest_endpoint(
    interest_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await accept_interest(db, interest_id, current_user.user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.post("/interests/{interest_id}/decline")
async def decline_interest_endpoint(
    interest_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await decline_interest(db, interest_id, current_user.user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.post("/interests/{interest_id}/withdraw")
async def withdraw_interest_endpoint(
    interest_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await withdraw_interest(db, interest_id, current_user.user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.get("/interests/sent")
async def get_sent_interests(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    items = await get_interests_sent(db, current_user.user_id, limit, offset)
    return {"interests": items, "count": len(items)}


@router.get("/interests/received")
async def get_received_interests(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    items = await get_interests_received(db, current_user.user_id, limit, offset)
    return {"interests": items, "count": len(items)}


# ---------------------------------------------------------------------------
# Shortlist
# ---------------------------------------------------------------------------

class ShortlistRequest(BaseModel):
    private_notes: Optional[str] = None


@router.post("/shortlist/{user_id}", status_code=status.HTTP_201_CREATED)
async def shortlist_user(
    user_id: UUID,
    body: ShortlistRequest = ShortlistRequest(),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await add_to_shortlist(db, current_user.user_id, user_id, body.private_notes)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.delete("/shortlist/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_shortlist(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await remove_from_shortlist(db, current_user.user_id, user_id)


@router.get("/shortlist")
async def get_my_shortlist(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    items = await get_shortlist(db, current_user.user_id, limit, offset)
    return {"shortlist": items, "count": len(items)}


# ---------------------------------------------------------------------------
# WhatsApp Contact — revealed only after mutual acceptance
# ---------------------------------------------------------------------------

@router.get("/interests/{interest_id}/whatsapp")
async def get_whatsapp_link(
    interest_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns a WhatsApp deep-link for the other party.
    Only available after both parties have a mutually accepted interest.
    Phone number is NEVER exposed before acceptance.
    """
    try:
        return await get_whatsapp_contact(db, interest_id, current_user.user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


# ---------------------------------------------------------------------------
# Block
# ---------------------------------------------------------------------------

@router.post("/users/{user_id}/block", status_code=status.HTTP_201_CREATED)
async def block_user_endpoint(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await block_user(db, current_user.user_id, user_id)
    except SocialError as exc:
        raise _handle_social_error(exc)


@router.delete("/users/{user_id}/block", status_code=status.HTTP_204_NO_CONTENT)
async def unblock_user_endpoint(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await unblock_user(db, current_user.user_id, user_id)


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

class ReportRequest(BaseModel):
    reason: str
    description: Optional[str] = None


@router.post("/reports", status_code=status.HTTP_201_CREATED)
async def report_user_endpoint(
    reported_user_id: UUID,
    body: ReportRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await report_user(db, current_user.user_id, reported_user_id, body.reason, body.description)
    except SocialError as exc:
        raise _handle_social_error(exc)


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

@router.get("/notifications")
async def get_notifications(
    limit: int = Query(30, ge=1, le=100),
    unread_only: bool = Query(False),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import text
    condition = "AND is_read = FALSE" if unread_only else ""
    result = await db.execute(
        text(f"""
            SELECT id, type, title, body, actor_user_id, entity_type, entity_id, is_read, created_at
            FROM notifications
            WHERE user_id = :uid {condition}
            ORDER BY created_at DESC
            LIMIT :limit
        """),
        {"uid": current_user.user_id, "limit": limit},
    )
    rows = result.fetchall()
    return {
        "notifications": [
            {
                "id": str(r.id),
                "type": r.type,
                "title": r.title,
                "body": r.body,
                "is_read": r.is_read,
                "created_at": r.created_at,
                "entity_type": r.entity_type,
                "entity_id": str(r.entity_id) if r.entity_id else None,
            }
            for r in rows
        ]
    }


@router.put("/notifications/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_notification_read(
    notification_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import text
    await db.execute(
        text("UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE id = :nid AND user_id = :uid"),
        {"nid": notification_id, "uid": current_user.user_id},
    )
    await db.commit()
