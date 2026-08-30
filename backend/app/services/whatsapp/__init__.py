"""
WhatsApp service factory — returns correct provider based on settings.
"""
from app.config import get_settings
from .base import WhatsAppService, WhatsAppSendResult
from .openwa_provider import OpenWAProvider
from .meta_provider import MetaWhatsAppProvider
from .mock_provider import MockWhatsAppProvider

_settings = get_settings()
_provider: WhatsAppService | None = None


def get_whatsapp_service() -> WhatsAppService:
    """
    FastAPI dependency / factory.
    Returns singleton provider based on WHATSAPP_PROVIDER setting.
    """
    global _provider
    if _provider is None:
        if _settings.whatsapp_provider == "openwa":
            _provider = OpenWAProvider()
        elif _settings.whatsapp_provider == "official":
            _provider = MetaWhatsAppProvider()
        else:
            _provider = MockWhatsAppProvider()
    return _provider


__all__ = ["WhatsAppService", "WhatsAppSendResult", "get_whatsapp_service"]
