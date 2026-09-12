"""
Search endpoints.
GET /search — filter profiles with pagination.
GET /matches — recommended matches.
GET /matches/{user_id} — compatibility score.
"""
from datetime import date, timedelta
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


def _build_order_clause(sort_by: Optional[str]) -> str:
    return {
        "age_asc":  "p.date_of_birth DESC NULLS LAST",   # youngest = largest DOB
        "age_desc": "p.date_of_birth ASC NULLS LAST",    # oldest = smallest DOB
        "newest":   "u.created_at DESC NULLS LAST",
    }.get(sort_by or "", "u.last_active_at DESC NULLS LAST")


@router.get("/search")
@limiter.limit("30/minute")
async def search_profiles(
    request: Request,
    # Direct lookup
    member_id: Optional[str] = Query(None),
    # Free-text name search
    q: Optional[str] = Query(None, max_length=100),
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
    sub_caste: Optional[str] = Query(None),
    gotra: Optional[str] = Query(None),
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
    # Sorting
    sort_by: Optional[str] = Query("last_active", pattern="^(last_active|age_asc|age_desc|newest)$"),
    # Pagination
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Search profiles with filters. Uses PostgreSQL full-text and indexed queries.
    """
    # ── member_id direct lookup ──────────────────────────────────────────────
    if member_id:
        member_id_upper = member_id.strip().upper()
        result = await db.execute(
            text("""
                SELECT u.id as user_id,
                       p.full_name, p.date_of_birth, p.height_cm, p.religion, p.mother_tongue,
                       p.marital_status, u.verification_status,
                       cl.state, cl.city,
                       ph.storage_path as photo_path, ph.thumbnail_path,
                       e.highest_qualification, em.profession,
                       u.last_active_at, u.member_id
                FROM users u
                JOIN profiles p ON p.user_id = u.id
                LEFT JOIN current_locations cl ON cl.user_id = u.id
                LEFT JOIN photos ph ON ph.user_id = u.id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
                LEFT JOIN education e ON e.user_id = u.id
                LEFT JOIN employment em ON em.user_id = u.id
                WHERE u.member_id = :member_id
                  AND u.deleted_at IS NULL
                  AND u.account_status = 'active'
                  AND u.id != :uid
            """),
            {"member_id": member_id_upper, "uid": current_user.user_id},
        )
        row = result.fetchone()
        if not row:
            return {"results": [], "total": 0, "page": 1, "page_size": 1, "total_pages": 0}

        supabase = get_supabase()
        cfg = get_settings()
        photo_url = None
        if row.photo_path:
            try:
                photo_url = supabase.storage.from_(cfg.storage_bucket_profile_photos).get_public_url(row.photo_path)
            except Exception:
                pass

        from app.utils import compute_age
        return {
            "results": [{
                "user_id": str(row.user_id),
                "member_id": row.member_id,
                "full_name": row.full_name or "",
                "age": compute_age(row.date_of_birth) if row.date_of_birth else None,
                "height_cm": row.height_cm,
                "religion": row.religion,
                "mother_tongue": row.mother_tongue,
                "marital_status": row.marital_status,
                "location": f"{row.city}, {row.state}" if row.city and row.state else (row.state or ""),
                "highest_qualification": row.highest_qualification,
                "profession": row.profession,
                "is_verified": row.verification_status == "verified",
                "primary_photo_url": photo_url,
                "last_active_at": row.last_active_at.isoformat() if row.last_active_at else None,
            }],
            "total": 1,
            "page": 1,
            "page_size": 1,
            "total_pages": 1,
        }

    # ── normal filter search ──────────────────────────────────────────────────
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
        # age >= min_age  →  dob <= today - min_age years (uses idx_profiles_dob)
        params["dob_max_for_min_age"] = date.today().replace(year=date.today().year - min_age)
        conditions.append("p.date_of_birth <= :dob_max_for_min_age")
    if max_age:
        # age <= max_age  →  dob >= today - (max_age+1) years + 1 day
        params["dob_min_for_max_age"] = date.today().replace(year=date.today().year - max_age - 1) + timedelta(days=1)
        conditions.append("p.date_of_birth >= :dob_min_for_max_age")
    if gender:
        conditions.append("p.gender = :gender")
        params["gender"] = gender
    if religion:
        conditions.append("LOWER(p.religion) = LOWER(:religion)")
        params["religion"] = religion
    if caste:
        conditions.append("LOWER(p.caste) LIKE LOWER(:caste)")
        params["caste"] = f"%{caste}%"
    if sub_caste:
        conditions.append("LOWER(p.sub_caste) LIKE LOWER(:sub_caste)")
        params["sub_caste"] = f"%{sub_caste}%"
    if gotra:
        conditions.append("LOWER(p.gotra) LIKE LOWER(:gotra)")
        params["gotra"] = f"%{gotra}%"
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
    if q:
        conditions.append("p.full_name ILIKE :q")
        params["q"] = f"%{q.strip()}%"

    # Apply must_have preferences from the requesting user's stored preferences
    # Only hard-filter on fields where importance = 'must_have'
    prefs_result = await db.execute(
        text("SELECT * FROM partner_preferences WHERE user_id = :uid"),
        {"uid": current_user.user_id},
    )
    prefs_row = prefs_result.fetchone()
    if prefs_row:
        prefs = prefs_row._asdict()
        if prefs.get("age_importance") == "must_have":
            pref_min = prefs.get("min_age")
            pref_max = prefs.get("max_age")
            if pref_min and "dob_max_for_min_age" not in params:
                params["pref_dob_max"] = date.today().replace(year=date.today().year - pref_min)
                conditions.append("p.date_of_birth <= :pref_dob_max")
            if pref_max and "dob_min_for_max_age" not in params:
                params["pref_dob_min"] = date.today().replace(year=date.today().year - pref_max - 1) + timedelta(days=1)
                conditions.append("p.date_of_birth >= :pref_dob_min")
        if prefs.get("location_importance") == "must_have":
            pref_states = prefs.get("preferred_states") or []
            if pref_states and not state:
                loc_placeholders = ", ".join(f":pref_state_{i}" for i in range(len(pref_states)))
                conditions.append(f"LOWER(cl.state) IN ({loc_placeholders})")
                for i, st in enumerate(pref_states):
                    params[f"pref_state_{i}"] = st.lower()
        if prefs.get("lifestyle_importance") == "must_have":
            pref_diets = prefs.get("preferred_diet") or []
            if pref_diets and not diet:
                diet_placeholders = ", ".join(f":pref_diet_{i}" for i in range(len(pref_diets)))
                conditions.append(f"ls.diet IN ({diet_placeholders})")
                for i, d in enumerate(pref_diets):
                    params[f"pref_diet_{i}"] = d

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
                   p.marital_status, p.caste, p.sub_caste, p.gotra,
                   u.verification_status,
                   cl.state, cl.city,
                   ph.storage_path as photo_path, ph.thumbnail_path,
                   e.highest_qualification, em.profession,
                   u.last_active_at, u.created_at, u.member_id
            FROM users u
            JOIN profiles p ON p.user_id = u.id
            LEFT JOIN current_locations cl ON cl.user_id = u.id
            LEFT JOIN native_places np ON np.user_id = u.id
            LEFT JOIN photos ph ON ph.user_id = u.id AND ph.is_primary = TRUE AND ph.deleted_at IS NULL
            LEFT JOIN education e ON e.user_id = u.id
            LEFT JOIN employment em ON em.user_id = u.id
            LEFT JOIN lifestyle ls ON ls.user_id = u.id
            WHERE {where_clause}
            ORDER BY {_build_order_clause(sort_by)}
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
            "member_id": row.member_id,
            "full_name": row.full_name or "",
            "age": age,          # may be null for profiles without DOB
            "height_cm": row.height_cm,
            "religion": row.religion,
            "caste": row.caste,
            "sub_caste": row.sub_caste,
            "gotra": row.gotra,
            "mother_tongue": row.mother_tongue,
            "marital_status": row.marital_status,
            "location": f"{row.city}, {row.state}" if row.city and row.state else (row.state or ""),
            "highest_qualification": row.highest_qualification,
            "profession": row.profession,
            "is_verified": row.verification_status == "verified",
            "primary_photo_url": photo_url,
            "last_active_at": row.last_active_at.isoformat() if row.last_active_at else None,
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
