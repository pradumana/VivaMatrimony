-- =============================================================================
-- Migration 010: VIVA 2.5 — Performance & UX gaps
--
-- CHANGES:
--
-- 1. biodata_exports
--    ADD template_name VARCHAR(20) — 'traditional' | 'floral' | 'half_photo'
--    ADD unique constraint (user_id, template_name) — per-template caching
--    Existing rows get template_name = 'traditional' (safe backfill)
--
-- 2. profile_views
--    Already has the unique constraint from migration 008.
--    ADD index on (viewed_id, viewed_at DESC) if missing — used by /viewers
--
-- 3. interests — index for mutual query
--    The mutual interests query filters WHERE status = 'accepted' with
--    (sender_id = :uid OR receiver_id = :uid). Add a partial index.
--
-- SAFE FOR EXISTING DATA:
--    All changes are additive or backfill-only.
--    No table drops. No column drops.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. biodata_exports — per-template caching
-- ---------------------------------------------------------------------------

ALTER TABLE biodata_exports
    ADD COLUMN IF NOT EXISTS template_name VARCHAR(20) NOT NULL DEFAULT 'traditional';

-- Backfill existing rows (all pre-2.5 biodatas were traditional)
UPDATE biodata_exports SET template_name = 'traditional' WHERE template_name = 'traditional';

-- Unique constraint: one cached PDF per user per template
ALTER TABLE biodata_exports
    DROP CONSTRAINT IF EXISTS biodata_exports_user_template_unique;

ALTER TABLE biodata_exports
    ADD CONSTRAINT biodata_exports_user_template_unique
    UNIQUE (user_id, template_name);

-- Drop the old unique-by-user index (replaced by the composite constraint above)
-- The old idx_biodata_exports_user index on (user_id, created_at DESC) is kept for sorting.

COMMENT ON COLUMN biodata_exports.template_name IS
    'Template used to generate this PDF: traditional | floral | half_photo. '
    'Each user can have one cached PDF per template.';

-- ---------------------------------------------------------------------------
-- 2. interests — partial index for mutual/accepted queries
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_interests_accepted_sender
    ON interests (sender_id, accepted_at DESC)
    WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS idx_interests_accepted_receiver
    ON interests (receiver_id, accepted_at DESC)
    WHERE status = 'accepted';

-- ---------------------------------------------------------------------------
-- 3. profile_views — ensure viewer lookup index exists
-- ---------------------------------------------------------------------------

-- Already has idx_profile_views_viewed (viewed_id, viewed_at DESC) from migration 001.
-- Defensive IF NOT EXISTS in case the sequence was applied differently.
CREATE INDEX IF NOT EXISTS idx_profile_views_viewed_at
    ON profile_views (viewed_id, viewed_at DESC);

-- ---------------------------------------------------------------------------
-- 4. partner_preferences — index for must-have filter lookup
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_partner_prefs_user
    ON partner_preferences (user_id);

-- Already exists from migration 001 (implied by UNIQUE constraint), but
-- explicit named index ensures the must-have filter sub-query is fast.
