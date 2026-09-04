"""
Profile endpoints.
GET/POST/PUT /profile
POST/DELETE /profile/photos
PUT /profile/photos/{id}/primary
GET/PUT /profile/location
GET/PUT /profile/native-place
GET/PUT /profile/education
GET/PUT /profile/employment
GET/PUT /profile/family
GET/PUT /profile/lifestyle
GET/PUT /preferences
"""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.database import get_db, get_supabase
from app.config import get_settings

settings = get_settings()
from app.middleware import get_current_user, AuthenticatedUser
from app.schemas.profile import (
    ProfileCreateRequest, ProfileUpdateRequest, ProfileResponse, FullProfileResponse,
    LocationRequest, LocationResponse,
    EducationRequest, EducationResponse,
    EmploymentRequest, EmploymentResponse,
    FamilyDetailsRequest, FamilyDetailsResponse,
    LifestyleRequest, LifestyleResponse,
    PartnerPreferencesRequest, PartnerPreferencesResponse,
    PhotoResponse,
)
from app.services import profile_service

router = APIRouter(prefix="/profile", tags=["Profile"])
prefs_router = APIRouter(prefix="/preferences", tags=["Preferences"])


# ---------------------------------------------------------------------------
# Profile CRUD  (exact paths — no path params, so safe before /{user_id})
# ---------------------------------------------------------------------------

@router.get("", response_model=FullProfileResponse)
async def get_my_profile(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current user's full profile."""
    data = await profile_service.get_profile(db, current_user.user_id, current_user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Profile not found. Please create your profile.")
    return data


@router.post("", response_model=FullProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_profile(
    body: ProfileCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create or initialize profile during onboarding."""
    result = await profile_service.upsert_profile(db, current_user.user_id, body.model_dump())
    return result


@router.put("", response_model=FullProfileResponse)
async def update_profile(
    body: ProfileUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update profile fields."""
    result = await profile_service.upsert_profile(
        db, current_user.user_id,
        body.model_dump(exclude_none=True)
    )
    return result


# ---------------------------------------------------------------------------
# Shared upsert helper (used by sub-resource routes below)
# ---------------------------------------------------------------------------

_UPSERT_ALLOWED_TABLES = frozenset({
    "current_locations", "native_places", "education",
    "employment", "family_details", "lifestyle",
})


async def _upsert_location(db: AsyncSession, user_id: UUID, data: dict, table: str):
    if table not in _UPSERT_ALLOWED_TABLES:
        raise ValueError(f"Invalid table: {table}")
    existing = await db.execute(
        text(f"SELECT id FROM {table} WHERE user_id = :uid"), {"uid": user_id}
    )
    if existing.fetchone():
        sets = ", ".join(f"{k} = :{k}" for k in data if k != "user_id")
        await db.execute(text(f"UPDATE {table} SET {sets}, updated_at = NOW() WHERE user_id = :user_id"), {"user_id": user_id, **data})
    else:
        cols = ", ".join(["user_id"] + list(data.keys()))
        vals = ", ".join([":user_id"] + [f":{k}" for k in data])
        await db.execute(text(f"INSERT INTO {table} ({cols}) VALUES ({vals})"), {"user_id": user_id, **data})
    await db.commit()


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

@router.get("", response_model=FullProfileResponse)
async def get_my_profile(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current user's full profile."""
    data = await profile_service.get_profile(db, current_user.user_id, current_user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Profile not found. Please create your profile.")
    return data


# ---------------------------------------------------------------------------
# Photos  (must be defined BEFORE /{user_id} to avoid path-param shadowing)
# ---------------------------------------------------------------------------

@router.get("/photos", response_model=list[PhotoResponse])
async def list_photos(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all photos for the current user."""
    result = await db.execute(
        text("""
            SELECT id, storage_path, thumbnail_path, file_size_bytes, is_primary,
                   display_order, created_at
            FROM photos
            WHERE user_id = :uid AND deleted_at IS NULL AND is_approved = TRUE
            ORDER BY display_order ASC
        """),
        {"uid": current_user.user_id},
    )
    rows = result.fetchall()
    supabase = get_supabase()
    bucket = settings.storage_bucket_profile_photos
    photos = []
    for row in rows:
        public_url = supabase.storage.from_(bucket).get_public_url(row.storage_path)
        thumb_url = supabase.storage.from_(bucket).get_public_url(row.thumbnail_path) if row.thumbnail_path else None
        photos.append({
            "id": row.id,
            "url": public_url,
            "thumbnail_url": thumb_url,
            "is_primary": row.is_primary,
            "display_order": row.display_order,
            "file_size_bytes": row.file_size_bytes,
            "created_at": row.created_at.isoformat(),
        })
    return photos


@router.post("/photos", response_model=PhotoResponse, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    photo: UploadFile = File(...),
    make_primary: bool = Form(False),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a profile photo. Validates, compresses, thumbnails automatically."""
    if not photo.content_type or photo.content_type not in profile_service.ALLOWED_PHOTO_MIMES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Unsupported file type. Allowed: JPEG, PNG, WebP",
        )

    # Reject oversized uploads before reading the full body.
    # Content-Length is optional (chunked uploads won't have it), so this is
    # a fast-path only — the service re-checks after read.
    max_bytes = settings.max_photo_size_bytes
    declared_size = photo.size  # populated by Starlette from Content-Length
    if declared_size is not None and declared_size > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"File too large. Maximum {settings.max_photo_size_mb}MB allowed.",
        )

    file_bytes = await photo.read()

    # Double-check actual size after read (covers chunked/missing Content-Length).
    if len(file_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"File too large. Maximum {settings.max_photo_size_mb}MB allowed.",
        )
    try:
        result = await profile_service.upload_photo(
            db=db,
            user_id=current_user.user_id,
            file_bytes=file_bytes,
            filename=photo.filename or "photo.jpg",
            mime_type=photo.content_type,
            make_primary=make_primary,
        )
        return result
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))


@router.delete("/photos/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_photo(
    photo_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a photo. Auto-selects next primary if needed."""
    try:
        await profile_service.delete_photo(db, current_user.user_id, photo_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.put("/photos/{photo_id}/primary", status_code=status.HTTP_204_NO_CONTENT)
async def set_primary_photo(
    photo_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Set a photo as the primary profile photo."""
    result = await db.execute(
        text("SELECT id FROM photos WHERE id = :pid AND user_id = :uid AND deleted_at IS NULL AND is_approved = TRUE"),
        {"pid": photo_id, "uid": current_user.user_id},
    )
    if not result.fetchone():
        raise HTTPException(status_code=404, detail="Photo not found")

    await db.execute(
        text("UPDATE photos SET is_primary = FALSE WHERE user_id = :uid AND is_primary = TRUE"),
        {"uid": current_user.user_id},
    )
    await db.execute(
        text("UPDATE photos SET is_primary = TRUE WHERE id = :pid"),
        {"pid": photo_id},
    )
    await db.commit()


# ---------------------------------------------------------------------------
# Location  (also before /{user_id})
# ---------------------------------------------------------------------------

@router.get("/location", response_model=LocationResponse)
async def get_location(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        text("SELECT * FROM current_locations WHERE user_id = :uid"), {"uid": current_user.user_id}
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Location not set")
    return {"country": row.country, "state": row.state, "district": row.district, "city": row.city}


@router.put("/location", response_model=LocationResponse)
async def update_location(
    body: LocationRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    await _upsert_location(db, current_user.user_id, data, "current_locations")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data


@router.get("/native-place", response_model=LocationResponse)
async def get_native_place(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        text("SELECT * FROM native_places WHERE user_id = :uid"), {"uid": current_user.user_id}
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Native place not set")
    return {"country": row.country, "state": row.state, "district": row.district, "city": row.city}


@router.put("/native-place", response_model=LocationResponse)
async def update_native_place(
    body: LocationRequest,
    is_visible: bool = True,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = {**body.model_dump(), "is_visible": is_visible}
    await _upsert_location(db, current_user.user_id, data, "native_places")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return body.model_dump()


@router.get("/education", response_model=EducationResponse)
async def get_education(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(text("SELECT * FROM education WHERE user_id = :uid"), {"uid": current_user.user_id})
    row = r.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Education not set")
    return {
        "highest_qualification": row.highest_qualification,
        "degree": row.degree,
        "field_of_study": row.field_of_study,
        "college_university": row.college_university,
        "graduation_year": row.graduation_year,
        "additional_qualifications": row.additional_qualifications,
    }


@router.put("/education", response_model=EducationResponse)
async def update_education(
    body: EducationRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    await _upsert_location(db, current_user.user_id, data, "education")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data


@router.get("/employment", response_model=EmploymentResponse)
async def get_employment(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(text("SELECT * FROM employment WHERE user_id = :uid"), {"uid": current_user.user_id})
    row = r.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Employment not set")
    return {c: getattr(row, c, None) for c in [
        "profession", "job_title", "company", "industry", "employment_type",
        "work_location", "income_min_lpa", "income_max_lpa", "show_company", "show_income"
    ]}


@router.put("/employment", response_model=EmploymentResponse)
async def update_employment(
    body: EmploymentRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    await _upsert_location(db, current_user.user_id, {k: v for k, v in data.items() if k not in ("income_min_lpa", "income_max_lpa") or v is not None}, "employment")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data


@router.get("/family", response_model=FamilyDetailsResponse)
async def get_family(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(text("SELECT * FROM family_details WHERE user_id = :uid"), {"uid": current_user.user_id})
    row = r.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Family details not set")
    return {c: getattr(row, c, None) for c in [
        "father_name", "father_occupation", "father_is_alive",
        "mother_name", "mother_occupation", "mother_is_alive",
        "brothers_count", "brothers_married", "sisters_count", "sisters_married",
        "family_type", "family_values", "family_location", "additional_info"
    ]}


@router.put("/family", response_model=FamilyDetailsResponse)
async def update_family(
    body: FamilyDetailsRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    await _upsert_location(db, current_user.user_id, data, "family_details")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data


@router.put("/lifestyle", response_model=LifestyleResponse)
async def update_lifestyle(
    body: LifestyleRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    await _upsert_location(db, current_user.user_id, data, "lifestyle")
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data


@router.post("/complete-onboarding", status_code=status.HTTP_204_NO_CONTENT)
async def complete_onboarding(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark onboarding as completed for the current user."""
    await db.execute(
        text("UPDATE users SET onboarding_completed = TRUE WHERE id = :user_id"),
        {"user_id": current_user.user_id},
    )
    await db.commit()


# ---------------------------------------------------------------------------
# User profile by ID  (MUST be last — path param catches everything above)
# ---------------------------------------------------------------------------

@router.get("/{user_id}", response_model=FullProfileResponse)
async def get_user_profile(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """View another user's profile. Applies privacy and block rules."""
    data = await profile_service.get_profile(db, user_id, current_user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Profile not found or not accessible")

    await db.execute(
        text("""
            INSERT INTO profile_views (viewer_id, viewed_id)
            VALUES (:viewer, :viewed)
            ON CONFLICT DO NOTHING
        """),
        {"viewer": current_user.user_id, "viewed": user_id},
    )
    await db.commit()
    return data

@prefs_router.get("", response_model=PartnerPreferencesResponse)
async def get_preferences(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(text("SELECT * FROM partner_preferences WHERE user_id = :uid"), {"uid": current_user.user_id})
    row = r.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Preferences not set")
    return row._asdict()


@prefs_router.put("", response_model=PartnerPreferencesResponse)
async def update_preferences(
    body: PartnerPreferencesRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump()
    existing = await db.execute(
        text("SELECT id FROM partner_preferences WHERE user_id = :uid"), {"uid": current_user.user_id}
    )
    if existing.fetchone():
        sets = ", ".join(f"{k} = :{k}" for k in data)
        await db.execute(
            text(f"UPDATE partner_preferences SET {sets}, updated_at = NOW() WHERE user_id = :user_id"),
            {"user_id": current_user.user_id, **data},
        )
    else:
        cols = "user_id, " + ", ".join(data.keys())
        vals = ":user_id, " + ", ".join(f":{k}" for k in data)
        await db.execute(
            text(f"INSERT INTO partner_preferences ({cols}) VALUES ({vals})"),
            {"user_id": current_user.user_id, **data},
        )
    await profile_service._update_completion(db, current_user.user_id)
    await db.commit()
    return data
