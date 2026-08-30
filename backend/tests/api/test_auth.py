"""
API tests for authentication endpoints.
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
async def test_send_otp_invalid_phone(async_client: AsyncClient):
    """Invalid phone should return 422."""
    response = await async_client.post("/api/v1/auth/send-otp", json={"phone": "abc"})
    assert response.status_code in (400, 422)
    # Should not expose internal error
    detail = response.json().get("detail", "")
    assert "traceback" not in detail.lower()
    assert "sql" not in detail.lower()


@pytest.mark.asyncio
async def test_send_otp_empty_phone(async_client: AsyncClient):
    """Empty phone should return 422."""
    response = await async_client.post("/api/v1/auth/send-otp", json={"phone": ""})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_verify_otp_wrong_format(async_client: AsyncClient):
    """Non-numeric OTP should fail validation."""
    response = await async_client.post("/api/v1/auth/verify-otp", json={
        "phone": "+919876543210",
        "otp": "ABCDEF"
    })
    assert response.status_code == 422


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
        headers={"Authorization": "Bearer invalid.token.here"}
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_logout_requires_auth(async_client: AsyncClient):
    """Logout without auth should fail."""
    response = await async_client.post("/api/v1/auth/logout")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_no_otp_in_response(async_client: AsyncClient):
    """OTP must NEVER appear in API response."""
    # Even in mock mode, OTP should not be in response body
    response = await async_client.post("/api/v1/auth/send-otp", json={"phone": "9876543210"})
    response_text = response.text
    # Should not contain any 6-digit sequence in a suspicious key
    import json
    if response.status_code == 200:
        data = response.json()
        assert "otp" not in data
        assert "code" not in data
        assert "pin" not in data


@pytest.mark.asyncio
async def test_profile_requires_auth(async_client: AsyncClient):
    """Profile endpoint without auth should return 401."""
    response = await async_client.get("/api/v1/profile")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_admin_login_wrong_credentials(async_client: AsyncClient):
    """Wrong admin credentials should return 401."""
    response = await async_client.post("/api/v1/admin/login", json={
        "email": "notexist@admin.com",
        "password": "wrongpassword"
    })
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
