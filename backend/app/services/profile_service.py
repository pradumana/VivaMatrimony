"""
Profile Service.
Handles profile CRUD, photos, education, employment, family, lifestyle, preferences.
"""
import hashlib
import io
import mimetypes
import os
import structlog
from datetime import date
from typing import Optional, Tuple
from uuid import UUID

from PIL import Image as PILImage
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_supabase
from app.utils import compute_age, safe_filename as _safe_filename

settings = get_settings()
logger = structlog.get_logger()

ALLOWED_PHOTO_MIMES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _compute_age(dob: date) -> int:
    return compute_age(dob)


def _cm_to_display(cm: Optional[int]) -> Optional[str]:
    if cm is None:
        return None
    feet = cm // 30.48
    inches = round((cm % 30.48) / 2.54)
    return f"{int(feet)}'{inches}\""


def _compute_completion(profile: dict, sections: dict) -> int:
    """Calculate profile completion percentage."""
    weights = {
        "basic": 20,       # profile row
        "photos": 15,      # at least 1 photo
        "education": 10,
        "employment": 10,
        "family": 10,
        "lifestyle": 10,
        "location": 10,
        "native_place": 5,
        "preferences": 10,
    }
    score = 0
    if profile.get("has_profile"):
        score += weights["basic"]
    if sections.get("photos", 0) > 0:
        score += weights["photos"]
    if sections.get("education"):
        score += weights["education"]
    if sections.get("employment"):
        score += weights["employment"]
    if sections.get("family"):
        score += weights["family"]
    if sections.get("lifestyle"):
        score += weights["lifestyle"]
    if sections.get("location"):
        score += weights["location"]
    if sections.get("native_place"):
        score += weights["native_place"]
    if sections.get("preferences"):
        score += weights["preferences"]
    return min(score, 100)


# ---------------------------------------------------------------------------
# Profile CRUD
# ---------------------------------------------------------------------------

async def get_profile(
    db: AsyncSession,
    user_id: UUID,
    requesting_user_id: Optional[UUID] = None,
) -> Optional[dict]:
    """
    Get a user's full profile.
    Applies privacy settings when requesting_user_id != user_id.
    """
    result = await db.execute(
        text("""
            SELECT p.*,
                   u.account_status, u.verification_status, u.last_active_at, u.member_id,
                   cl.country as cl_country, cl.state as cl_state, cl.district as cl_district, cl.city as cl_city,
                   np.country as np_country, np.state as np_state, np.district as np_district, np.city as np_city, np.is_visible as np_visible,
                   e.highest_qualification, e.degree, e.field_of_study, e.college_university, e.graduation_year, e.additional_qualifications,
                   em.profession, em.job_title, em.company, em.industry, em.employment_type,
                   em.work_location, em.income_min_lpa, em.income_max_lpa, em.show_company, em.show_income,
                   fd.father_name, fd.father_occupation, fd.father_is_alive,
                   fd.mother_name, fd.mother_occupation, fd.mother_is_alive,
                   fd.brothers_count, fd.brothers_married, fd.sisters_count, fd.sisters_married,
                   fd.family_type, fd.family_values, fd.family_location, fd.additional_info as fam_info, fd.show_parents_info,
                   ls.diet, ls.smoking, ls.drinking, ls.fitness, ls.hobbies, ls.interests, ls.travel, ls.pets, ls.pet_types, ls.other_info as ls_info
            FROM profiles p
            JOIN users u ON u.id = p.user_id
            LEFT JOIN current_locations cl ON cl.user_id = p.user_id
            LEFT JOIN native_places np ON np.user_id = p.user_id
            LEFT JOIN education e ON e.user_id = p.user_id
            LEFT JOIN employment em ON em.user_id = p.user_id
            LEFT JOIN family_details fd ON fd.user_id = p.user_id
            LEFT JOIN lifestyle ls ON ls.user_id = p.user_id
            WHERE p.user_id = :user_id
              AND u.deleted_at IS NULL
        """),
        {"user_id": user_id},
    )
    row = result.fetchone()
    if not row:
        return None

    is_own = requesting_user_id == user_id

    # Check block
    if not is_own and requesting_user_id:
        block_result = await db.execute(
            text("""
                SELECT 1 FROM blocks
                WHERE (blocker_id = :a AND blocked_id = :b)
                   OR (blocker_id = :b AND blocked_id = :a)
                LIMIT 1
            """),
            {"a": requesting_user_id, "b": user_id},
        )
        if block_result.fetchone():
            return None  # Hidden due to block

    # Check account status for non-own views
    if not is_own and row.account_status not in ("active", "pending_verification"):
        return None

    # Get primary photo
    photo_result = await db.execute(
        text("""
            SELECT id, storage_path, thumbnail_path FROM photos
            WHERE user_id = :user_id AND is_primary = TRUE AND deleted_at IS NULL
            LIMIT 1
        """),
        {"user_id": user_id},
    )
    primary_photo = photo_result.fetchone()

    photo_count_result = await db.execute(
        text("SELECT COUNT(*) as cnt FROM photos WHERE user_id = :user_id AND deleted_at IS NULL AND is_approved = TRUE"),
        {"user_id": user_id},
    )
    photo_count = photo_count_result.fetchone().cnt

    supabase = get_supabase()

    def get_public_url(path: str, bucket: str) -> str:
        try:
            res = supabase.storage.from_(bucket).get_public_url(path)
            return res
        except Exception:
            return ""

    primary_photo_url = None
    thumbnail_url = None
    if primary_photo:
        primary_photo_url = get_public_url(primary_photo.storage_path, settings.storage_bucket_profile_photos)
        if primary_photo.thumbnail_path:
            thumbnail_url = get_public_url(primary_photo.thumbnail_path, settings.storage_bucket_profile_photos)

    dob = row.date_of_birth
    age = _compute_age(dob)

    profile_data = {
        "id": row.id,
        "user_id": row.user_id,
        "full_name": row.full_name,
        "gender": row.gender,
        "date_of_birth": dob,
        "age": age,
        "height_cm": row.height_cm,
        "height_display": _cm_to_display(row.height_cm),
        "marital_status": row.marital_status,
        "have_children": row.have_children,
        "children_count": row.children_count,
        "mother_tongue": row.mother_tongue,
        "languages_known": row.languages_known,
        "religion": row.religion,
        "caste": row.caste,
        "sub_caste": row.sub_caste,
        "about_me": row.about_me,
        "profile_visibility": row.profile_visibility,
        "photo_visibility": row.photo_visibility,
        "completion_percentage": row.completion_percentage,
        "is_verified": row.verification_status == "verified",
        "last_active_at": row.last_active_at,
    }

    current_location = {
        "country": row.cl_country,
        "state": row.cl_state,
        "district": row.cl_district,
        "city": row.cl_city,
    } if row.cl_country else None

    # Native place: respect visibility
    native_place = None
    if row.np_country and (is_own or row.np_visible):
        native_place = {
            "country": row.np_country,
            "state": row.np_state,
            "district": row.np_district,
            "city": row.np_city,
        }

    education = None
    if row.highest_qualification or row.degree:
        education = {
            "highest_qualification": row.highest_qualification,
            "degree": row.degree,
            "field_of_study": row.field_of_study,
            "college_university": row.college_university,
            "graduation_year": row.graduation_year,
            "additional_qualifications": row.additional_qualifications,
        }

    employment = None
    if row.profession:
        employment = {
            "profession": row.profession,
            "job_title": row.job_title,
            "company": row.company if (is_own or row.show_company) else None,
            "industry": row.industry,
            "employment_type": row.employment_type,
            "work_location": row.work_location,
            "income_min_lpa": row.income_min_lpa if (is_own or row.show_income) else None,
            "income_max_lpa": row.income_max_lpa if (is_own or row.show_income) else None,
            "show_company": row.show_company,
            "show_income": row.show_income,
        }

    family = None
    if row.family_type or row.brothers_count is not None:
        family = {
            "father_name": row.father_name if (is_own or row.show_parents_info) else None,
            "father_occupation": row.father_occupation,
            "father_is_alive": row.father_is_alive,
            "mother_name": row.mother_name if (is_own or row.show_parents_info) else None,
            "mother_occupation": row.mother_occupation,
            "mother_is_alive": row.mother_is_alive,
            "brothers_count": row.brothers_count,
            "brothers_married": row.brothers_married,
            "sisters_count": row.sisters_count,
            "sisters_married": row.sisters_married,
            "family_type": row.family_type,
            "family_values": row.family_values,
            "family_location": row.family_location,
            "additional_info": row.fam_info,
        }

    lifestyle = None
    if row.diet or row.smoking:
        lifestyle = {
            "diet": row.diet,
            "smoking": row.smoking,
            "drinking": row.drinking,
            "fitness": row.fitness,
            "hobbies": row.hobbies,
            "interests": row.interests,
            "travel": row.travel,
            "pets": row.pets,
            "pet_types": row.pet_types,
            "other_info": row.ls_info,
        }

    return {
        "profile": profile_data,
        "member_id": row.member_id,
        "current_location": current_location,
        "native_place": native_place,
        "education": education,
        "employment": employment,
        "family": family,
        "lifestyle": lifestyle,
        "primary_photo_url": primary_photo_url,
        "thumbnail_url": thumbnail_url,
        "photo_count": photo_count,
    }


async def upsert_profile(
    db: AsyncSession,
    user_id: UUID,
    data: dict,
) -> dict:
    """Create or update profile."""
    existing = await db.execute(
        text("SELECT id FROM profiles WHERE user_id = :user_id"),
        {"user_id": user_id},
    )
    exists = existing.fetchone() is not None

    if exists:
        await db.execute(
            text("""
                UPDATE profiles SET
                  full_name = COALESCE(:full_name, full_name),
                  gender = COALESCE(:gender, gender),
                  date_of_birth = COALESCE(:dob, date_of_birth),
                  height_cm = COALESCE(:height, height_cm),
                  marital_status = COALESCE(:marital_status, marital_status),
                  have_children = COALESCE(:have_children, have_children),
                  children_count = COALESCE(:children_count, children_count),
                  mother_tongue = COALESCE(:mother_tongue, mother_tongue),
                  languages_known = COALESCE(:languages, languages_known),
                  religion = COALESCE(:religion, religion),
                  caste = COALESCE(:caste, caste),
                  sub_caste = COALESCE(:sub_caste, sub_caste),
                  about_me = COALESCE(:about_me, about_me),
                  updated_at = NOW()
                WHERE user_id = :user_id
            """),
            {
                "user_id": user_id,
                "full_name": data.get("full_name"),
                "gender": data.get("gender"),
                "dob": data.get("date_of_birth"),
                "height": data.get("height_cm"),
                "marital_status": data.get("marital_status"),
                "have_children": data.get("have_children"),
                "children_count": data.get("children_count"),
                "mother_tongue": data.get("mother_tongue"),
                "languages": data.get("languages_known"),
                "religion": data.get("religion"),
                "caste": data.get("caste"),
                "sub_caste": data.get("sub_caste"),
                "about_me": data.get("about_me"),
            },
        )
    else:
        await db.execute(
            text("""
                INSERT INTO profiles (
                  user_id, full_name, gender, date_of_birth, height_cm,
                  marital_status, have_children, children_count,
                  mother_tongue, languages_known, religion, caste, sub_caste, about_me
                ) VALUES (
                  :user_id, :full_name, :gender, :dob, :height,
                  :marital_status, :have_children, :children_count,
                  :mother_tongue, :languages, :religion, :caste, :sub_caste, :about_me
                )
            """),
            {
                "user_id": user_id,
                "full_name": data.get("full_name"),
                "gender": data.get("gender"),
                "dob": data.get("date_of_birth"),
                "height": data.get("height_cm"),
                "marital_status": data.get("marital_status", "never_married"),
                "have_children": data.get("have_children", False),
                "children_count": data.get("children_count", 0),
                "mother_tongue": data.get("mother_tongue"),
                "languages": data.get("languages_known"),
                "religion": data.get("religion"),
                "caste": data.get("caste"),
                "sub_caste": data.get("sub_caste"),
                "about_me": data.get("about_me"),
            },
        )

    await _update_completion(db, user_id)
    await db.commit()
    return await get_profile(db, user_id, requesting_user_id=user_id)


async def _update_completion(db: AsyncSession, user_id: UUID) -> None:
    """Recalculate and update completion_percentage."""
    checks = await db.execute(
        text("""
            SELECT
              (SELECT COUNT(*) FROM photos WHERE user_id = :uid AND deleted_at IS NULL) as photos,
              (SELECT COUNT(*) FROM education WHERE user_id = :uid) as edu,
              (SELECT COUNT(*) FROM employment WHERE user_id = :uid) as emp,
              (SELECT COUNT(*) FROM family_details WHERE user_id = :uid) as fam,
              (SELECT COUNT(*) FROM lifestyle WHERE user_id = :uid) as ls,
              (SELECT COUNT(*) FROM current_locations WHERE user_id = :uid) as loc,
              (SELECT COUNT(*) FROM native_places WHERE user_id = :uid) as np,
              (SELECT COUNT(*) FROM partner_preferences WHERE user_id = :uid) as prefs
        """),
        {"uid": user_id},
    )
    c = checks.fetchone()

    pct = 20  # base for having a profile row
    if c.photos > 0: pct += 15
    if c.edu > 0: pct += 10
    if c.emp > 0: pct += 10
    if c.fam > 0: pct += 10
    if c.ls > 0: pct += 10
    if c.loc > 0: pct += 10
    if c.np > 0: pct += 5
    if c.prefs > 0: pct += 10

    await db.execute(
        text("UPDATE profiles SET completion_percentage = :pct WHERE user_id = :uid"),
        {"pct": min(pct, 100), "uid": user_id},
    )


# ---------------------------------------------------------------------------
# Photo upload
# ---------------------------------------------------------------------------

async def upload_photo(
    db: AsyncSession,
    user_id: UUID,
    file_bytes: bytes,
    filename: str,
    mime_type: str,
    make_primary: bool = False,
) -> dict:
    """
    Validate, compress, upload photo to Supabase Storage.
    Returns photo record.
    """
    # Validate MIME
    if mime_type not in ALLOWED_PHOTO_MIMES:
        raise ValueError(f"Unsupported image type: {mime_type}")

    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_PHOTO_EXTENSIONS:
        raise ValueError(f"Unsupported file extension: {ext}")

    if len(file_bytes) > settings.max_photo_size_bytes:
        raise ValueError(f"File too large. Maximum {settings.max_photo_size_mb}MB allowed")

    # Open and validate image
    try:
        img = PILImage.open(io.BytesIO(file_bytes))
        img.verify()
        img = PILImage.open(io.BytesIO(file_bytes))  # Re-open after verify
    except Exception:
        raise ValueError("Invalid or corrupt image file")

    width, height = img.size
    if width < 100 or height < 100:
        raise ValueError("Image too small. Minimum 100x100 pixels required")

    # Compress and resize main image (max 1200px on longest side)
    img = img.convert("RGB")
    max_dim = 1200
    if max(width, height) > max_dim:
        img.thumbnail((max_dim, max_dim), PILImage.LANCZOS)

    compressed_bytes = io.BytesIO()
    img.save(compressed_bytes, format="JPEG", quality=85, optimize=True)
    compressed_bytes.seek(0)
    final_bytes = compressed_bytes.read()

    # Generate thumbnail
    thumb = img.copy()
    thumb.thumbnail((settings.thumbnail_width, settings.thumbnail_height), PILImage.LANCZOS)
    thumb_bytes_io = io.BytesIO()
    thumb.save(thumb_bytes_io, format="JPEG", quality=80)
    thumb_bytes_io.seek(0)
    thumb_bytes = thumb_bytes_io.read()

    # Check how many photos user already has
    count_result = await db.execute(
        text("SELECT COUNT(*) as cnt FROM photos WHERE user_id = :uid AND deleted_at IS NULL"),
        {"uid": user_id},
    )
    photo_count = count_result.fetchone().cnt
    if photo_count >= 10:
        raise ValueError("Maximum 10 photos allowed")

    # Determine if this should be primary
    is_primary = make_primary or photo_count == 0

    # Get next display order
    order_result = await db.execute(
        text("SELECT COALESCE(MAX(display_order), -1) + 1 as next_order FROM photos WHERE user_id = :uid AND deleted_at IS NULL"),
        {"uid": user_id},
    )
    display_order = order_result.fetchone().next_order

    # Upload to Supabase Storage
    supabase = get_supabase()
    safe_filename = f"{user_id}/{_safe_filename(filename)}"
    thumb_filename = f"{user_id}/thumb_{_safe_filename(filename)}"

    try:
        supabase.storage.from_(settings.storage_bucket_profile_photos).upload(
            path=safe_filename,
            file=final_bytes,
            file_options={"content-type": "image/jpeg"},
        )
        supabase.storage.from_(settings.storage_bucket_profile_photos).upload(
            path=thumb_filename,
            file=thumb_bytes,
            file_options={"content-type": "image/jpeg"},
        )
    except Exception as exc:
        logger.error("photo_upload_failed", error=str(exc), user_id=str(user_id))
        raise ValueError("Failed to upload photo. Please try again.")

    # If primary, demote existing primary
    if is_primary:
        await db.execute(
            text("UPDATE photos SET is_primary = FALSE WHERE user_id = :uid AND is_primary = TRUE AND deleted_at IS NULL"),
            {"uid": user_id},
        )

    # Save metadata
    insert_result = await db.execute(
        text("""
            INSERT INTO photos (
              user_id, storage_path, thumbnail_path, file_name,
              file_size_bytes, mime_type, width_px, height_px,
              is_primary, display_order
            ) VALUES (
              :uid, :path, :thumb_path, :filename,
              :size, :mime, :w, :h, :primary, :order
            ) RETURNING id
        """),
        {
            "uid": user_id,
            "path": safe_filename,
            "thumb_path": thumb_filename,
            "filename": filename,
            "size": len(final_bytes),
            "mime": "image/jpeg",
            "w": img.width,
            "h": img.height,
            "primary": is_primary,
            "order": display_order,
        },
    )
    photo_id = insert_result.fetchone().id

    await _update_completion(db, user_id)
    await db.commit()

    public_url = supabase.storage.from_(settings.storage_bucket_profile_photos).get_public_url(safe_filename)
    thumb_url = supabase.storage.from_(settings.storage_bucket_profile_photos).get_public_url(thumb_filename)

    logger.info("photo_uploaded", user_id=str(user_id), photo_id=str(photo_id))
    return {
        "id": photo_id,
        "url": public_url,
        "thumbnail_url": thumb_url,
        "is_primary": is_primary,
        "display_order": display_order,
    }


async def delete_photo(db: AsyncSession, user_id: UUID, photo_id: UUID) -> dict:
    """Soft-delete a photo. If primary, try to set another as primary."""
    result = await db.execute(
        text("""
            SELECT storage_path, thumbnail_path, is_primary
            FROM photos
            WHERE id = :photo_id AND user_id = :user_id AND deleted_at IS NULL
        """),
        {"photo_id": photo_id, "user_id": user_id},
    )
    photo = result.fetchone()
    if not photo:
        raise ValueError("Photo not found")

    was_primary = photo.is_primary

    await db.execute(
        text("UPDATE photos SET deleted_at = NOW() WHERE id = :photo_id"),
        {"photo_id": photo_id},
    )

    if was_primary:
        # Assign primary to next available photo
        next_photo = await db.execute(
            text("""
                SELECT id FROM photos
                WHERE user_id = :uid AND deleted_at IS NULL AND is_approved = TRUE
                ORDER BY display_order ASC
                LIMIT 1
            """),
            {"uid": user_id},
        )
        next_row = next_photo.fetchone()
        if next_row:
            await db.execute(
                text("UPDATE photos SET is_primary = TRUE WHERE id = :id"),
                {"id": next_row.id},
            )

    await _update_completion(db, user_id)
    await db.commit()

    # Clean up storage (non-blocking)
    try:
        supabase = get_supabase()
        supabase.storage.from_(settings.storage_bucket_profile_photos).remove([photo.storage_path])
        if photo.thumbnail_path:
            supabase.storage.from_(settings.storage_bucket_profile_photos).remove([photo.thumbnail_path])
    except Exception as exc:
        logger.warning("photo_storage_cleanup_failed", error=str(exc))

    return {"success": True, "was_primary": was_primary}


