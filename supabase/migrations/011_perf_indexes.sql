-- =============================================================================
-- Migration 011 — Performance indexes
--
-- Adds indexes on columns used in WHERE filters that were previously missing,
-- causing full-table scans on search queries:
--   • current_locations.state  (equality filter in /search)
--   • current_locations.city   (LIKE filter in /search — prefix only)
--   • lifestyle.diet           (equality filter in /search and matches)
--
-- Also removes the dependency on get_age() in search by documenting that
-- age filtering now uses plain DOB range comparisons, which hit the existing
-- idx_profiles_dob B-tree index without needing a functional index.
-- =============================================================================

-- current_locations.state — used in WHERE LOWER(cl.state) = LOWER(:state)
CREATE INDEX IF NOT EXISTS idx_current_locations_state
    ON current_locations (state);

-- current_locations.city — used in WHERE LOWER(cl.city) LIKE LOWER(:city)
-- B-tree covers prefix-LIKE when the pattern has no leading wildcard.
CREATE INDEX IF NOT EXISTS idx_current_locations_city
    ON current_locations (city);

-- lifestyle.diet — used in WHERE ls.diet = :diet
CREATE INDEX IF NOT EXISTS idx_lifestyle_diet
    ON lifestyle (diet);

-- lifestyle.user_id — FK join used on every search that filters by diet
CREATE INDEX IF NOT EXISTS idx_lifestyle_user_id
    ON lifestyle (user_id);
