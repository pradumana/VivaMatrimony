"""Unit tests for phone number normalization."""
import pytest
from app.utils.phone import normalize_phone, mask_phone, PhoneValidationError, get_country_code


class TestNormalizePhone:
    def test_indian_10digit(self):
        assert normalize_phone("9876543210") == "+919876543210"

    def test_indian_with_country_code(self):
        assert normalize_phone("+919876543210") == "+919876543210"

    def test_indian_with_0_prefix(self):
        assert normalize_phone("09876543210") == "+919876543210"

    def test_indian_with_91_prefix(self):
        assert normalize_phone("919876543210") == "+919876543210"

    def test_with_spaces(self):
        assert normalize_phone("98765 43210") == "+919876543210"

    def test_with_hyphens(self):
        assert normalize_phone("9876-543210") == "+919876543210"

    def test_us_number(self):
        result = normalize_phone("+12025551234", default_country="US")
        assert result == "+12025551234"

    def test_empty_raises(self):
        with pytest.raises(PhoneValidationError):
            normalize_phone("")

    def test_invalid_number_raises(self):
        with pytest.raises(PhoneValidationError):
            normalize_phone("123")

    def test_too_long_raises(self):
        with pytest.raises(PhoneValidationError):
            normalize_phone("99999999999999999999")

    def test_alpha_raises(self):
        with pytest.raises(PhoneValidationError):
            normalize_phone("abcdefghij")


class TestMaskPhone:
    def test_indian_masked(self):
        masked = mask_phone("+919876543210")
        assert "210" in masked
        assert "*" in masked
        assert "987" not in masked or masked.startswith("+91")

    def test_short_number(self):
        assert mask_phone("123") == "***"


class TestCountryCode:
    def test_indian_country_code(self):
        assert get_country_code("+919876543210") == "+91"

    def test_us_country_code(self):
        assert get_country_code("+12025551234") == "+1"
