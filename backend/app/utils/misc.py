"""
Miscellaneous shared utilities.
"""
import os
import uuid
from datetime import date
from typing import Optional


def compute_age(dob: date) -> int:
    """Return age in whole years given a date of birth."""
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def safe_filename(filename: str) -> str:
    """Return a collision-safe filename with the original extension."""
    ext = os.path.splitext(filename)[1].lower() or ".bin"
    return f"{uuid.uuid4().hex}{ext}"


def safe_photo_filename() -> str:
    """Return a collision-safe .jpg filename (all uploaded photos are compressed to JPEG)."""
    return f"{uuid.uuid4().hex}.jpg"


def get_public_url(storage_path: Optional[str], bucket: str) -> Optional[str]:
    """
    Get the public URL for a Supabase storage path.
    Returns None (not empty string) on failure so callers can do `url or placeholder`.
    Centralises the try/except that was copy-pasted across 6 service files.
    """
    if not storage_path:
        return None
    from app.database import get_supabase
    try:
        return get_supabase().storage.from_(bucket).get_public_url(storage_path)
    except Exception:
        return None
