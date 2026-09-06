-- =============================================================================
-- Migration 005: Switch from WhatsApp OTP auth to Supabase Auth
--
-- What changes:
--   1. Add email column to users (unique, nullable — existing rows have no email)
--   2. Make phone columns nullable (existing rows keep their data)
--   3. Add unique partial index on email (ignores NULLs)
--   4. otp_codes and sessions tables are KEPT for audit trail — not dropped
--   5. Add supabase_uid column (= auth.users.id) as the stable link to
--      Supabase Auth. This is the same UUID the backend JWT "sub" now contains.
--
-- Apply via Supabase SQL Editor.
-- =============================================================================

-- 1. Make phone columns nullable (existing phone-auth users keep their data)
ALTER TABLE users
    ALTER COLUMN phone             DROP NOT NULL,
    ALTER COLUMN phone_country_code DROP NOT NULL,
    ALTER COLUMN phone_normalized   DROP NOT NULL;

-- 2. Add email column
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS email VARCHAR(320);

-- 3. Unique index on email — partial so multiple NULL rows are allowed
--    (existing phone-only users have no email yet)
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
    ON users (email)
    WHERE email IS NOT NULL;

-- 4. supabase_uid: the UUID from Supabase Auth (auth.users.id).
--    For new registrations this equals the users.id we create.
--    We keep users.id as the application PK; supabase_uid is an alias
--    used only for the JWT->DB lookup. In practice they are the same value
--    because we INSERT the Supabase Auth UID as users.id on first login.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS supabase_uid UUID;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_supabase_uid
    ON users (supabase_uid)
    WHERE supabase_uid IS NOT NULL;

-- 5. Deprecate otp-related app_settings rows (keep rows, just document)
COMMENT ON TABLE otp_codes IS
    'Deprecated — WhatsApp OTP auth removed in migration 005. '
    'Kept for audit trail. No new rows will be inserted.';

COMMENT ON TABLE sessions IS
    'Deprecated — custom JWT sessions removed in migration 005. '
    'Supabase Auth manages sessions. Kept for audit trail.';

-- 6. Remove the otp_resend_cooldown_secs app_setting row (no longer used)
--    Guard: app_settings is created in migration 004; skip if not yet applied.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'app_settings'
  ) THEN
    DELETE FROM app_settings WHERE key = 'otp_resend_cooldown_secs';
  END IF;
END $$;

-- 7. Index for fast JWT sub lookup (email-auth users looked up by supabase_uid)
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email)
    WHERE email IS NOT NULL;
