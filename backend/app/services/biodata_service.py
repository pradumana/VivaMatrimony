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
from app.services.profile_service import get_profile

settings = get_settings()
logger = structlog.get_logger()


async def generate_biodata_pdf(
    db: AsyncSession,
    user_id: UUID,
    template: str = "traditional",
) -> bytes:
    """
    Generate matrimonial biodata PDF for a user.
    template: 'traditional' | 'floral' | 'half_photo'
    - Respects privacy settings
    - Never includes certificates, admin notes, phone numbers
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

    # Fetch all approved photos for the photos page
    supabase = get_supabase()
    photos_result = await db.execute(
        text("""
            SELECT storage_path FROM photos
            WHERE user_id = :uid AND deleted_at IS NULL AND is_approved = TRUE
            ORDER BY is_primary DESC, display_order ASC
        """),
        {"uid": user_id},
    )
    all_photo_urls = []
    for p in photos_result.fetchall():
        try:
            url = supabase.storage.from_(settings.storage_bucket_profile_photos).get_public_url(p.storage_path)
            all_photo_urls.append(url)
        except Exception:
            pass

    # Build template context — NO sensitive data
    context = {
        "full_name": profile.get("full_name", ""),
        "age": profile.get("age"),
        "gender": profile.get("gender", "").title(),
        "height": profile.get("height_display"),
        "marital_status": _format_enum(profile.get("marital_status", "")),
        "have_children": profile.get("have_children"),
        "children_count": profile.get("children_count"),
        "mother_tongue": profile.get("mother_tongue", ""),
        "languages_known": profile.get("languages_known") or [],
        "religion": profile.get("religion", ""),
        "caste": profile.get("caste", ""),
        "sub_caste": profile.get("sub_caste", ""),
        "gotra": profile.get("gotra", ""),
        "about_me": profile.get("about_me", ""),
        "photo_url": primary_photo_url,
        "all_photo_urls": all_photo_urls,
        "is_verified": profile.get("is_verified", False),
        "member_id": profile_data.get("member_id"),

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

        # Partner preferences
        "partner_preferences": await _fetch_partner_preferences(db, user_id),

        "app_name": "Viva",
        "app_tagline": "Find someone who feels like home.",
    }

    # Try WeasyPrint; fallback message on failure
    try:
        pdf_bytes = _render_pdf(context, template=template)
    except Exception as exc:
        logger.error("biodata_pdf_generation_failed", error=str(exc), user_id=str(user_id))
        raise ValueError("We couldn't generate your biodata. Please try again.")

    # Upload to Supabase Storage
    supabase = get_supabase()
    storage_path = f"{user_id}/biodata_{template}.pdf"

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

    # Upsert export record — one row per (user, template), idempotent
    profile_hash = _compute_profile_hash(profile_data)
    await db.execute(
        text("""
            INSERT INTO biodata_exports
                (user_id, storage_path, template_name, status, profile_hash, generated_at)
            VALUES (:uid, :path, :tmpl, 'ready', :hash, NOW())
            ON CONFLICT (user_id, template_name) DO UPDATE SET
                storage_path  = EXCLUDED.storage_path,
                status        = 'ready',
                profile_hash  = EXCLUDED.profile_hash,
                is_stale      = FALSE,
                generated_at  = NOW(),
                updated_at    = NOW()
        """),
        {"uid": user_id, "path": storage_path, "hash": profile_hash, "tmpl": template},
    )
    await db.commit()

    return pdf_bytes


def _render_pdf(context: dict, template: str = "traditional") -> bytes:
    """Render HTML template and convert to PDF via WeasyPrint."""
    import os
    template_dir = os.path.join(os.path.dirname(__file__), "..", "utils", "templates")

    _template_files = {
        "traditional": "biodata.html",
        "floral": "biodata_floral.html",
        "half_photo": "biodata_half_photo.html",
    }
    template_file = _template_files.get(template, "biodata.html")

    env = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=select_autoescape(["html", "xml"]),
    )
    tmpl = env.get_template(template_file)
    html_content = tmpl.render(**context)

    from weasyprint import HTML, CSS
    # Do NOT use @import url() for Google Fonts — Render has no outbound HTTP
    # during rendering, so a network font fetch blocks and then fails, causing
    # the entire PDF generation to crash. The templates already declare
    # font-family fallbacks (Arial, sans-serif); this CSS just reinforces them.
    font_css = CSS(string="""
        body {
            font-family: 'Noto Sans', 'DejaVu Sans', Arial, sans-serif;
        }
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


async def _fetch_partner_preferences(db: AsyncSession, user_id: UUID) -> Optional[dict]:
    """Fetch partner preferences for biodata — returns None if not set."""
    result = await db.execute(
        text("""
            SELECT min_age, max_age, preferred_states, preferred_castes,
                   preferred_subcastes, min_education, preferred_professions,
                   min_income_lpa, preferred_diet, preferred_family_types,
                   preferred_family_values, smoking_preference, drinking_preference
            FROM partner_preferences WHERE user_id = :uid
        """),
        {"uid": user_id},
    )
    row = result.fetchone()
    if not row:
        return None
    d = row._asdict()
    # Coerce any PostgreSQL array that arrives as a string
    for key in ("preferred_states", "preferred_castes", "preferred_subcastes",
                "preferred_professions", "preferred_diet",
                "preferred_family_types", "preferred_family_values"):
        val = d.get(key)
        if isinstance(val, str):
            stripped = val.strip("{}")
            d[key] = [v.strip() for v in stripped.split(",") if v.strip()] if stripped else []
        elif val is None:
            d[key] = []
    return d if any(d.values()) else None
