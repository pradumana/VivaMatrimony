-- =============================================================================
-- Migration 004: Admin panel extensions
-- Adds: app_settings table, resolution_note column on reports
-- =============================================================================

-- ── app_settings ─────────────────────────────────────────────────────────────
-- Simple key/value store for super-admin-configurable platform settings.
-- Only expose rows that the backend is ready to act on.

CREATE TABLE IF NOT EXISTS app_settings (
    key         VARCHAR(100) PRIMARY KEY,
    value       TEXT         NOT NULL,
    description TEXT,
    updated_by  UUID         REFERENCES admin_users(id),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Seed with initial safe defaults (non-sensitive, non-secret values only)
INSERT INTO app_settings (key, value, description) VALUES
    ('verification_sla_days',    '1-2 business days', 'SLA shown to users for certificate review'),
    ('report_review_hours',      '24-48 hours',        'SLA shown to users for report review'),
    ('max_photos_per_user',      '10',                 'Maximum profile photos allowed per user'),
    ('otp_resend_cooldown_secs', '60',                 'OTP resend cooldown in seconds')
ON CONFLICT (key) DO NOTHING;


-- ── resolution_note on reports ────────────────────────────────────────────────
-- Already referenced by dismiss/resolve endpoints; add if not present.

ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS resolution_note TEXT;


-- ── suspended_reason / banned_reason columns ─────────────────────────────────
-- These may already exist from migration 001; guard with IF NOT EXISTS.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
    ADD COLUMN IF NOT EXISTS suspended_at     TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS banned_reason    TEXT,
    ADD COLUMN IF NOT EXISTS banned_at        TIMESTAMPTZ;
