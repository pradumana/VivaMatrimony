"""
Test configuration and fixtures.
Uses in-memory SQLite for unit tests; real DB for integration tests.
"""
import asyncio
import os
import pytest
from typing import AsyncGenerator

import pytest_asyncio
from fastapi.testclient import TestClient
from httpx import AsyncClient, ASGITransport

# Override settings before importing app
os.environ.setdefault("APP_SECRET_KEY", "test-secret-key-minimum-32-characters-long")
os.environ.setdefault("JWT_SECRET_KEY", "test-jwt-secret-key-minimum-32-characters-long")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost:5432/viva_test")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-anon-key")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
os.environ.setdefault("WHATSAPP_PROVIDER", "mock")

from app.main import app


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test"
    ) as client:
        yield client


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)
