"""
API tests for authentication endpoints.
send-otp / verify-otp tests removed — WhatsApp OTP auth removed in migration 005.
"""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(async_client: AsyncClient):
    """Health endpoint should always return 200."""
    response = await async_client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["app"] == "Viva"


@pytest.mark.asyncio
async def test_me_requires_auth(async_client: AsyncClient):
    """GET /auth/me without token should return 401."""
    response = await async_client.get("/api/v1/auth/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_me_with_invalid_token(async_client: AsyncClient):
    """Invalid JWT should return 401."""
    response = await async_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_register_requires_auth(async_client: AsyncClient):
    """POST /auth/register without a Supabase JWT should return 401."""
    response = await async_client.post("/api/v1/auth/register")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_register_with_invalid_token(async_client: AsyncClient):
    """POST /auth/register with a bad JWT should return 401."""
    response = await async_client.post(
        "/api/v1/auth/register",
        headers={"Authorization": "Bearer bad.token.value"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_logout_requires_auth(async_client: AsyncClient):
    """Logout without auth should return 401."""
    response = await async_client.post("/api/v1/auth/logout")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_profile_requires_auth(async_client: AsyncClient):
    """Profile endpoint without auth should return 401."""
    response = await async_client.get("/api/v1/profile")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_admin_login_wrong_credentials(async_client: AsyncClient):
    """Wrong admin credentials should return 401."""
    response = await async_client.post(
        "/api/v1/admin/login",
        json={"email": "notexist@admin.com", "password": "wrongpassword"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_search_requires_auth(async_client: AsyncClient):
    """Search without auth should return 401."""
    response = await async_client.get("/api/v1/search")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_matches_requires_auth(async_client: AsyncClient):
    """Matches without auth should return 401."""
    response = await async_client.get("/api/v1/matches")
    assert response.status_code == 401
