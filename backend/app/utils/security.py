"""
Security utilities: OTP generation, hashing, JWT creation.
"""
import hashlib
import hmac
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from jose import jwt
from passlib.context import CryptContext

from app.config import get_settings

settings = get_settings()

# ---------------------------------------------------------------------------
# Password / OTP hashing context
# ---------------------------------------------------------------------------
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def generate_otp(length: int = None) -> str:
    """Generate a cryptographically secure numeric OTP."""
    length = length or settings.otp_length
    # secrets.randbelow for uniform distribution
    otp = "".join([str(secrets.randbelow(10)) for _ in range(length)])
    return otp


def hash_otp(otp: str) -> str:
    """Hash OTP using bcrypt. NEVER store plaintext OTP."""
    return pwd_context.hash(otp)


def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    """Verify an OTP against its bcrypt hash."""
    try:
        return pwd_context.verify(plain_otp, hashed_otp)
    except Exception:
        return False


def hash_password(password: str) -> str:
    """Hash admin password."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify admin password."""
    try:
        return pwd_context.verify(plain, hashed)
    except Exception:
        return False


def hash_token(token: str) -> str:
    """SHA-256 hash for refresh tokens (fast, not bcrypt)."""
    return hashlib.sha256(token.encode()).hexdigest()


# ---------------------------------------------------------------------------
# JWT creation
# ---------------------------------------------------------------------------

def create_access_token(
    user_id: UUID,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create a user access JWT."""
    expire = datetime.now(tz=timezone.utc) + (
        expires_delta or timedelta(minutes=settings.jwt_access_token_expire_minutes)
    )
    payload = {
        "sub": str(user_id),
        "type": "access",
        "exp": expire,
        "iat": datetime.now(tz=timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token() -> tuple[str, str]:
    """
    Create a refresh token.
    Returns (raw_token, hashed_token).
    Store the hash in DB; return raw to client.
    """
    raw = secrets.token_urlsafe(64)
    return raw, hash_token(raw)


def create_admin_access_token(
    admin_id: UUID,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create an admin access JWT (separate type claim)."""
    expire = datetime.now(tz=timezone.utc) + (
        expires_delta or timedelta(minutes=60)
    )
    payload = {
        "sub": str(admin_id),
        "type": "admin_access",
        "exp": expire,
        "iat": datetime.now(tz=timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
