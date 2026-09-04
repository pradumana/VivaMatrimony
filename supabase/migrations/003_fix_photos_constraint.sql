-- =============================================================================
-- Migration 003: Fix photos_one_primary constraint
-- The original UNIQUE (user_id, is_primary) wrongly prevents having more than
-- one non-primary photo per user. Drop it — the partial unique index
-- idx_photos_primary_unique already correctly enforces one primary per user.
-- =============================================================================

ALTER TABLE photos DROP CONSTRAINT IF EXISTS photos_one_primary;
