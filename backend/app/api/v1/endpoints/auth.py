"""
Authentication endpoints.
POST /auth/send-otp
POST /auth/verify-otp
POST /auth/refresh
POST /auth/logout
GET  /auth/me
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware import (
    get_current_user, AuthenticatedUser, limiter
)
from app.schemas.auth import (
    SendOTPRequest, SendOTPResponse,
    VerifyOTPRequest, VerifyOTPResponse,
    RefreshTokenRequest, TokenResponse,
    MeResponse,
)
from app.services.auth_service import (
    AuthError,
    send_otp,
    verify_otp_and_login,
    refresh_access_token,
    logout,
)
from app.utils.phone import mask_phone
from app.config import get_settings

settings = get_settings()
router = APIRouter(prefix="/auth", tags=["Authentication"])


def _get_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/send-otp", response_model=SendOTPResponse)
@limiter.limit("5/hour")
async def send_otp_endpoint(
    request: Request,
    body: SendOTPRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Send OTP to a WhatsApp number.
    Rate limited: 5 per hour per IP.
    """
    try:
        result = await send_otp(
            db=db,
            phone=body.phone,
            ip_address=_get_ip(request),
            user_agent=request.headers.get("User-Agent"),
        )
        return SendOTPResponse(**result)
    except AuthError as exc:
        code_to_status = {
            "invalid_phone": status.HTTP_422_UNPROCESSABLE_ENTITY,
            "account_restricted": status.HTTP_403_FORBIDDEN,
            "daily_limit_exceeded": status.HTTP_429_TOO_MANY_REQUESTS,
            "resend_cooldown": status.HTTP_429_TOO_MANY_REQUESTS,
            "whatsapp_unavailable": status.HTTP_503_SERVICE_UNAVAILABLE,
        }
        raise HTTPException(
            status_code=code_to_status.get(exc.code, status.HTTP_400_BAD_REQUEST),
            detail=str(exc),
        )


@router.post("/verify-otp", response_model=VerifyOTPResponse)
@limiter.limit("10/hour")
async def verify_otp_endpoint(
    request: Request,
    body: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Verify OTP and return JWT tokens.
    Creates user if first-time login.
    """
    try:
        result = await verify_otp_and_login(
            db=db,
            phone=body.phone,
            otp=body.otp,
            device_info=body.device_info,
            ip_address=_get_ip(request),
        )
        return VerifyOTPResponse(**result)
    except AuthError as exc:
        code_to_status = {
            "invalid_phone": status.HTTP_422_UNPROCESSABLE_ENTITY,
            "no_active_otp": status.HTTP_400_BAD_REQUEST,
            "otp_expired": status.HTTP_400_BAD_REQUEST,
            "max_attempts_exceeded": status.HTTP_429_TOO_MANY_REQUESTS,
            "invalid_otp": status.HTTP_400_BAD_REQUEST,
            "account_restricted": status.HTTP_403_FORBIDDEN,
        }
        raise HTTPException(
            status_code=code_to_status.get(exc.code, status.HTTP_400_BAD_REQUEST),
            detail=str(exc),
        )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token_endpoint(
    body: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Exchange refresh token for new access token."""
    try:
        result = await refresh_access_token(db=db, refresh_token=body.refresh_token)
        return TokenResponse(**result)
    except AuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout_endpoint(
    request: Request,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke current session."""
    # Extract refresh token from body if provided
    body = await request.json() if request.headers.get("content-type") == "application/json" else {}
    refresh_token = body.get("refresh_token") if body else None

    await logout(db=db, user_id=current_user.user_id, refresh_token=refresh_token)


@router.get("/me", response_model=MeResponse)
async def me_endpoint(
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Get current user identity from JWT."""
    return MeResponse(
        user_id=str(current_user.user_id),
        phone_normalized=current_user.phone_normalized,
        account_status=current_user.account_status,
        onboarding_completed=current_user.onboarding_completed,
        masked_phone=mask_phone(current_user.phone_normalized),
    )
