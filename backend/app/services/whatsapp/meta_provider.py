"""
Meta / Official WhatsApp Business Cloud API provider.
Production-ready implementation using approved message templates.
"""
import structlog
import httpx

from app.config import get_settings
from .base import WhatsAppService, WhatsAppSendResult

settings = get_settings()
logger = structlog.get_logger()

META_API_BASE = "https://graph.facebook.com/v19.0"


class MetaWhatsAppProvider(WhatsAppService):
    """
    Official Meta WhatsApp Business Cloud API.
    Requires approved OTP template named 'viva_otp'.
    """

    def __init__(self):
        self.token = settings.meta_whatsapp_token
        self.phone_number_id = settings.meta_whatsapp_phone_number_id

    def _format_number(self, phone_normalized: str) -> str:
        """Remove + prefix for Meta API: +919876543210 → 919876543210"""
        return phone_normalized.lstrip("+")

    async def send_otp(
        self,
        phone_normalized: str,
        otp: str,
        language: str = "en",
    ) -> WhatsAppSendResult:
        to_number = self._format_number(phone_normalized)
        lang_code = "en_US" if language == "en" else "hi"

        payload = {
            "messaging_product": "whatsapp",
            "to": to_number,
            "type": "template",
            "template": {
                "name": "viva_otp",
                "language": {"code": lang_code},
                "components": [
                    {
                        "type": "body",
                        "parameters": [
                            {"type": "text", "text": otp},
                        ],
                    },
                    {
                        # Button for copy-code (optional — remove if template doesn't have it)
                        "type": "button",
                        "sub_type": "url",
                        "index": "0",
                        "parameters": [
                            {"type": "text", "text": otp},
                        ],
                    },
                ],
            },
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    f"{META_API_BASE}/{self.phone_number_id}/messages",
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {self.token}",
                        "Content-Type": "application/json",
                    },
                )
                response.raise_for_status()
                data = response.json()
                message_id = data.get("messages", [{}])[0].get("id")
                return WhatsAppSendResult(
                    success=True,
                    message_id=message_id,
                    provider="meta",
                )
        except httpx.TimeoutException:
            logger.warning("meta_whatsapp_timeout")
            return WhatsAppSendResult(
                success=False,
                error="WhatsApp service timeout",
                provider="meta",
            )
        except httpx.HTTPStatusError as exc:
            logger.error("meta_whatsapp_error", status=exc.response.status_code)
            return WhatsAppSendResult(
                success=False,
                error="WhatsApp API error",
                provider="meta",
            )
        except Exception as exc:
            logger.error("meta_whatsapp_failed", error=str(exc))
            return WhatsAppSendResult(
                success=False,
                error="Failed to send WhatsApp message",
                provider="meta",
            )

    async def is_available(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(
                    f"{META_API_BASE}/{self.phone_number_id}",
                    headers={"Authorization": f"Bearer {self.token}"},
                )
                return response.status_code == 200
        except Exception:
            return False
