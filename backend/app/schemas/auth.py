"""Auth request/response schemas."""
from typing import Optional
from pydantic import BaseModel, field_validator
import re


class SendOTPRequest(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def phone_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Phone number is required")
        if len(v) > 20:
            raise ValueError("Phone number too long")
        return v


class SendOTPResponse(BaseModel):
    success: bool
    masked_phone: str
    resend_after: int
    expires_in_minutes: int
    message: str = "OTP sent to your WhatsApp number"


class VerifyOTPRequest(BaseModel):
    phone: str
    otp: str
    device_info: Optional[str] = None

    @field_validator("otp")
    @classmethod
    def otp_format(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit():
            raise ValueError("OTP must contain only digits")
        if len(v) < 4 or len(v) > 8:
            raise ValueError("Invalid OTP format")
        return v


class VerifyOTPResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    user_id: str
    is_new_user: bool
    onboarding_completed: bool
    account_status: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"


class MeResponse(BaseModel):
    user_id: str
    phone_normalized: str
    account_status: str
    onboarding_completed: bool
    masked_phone: str
