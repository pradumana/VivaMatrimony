-- =============================================================================
-- Migration 007: Add optional whatsapp_phone to profiles table
--
-- Purpose:
--   After the WhatsApp OTP auth migration, new users register with email and
--   have no phone_normalized set. The whatsapp_phone field on profiles lets
--   users optionally provide a WhatsApp number for contact exchange after an
--   interest is accepted — this is business contact data, not auth data.
--
-- Design:
--   - Stored on profiles (not users) because it is profile/contact information
--   - Nullable — existing users and users who skip it have NULL
--   - Validated as E.164-style (starts with +, 7-15 digits) — server enforces this
--   - show_whatsapp_phone controls visibility (default TRUE — visible to connections only)
-- =============================================================================

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS whatsapp_phone       VARCHAR(20),
    ADD COLUMN IF NOT EXISTS show_whatsapp_phone  BOOLEAN NOT NULL DEFAULT TRUE;

-- Constraint: if provided, must look like an E.164 number
ALTER TABLE profiles
    ADD CONSTRAINT profiles_whatsapp_phone_format
    CHECK (
        whatsapp_phone IS NULL
        OR (whatsapp_phone ~ '^\+[1-9]\d{6,14}$')
    );

COMMENT ON COLUMN profiles.whatsapp_phone IS
    'Optional WhatsApp contact number. Only shared with accepted interest partners.';
COMMENT ON COLUMN profiles.show_whatsapp_phone IS
    'When FALSE, whatsapp_phone is never exposed — even after interest acceptance.';
