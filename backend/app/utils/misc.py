"""
Miscellaneous shared utilities.
"""
import os
import uuid
from datetime import date


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
