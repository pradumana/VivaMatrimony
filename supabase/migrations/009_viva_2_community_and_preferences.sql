-- =============================================================================
-- Migration 009: VIVA 2.0 — Community fields & Partner Preferences expansion
--
-- WHAT CHANGES:
--
-- 1. profiles table
--    ADD gotra VARCHAR(100) — user-provided gotra (nullable, free text)
--    ADD INDEX on sub_caste (mirrors existing caste index for search parity)
--
-- 2. partner_preferences table
--    ADD preferred_subcastes TEXT[]          — community preference
--    ADD preferred_gotras    TEXT[]          — community preference
--    ADD want_children_timeline VARCHAR(50)  — 'soon','1_3_years','later','not_decided'
--    ADD career_preference   VARCHAR(50)     — 'may_work','should_work','no_preference'
--    ADD min_income_lpa_pref NUMERIC(10,2)   — ALREADY EXISTS as min_income_lpa; no-op
--
-- 3. Indexes
--    ADD on profiles(gotra) — same pattern as profiles(caste)
--    ADD on profiles(sub_caste) — for search filter parity
--
-- EXISTING TABLES / COLUMNS REUSED (not duplicated):
--    profiles.caste      — already exists
--    profiles.sub_caste  — already exists
--    partner_preferences.preferred_castes — already exists
--    partner_preferences.min_income_lpa   — already exists
--
-- SAFE FOR EXISTING USERS:
--    All new columns are nullable with no DEFAULT constraint pressure.
--    Existing rows get NULL for all new columns — fully backward-compatible.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. profiles — add gotra
-- ---------------------------------------------------------------------------

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS gotra VARCHAR(100);

COMMENT ON COLUMN profiles.gotra IS
    'User-provided gotra. Public matrimonial information — may appear on '
    'profile, search results, and biodata. Nullable; NULL = not specified.';

-- ---------------------------------------------------------------------------
-- 2. partner_preferences — add community + life-stage preference columns
-- ---------------------------------------------------------------------------

ALTER TABLE partner_preferences
    ADD COLUMN IF NOT EXISTS preferred_subcastes        TEXT[],
    ADD COLUMN IF NOT EXISTS preferred_gotras           TEXT[],
    -- Children timeline (soft preference — never a hard filter automatically)
    ADD COLUMN IF NOT EXISTS want_children_timeline     VARCHAR(50),
    -- Career preference for partner
    ADD COLUMN IF NOT EXISTS career_preference          VARCHAR(50);

COMMENT ON COLUMN partner_preferences.preferred_subcastes IS
    'Preferred sub-castes. NULL or empty = no preference (any subcaste).';
COMMENT ON COLUMN partner_preferences.preferred_gotras IS
    'Preferred gotras. NULL or empty = no preference. '
    'Gotra exclusion (same-gotra) must be explicitly configured by product rules.';
COMMENT ON COLUMN partner_preferences.want_children_timeline IS
    'Expected values: soon | 1_3_years | later | not_decided | NULL (no preference).';
COMMENT ON COLUMN partner_preferences.career_preference IS
    'Expected values: may_work | should_work | no_preference | NULL (no preference).';

-- ---------------------------------------------------------------------------
-- 3. Indexes — only on columns used in WHERE clauses of search queries
-- ---------------------------------------------------------------------------

-- sub_caste search (mirrors existing idx_profiles_caste)
CREATE INDEX IF NOT EXISTS idx_profiles_sub_caste
    ON profiles (sub_caste);

-- gotra search
CREATE INDEX IF NOT EXISTS idx_profiles_gotra
    ON profiles (gotra);

-- ---------------------------------------------------------------------------
-- 4. Full-text search index update — include gotra in the existing FTS vector
--    The original index (idx_profiles_fts) was created without gotra.
--    Drop and recreate to include it. This is safe — the index is advisory
--    for performance only; the table data is unchanged.
-- ---------------------------------------------------------------------------

DROP INDEX IF EXISTS idx_profiles_fts;

CREATE INDEX idx_profiles_fts ON profiles
    USING gin(to_tsvector('english',
        COALESCE(full_name, '')    || ' ' ||
        COALESCE(religion, '')     || ' ' ||
        COALESCE(caste, '')        || ' ' ||
        COALESCE(sub_caste, '')    || ' ' ||
        COALESCE(gotra, '')        || ' ' ||
        COALESCE(mother_tongue, '')
    ));
