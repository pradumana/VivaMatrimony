-- =============================================================================
-- Migration 002: Add member_id to users
-- Format: VIVA + zero-padded 6-digit sequence, e.g. VIVA001234
-- =============================================================================

-- Sequence for the numeric part
CREATE SEQUENCE IF NOT EXISTS member_id_seq START 1000 INCREMENT 1;

-- Add column (nullable during migration; backfill existing rows below)
ALTER TABLE users ADD COLUMN IF NOT EXISTS member_id VARCHAR(12) UNIQUE;

-- Backfill existing users in creation order
UPDATE users
SET member_id = 'VIVA' || LPAD(nextval('member_id_seq')::TEXT, 6, '0')
WHERE member_id IS NULL;

-- Now make it NOT NULL and default for new rows
ALTER TABLE users ALTER COLUMN member_id SET NOT NULL;
ALTER TABLE users ALTER COLUMN member_id SET DEFAULT 'VIVA' || LPAD(nextval('member_id_seq')::TEXT, 6, '0');

-- Fast lookup index for member_id search
CREATE INDEX IF NOT EXISTS idx_users_member_id ON users (member_id);
