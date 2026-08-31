"""
Database connection management.
Uses asyncpg for async PostgreSQL + SQLAlchemy core for queries.
Supabase client is also initialized here.
"""
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool
from supabase import create_client, Client

from app.config import get_settings

settings = get_settings()

# ---------------------------------------------------------------------------
# SQLAlchemy async engine
# ---------------------------------------------------------------------------

def _build_async_url(url: str) -> str:
    """Convert postgresql:// to postgresql+asyncpg://"""
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+asyncpg://", 1)
    return url


# NullPool + statement_cache_size=0: required for Supabase/PgBouncer in
# transaction pooling mode. NullPool avoids SQLAlchemy holding connections
# between requests (PgBouncer owns the pool); statement_cache_size=0
# disables asyncpg prepared statements which don't survive across bouncer
# connections.
# ponytail: NullPool means one DB round-trip to acquire a connection per
# request. Upgrade path: switch DATABASE_URL to Supabase's direct connection
# string (db.[ref].supabase.co:5432) and restore QueuePool with pool_size=5.
engine: AsyncEngine = create_async_engine(
    _build_async_url(settings.database_url),
    echo=settings.app_debug,
    poolclass=NullPool,
    connect_args={"statement_cache_size": 0, "prepared_statement_cache_size": 0},
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: yields a DB session, closes after request."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ---------------------------------------------------------------------------
# Supabase client (service role — for server-side operations)
# ---------------------------------------------------------------------------

_supabase_client: Client | None = None


def get_supabase() -> Client:
    """
    Returns a Supabase client using the service_role key.
    NEVER expose this key to Flutter or the public.
    """
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
        )
    return _supabase_client
