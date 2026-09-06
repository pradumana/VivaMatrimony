"""Auth request/response schemas. OTP/WhatsApp schemas removed in migration 005."""
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator


class RegisterRequest(BaseModel):
    """
    Sent by Flutter after Supabase Auth signUp/signIn succeeds.
    The email here is a fallback — the middleware extracts it from the
    validated JWT claim first. This field is only used when the JWT's
    email claim is absent (shouldn't happen with Supabase Auth).
    """
    email: Optional[EmailStr] = None

    @field_validator("email", mode="before")
    @classmethod
    def normalise_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip().lower()
        return v or None


class MeResponse(BaseModel):
    user_id: str
    email: Optional[str]
    account_status: str
    onboarding_completed: bool
