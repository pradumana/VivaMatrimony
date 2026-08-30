"""
Audit logging utility.
All sensitive actions (ban, verify, delete, approve certificate) are logged.
"""
import json
from typing import Any, Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


async def log_action(
    db: AsyncSession,
    actor_type: str,           # 'user' | 'admin' | 'system'
    actor_id: Optional[UUID],
    action: str,
    target_type: Optional[str] = None,
    target_id: Optional[UUID] = None,
    details: Optional[dict] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
) -> None:
    """
    Write an audit log entry.
    Fires-and-forgets — does not raise on failure to avoid disrupting main flow.
    """
    try:
        await db.execute(
            text("""
                INSERT INTO audit_logs (
                    actor_type, actor_id, action,
                    target_type, target_id, details,
                    ip_address, user_agent
                ) VALUES (
                    :actor_type, :actor_id, :action,
                    :target_type, :target_id, :details,
                    :ip_address, :user_agent
                )
            """),
            {
                "actor_type": actor_type,
                "actor_id": actor_id,
                "action": action,
                "target_type": target_type,
                "target_id": target_id,
                "details": json.dumps(details) if details else None,
                "ip_address": ip_address,
                "user_agent": user_agent,
            },
        )
        await db.commit()
    except Exception:
        # Audit logging must never crash the main request
        import structlog
        log = structlog.get_logger()
        log.error("audit_log_failed", action=action, actor_id=str(actor_id))
