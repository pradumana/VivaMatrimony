"""
JWT Authentication Middleware.
Validates Supabase-issued JWTs.

Supabase projects created before mid-2024 sign tokens with HS256 using the
project JWT secret. Newer projects use ES256 with a keypair — the public key
is served at <supabase_url>/auth/v1/.well-known/jwks.json.

We support both: try JWKS (ES256) first, fall back to HS256 shared secret.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID
import httpx

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
# JWKS cache — fetched once on first request, held in memory
# ---------------------------------------------------------------------------
_jwks_cache: Optional[dict] = None


async def _get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is not None:
        return _jwks_cache
    url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
    async with httpx.AsyncClient(timeout=5) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        _jwks_cache = resp.json()
    return _jwks_cache


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
    Decode and validate a Supabase JWT.
    Tries ES256 via JWKS first; falls back to HS256 shared secret.
    """
    # Peek at the header to pick the right algorithm
    header = jwt.get_unverified_header(token)
    alg = header.get("alg", "HS256")

    if alg == "ES256":
        try:
            jwks = await _get_jwks()
            kid = header.get("kid")
            # Find matching key
            key = None
            for k in jwks.get("keys", []):
                if kid is None or k.get("kid") == kid:
                    key = k
                    break
            if key is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token signing key not found",
                    headers={"WWW-Authenticate": "Bearer"},
                )
            payload = jwt.decode(
                token,
                key,
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

    # HS256 path (legacy projects)
    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
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
