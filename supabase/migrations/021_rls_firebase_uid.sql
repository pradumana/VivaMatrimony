-- =============================================================================
-- Migration 021: Rewrite RLS helpers for Firebase JWTs
--
-- Problem: auth.uid() casts the JWT "sub" claim to UUID. Firebase UIDs are
-- strings (e.g. "abc123XYZ456"), not UUIDs — so auth.uid() returns NULL for
-- every Firebase JWT, silently breaking every RLS policy.
--
-- Fix: replace current_user_id() with a version that looks up the Firebase UID
-- (JWT sub) in user_identity_map → users.id (UUID).
-- Add current_firebase_uid() for storage policies that need the raw UID string.
--
-- All existing table policies use current_user_id() — they continue to work
-- unchanged once this function is replaced.
--
-- Apply AFTER migration 020_firebase_uid.sql.
-- Safe to run multiple times (CREATE OR REPLACE is idempotent).
-- =============================================================================

-- 1. Raw Firebase UID from JWT (TEXT)
-- Use (select ...) sub-select so the planner treats it as stable within a query,
-- which avoids repeated JWKS lookups on policies with many rows.
CREATE OR REPLACE FUNCTION current_firebase_uid() RETURNS TEXT AS $$
    SELECT (SELECT auth.jwt()->>'sub')
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_firebase_uid() IS
    'Returns the Firebase UID string from the current JWT sub claim. '
    'Use in storage policies where the folder name is the Firebase UID.';

-- 2. Mapped UUID — Firebase UID → users.id (UUID)
-- This is a drop-in replacement for the old current_user_id() which used
-- auth.uid() (UUID cast — broken for Firebase JWTs).
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
    SELECT supabase_user_id
    FROM user_identity_map
    WHERE firebase_uid = (SELECT auth.jwt()->>'sub')
    LIMIT 1
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

COMMENT ON FUNCTION current_user_id() IS
    'Maps the Firebase UID in the current JWT to the internal users.id UUID '
    'via user_identity_map. Drop-in replacement for the old auth.uid()-based version.';

-- 3. Storage policies: replace auth.uid()::TEXT with current_firebase_uid()
--
-- The storage bucket policies in supabase/rls/storage.sql use:
--   (storage.foldername(name))[1] = auth.uid()::TEXT
-- which also breaks for Firebase UIDs. We replace those policies here.
--
-- profile-photos bucket
DROP POLICY IF EXISTS "profile_photos_owner_insert" ON storage.objects;
CREATE POLICY "profile_photos_owner_insert"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'profile-photos'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = current_firebase_uid()
);

DROP POLICY IF EXISTS "profile_photos_owner_update" ON storage.objects;
CREATE POLICY "profile_photos_owner_update"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'profile-photos'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = current_firebase_uid()
);

DROP POLICY IF EXISTS "profile_photos_owner_delete" ON storage.objects;
CREATE POLICY "profile_photos_owner_delete"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'profile-photos'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = current_firebase_uid()
);

-- biodata-pdfs bucket (owner read)
DROP POLICY IF EXISTS "biodata_pdfs_owner_read" ON storage.objects;
CREATE POLICY "biodata_pdfs_owner_read"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'biodata-pdfs'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = current_firebase_uid()
);

-- verification-docs bucket (owner insert)
DROP POLICY IF EXISTS "vdocs_owner_insert" ON storage.objects;
CREATE POLICY "vdocs_owner_insert"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'verification-docs'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = current_firebase_uid()
);

-- =============================================================================
-- ROLLBACK (run manually if migration must be reverted):
-- =============================================================================
--
-- Restore old auth.uid()-based helpers:
--
-- CREATE OR REPLACE FUNCTION current_firebase_uid() RETURNS TEXT AS $$
--     SELECT auth.uid()::TEXT
-- $$ LANGUAGE SQL SECURITY DEFINER STABLE;
--
-- CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
--     SELECT COALESCE(
--         auth.uid(),
--         (current_setting('app.current_user_id', true))::UUID
--     )
-- $$ LANGUAGE SQL SECURITY DEFINER;
--
-- Then re-run the original storage.sql policies to restore auth.uid()::TEXT.
--
-- =============================================================================
