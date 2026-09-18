-- Migration 019: add reviewed_at to photos for admin moderation filtering
-- Distinguishes "auto-approved on upload" (reviewed_at IS NULL) from
-- "manually reviewed and approved" (reviewed_at IS NOT NULL).
ALTER TABLE photos ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE photos ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES admin_users(id);
