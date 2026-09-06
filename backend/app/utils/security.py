"""
Security utilities.
OTP generation/hashing and custom JWT creation removed in migration 005.
Supabase Auth handles all user authentication credentials.

Kept:
  hash_password / verify_password  — admin panel login (admin_users table)
  create_admin_access_token        — admin JWT for viva-admin panel
  hash_token                       — still referenced by admin_auth if needed
"""
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from jose import jwt
from passlib.context import CryptContext

from app.config import get_settings

settings = get_settings()

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------------------------------------------------------------------------
# Admin password hashing (admin_users table only — never for regular users)
# ---------------------------------------------------------------------------

def hash_password(password: str) -> str:
    """Hash an admin password with bcrypt."""
    return _pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify an admin password against its bcrypt hash."""
    try:
        return _pwd_context.verify(plain, hashed)
    except Exception:
        return False


def hash_token(token: str) -> str:
    """SHA-256 hash — used by admin session tokens."""
    return hashlib.sha256(token.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Admin JWT (separate from Supabase user JWTs)
# ---------------------------------------------------------------------------

def create_admin_access_token(
    admin_id: UUID,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Create an admin-only JWT signed with our own secret.
    type='admin_access' distinguishes it from Supabase user tokens.
    """
    expire = datetime.now(tz=timezone.utc) + (expires_delta or timedelta(minutes=60))
    payload = {
        "sub": str(admin_id),
        "type": "admin_access",
        "exp": expire,
        "iat": datetime.now(tz=timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
