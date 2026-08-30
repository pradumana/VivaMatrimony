"""
JWT Authentication Middleware + Dependencies.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text

from app.config import get_settings
from app.database import get_db

settings = get_settings()
_bearer = HTTPBearer(auto_error=False)


class AuthenticatedUser:
    """Represents a verified, active user from JWT."""

    def __init__(
        self,
        user_id: UUID,
        phone_normalized: str,
        account_status: str,
        onboarding_completed: bool,
    ):
        self.user_id = user_id
        self.phone_normalized = phone_normalized
        self.account_status = account_status
        self.onboarding_completed = onboarding_completed


def _decode_token(token: str) -> dict:
    """Decode and validate JWT. Raises HTTPException on failure."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer),
    db: AsyncSession = Depends(get_db),
) -> AuthenticatedUser:
    """
    FastAPI dependency — extracts user from JWT.
    Validates token, checks expiry, checks account status.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = _decode_token(credentials.credentials)

    # Extract claims
    user_id_str: Optional[str] = payload.get("sub")
    token_type: Optional[str] = payload.get("type")
    exp: Optional[int] = payload.get("exp")

    if not user_id_str or token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token claims",
        )

    # Check expiry explicitly (jose already does this, but belt & suspenders)
    if exp and datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(tz=timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
        )

    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject",
        )

    # Fetch user from DB — DO NOT trust token claims for status
    result = await db.execute(
        text("""
            SELECT id, phone_normalized, account_status, onboarding_completed
            FROM users
            WHERE id = :user_id AND deleted_at IS NULL
        """),
        {"user_id": user_id},
    )
    row = result.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    account_status = row.account_status

    if account_status in ("suspended", "banned"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is {account_status}. Contact support.",
        )

    if account_status == "deleted":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account has been deleted",
        )

    return AuthenticatedUser(
        user_id=row.id,
        phone_normalized=row.phone_normalized,
        account_status=row.account_status,
        onboarding_completed=row.onboarding_completed,
    )


async def get_current_active_user(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    """Dependency that additionally requires account_status == 'active'."""
    if current_user.account_status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is not active. Please complete verification.",
        )
    return current_user


async def get_current_onboarded_user(
    current_user: AuthenticatedUser = Depends(get_current_active_user),
) -> AuthenticatedUser:
    """Dependency that requires onboarding to be completed."""
    if not current_user.onboarding_completed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please complete your profile first.",
        )
    return current_user
