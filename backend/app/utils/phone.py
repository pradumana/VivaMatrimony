"""
Phone number normalization and validation.
Uses the 'phonenumbers' library for E.164 normalization.
"""
from typing import Optional
import phonenumbers
from phonenumbers import PhoneNumberFormat, NumberParseException


class PhoneValidationError(ValueError):
    pass


def normalize_phone(
    phone: str,
    default_country: str = "IN",
) -> str:
    """
    Normalize a phone number to E.164 format.
    e.g. '9876543210' → '+919876543210'
         '+919876543210' → '+919876543210'
         '09876543210' → '+919876543210'

    Raises PhoneValidationError on invalid input.
    """
    phone = phone.strip().replace(" ", "").replace("-", "").replace("(", "").replace(")", "")

    if not phone:
        raise PhoneValidationError("Phone number cannot be empty")

    try:
        parsed = phonenumbers.parse(phone, default_country)
    except NumberParseException as exc:
        raise PhoneValidationError(f"Unable to parse phone number: {phone}") from exc

    if not phonenumbers.is_valid_number(parsed):
        raise PhoneValidationError(f"Invalid phone number: {phone}")

    return phonenumbers.format_number(parsed, PhoneNumberFormat.E164)


def get_country_code(phone_normalized: str) -> str:
    """Extract country code from E.164 number. e.g. '+919876543210' → '+91'"""
    try:
        parsed = phonenumbers.parse(phone_normalized, None)
        return f"+{parsed.country_code}"
    except NumberParseException:
        return "+91"


def mask_phone(phone_normalized: str) -> str:
    """
    Return a masked version for display.
    e.g. '+919876543210' → '+91 98765 **210'
    """
    if len(phone_normalized) < 7:
        return "***"
    visible_end = phone_normalized[-3:]
    masked_middle = "*" * (len(phone_normalized) - 6)
    country_part = phone_normalized[:3]
    return f"{country_part}{masked_middle}{visible_end}"


def is_indian_number(phone_normalized: str) -> bool:
    """Check if the number is an Indian mobile number."""
    return phone_normalized.startswith("+91")
