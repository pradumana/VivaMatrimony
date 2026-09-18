-- Migration 017: deduplicate profile_views and add unique constraint
-- profile_views was inserted with ON CONFLICT DO NOTHING but had no unique constraint,
-- meaning duplicates could accumulate on every page view.
-- Strategy: keep only the most recent view per (viewer_id, viewed_id) pair,
-- then add the constraint so the conflict clause actually works.

-- Remove duplicates, keeping the latest view per pair
DELETE FROM profile_views pv
WHERE pv.id NOT IN (
    SELECT DISTINCT ON (viewer_id, viewed_id) id
    FROM profile_views
    ORDER BY viewer_id, viewed_id, viewed_at DESC
);

-- Add unique constraint so ON CONFLICT (viewer_id, viewed_id) fires correctly
ALTER TABLE profile_views
    ADD CONSTRAINT profile_views_pair_unique UNIQUE (viewer_id, viewed_id);

-- Update viewed_at to NOW() on re-visit so callers see the freshest timestamp
-- The insert in profile.py is updated to use ON CONFLICT (viewer_id, viewed_id) DO UPDATE
