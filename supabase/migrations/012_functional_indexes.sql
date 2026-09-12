-- =============================================================================
-- Migration 012 — Functional indexes + trigram indexes
--
-- Problem 1: Search filters use LOWER(col) = LOWER(:val) for religion, caste,
--   sub_caste, gotra, mother_tongue, state. The existing plain B-tree indexes
--   are on raw column values, so PostgreSQL ignores them for LOWER() comparisons
--   and falls back to a full sequential scan.
--   Fix: functional indexes on LOWER(col) — the planner uses these directly.
--
-- Problem 2: city and profession searches use LIKE '%term%' (leading wildcard).
--   B-tree indexes never help with leading wildcards. pg_trgm GIN indexes do.
--   Fix: GIN trigram indexes on city and profession.
--
-- Problem 3: employment.user_id has no index despite being the FK join column
--   used on every search that touches employment.
--
-- All CREATE INDEX statements use IF NOT EXISTS — safe to re-run.
-- =============================================================================

-- Require pg_trgm for trigram (GIN) indexes.
-- Already present on Supabase; CREATE EXTENSION IF NOT EXISTS is a no-op when
-- the extension is installed, so this is safe in all environments.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------------
-- profiles: LOWER() functional indexes for case-insensitive equality filters
-- ---------------------------------------------------------------------------

-- LOWER(religion) — used in WHERE LOWER(p.religion) = LOWER(:religion)
CREATE INDEX IF NOT EXISTS idx_profiles_religion_lower
    ON profiles (LOWER(religion));

-- LOWER(caste) — used in WHERE LOWER(p.caste) LIKE LOWER(:caste)
-- A functional index on LOWER(caste) still helps with prefix LIKE 'val%';
-- for '%val%' patterns the trigram index below is better, but we keep this
-- for equality and prefix lookups.
CREATE INDEX IF NOT EXISTS idx_profiles_caste_lower
    ON profiles (LOWER(caste));

-- LOWER(sub_caste)
CREATE INDEX IF NOT EXISTS idx_profiles_sub_caste_lower
    ON profiles (LOWER(sub_caste));

-- LOWER(gotra)
CREATE INDEX IF NOT EXISTS idx_profiles_gotra_lower
    ON profiles (LOWER(gotra));

-- LOWER(mother_tongue)
CREATE INDEX IF NOT EXISTS idx_profiles_mother_tongue_lower
    ON profiles (LOWER(mother_tongue));

-- GIN trigram on full_name — already added in migration 009 as
-- idx_profiles_name_trgm; listed here as a comment for completeness only.
-- (do NOT re-create it)

-- ---------------------------------------------------------------------------
-- current_locations: LOWER() functional index for state equality filter
-- ---------------------------------------------------------------------------

-- LOWER(state) — used in WHERE LOWER(cl.state) = LOWER(:state)
-- The plain idx_current_locations_state from migration 001 is bypassed by
-- LOWER(); this functional index is used instead.
CREATE INDEX IF NOT EXISTS idx_current_locations_state_lower
    ON current_locations (LOWER(state));

-- GIN trigram on city — WHERE cl.city ILIKE '%term%' uses this.
-- Switch the query to ILIKE (case-insensitive LIKE) so the planner picks it up.
CREATE INDEX IF NOT EXISTS idx_current_locations_city_trgm
    ON current_locations USING gin(city gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- employment: trigram index on profession + FK join index
-- ---------------------------------------------------------------------------

-- GIN trigram on profession — WHERE em.profession ILIKE '%term%'
CREATE INDEX IF NOT EXISTS idx_employment_profession_trgm
    ON employment USING gin(profession gin_trgm_ops);

-- employment.user_id — FK join used on every search that touches employment
CREATE INDEX IF NOT EXISTS idx_employment_user_id
    ON employment (user_id);
