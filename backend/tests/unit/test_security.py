"""Unit tests for OTP generation, hashing, JWT creation."""
import pytest
from app.utils.security import (
    generate_otp, hash_otp, verify_otp,
    hash_password, verify_password, hash_token,
    create_access_token, create_refresh_token, create_admin_access_token,
)
import uuid


class TestOTP:
    def test_otp_length(self):
        otp = generate_otp(6)
        assert len(otp) == 6

    def test_otp_is_numeric(self):
        otp = generate_otp(6)
        assert otp.isdigit()

    def test_otp_custom_length(self):
        assert len(generate_otp(4)) == 4
        assert len(generate_otp(8)) == 8

    def test_otp_randomness(self):
        # Very unlikely to get same OTP twice
        otps = {generate_otp(6) for _ in range(20)}
        assert len(otps) > 10

    def test_otp_hash_and_verify(self):
        otp = generate_otp(6)
        hashed = hash_otp(otp)
        assert hashed != otp
        assert verify_otp(otp, hashed) is True

    def test_otp_wrong_value_fails(self):
        otp = generate_otp(6)
        hashed = hash_otp(otp)
        wrong = str(int(otp) + 1).zfill(6)
        assert verify_otp(wrong, hashed) is False

    def test_otp_plaintext_not_stored(self):
        otp = "123456"
        hashed = hash_otp(otp)
        assert "123456" not in hashed

    def test_otp_not_logged(self, capsys):
        otp = generate_otp(6)
        hash_otp(otp)
        captured = capsys.readouterr()
        assert otp not in captured.out
        assert otp not in captured.err


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
        pwd = "SamePassword123"
        h1 = hash_password(pwd)
        h2 = hash_password(pwd)
        assert h1 != h2  # bcrypt uses different salts


class TestTokens:
    def test_hash_token(self):
        token = "random_refresh_token_string"
        h = hash_token(token)
        assert h != token
        assert len(h) == 64  # SHA-256 hex

    def test_hash_token_deterministic(self):
        token = "same_token"
        assert hash_token(token) == hash_token(token)

    def test_create_access_token(self):
        user_id = uuid.uuid4()
        token = create_access_token(user_id)
        assert isinstance(token, str)
        assert len(token) > 50

    def test_create_refresh_token(self):
        raw, hashed = create_refresh_token()
        assert raw != hashed
        assert len(raw) > 50
        assert hash_token(raw) == hashed

    def test_access_token_contains_user_id(self):
        from jose import jwt
        from app.config import get_settings
        settings = get_settings()
        user_id = uuid.uuid4()
        token = create_access_token(user_id)
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        assert payload["sub"] == str(user_id)
        assert payload["type"] == "access"

    def test_admin_token_type(self):
        from jose import jwt
        from app.config import get_settings
        settings = get_settings()
        admin_id = uuid.uuid4()
        token = create_admin_access_token(admin_id)
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        assert payload["type"] == "admin_access"
