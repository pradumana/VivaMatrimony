"""
JWT Authentication Middleware — Phase 4 update: Firebase Auth (RS256).

Validates Firebase-issued JWTs using Google's public JWKS endpoint.
The Firebase UID (JWT sub) is a string, not a UUID — looked up in
user_identity_map to get the internal users.id (UUID).

JWKS endpoint (public, no auth required):
  https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com

Token validation rules:
  alg  = RS256
  aud  = FIREBASE_PROJECT_ID (from settings)
  iss  = https://securetoken.google.com/<FIREBASE_PROJECT_ID>

The JWKS is fetched at first use and cached in memory.
On key-not-found (kid mismatch) the cache is cleared and re-fetched once.
"""
import logging
import time
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import httpx
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_db

settings = get_settings()
logger = logging.getLogger(__name__)

_bearer = HTTPBearer(auto_error=False)

# ---------------------------------------------------------------------------
# JWKS cache — populated lazily, refreshed on kid-not-found
# ---------------------------------------------------------------------------
_FIREBASE_JWKS_URL = (
    "https://www.googleapis.com/service_accounts/v1/jwk/"
    "securetoken@system.gserviceaccount.com"
)
_jwks_cache: dict = {}          # kid → JWK dict
_jwks_fetched_at: float = 0.0   # epoch seconds
_JWKS_TTL = 3600                 # re-fetch at most once per hour


async def _get_jwks() -> dict:
    """Return the cached JWKS dict (kid→key), fetching from Google if stale."""
    global _jwks_cache, _jwks_fetched_at
    now = time.time()
    if _jwks_cache and (now - _jwks_fetched_at) < _JWKS_TTL:
        return _jwks_cache
    async with httpx.AsyncClient(timeout=5.0) as client:
        resp = await client.get(_FIREBASE_JWKS_URL)
        resp.raise_for_status()
        data = resp.json()
    _jwks_cache = {k["kid"]: k for k in data.get("keys", [])}
    _jwks_fetched_at = now
    logger.info("Firebase JWKS refreshed, %d keys", len(_jwks_cache))
    return _jwks_cache


async def _decode_firebase_token(token: str) -> dict:
    """
    Decode and validate a Firebase JWT.
    Raises HTTP 401 on any validation failure.
    """
    # Peek at the header to get the kid without full decode
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token header",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    kid = header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing kid header",
        )

    # Fetch JWKS (cached)
    jwks = await _get_jwks()
    if kid not in jwks:
        # kid not in cache — force a refresh once
        global _jwks_fetched_at
        _jwks_fetched_at = 0.0
        jwks = await _get_jwks()
    if kid not in jwks:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unknown token signing key",
        )

    jwk_key = jwks[kid]
    project_id = settings.firebase_project_id  # "viva-analytics-135d4"

    try:
        payload = jwt.decode(
            token,
            jwk_key,
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}",
            options={"verify_aud": True, "verify_iss": True},
        )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


class AuthenticatedUser:
    """Represents a verified, active user extracted from a Firebase JWT."""

    def __init__(
        self,
        user_id: UUID,           # users.id (UUID PK in our DB)
        firebase_uid: str,       # Firebase UID string from JWT sub
        email: Optional[str],
        account_status: str,
        onboarding_completed: bool,
    ):
        self.user_id = user_id
        self.firebase_uid = firebase_uid
        self.email = email
        self.account_status = account_status
        self.onboarding_completed = onboarding_completed


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer),
    db: AsyncSession = Depends(get_db),
) -> AuthenticatedUser:
    """
    FastAPI dependency — validates Firebase JWT and returns active user.

    Flow:
      1. Decode + verify JWT (RS256, Google JWKS)
      2. Extract sub (= Firebase UID string)
      3. Look up user_identity_map to get internal users.id UUID
      4. Load user from DB — never trust token claims for account status
      5. Reject suspended / banned / deleted accounts
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = await _decode_firebase_token(credentials.credentials)

    firebase_uid: Optional[str] = payload.get("sub")
    if not firebase_uid:
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

    email: Optional[str] = payload.get("email")

    # Look up users.id via user_identity_map
    result = await db.execute(
        text("""
            SELECT u.id, u.email, u.account_status, u.onboarding_completed
            FROM user_identity_map uim
            JOIN users u ON u.id = uim.supabase_user_id
            WHERE uim.firebase_uid = :fuid
              AND u.deleted_at IS NULL
        """),
        {"fuid": firebase_uid},
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
        firebase_uid=firebase_uid,
        email=email or row.email,
        account_status=row.account_status,
        onboarding_completed=row.onboarding_completed,
    )


async def get_jwt_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer),
) -> AuthenticatedUser:
    """
    Lightweight dependency — validates Firebase JWT signature only.
    Does NOT require a users row or identity map entry yet.

    Use ONLY for /auth/register which creates those rows.
    All other protected endpoints must use get_current_user.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = await _decode_firebase_token(credentials.credentials)

    firebase_uid: Optional[str] = payload.get("sub")
    if not firebase_uid:
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

    email: Optional[str] = payload.get("email")

    # user_id is unknown until the users row is created — use a nil UUID
    # as a sentinel; get_or_create_user will assign the real UUID.
    return AuthenticatedUser(
        user_id=UUID("00000000-0000-0000-0000-000000000000"),
        firebase_uid=firebase_uid,
        email=email,
        account_status="pending_verification",
        onboarding_completed=False,
    )
