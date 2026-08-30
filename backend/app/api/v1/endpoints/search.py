"""
Search endpoints.
GET /search — filter profiles with pagination.
GET /matches — recommended matches.
GET /matches/{user_id} — compatibility score.
"""
from datetime import date
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_db, get_supabase
from app.middleware import get_current_user, AuthenticatedUser, limiter
from app.services.matching_service import get_recommended_matches, calculate_compatibility
from app.utils import compute_age
from fastapi import Request

router = APIRouter(tags=["Search & Matching"])


@router.get("/search")
@limiter.limit("30/minute")
async def search_profiles(
    request: Request,
    # Age
    min_age: Optional[int] = Query(None, ge=18, le=80),
    max_age: Optional[int] = Query(None, ge=18, le=80),
    # Location
    state: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    country: Optional[str] = Query(None),
    # Native place
    native_state: Optional[str] = Query(None),
    native_district: Optional[str] = Query(None),
    # Personal
    gender: Optional[str] = Query(None),
    religion: Optional[str] = Query(None),
    caste: Optional[str] = Query(None),
    mother_tongue: Optional[str] = Query(None),
    marital_status: Optional[str] = Query(None),
    # Education
    min_qualification: Optional[str] = Query(None),
    # Employment
    profession: Optional[str] = Query(None),
    # Lifestyle
    diet: Optional[str] = Query(None),
    # Verification
    verified_only: bool = Query(False),
    has_photo: bool = Query(False),
    # Pagination
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Search profiles with filters. Uses PostgreSQL full-text and indexed queries.
    """
    offset = (page - 1) * page_size

    # Build query dynamically
    conditions = [
        "u.id != :uid",
        "u.account_status = 'active'",
        "u.deleted_at IS NULL",
        "p.profile_visibility != 'hidden'",
        """NOT EXISTS (
            SELECT 1 FROM blocks b
            WHERE (b.blocker_id = :uid AND b.blocked_id = u.id)
               OR (b.blocker_id = u.id AND b.blocked_id = :uid)
        )""",
    ]
    params: dict = {"uid": current_user.user_id, "limit": page_size, "offset": offset}

    if min_age:
        conditions.append("get_age(p.date_of_birth) >= :min_age")
        params["min_age"] = min_age
    if max_age:
        conditions.append("get_age(p.date_of_birth) <= :max_age")
        params["max_age"] = max_age
    if gender:
        conditions.append("p.gender = :gender")
        params["gender"] = gender
    if religion:
        conditions.append("LOWER(p.religion) = LOWER(:religion)")
        params["religion"] = religion
    if caste:
        conditions.append("LOWER(p.caste) LIKE LOWER(:caste)")
        params["caste"] = f"%{caste}%"
    if mother_tongue:
        conditions.append("LOWER(p.mother_tongue) = LOWER(:mother_tongue)")
        params["mother_tongue"] = mother_tongue
    if marital_status:
        conditions.append("p.marital_status = :marital_status")
        params["marital_status"] = marital_status
    if state:
        conditions.append("LOWER(cl.state) = LOWER(:state)")
        params["state"] = state
    if city:
        conditions.append("LOWER(cl.city) LIKE LOWER(:city)")
        params["city"] = f"%{city}%"
    if native_state:
        conditions.append("LOWER(np.state) = LOWER(:native_state)")
        params["native_state"] = native_state
    if native_district:
        conditions.append("LOWER(np.district) LIKE LOWER(:native_district)")
        params["native_district"] = f"%{native_district}%"
    if profession:
        conditions.append("LOWER(em.profession) LIKE LOWER(:profession)")
        params["profession"] = f"%{profession}%"
    if diet:
        conditions.append("ls.diet = :diet")
        params["diet"] = diet
    if verified_only:
        conditions.append("u.verification_status = 'verified'")
    if has_photo:
        conditions.append("EXISTS (SELECT 1 FROM photos ph WHERE ph.user_id = u.id AND ph.deleted_at IS NULL)")

    where_clause = " AND ".join(conditions)

    count_result = await db.execute(
        text(f"""
            SELECT COUNT(DISTINCT u.id) as total
            FROM users u
            JOIN profiles p ON p.user_id = u.id
            LEFT JOIN current_locations cl ON cl.user_id = u.id
            LEFT JOIN native_places np ON np.user_id = u.id
            LEFT JOIN employment em ON em.user_id = u.id
            LEFT JOIN lifestyle ls ON ls.user_id = u.id
            WHERE {where_clause}
        """),
        params,
    )
    total = count_result.fetchone().total

    result = await db.execute(
        text(f"""
            SELECT DISTINCT u.id as user_id,
                   p.full_name, p.date_of_birth, p.height_cm, p.religion, p.mother_tongue,
                   p.marital_status, u.verification_status,
                   cl.state, cl.city,
                   ph.storage_path as photo_path, ph.thumbnail_path,
                   e.highest_qualification, em.profession,
                   u.last_active_at
            FROM users u
            JOIN profiles p ON p.user_id = u.id
            LEFT JOIN current_locations cl ON cl.user_id = u.id
            LEFT JOIN native_places np ON np.user_id = u.id
            LEFT JOIN photos ph ON ph.user_id = u.id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
            LEFT JOIN education e ON e.user_id = u.id
            LEFT JOIN employment em ON em.user_id = u.id
            LEFT JOIN lifestyle ls ON ls.user_id = u.id
            WHERE {where_clause}
            ORDER BY u.last_active_at DESC NULLS LAST
            LIMIT :limit OFFSET :offset
        """),
        params,
    )
    rows = result.fetchall()

    supabase = get_supabase()
    cfg = get_settings()

    profiles = []
    for row in rows:
        dob = row.date_of_birth
        age = compute_age(dob) if dob else None
        photo_url = None
        if row.photo_path:
            try:
                photo_url = supabase.storage.from_(cfg.storage_bucket_profile_photos).get_public_url(row.photo_path)
            except Exception:
                pass

        profiles.append({
            "user_id": str(row.user_id),
            "full_name": row.full_name,
            "age": age,
            "height_cm": row.height_cm,
            "religion": row.religion,
            "mother_tongue": row.mother_tongue,
            "marital_status": row.marital_status,
            "location": f"{row.city}, {row.state}" if row.city and row.state else (row.state or ""),
            "highest_qualification": row.highest_qualification,
            "profession": row.profession,
            "is_verified": row.verification_status == "verified",
            "primary_photo_url": photo_url,
            "last_active_at": row.last_active_at,
        })

    return {
        "results": profiles,
        "total": total,
        "page": page,
        "page_size": page_size,
        "total_pages": (total + page_size - 1) // page_size,
    }


@router.get("/matches")
async def get_matches(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get recommended matches sorted by compatibility."""
    matches = await get_recommended_matches(db, current_user.user_id, limit=limit, offset=offset)
    return {"matches": matches, "count": len(matches)}


@router.get("/matches/{user_id}")
async def get_compatibility(
    user_id: UUID,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get compatibility score between current user and another user."""
    result = await calculate_compatibility(db, current_user.user_id, user_id)
    return result
