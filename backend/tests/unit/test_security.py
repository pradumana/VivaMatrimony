"""Unit tests for security utilities — password hashing and admin JWT."""
import pytest
import uuid
from app.utils.security import (
    hash_password, verify_password, hash_token,
    create_admin_access_token,
)


class TestPasswordHashing:
    def test_hash_and_verify(self):
        pwd = "SecureAdminPassword123!"
        hashed = hash_password(pwd)
        assert verify_password(pwd, hashed)

    def test_wrong_password_fails(self):
        pwd = "SecureAdminPassword123!"
        hashed = hash_password(pwd)
        assert not verify_password("WrongPassword", hashed)

    def test_hash_different_each_time(self):
        # bcrypt uses different salts
        pwd = "SamePassword123"
        h1 = hash_password(pwd)
        h2 = hash_password(pwd)
        assert h1 != h2


class TestTokens:
    def test_hash_token(self):
        token = "random_refresh_token_string"
        h = hash_token(token)
        assert h != token
        assert len(h) == 64  # SHA-256 hex

    def test_hash_token_deterministic(self):
        token = "same_token"
        assert hash_token(token) == hash_token(token)

    def test_admin_token_type(self):
        from jose import jwt
        from app.config import get_settings
        settings = get_settings()
        admin_id = uuid.uuid4()
        token = create_admin_access_token(admin_id)
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        assert payload["type"] == "admin_access"
        assert payload["sub"] == str(admin_id)
