-- =============================================================================
-- Migration 006: Remove obsolete WhatsApp/OTP authentication tables and columns
--
-- DEPENDENCY AUDIT (performed before writing this migration):
--
-- otp_codes table:
--   - No backend code references it after migration 005
--   - No FK from any other table points to otp_codes
--   - RLS policy: otp_no_direct_access (deny-all) — purely defensive, now dead
--   - app_settings row 'otp_resend_cooldown_secs' already deleted in migration 005
--   → SAFE TO DROP
--
-- sessions table (custom JWT sessions):
--   - No backend code references it after migration 005
--   - No FK from any other table points to sessions
--   - RLS: enabled but no policies — just a stub
--   → SAFE TO DROP
--
-- users.phone column:
--   - Made nullable in migration 005
--   - Not read by any backend, admin, or Flutter code after migration 005
--   - The canonical column is phone_normalized (see below)
--   → SAFE TO DROP
--
-- users.phone_country_code column:
--   - Made nullable in migration 005
--   - Not read by any backend, admin, or Flutter code after migration 005
--   → SAFE TO DROP
--
-- COLUMNS INTENTIONALLY KEPT:
--   users.phone_normalized  — actively used for:
--     1. Reference member lookup by phone (verification_service.py)
--     2. WhatsApp contact exchange after interest acceptance (social_service.py)
--     3. Admin user search (admin.py)
--     4. Admin panel display (UserDetailPage.tsx via phone_normalized field)
--   This is business contact data, NOT authentication data.
--
-- ALL OTHER TABLES: unchanged — full audit confirmed no other auth-only tables exist.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Drop obsolete RLS policies first (must happen before dropping tables)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS otp_no_direct_access ON otp_codes;

-- sessions had RLS enabled but no named policies — nothing to drop explicitly.

-- ---------------------------------------------------------------------------
-- 2. Drop obsolete indexes (auto-dropped with table, but explicit for clarity)
-- ---------------------------------------------------------------------------

DROP INDEX IF EXISTS idx_otp_phone;
DROP INDEX IF EXISTS idx_otp_expires;
DROP INDEX IF EXISTS idx_sessions_user_id;
DROP INDEX IF EXISTS idx_sessions_refresh_hash;
DROP INDEX IF EXISTS idx_sessions_expires;

-- ---------------------------------------------------------------------------
-- 3. Drop the tables
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS otp_codes;
DROP TABLE IF EXISTS sessions;

-- ---------------------------------------------------------------------------
-- 4. Drop obsolete columns from users table
--    phone and phone_country_code were only used to build phone_normalized
--    during OTP signup. phone_normalized is kept (business contact data).
-- ---------------------------------------------------------------------------

ALTER TABLE users
    DROP COLUMN IF EXISTS phone,
    DROP COLUMN IF EXISTS phone_country_code;

-- ---------------------------------------------------------------------------
-- 5. Verification: phone_normalized, email, supabase_uid all still present
--    No action needed — added in migration 005, untouched here.
-- ---------------------------------------------------------------------------

-- Confirm phone_normalized still has its index (created in migration 001)
-- CREATE INDEX IF NOT EXISTS idx_users_phone_normalized ON users (phone_normalized);
-- Already exists — no-op guard only.
