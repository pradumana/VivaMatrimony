"""
FCM token management endpoints.

POST /fcm/token   — register or refresh the device push token for the current user
DELETE /fcm/token — remove the device push token on logout
"""
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware import get_current_user, AuthenticatedUser

router = APIRouter(prefix="/fcm", tags=["FCM"])


class FcmTokenRequest(BaseModel):
    token: str
    platform: str = "android"  # android | ios


@router.post("/token", status_code=status.HTTP_204_NO_CONTENT)
async def register_token(
    body: FcmTokenRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Register or refresh the FCM device token for the authenticated user."""
    await db.execute(
        text("UPDATE users SET fcm_token = :token WHERE id = :uid"),
        {"token": body.token, "uid": str(current_user.user_id)},
    )
    await db.commit()


@router.delete("/token", status_code=status.HTTP_204_NO_CONTENT)
async def deregister_token(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Remove the FCM device token on logout.
    Prevents push notifications from being delivered to a logged-out device.
    """
    await db.execute(
        text("UPDATE users SET fcm_token = NULL WHERE id = :uid"),
        {"uid": str(current_user.user_id)},
    )
    await db.commit()
