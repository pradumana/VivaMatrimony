"""
Authentication endpoints.

POST /auth/register  — create users row after Supabase Auth signup (idempotent)
POST /auth/logout    — best-effort audit log; session revoked by Supabase
GET  /auth/me        — return current user identity

WhatsApp / OTP endpoints removed in migration 005.
Session management is fully handled by Supabase Auth SDK on the client.
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware import get_current_user, get_jwt_user, AuthenticatedUser
from app.schemas.auth import RegisterRequest, MeResponse
from app.services.auth_service import AuthError, get_or_create_user
from app.utils.audit import log_action
from app.config import get_settings

settings = get_settings()
router = APIRouter(prefix="/auth", tags=["Authentication"])


def _get_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/register", status_code=status.HTTP_200_OK)
async def register(
    body: Optional[RegisterRequest] = None,
    current_user: AuthenticatedUser = Depends(get_jwt_user),  # no DB lookup — row may not exist yet
    db: AsyncSession = Depends(get_db),
    request: Request = None,
):
    """
    Called by the Flutter app immediately after Supabase Auth signUp/signIn.
    Creates a users row if it doesn't exist yet (idempotent).
    Returns onboarding state so the client can route correctly.

    The Supabase JWT is already validated by get_current_user — the user_id
    in the token IS the authoritative identity. We never accept user_id from
    the request body.
    """
    try:
        result = await get_or_create_user(
            db=db,
            user_id=current_user.user_id,
            email=current_user.email or (body.email if body else None),
        )
    except AuthError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    await log_action(
        db, "user", current_user.user_id, "register_or_login",
        details={"is_new": result["is_new_user"], "ip": _get_ip(request) if request else None},
    )

    return result


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    request: Request = None,
):
    """
    Audit-log the logout. The actual session revocation is done by
    Supabase Auth on the client (supabase.auth.signOut()).
    This endpoint is best-effort — the client should call it but a failure
    here must never block the local signOut.
    """
    await log_action(
        db, "user", current_user.user_id, "logout",
        details={"ip": _get_ip(request) if request else None},
    )


@router.get("/me", response_model=MeResponse)
async def me(
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Return current user identity from validated JWT."""
    return MeResponse(
        user_id=str(current_user.user_id),
        email=current_user.email,
        account_status=current_user.account_status,
        onboarding_completed=current_user.onboarding_completed,
    )
