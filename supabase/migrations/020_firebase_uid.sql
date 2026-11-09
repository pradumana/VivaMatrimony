-- =============================================================================
-- Migration 020: Add Firebase UID support
--
-- Strategy: additive-only. Never changes the users.id UUID primary key.
-- Firebase UIDs are strings (28-char alphanumeric), not UUIDs.
-- We add a firebase_uid TEXT column and a user_identity_map table so the
-- backend can map incoming Firebase JWTs → users.id (UUID) for all DB queries.
--
-- Apply via: Supabase SQL Editor or CLI
-- Safe to run multiple times (all statements are idempotent).
-- =============================================================================

-- 1. Add firebase_uid column to users table (additive)
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- Unique index — one Firebase UID maps to exactly one users row
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid
    ON users (firebase_uid)
    WHERE firebase_uid IS NOT NULL;

-- 2. Identity mapping table (additive)
-- Maps firebase_uid (string) ↔ supabase_user_id (UUID = users.id PK).
-- The backend uses this for every JWT→DB lookup.
CREATE TABLE IF NOT EXISTS user_identity_map (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supabase_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    firebase_uid     TEXT NOT NULL,
    email            TEXT,
    migrated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uim_firebase_uid_unique UNIQUE (firebase_uid),
    CONSTRAINT uim_supabase_uid_unique UNIQUE (supabase_user_id)
);

CREATE INDEX IF NOT EXISTS idx_uim_firebase_uid
    ON user_identity_map (firebase_uid);

CREATE INDEX IF NOT EXISTS idx_uim_supabase_uid
    ON user_identity_map (supabase_user_id);

-- 3. Backfill: for existing users whose Supabase Auth UID == users.id,
--    populate firebase_uid and user_identity_map from users.supabase_uid.
--    This is the "dual-read period" bridge — existing users who haven't
--    migrated to Firebase yet will have their Supabase UID stored as firebase_uid
--    so the old backend lookup still works.
--    Run the Python migration script to import existing users into Firebase
--    and update these values to real Firebase UIDs.
DO $$
BEGIN
    -- Only backfill rows that have a supabase_uid set
    INSERT INTO user_identity_map (supabase_user_id, firebase_uid, email)
    SELECT id, supabase_uid::TEXT, email
    FROM users
    WHERE supabase_uid IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM user_identity_map uim
          WHERE uim.supabase_user_id = users.id
      );
END $$;

-- =============================================================================
-- ROLLBACK (run manually if migration must be reverted):
-- =============================================================================
--
-- DROP TABLE IF EXISTS user_identity_map;
-- ALTER TABLE users DROP COLUMN IF EXISTS firebase_uid;
-- DROP INDEX IF EXISTS idx_users_firebase_uid;
--
-- =============================================================================
