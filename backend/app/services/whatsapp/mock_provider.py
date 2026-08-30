"""
Mock WhatsApp provider for testing.
Logs OTP to console/test output — NEVER use in production.
"""
import structlog

from .base import WhatsAppService, WhatsAppSendResult

logger = structlog.get_logger()


class MockWhatsAppProvider(WhatsAppService):
    """
    Testing-only provider.
    Prints OTP to log output instead of sending via WhatsApp.
    """

    async def send_otp(
        self,
        phone_normalized: str,
        otp: str,
        language: str = "en",
    ) -> WhatsAppSendResult:
        # Safe to log OTP in test/dev — masked in production
        logger.info(
            "MOCK_WHATSAPP_OTP",
            phone=phone_normalized,
            otp=otp,
            note="This would be sent via WhatsApp in production",
        )
        return WhatsAppSendResult(
            success=True,
            message_id="mock-msg-id",
            provider="mock",
        )

    async def is_available(self) -> bool:
        return True
