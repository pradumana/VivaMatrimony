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
from PIL import Image as PILImage

from app.config import get_settings
from app.database import get_supabase
from app.services.profile_service import get_profile

settings = get_settings()
logger = structlog.get_logger()

# Image optimization constants
MAX_IMAGE_WIDTH = 800  # pixels
MAX_IMAGE_HEIGHT = 1000  # pixels  
MAX_IMAGE_SIZE_MB = 2  # MB before compression
JPEG_QUALITY = 85  # Balance between quality and size


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
            # Optimize image before adding to PDF
            optimized_url = await _optimize_image_for_pdf(url, supabase, p.storage_path)
            all_photo_urls.append(optimized_url if optimized_url else url)
        except Exception as exc:
            logger.warning("photo_optimization_failed", path=p.storage_path, error=str(exc))
            # Use original URL as fallback
            try:
                url = supabase.storage.from_(settings.storage_bucket_profile_photos).get_public_url(p.storage_path)
                all_photo_urls.append(url)
            except Exception:
                pass

    # Build template context — NO sensitive data
    context = {
        "full_name": _normalize_text(profile.get("full_name", "")),
        "age": profile.get("age"),
        "gender": _normalize_text(profile.get("gender", "")).title() if profile.get("gender") else None,
        "height": profile.get("height_display"),
        "marital_status": _format_enum(profile.get("marital_status", "")),
        "have_children": profile.get("have_children"),
        "children_count": profile.get("children_count"),
        "mother_tongue": _normalize_text(profile.get("mother_tongue", "")),
        "languages_known": _normalize_array(profile.get("languages_known")),
        "religion": _normalize_text(profile.get("religion", "")),
        "caste": _normalize_text(profile.get("caste", "")),
        "sub_caste": _normalize_text(profile.get("sub_caste", "")),
        "gotra": _normalize_text(profile.get("gotra", "")),
        "about_me": _normalize_text(profile.get("about_me", "")),
        "photo_url": primary_photo_url,
        "all_photo_urls": all_photo_urls,
        "is_verified": profile.get("is_verified", False),
        "member_id": profile_data.get("member_id"),

        # Location
        "current_location": _format_location(profile_data.get("current_location")),
        "native_place": _format_location(profile_data.get("native_place")),

        # Education
        "education": _normalize_education(profile_data.get("education")),

        # Employment — respect show_income/show_company flags
        "employment": _filter_employment(profile_data.get("employment")),

        # Family — respect show_parents_info
        "family": _normalize_family(profile_data.get("family")),

        # Lifestyle
        "lifestyle": _normalize_lifestyle(profile_data.get("lifestyle")),

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

    # Map template names to V2 templates (new premium designs)
    _template_files = {
        "traditional": "biodata_traditional_v2.html",
        "modern": "biodata_modern_v2.html",
        "floral": "biodata_floral_v2.html",
        "royal": "biodata_royal_v2.html",
        # Legacy fallbacks for old template names
        "half_photo": "biodata_modern_v2.html",  # Map old "half_photo" to new "modern"
    }
    template_file = _template_files.get(template, "biodata_traditional_v2.html")

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
    """Format location dict into readable string."""
    if not loc:
        return None
    parts = [p for p in [loc.get("city"), loc.get("district"), loc.get("state"), loc.get("country")] if p]
    return ", ".join(parts) if parts else None


def _format_enum(val: str) -> str:
    """Convert enum value to title case display text."""
    if not val:
        return ""
    return val.replace("_", " ").title()


def _normalize_text(text: Optional[str]) -> Optional[str]:
    """Normalize text: trim whitespace, handle empty strings."""
    if not text:
        return None
    text = text.strip()
    return text if text else None


def _normalize_array(arr: Optional[list]) -> Optional[list]:
    """Normalize array: remove empty items, handle None."""
    if not arr:
        return None
    normalized = [item.strip() for item in arr if item and str(item).strip()]
    return normalized if normalized else None


def _filter_employment(employment: Optional[dict]) -> Optional[dict]:
    """Filter employment data based on privacy settings."""
    if not employment:
        return None
    result = dict(employment)
    
    # Normalize text fields
    if result.get("profession"):
        result["profession"] = _normalize_text(result["profession"])
    if result.get("job_title"):
        result["job_title"] = _normalize_text(result["job_title"])
    if result.get("industry"):
        result["industry"] = _normalize_text(result["industry"])
    if result.get("work_location"):
        result["work_location"] = _normalize_text(result["work_location"])
    
    # Apply privacy filters
    if not result.get("show_company"):
        result["company"] = None
    elif result.get("company"):
        result["company"] = _normalize_text(result["company"])
    
    if not result.get("show_income"):
        result["income_min_lpa"] = None
        result["income_max_lpa"] = None
    
    return result if any([
        result.get("profession"),
        result.get("job_title"),
        result.get("company"),
        result.get("industry"),
        result.get("income_min_lpa")
    ]) else None


def _normalize_education(education: Optional[dict]) -> Optional[dict]:
    """Normalize education data."""
    if not education:
        return None
    result = dict(education)
    
    # Normalize text fields
    for field in ["highest_qualification", "degree", "field_of_study", "college_university", "additional_qualifications"]:
        if result.get(field):
            result[field] = _normalize_text(result[field])
    
    return result if any(result.values()) else None


def _normalize_family(family: Optional[dict]) -> Optional[dict]:
    """Normalize family data and respect privacy settings."""
    if not family:
        return None
    result = dict(family)
    
    # Apply privacy filter for parent information
    if not result.get("show_parents_info"):
        result["father_name"] = None
        result["father_occupation"] = None
        result["father_is_alive"] = None
        result["mother_name"] = None
        result["mother_occupation"] = None
        result["mother_is_alive"] = None
    else:
        # Normalize text fields only if showing parent info
        for field in ["father_name", "father_occupation", "mother_name", "mother_occupation"]:
            if result.get(field):
                result[field] = _normalize_text(result[field])
    
    # Always normalize non-parent fields
    for field in ["family_location", "additional_info"]:
        if result.get(field):
            result[field] = _normalize_text(result[field])
    
    # Format family type and values
    if result.get("family_type"):
        result["family_type"] = _normalize_text(result["family_type"])
    if result.get("family_values"):
        result["family_values"] = _normalize_text(result["family_values"])
    
    # Return None if no displayable family data exists
    return result if any([
        result.get("father_name"),
        result.get("mother_name"),
        result.get("brothers_count") is not None,
        result.get("sisters_count") is not None,
        result.get("family_type"),
        result.get("family_values"),
        result.get("family_location"),
        result.get("additional_info")
    ]) else None


def _normalize_lifestyle(lifestyle: Optional[dict]) -> Optional[dict]:
    """Normalize lifestyle data."""
    if not lifestyle:
        return None
    result = dict(lifestyle)
    
    # Normalize text fields
    for field in ["fitness", "other_info"]:
        if result.get(field):
            result[field] = _normalize_text(result[field])
    
    # Normalize arrays
    if result.get("hobbies"):
        result["hobbies"] = _normalize_array(result["hobbies"])
    if result.get("interests"):
        result["interests"] = _normalize_array(result["interests"])
    if result.get("pet_types"):
        result["pet_types"] = _normalize_array(result["pet_types"])
    
    return result if any([
        result.get("diet"),
        result.get("smoking"),
        result.get("drinking"),
        result.get("fitness"),
        result.get("hobbies"),
        result.get("interests"),
        result.get("travel"),
        result.get("pets"),
        result.get("other_info")
    ]) else None


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


async def _optimize_image_for_pdf(image_url: str, supabase, storage_path: str) -> Optional[str]:
    """
    Optimize image for PDF embedding to reduce file size.
    Downloads, resizes, compresses, and re-uploads optimized version.
    Returns optimized URL or None if optimization fails.
    """
    try:
        import httpx
        from io import BytesIO
        
        # Download image
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(image_url)
            if response.status_code != 200:
                return None
            
            image_bytes = response.content
            
            # Check if image is already small enough
            size_mb = len(image_bytes) / (1024 * 1024)
            if size_mb < 0.5:  # Already small, skip optimization
                return None
            
            # Open image with Pillow
            img = PILImage.open(BytesIO(image_bytes))
            
            # Convert RGBA to RGB if needed
            if img.mode in ('RGBA', 'LA', 'P'):
                background = PILImage.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background
            elif img.mode != 'RGB':
                img = img.convert('RGB')
            
            # Calculate new dimensions maintaining aspect ratio
            width, height = img.size
            if width > MAX_IMAGE_WIDTH or height > MAX_IMAGE_HEIGHT:
                ratio = min(MAX_IMAGE_WIDTH / width, MAX_IMAGE_HEIGHT / height)
                new_width = int(width * ratio)
                new_height = int(height * ratio)
                img = img.resize((new_width, new_height), PILImage.Resampling.LANCZOS)
            
            # Save optimized image to bytes
            output = BytesIO()
            img.save(output, format='JPEG', quality=JPEG_QUALITY, optimize=True)
            optimized_bytes = output.getvalue()
            
            # Only use optimized version if significantly smaller
            optimized_size_mb = len(optimized_bytes) / (1024 * 1024)
            if optimized_size_mb >= size_mb * 0.8:  # Less than 20% reduction, skip
                return None
            
            # Upload optimized version with _optimized suffix
            base_path = storage_path.rsplit('.', 1)[0]
            ext = storage_path.rsplit('.', 1)[1] if '.' in storage_path else 'jpg'
            optimized_path = f"{base_path}_optimized.jpg"
            
            try:
                # Remove existing optimized version if any
                supabase.storage.from_(settings.storage_bucket_profile_photos).remove([optimized_path])
            except Exception:
                pass
            
            # Upload new optimized version
            supabase.storage.from_(settings.storage_bucket_profile_photos).upload(
                path=optimized_path,
                file=optimized_bytes,
                file_options={"content-type": "image/jpeg"},
            )
            
            # Return optimized URL
            optimized_url = supabase.storage.from_(settings.storage_bucket_profile_photos).get_public_url(optimized_path)
            logger.info("image_optimized", 
                       original_size_mb=round(size_mb, 2), 
                       optimized_size_mb=round(optimized_size_mb, 2),
                       reduction_pct=round((1 - optimized_size_mb/size_mb) * 100, 1))
            return optimized_url
            
    except Exception as exc:
        logger.warning("image_optimization_failed", error=str(exc), storage_path=storage_path)
        return None
