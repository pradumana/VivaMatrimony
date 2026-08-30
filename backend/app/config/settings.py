"""
Application settings — loaded from environment variables / .env file.
Never import secrets directly; always use settings.field_name.
"""
from functools import lru_cache
from typing import List, Literal
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # -------------------------------------------------------------------------
    # Application
    # -------------------------------------------------------------------------
    app_name: str = "Viva"
    app_env: Literal["development", "staging", "production"] = "development"
    app_debug: bool = False
    app_secret_key: str
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_version: str = "1.0.0"
    allowed_origins: str = "http://localhost:3000"

    @property
    def cors_origins(self) -> List[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    # -------------------------------------------------------------------------
    # Database
    # -------------------------------------------------------------------------
    database_url: str
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str

    # -------------------------------------------------------------------------
    # JWT
    # -------------------------------------------------------------------------
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    # -------------------------------------------------------------------------
    # OTP
    # -------------------------------------------------------------------------
    otp_length: int = 6
    otp_expire_minutes: int = 10
    otp_max_attempts: int = 5
    otp_resend_cooldown_seconds: int = 60
    otp_max_send_per_day: int = 10

    # -------------------------------------------------------------------------
    # WhatsApp
    # -------------------------------------------------------------------------
    whatsapp_provider: Literal["openwa", "official", "mock"] = "mock"

    # OpenWA
    openwa_base_url: str = "http://localhost:8002"
    openwa_api_key: str = ""

    # Meta / Official
    meta_whatsapp_token: str = ""
    meta_whatsapp_phone_number_id: str = ""
    meta_whatsapp_verify_token: str = ""

    # -------------------------------------------------------------------------
    # Storage
    # -------------------------------------------------------------------------
    storage_bucket_profile_photos: str = "profile-photos"
    storage_bucket_biodata: str = "biodata-pdfs"
    storage_bucket_verification_docs: str = "verification-docs"

    max_photo_size_mb: int = 10
    max_document_size_mb: int = 20
    thumbnail_width: int = 400
    thumbnail_height: int = 500

    @property
    def max_photo_size_bytes(self) -> int:
        return self.max_photo_size_mb * 1024 * 1024

    @property
    def max_document_size_bytes(self) -> int:
        return self.max_document_size_mb * 1024 * 1024

    # -------------------------------------------------------------------------
    # Rate Limiting
    # -------------------------------------------------------------------------
    rate_limit_per_minute: int = 60
    rate_limit_otp_per_hour: int = 5
    rate_limit_search_per_minute: int = 30

    # -------------------------------------------------------------------------
    # Admin
    # -------------------------------------------------------------------------
    admin_email: str = "admin@viva.app"

    # -------------------------------------------------------------------------
    # PDF
    # -------------------------------------------------------------------------
    pdf_font_dir: str = "app/utils/fonts"
    pdf_template_dir: str = "app/utils/templates"

    # -------------------------------------------------------------------------
    # Logging
    # -------------------------------------------------------------------------
    log_level: str = "INFO"

    # -------------------------------------------------------------------------
    # Security
    # -------------------------------------------------------------------------
    bcrypt_rounds: int = 12

    # -------------------------------------------------------------------------
    # Notifications (FCM)
    # -------------------------------------------------------------------------
    fcm_server_key: str = ""

    # -------------------------------------------------------------------------
    # Validators
    # -------------------------------------------------------------------------
    @field_validator("app_secret_key")
    @classmethod
    def secret_key_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("APP_SECRET_KEY must be at least 32 characters")
        return v

    @field_validator("jwt_secret_key")
    @classmethod
    def jwt_key_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters")
        return v


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton — call once, reuse everywhere."""
    return Settings()
