"""
Admin authentication dependency.
Separate from user auth — uses admin_users table.
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
_admin_bearer = HTTPBearer(auto_error=False)


class AdminUser:
    def __init__(self, admin_id: UUID, email: str, role: str, full_name: str):
        self.admin_id = admin_id
        self.email = email
        self.role = role
        self.full_name = full_name

    def can(self, action: str) -> bool:
        """Simple RBAC check."""
        perms = {
            "super_admin": {"*"},
            "admin": {"verify", "moderate", "view_users", "ban", "suspend", "audit"},
            "moderator": {"moderate", "view_users", "audit"},
            "support": {"view_users", "audit"},
        }
        allowed = perms.get(self.role, set())
        return "*" in allowed or action in allowed

    def require(self, action: str) -> None:
        """Raise 403 if admin lacks permission."""
        if not self.can(action):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permission denied: requires '{action}'",
            )


async def get_current_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_admin_bearer),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """Dependency for admin-only endpoints."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authentication required",
        )

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token",
        )

    admin_id_str = payload.get("sub")
    token_type = payload.get("type")

    if not admin_id_str or token_type != "admin_access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token claims",
        )

    try:
        admin_id = UUID(admin_id_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    result = await db.execute(
        text("""
            SELECT id, email, role, full_name, is_active
            FROM admin_users
            WHERE id = :admin_id
        """),
        {"admin_id": admin_id},
    )
    row = result.fetchone()

    if row is None or not row.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin account not found or inactive",
        )

    return AdminUser(
        admin_id=row.id,
        email=row.email,
        role=row.role,
        full_name=row.full_name,
    )
