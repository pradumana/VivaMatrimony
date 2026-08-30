"""
OpenWA Provider — Development / POC ONLY.
DO NOT use in production. Violates WhatsApp ToS.
"""
import structlog
from typing import Optional
import httpx

from app.config import get_settings
from .base import WhatsAppService, WhatsAppSendResult

settings = get_settings()
logger = structlog.get_logger()

OTP_TEMPLATE_EN = (
    "Hi! Your *Viva* verification code is: *{otp}*\n\n"
    "Valid for {minutes} minutes. Do not share this code with anyone.\n\n"
    "_- Viva Team_"
)

OTP_TEMPLATE_HI = (
    "नमस्ते! आपका *Viva* सत्यापन कोड है: *{otp}*\n\n"
    "यह कोड {minutes} मिनट के लिए वैध है। इसे किसी के साथ साझा न करें।\n\n"
    "_- Viva Team_"
)


class OpenWAProvider(WhatsAppService):
    """
    OpenWA/wa-automate provider for development.
    Requires a running OpenWA server.
    """

    def __init__(self):
        self.base_url = settings.openwa_base_url.rstrip("/")
        self.api_key = settings.openwa_api_key

    def _get_message(self, otp: str, language: str) -> str:
        template = OTP_TEMPLATE_HI if language == "hi" else OTP_TEMPLATE_EN
        return template.format(otp=otp, minutes=settings.otp_expire_minutes)

    async def send_otp(
        self,
        phone_normalized: str,
        otp: str,
        language: str = "en",
    ) -> WhatsAppSendResult:
        # Convert E.164 to WhatsApp format: +919876543210 → 919876543210@c.us
        wa_number = phone_normalized.lstrip("+") + "@c.us"
        message = self._get_message(otp, language)

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    f"{self.base_url}/api/sendText",
                    json={"args": {"to": wa_number, "content": message}},
                    headers={"Authorization": self.api_key},
                )
                response.raise_for_status()
                data = response.json()
                return WhatsAppSendResult(
                    success=True,
                    message_id=str(data.get("id", "")),
                    provider="openwa",
                )
        except httpx.TimeoutException:
            logger.warning("openwa_timeout", phone=wa_number[:6] + "***")
            return WhatsAppSendResult(
                success=False,
                error="WhatsApp service timeout",
                provider="openwa",
            )
        except httpx.HTTPStatusError as exc:
            logger.error("openwa_http_error", status=exc.response.status_code)
            return WhatsAppSendResult(
                success=False,
                error="WhatsApp service error",
                provider="openwa",
            )
        except Exception as exc:
            logger.error("openwa_send_failed", error=str(exc))
            return WhatsAppSendResult(
                success=False,
                error="Failed to send WhatsApp message",
                provider="openwa",
            )

    async def is_available(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{self.base_url}/api/isConnected")
                return response.status_code == 200
        except Exception:
            return False
