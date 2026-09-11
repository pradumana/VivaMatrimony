"""
Matching & Compatibility Scoring Service.
Rule-based algorithm — no AI/ML initially.

Scoring weights:
  Age match:          20%
  Location:           15%
  Education:          15%
  Profession:         15%
  Lifestyle:          10%
  Preferences align:  15%
  Family:             10%
"""
from datetime import date
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.config import get_settings
from app.database import get_supabase
from app.utils import compute_age


WEIGHTS = {
    "age": 0.20,
    "location": 0.12,
    "education": 0.12,
    "profession": 0.12,
    "lifestyle": 0.09,
    "preferences": 0.12,
    "family": 0.08,
    "community": 0.15,
}


async def calculate_compatibility(
    db: AsyncSession,
    user_id: UUID,
    candidate_id: UUID,
) -> dict:
    """
    Calculate compatibility score between two users.
    Returns score (0-100) and breakdown by dimension.
    """
    # Fetch user's preferences
    user_data = await _fetch_user_data(db, user_id)
    candidate_data = await _fetch_user_data(db, candidate_id)

    if not user_data or not candidate_data:
        return {
            "score": None,
            "message": "Complete your profile to calculate compatibility.",
            "breakdown": {},
        }

    # Fetch preferences
    user_prefs = await _fetch_preferences(db, user_id)
    candidate_prefs = await _fetch_preferences(db, candidate_id)

    if not user_prefs:
        return {
            "score": None,
            "message": "Complete your partner preferences to calculate compatibility.",
            "breakdown": {},
        }

    scores = {}

    # Age score (20%)
    scores["age"] = _score_age(
        user_prefs.get("min_age"), user_prefs.get("max_age"),
        candidate_data.get("age"),
        candidate_prefs.get("min_age") if candidate_prefs else None,
        candidate_prefs.get("max_age") if candidate_prefs else None,
        user_data.get("age"),
    )

    # Location (15%)
    scores["location"] = _score_location(
        user_prefs.get("preferred_states", []),
        user_prefs.get("preferred_cities", []),
        candidate_data.get("state"),
        candidate_data.get("city"),
    )

    # Education (15%)
    scores["education"] = _score_education(
        user_prefs.get("min_education"),
        candidate_data.get("highest_qualification"),
    )

    # Profession (15%)
    scores["profession"] = _score_profession(
        user_prefs.get("preferred_professions", []),
        candidate_data.get("profession"),
        user_prefs.get("min_income_lpa"),
        candidate_data.get("income_max_lpa"),
    )

    # Lifestyle (10%)
    scores["lifestyle"] = _score_lifestyle(
        user_prefs.get("preferred_diet", []),
        user_prefs.get("smoking_preference"),
        user_prefs.get("drinking_preference"),
        candidate_data.get("diet"),
        candidate_data.get("smoking"),
        candidate_data.get("drinking"),
    )

    # Preferences alignment (15%) — how well candidate's prefs match user
    scores["preferences"] = _score_preferences_alignment(
        user_data, candidate_prefs or {}
    )

    # Family (10%)
    scores["family"] = _score_family(
        user_prefs.get("preferred_family_types", []),
        user_prefs.get("preferred_family_values", []),
        candidate_data.get("family_type"),
        candidate_data.get("family_values"),
    )

    # Community (15%) — only use explicitly stored values, never inferred
    scores["community"] = _score_community(
        user_prefs.get("preferred_castes", []),
        user_prefs.get("preferred_subcastes", []),
        user_prefs.get("preferred_gotras", []),
        candidate_data.get("caste"),
        candidate_data.get("sub_caste"),
        candidate_data.get("gotra"),
    )

    # Weighted total
    total = sum(scores[k] * WEIGHTS[k] for k in WEIGHTS)
    total_pct = round(total * 100)

    breakdown = {k: round(v * 100) for k, v in scores.items()}

    return {
        "score": total_pct,
        "message": _score_message(total_pct),
        "breakdown": breakdown,
        "disclaimer": "Based on the preferences provided. Compatibility is a guide, not a guarantee.",
    }


async def get_recommended_matches(
    db: AsyncSession,
    user_id: UUID,
    limit: int = 20,
    offset: int = 0,
) -> list:
    """
    Get recommended matches for a user, sorted by compatibility.

    ponytail: previously had an N+1 — one calculate_compatibility() call per
    candidate, each making 3 DB round-trips. Now uses two batch queries:
    one for candidate profile data, one for user's own preferences, then
    scores entirely in-memory. Upgrade path: materialise scores in a
    pre-computed column if the list grows beyond ~200 candidates.
    """
    # 1. Fetch requesting user's data + preferences in parallel
    user_data = await _fetch_user_data(db, user_id)
    user_prefs = await _fetch_preferences(db, user_id)

    if not user_data:
        return []

    opposite_gender = "female" if user_data.get("gender") == "male" else "male"

    # 2. Fetch all candidates in a single query — includes everything needed
    #    for both display and scoring (no secondary per-row queries).
    result = await db.execute(
        text("""
            SELECT DISTINCT
                   u.id            AS user_id,
                   p.full_name,    p.date_of_birth, p.height_cm,
                   p.religion,     p.caste,         p.sub_caste, p.gotra,
                   p.mother_tongue,
                   -- scoring fields
                   cl.state,        cl.city,
                   e.highest_qualification,
                   em.profession,   em.income_max_lpa,
                   ls.diet,         ls.smoking,      ls.drinking,
                   fd.family_type,  fd.family_values,
                   -- display fields
                   u.verification_status,
                   ph.storage_path AS primary_photo_path,
                   u.last_active_at
            FROM users u
            JOIN profiles p ON p.user_id = u.id
            LEFT JOIN current_locations cl  ON cl.user_id  = u.id
            LEFT JOIN photos ph             ON ph.user_id  = u.id
                                           AND ph.is_primary = TRUE
                                           AND ph.deleted_at IS NULL
            LEFT JOIN education e           ON e.user_id   = u.id
            LEFT JOIN employment em         ON em.user_id  = u.id
            LEFT JOIN lifestyle ls          ON ls.user_id  = u.id
            LEFT JOIN family_details fd     ON fd.user_id  = u.id
            WHERE u.id != :uid
              AND u.account_status = 'active'
              AND u.deleted_at IS NULL
              AND p.gender = :gender
              AND p.profile_visibility != 'hidden'
              AND NOT EXISTS (
                SELECT 1 FROM blocks b
                WHERE (b.blocker_id = :uid AND b.blocked_id = u.id)
                   OR (b.blocker_id = u.id AND b.blocked_id = :uid)
              )
            ORDER BY u.last_active_at DESC NULLS LAST
            LIMIT :limit OFFSET :offset
        """),
        {"uid": user_id, "gender": opposite_gender, "limit": limit, "offset": offset},
    )
    rows = result.fetchall()
    if not rows:
        return []

    # 3. Batch-fetch all candidate preferences in a single query.
    candidate_ids = [row.user_id for row in rows]
    placeholders = ", ".join(f":id{i}" for i in range(len(candidate_ids)))
    prefs_result = await db.execute(
        text(f"SELECT * FROM partner_preferences WHERE user_id IN ({placeholders})"),
        {f"id{i}": cid for i, cid in enumerate(candidate_ids)},
    )
    prefs_by_user = {row.user_id: row._asdict() for row in prefs_result.fetchall()}

    supabase = get_supabase()
    cfg = get_settings()

    matches = []
    for row in rows:
        age = compute_age(row.date_of_birth) if row.date_of_birth else None

        photo_url = None
        if row.primary_photo_path:
            try:
                photo_url = supabase.storage.from_(
                    cfg.storage_bucket_profile_photos
                ).get_public_url(row.primary_photo_path)
            except Exception:
                pass

        # Build candidate data dict from the single row — no extra DB call
        candidate_data = {
            "age": age,
            "gender": opposite_gender,
            "caste": row.caste,
            "sub_caste": row.sub_caste,
            "gotra": row.gotra,
            "state": row.state,
            "city": row.city,
            "highest_qualification": row.highest_qualification,
            "profession": row.profession,
            "income_max_lpa": row.income_max_lpa,
            "diet": row.diet,
            "smoking": row.smoking,
            "drinking": row.drinking,
            "family_type": row.family_type,
            "family_values": row.family_values,
        }
        candidate_prefs = prefs_by_user.get(row.user_id)

        # Score in-memory — no DB calls
        score, breakdown = _score_pair(user_data, user_prefs, candidate_data, candidate_prefs)

        matches.append({
            "user_id": str(row.user_id),
            "full_name": row.full_name or "",
            "age": age,
            "height_cm": row.height_cm,
            "location": (
                f"{row.city}, {row.state}" if row.city and row.state
                else row.state or row.city or "India"
            ),
            "highest_qualification": row.highest_qualification,
            "profession": row.profession,
            "is_verified": row.verification_status == "verified",
            "primary_photo_url": photo_url,
            "compatibility_score": score,
            "compatibility_breakdown": breakdown,
            "last_active_at": row.last_active_at.isoformat() if row.last_active_at else None,
        })

    matches.sort(key=lambda x: x.get("compatibility_score") or 0, reverse=True)
    return matches


def _score_pair(
    user_data: dict,
    user_prefs: Optional[dict],
    candidate_data: dict,
    candidate_prefs: Optional[dict],
) -> tuple[Optional[int], dict]:
    """
    Pure in-memory compatibility scoring for a (user, candidate) pair.
    Returns (score_pct: int|None, breakdown: dict).
    """
    if not user_prefs:
        return None, {}

    scores = {
        "age": _score_age(
            user_prefs.get("min_age"), user_prefs.get("max_age"),
            candidate_data.get("age"),
            candidate_prefs.get("min_age") if candidate_prefs else None,
            candidate_prefs.get("max_age") if candidate_prefs else None,
            user_data.get("age"),
        ),
        "location": _score_location(
            user_prefs.get("preferred_states") or [],
            user_prefs.get("preferred_cities") or [],
            candidate_data.get("state"),
            candidate_data.get("city"),
        ),
        "education": _score_education(
            user_prefs.get("min_education"),
            candidate_data.get("highest_qualification"),
        ),
        "profession": _score_profession(
            user_prefs.get("preferred_professions") or [],
            candidate_data.get("profession"),
            user_prefs.get("min_income_lpa"),
            candidate_data.get("income_max_lpa"),
        ),
        "lifestyle": _score_lifestyle(
            user_prefs.get("preferred_diet") or [],
            user_prefs.get("smoking_preference"),
            user_prefs.get("drinking_preference"),
            candidate_data.get("diet"),
            candidate_data.get("smoking"),
            candidate_data.get("drinking"),
        ),
        "preferences": _score_preferences_alignment(user_data, candidate_prefs or {}),
        "family": _score_family(
            user_prefs.get("preferred_family_types") or [],
            user_prefs.get("preferred_family_values") or [],
            candidate_data.get("family_type"),
            candidate_data.get("family_values"),
        ),
        "community": _score_community(
            user_prefs.get("preferred_castes") or [],
            user_prefs.get("preferred_subcastes") or [],
            user_prefs.get("preferred_gotras") or [],
            candidate_data.get("caste"),
            candidate_data.get("sub_caste"),
            candidate_data.get("gotra"),
        ),
    }
    total = round(sum(scores[k] * WEIGHTS[k] for k in WEIGHTS) * 100)
    breakdown = {k: round(v * 100) for k, v in scores.items()}
    return total, breakdown


# ---------------------------------------------------------------------------
# Scoring functions
# ---------------------------------------------------------------------------

def _score_age(
    pref_min: Optional[int], pref_max: Optional[int], candidate_age: Optional[int],
    cand_pref_min: Optional[int], cand_pref_max: Optional[int], user_age: Optional[int],
) -> float:
    """Score 0.0–1.0 based on age compatibility."""
    if candidate_age is None:
        return 0.5  # Unknown = neutral

    score = 0.0

    # Check if candidate is within user's preferred range
    if pref_min and pref_max:
        if pref_min <= candidate_age <= pref_max:
            score += 0.6
        elif abs(candidate_age - pref_min) <= 2 or abs(candidate_age - pref_max) <= 2:
            score += 0.3
    else:
        score += 0.5  # No preference = neutral

    # Check if user age fits candidate's preferences
    if user_age and cand_pref_min and cand_pref_max:
        if cand_pref_min <= user_age <= cand_pref_max:
            score += 0.4
        elif abs(user_age - cand_pref_min) <= 2 or abs(user_age - cand_pref_max) <= 2:
            score += 0.2
    else:
        score += 0.3

    return min(score, 1.0)


def _score_location(
    preferred_states: list, preferred_cities: list,
    candidate_state: Optional[str], candidate_city: Optional[str],
) -> float:
    if not preferred_states and not preferred_cities:
        return 0.7  # No preference = mostly compatible
    if candidate_city and candidate_city in preferred_cities:
        return 1.0
    if candidate_state and candidate_state in preferred_states:
        return 0.8
    return 0.3


def _score_education(min_education: Optional[str], candidate_qual: Optional[str]) -> float:
    if not min_education:
        return 0.7

    edu_levels = {
        "high_school": 1, "diploma": 2, "bachelor": 3,
        "master": 4, "phd": 5, "professional": 4,
    }

    min_level = _get_edu_level(min_education, edu_levels)
    cand_level = _get_edu_level(candidate_qual or "", edu_levels)

    if cand_level >= min_level:
        return 1.0
    elif cand_level == min_level - 1:
        return 0.5
    return 0.2


def _get_edu_level(qual: str, levels: dict) -> int:
    qual_lower = qual.lower()
    for key, val in levels.items():
        if key in qual_lower:
            return val
    return 2  # Default: diploma level


def _score_profession(
    preferred_profs: list, candidate_prof: Optional[str],
    min_income: Optional[float], candidate_income: Optional[float],
) -> float:
    score = 0.5  # base
    if preferred_profs and candidate_prof:
        if any(p.lower() in candidate_prof.lower() for p in preferred_profs):
            score += 0.3

    if min_income and candidate_income:
        if candidate_income >= min_income:
            score += 0.2
    elif not min_income:
        score += 0.2

    return min(score, 1.0)


def _score_lifestyle(
    preferred_diets: list, smoking_pref: Optional[str], drinking_pref: Optional[str],
    candidate_diet: Optional[str], candidate_smoking: Optional[str], candidate_drinking: Optional[str],
) -> float:
    score = 0.0
    checks = 0

    if preferred_diets and candidate_diet:
        score += 1.0 if candidate_diet in preferred_diets else 0.3
        checks += 1

    if smoking_pref and candidate_smoking:
        score += 1.0 if candidate_smoking == smoking_pref else (0.5 if candidate_smoking == "occasionally" else 0.0)
        checks += 1

    if drinking_pref and candidate_drinking:
        score += 1.0 if candidate_drinking == drinking_pref else (0.5 if candidate_drinking == "occasionally" else 0.0)
        checks += 1

    return (score / checks) if checks > 0 else 0.7  # No preference = neutral


def _score_preferences_alignment(user_data: dict, candidate_prefs: dict) -> float:
    """How well does user fit into candidate's preferences."""
    score = 0.5
    if not candidate_prefs:
        return score

    user_age = user_data.get("age")
    cand_min = candidate_prefs.get("min_age")
    cand_max = candidate_prefs.get("max_age")

    if user_age and cand_min and cand_max:
        if cand_min <= user_age <= cand_max:
            score += 0.3
        else:
            score -= 0.2

    return max(0.0, min(score, 1.0))


def _score_family(
    preferred_types: list, preferred_values: list,
    candidate_type: Optional[str], candidate_values: Optional[str],
) -> float:
    score = 0.7
    if preferred_types and candidate_type:
        score = 1.0 if candidate_type in preferred_types else 0.4
    if preferred_values and candidate_values:
        adj = 1.0 if candidate_values in preferred_values else 0.4
        score = (score + adj) / 2
    return score


def _score_community(
    preferred_castes: list, preferred_subcastes: list, preferred_gotras: list,
    candidate_caste: Optional[str], candidate_subcaste: Optional[str], candidate_gotra: Optional[str],
) -> float:
    """
    Score community compatibility.
    Only explicit preferences matter — never infer from name/location.
    No preference (empty list) = neutral (0.7).
    """
    if not preferred_castes and not preferred_subcastes and not preferred_gotras:
        return 0.7  # No community preference = mostly compatible

    score = 0.0
    checks = 0

    if preferred_castes and candidate_caste:
        match = any(p.lower() in candidate_caste.lower() or candidate_caste.lower() in p.lower()
                    for p in preferred_castes)
        score += 1.0 if match else 0.2
        checks += 1
    elif preferred_castes and not candidate_caste:
        score += 0.5  # Unknown caste = neutral
        checks += 1

    if preferred_subcastes and candidate_subcaste:
        match = any(p.lower() in candidate_subcaste.lower() or candidate_subcaste.lower() in p.lower()
                    for p in preferred_subcastes)
        score += 1.0 if match else 0.3
        checks += 1
    elif preferred_subcastes and not candidate_subcaste:
        score += 0.5
        checks += 1

    if preferred_gotras and candidate_gotra:
        match = any(p.lower() == candidate_gotra.lower() for p in preferred_gotras)
        score += 1.0 if match else 0.4
        checks += 1

    return (score / checks) if checks > 0 else 0.7


def _score_message(score: int) -> str:
    if score >= 85:
        return "Highly compatible based on your preferences."
    elif score >= 70:
        return "Good compatibility based on your preferences."
    elif score >= 50:
        return "Moderate compatibility. Worth exploring."
    else:
        return "Based on the preferences provided, this profile appears compatible."


async def _fetch_user_data(db: AsyncSession, user_id: UUID) -> Optional[dict]:
    result = await db.execute(
        text("""
            SELECT p.date_of_birth, p.gender, p.religion, p.caste, p.sub_caste, p.gotra, p.mother_tongue,
                   cl.state, cl.city,
                   e.highest_qualification,
                   em.profession, em.income_max_lpa,
                   ls.diet, ls.smoking, ls.drinking,
                   fd.family_type, fd.family_values
            FROM profiles p
            LEFT JOIN current_locations cl ON cl.user_id = p.user_id
            LEFT JOIN education e ON e.user_id = p.user_id
            LEFT JOIN employment em ON em.user_id = p.user_id
            LEFT JOIN lifestyle ls ON ls.user_id = p.user_id
            LEFT JOIN family_details fd ON fd.user_id = p.user_id
            WHERE p.user_id = :uid
        """),
        {"uid": user_id},
    )
    row = result.fetchone()
    if not row:
        return None

    dob = row.date_of_birth
    age = compute_age(dob) if dob else None

    return {
        "age": age,
        "gender": row.gender,
        "religion": row.religion,
        "caste": row.caste,
        "sub_caste": row.sub_caste,
        "gotra": row.gotra,
        "mother_tongue": row.mother_tongue,
        "state": row.state,
        "city": row.city,
        "highest_qualification": row.highest_qualification,
        "profession": row.profession,
        "income_max_lpa": row.income_max_lpa,
        "diet": row.diet,
        "smoking": row.smoking,
        "drinking": row.drinking,
        "family_type": row.family_type,
        "family_values": row.family_values,
    }


async def _fetch_preferences(db: AsyncSession, user_id: UUID) -> Optional[dict]:
    result = await db.execute(
        text("SELECT * FROM partner_preferences WHERE user_id = :uid"),
        {"uid": user_id},
    )
    row = result.fetchone()
    if not row:
        return None
    return row._asdict()
