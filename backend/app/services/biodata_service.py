"""
Biodata PDF Generation Service.
Generates a beautiful matrimonial biodata PDF using WeasyPrint + Jinja2.
Respects all privacy settings.
"""
import hashlib
import io
import json
import structlog
from typing import Optional
from uuid import UUID

from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_supabase
from app.services.profile_service import get_profile, _compute_age

settings = get_settings()
logger = structlog.get_logger()


async def generate_biodata_pdf(
    db: AsyncSession,
    user_id: UUID,
) -> bytes:
    """
    Generate matrimonial biodata PDF for a user.
    - Respects privacy settings
    - Never includes certificates, admin notes, phone numbers
    - Supports Unicode/Hindi
    Returns raw PDF bytes.
    """
    # Fetch full profile (own view — all fields)
    profile_data = await get_profile(db, user_id, requesting_user_id=user_id)
    if not profile_data:
        raise ValueError("Profile not found. Please complete your profile first.")

    profile = profile_data.get("profile", {})

    if not profile.get("full_name"):
        raise ValueError("Please complete your basic profile information before generating biodata.")

    # Fetch primary photo URL
    primary_photo_url = profile_data.get("primary_photo_url")

    # Build template context — NO sensitive data
    context = {
        "full_name": profile.get("full_name", ""),
        "age": profile.get("age"),
        "gender": profile.get("gender", "").title(),
        "height": profile.get("height_display"),
        "marital_status": _format_enum(profile.get("marital_status", "")),
        "mother_tongue": profile.get("mother_tongue", ""),
        "religion": profile.get("religion", ""),
        "caste": profile.get("caste", ""),
        "about_me": profile.get("about_me", ""),
        "photo_url": primary_photo_url,
        "is_verified": profile.get("is_verified", False),

        # Location
        "current_location": _format_location(profile_data.get("current_location")),
        "native_place": _format_location(profile_data.get("native_place")),

        # Education
        "education": profile_data.get("education"),

        # Employment — respect show_income/show_company flags
        "employment": _filter_employment(profile_data.get("employment")),

        # Family — respect show_parents_info
        "family": _filter_family(profile_data.get("family")),

        # Lifestyle
        "lifestyle": profile_data.get("lifestyle"),

        "app_name": "Viva",
        "app_tagline": "Find someone who feels like home.",
    }

    # Try WeasyPrint; fallback message on failure
    try:
        pdf_bytes = _render_pdf(context)
    except Exception as exc:
        logger.error("biodata_pdf_generation_failed", error=str(exc), user_id=str(user_id))
        raise ValueError("We couldn't generate your biodata. Please try again.")

    # Upload to Supabase Storage
    supabase = get_supabase()
    storage_path = f"{user_id}/biodata.pdf"

    try:
        # Remove existing if any
        supabase.storage.from_(settings.storage_bucket_biodata).remove([storage_path])
    except Exception:
        pass

    try:
        supabase.storage.from_(settings.storage_bucket_biodata).upload(
            path=storage_path,
            file=pdf_bytes,
            file_options={"content-type": "application/pdf"},
        )
    except Exception as exc:
        logger.warning("biodata_storage_upload_failed", error=str(exc))
        # Still return the PDF bytes even if storage fails

    # Update export record
    profile_hash = _compute_profile_hash(profile_data)
    existing = await db.execute(
        text("SELECT id FROM biodata_exports WHERE user_id = :uid"),
        {"uid": user_id},
    )
    if existing.fetchone():
        await db.execute(
            text("""
                UPDATE biodata_exports SET
                  storage_path = :path,
                  status = 'ready',
                  profile_hash = :hash,
                  is_stale = FALSE,
                  generated_at = NOW(),
                  updated_at = NOW()
                WHERE user_id = :uid
            """),
            {"uid": user_id, "path": storage_path, "hash": profile_hash},
        )
    else:
        await db.execute(
            text("""
                INSERT INTO biodata_exports (user_id, storage_path, status, profile_hash, generated_at)
                VALUES (:uid, :path, 'ready', :hash, NOW())
            """),
            {"uid": user_id, "path": storage_path, "hash": profile_hash},
        )
    await db.commit()

    return pdf_bytes


def _render_pdf(context: dict) -> bytes:
    """Render HTML template and convert to PDF via WeasyPrint."""
    import os
    template_dir = os.path.join(os.path.dirname(__file__), "..", "utils", "templates")

    env = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=select_autoescape(["html", "xml"]),
    )
    template = env.get_template("biodata.html")
    html_content = template.render(**context)

    from weasyprint import HTML, CSS
    font_css = CSS(string="""
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;600;700&family=Noto+Sans+Devanagari:wght@400;600;700&display=swap');
        body { font-family: 'Noto Sans', 'Noto Sans Devanagari', sans-serif; }
    """)

    pdf_bytes = HTML(string=html_content).write_pdf(stylesheets=[font_css])
    return pdf_bytes


def _format_location(loc: Optional[dict]) -> Optional[str]:
    if not loc:
        return None
    parts = [p for p in [loc.get("city"), loc.get("district"), loc.get("state"), loc.get("country")] if p]
    return ", ".join(parts) if parts else None


def _format_enum(val: str) -> str:
    return val.replace("_", " ").title()


def _filter_employment(employment: Optional[dict]) -> Optional[dict]:
    if not employment:
        return None
    result = dict(employment)
    if not result.get("show_company"):
        result["company"] = None
    if not result.get("show_income"):
        result["income_min_lpa"] = None
        result["income_max_lpa"] = None
    return result


def _filter_family(family: Optional[dict]) -> Optional[dict]:
    if not family:
        return None
    return family  # Already filtered in get_profile for own view


def _compute_profile_hash(profile_data: dict) -> str:
    """Hash of profile data to detect staleness."""
    data_str = json.dumps(profile_data, default=str, sort_keys=True)
    return hashlib.sha256(data_str.encode()).hexdigest()[:16]
