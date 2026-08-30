"""
WhatsApp Service Interface.
All providers must implement this interface.
Business logic NEVER imports a concrete provider directly.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class WhatsAppSendResult:
    success: bool
    message_id: Optional[str] = None
    error: Optional[str] = None
    provider: str = "unknown"


class WhatsAppService(ABC):
    """Abstract WhatsApp messaging service."""

    @abstractmethod
    async def send_otp(
        self,
        phone_normalized: str,
        otp: str,
        language: str = "en",
    ) -> WhatsAppSendResult:
        """
        Send OTP to a WhatsApp number.
        NEVER include the OTP in error logs or exception messages.
        """
        ...

    @abstractmethod
    async def is_available(self) -> bool:
        """Health check — returns True if the provider is reachable."""
        ...
