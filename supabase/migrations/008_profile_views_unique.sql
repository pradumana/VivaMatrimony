-- =============================================================================
-- Migration 008: Add unique constraint to profile_views(viewer_id, viewed_id)
--
-- Problem:
--   profile_service.py inserts profile views with ON CONFLICT DO NOTHING, but
--   profile_views had no unique constraint on (viewer_id, viewed_id), so the
--   conflict never fired and every page-load inserted a duplicate row.
--
-- Fix:
--   Deduplicate existing rows (keep earliest), then add the unique index that
--   ON CONFLICT DO NOTHING requires to actually work.
-- =============================================================================

-- 1. Remove duplicate rows — keep the earliest view per (viewer_id, viewed_id) pair
DELETE FROM profile_views
WHERE id NOT IN (
    SELECT DISTINCT ON (viewer_id, viewed_id) id
    FROM profile_views
    ORDER BY viewer_id, viewed_id, viewed_at ASC
);

-- 2. Add the unique constraint (also serves as the index for ON CONFLICT)
ALTER TABLE profile_views
    ADD CONSTRAINT profile_views_viewer_viewed_unique UNIQUE (viewer_id, viewed_id);
