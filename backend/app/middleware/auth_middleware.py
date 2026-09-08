"""
JWT Authentication Middleware.
Validates Supabase-issued JWTs.

This project uses ES256. The public key is embedded directly from the
project's JWKS endpoint to avoid a runtime HTTP call on every request.

Key source: https://qzjxluqbqlziqimgadgl.supabase.co/auth/v1/.well-known/jwks.json
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

# ---------------------------------------------------------------------------
# Embedded public key — avoids a runtime JWKS fetch on every request.
# Rotate this if Supabase rotates the signing key (rare; check the dashboard).
# ---------------------------------------------------------------------------
_SUPABASE_JWK = {
    "alg": "ES256",
    "crv": "P-256",
    "ext": True,
    "key_ops": ["verify"],
    "kid": "9317f634-951b-448c-9314-fd41d1ead105",
    "kty": "EC",
    "use": "sig",
    "x": "FVddjP8mJ_wxxpYEcKolV-JViefKC25_ORQFaF4i9P4",
    "y": "GTpTgF_YSbYR64SYj4sLRkVU83bLtBzfkCajnk06oGA",
}


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


async def _decode_supabase_token(token: str) -> dict:
    """
    Decode and validate a Supabase JWT using the embedded ES256 public key.
    Raises HTTP 401 on any validation failure.
    """
    try:
        payload = jwt.decode(
            token,
            _SUPABASE_JWK,
            algorithms=["ES256"],
            options={"verify_aud": False},
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

    payload = await _decode_supabase_token(credentials.credentials)

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


async def get_jwt_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer),
) -> AuthenticatedUser:
    """
    Lightweight dependency — validates the Supabase JWT signature only.
    Does NOT require a users row in the DB.

    Use ONLY for endpoints whose job is to CREATE that row (e.g. /auth/register).
    All other protected endpoints must use get_current_user.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = await _decode_supabase_token(credentials.credentials)

    user_id_str: Optional[str] = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject",
        )

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

    # Extract email from token claims (Supabase puts it in "email")
    email: Optional[str] = payload.get("email")

    return AuthenticatedUser(
        user_id=user_id,
        email=email,
        account_status="pending_verification",  # unknown until row created
        onboarding_completed=False,
    )
