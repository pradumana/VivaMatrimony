"""
JWT Authentication Middleware.
Validates Supabase-issued JWTs using the project's JWT secret.
Supabase signs tokens with HS256 using the project's jwt_secret (found in
Project Settings → API → JWT Secret in the Supabase dashboard).
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_db

settings = get_settings()
_bearer = HTTPBearer(auto_error=False)


class AuthenticatedUser:
    """Represents a verified, active user extracted from a Supabase JWT."""

    def __init__(
        self,
        user_id: UUID,
        email: Optional[str],
        account_status: str,
        onboarding_completed: bool,
    ):
        self.user_id = user_id
        self.email = email
        self.account_status = account_status
        self.onboarding_completed = onboarding_completed


def _decode_supabase_token(token: str) -> dict:
    """
    Decode and validate a Supabase JWT.
    Supabase uses HS256 with the project JWT secret.
    The secret is in Supabase dashboard → Project Settings → API → JWT Secret.
    Store it as SUPABASE_JWT_SECRET in backend .env.
    """
    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False},  # Supabase tokens have aud="authenticated"
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
    FastAPI dependency — validates Supabase JWT and returns active user.

    Flow:
      1. Decode + verify JWT signature with SUPABASE_JWT_SECRET
      2. Extract sub (= Supabase Auth user UUID = our users.id)
      3. Load user from DB — never trust token claims for account status
      4. Reject suspended / banned / deleted accounts
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = _decode_supabase_token(credentials.credentials)

    # Supabase puts the user UUID in "sub"
    user_id_str: Optional[str] = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject",
        )

    # Belt-and-suspenders expiry check (jose already validates this)
    exp: Optional[int] = payload.get("exp")
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

    # Load from DB — account status is authoritative here, not in the token
    result = await db.execute(
        text("""
            SELECT id, email, account_status, onboarding_completed
            FROM users
            WHERE id = :uid AND deleted_at IS NULL
        """),
        {"uid": user_id},
    )
    row = result.fetchone()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found. Please complete registration.",
        )

    if row.account_status in ("suspended", "banned"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account is {row.account_status}. Contact support.",
        )

    if row.account_status == "deleted":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account has been deleted.",
        )

    return AuthenticatedUser(
        user_id=row.id,
        email=row.email,
        account_status=row.account_status,
        onboarding_completed=row.onboarding_completed,
    )
