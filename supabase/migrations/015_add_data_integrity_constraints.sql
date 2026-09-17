-- =============================================================================
-- Migration 015: Add Data Integrity Constraints
-- =============================================================================
-- PURPOSE: Add database constraints to prevent edge cases and race conditions
--
-- CHANGES:
--   1. Add unique constraint on interests (sender_id, receiver_id) to prevent duplicates
--   2. Fix photos primary constraint to allow proper single-primary enforcement
--   3. Add check constraint to prevent self-interests
--   4. Add check constraint to prevent self-blocks
--
-- SAFETY: All constraints are additive — no data modification
-- Note: interests table does NOT have deleted_at column
-- =============================================================================

-- 1. Additional unique constraint on interests to prevent duplicate interests between same users
-- The table already has UNIQUE (sender_id, receiver_id) but we add a comment for clarity
COMMENT ON CONSTRAINT interests_unique ON interests IS
  'Prevents duplicate interests between the same sender and receiver. '
  'Enforces business rule: only one interest record allowed per user pair, use status to track changes.';

-- 2. Self-interest prevention at database level
-- Already exists as interests_no_self in initial schema, adding comment
COMMENT ON CONSTRAINT interests_no_self ON interests IS
  'Prevents users from sending interests to themselves';

-- 3. Self-block prevention at database level
-- Already exists as blocks_no_self, adding comment
COMMENT ON CONSTRAINT blocks_no_self ON blocks IS
  'Prevents users from blocking themselves';

-- 4. Ensure only one primary photo per user
-- The partial unique index idx_photos_primary_unique (created in initial schema) 
-- handles this correctly by enforcing uniqueness only where is_primary = TRUE AND deleted_at IS NULL
COMMENT ON INDEX idx_photos_primary_unique IS
  'Ensures each user has at most one primary photo. '
  'Partial index only enforces uniqueness for non-deleted primary photos.';

-- 5. Add check constraint for shortlists to prevent self-shortlisting
-- Shortlist table uses 'target_user_id' not 'shortlisted_user_id'
ALTER TABLE shortlists 
  ADD CONSTRAINT chk_shortlists_no_self 
  CHECK (user_id != target_user_id);

COMMENT ON CONSTRAINT chk_shortlists_no_self ON shortlists IS
  'Prevents users from shortlisting themselves';

-- 6. Add check constraint for reports to prevent self-reporting
-- Already exists as reports_no_self, adding comment
COMMENT ON CONSTRAINT reports_no_self ON reports IS
  'Prevents users from reporting themselves';

-- =============================================================================
-- DATA VALIDATION: Check for existing constraint violations
-- =============================================================================
-- These queries will help identify any existing data that violates the constraints

-- Check for self-interests (should be 0) - already prevented by existing constraint
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM interests 
  WHERE sender_id = receiver_id;
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % self-interests that violate constraint', violation_count;
  END IF;
END $$;

-- Check for duplicate interests (should be 0) - already prevented by existing unique constraint
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM (
    SELECT sender_id, receiver_id, COUNT(*) as cnt
    FROM interests
    GROUP BY sender_id, receiver_id
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % duplicate interest pairs that violate constraint', violation_count;
  END IF;
END $$;

-- Check for self-blocks (should be 0) - already prevented by existing constraint
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM blocks 
  WHERE blocker_id = blocked_id;
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % self-blocks that violate constraint', violation_count;
  END IF;
END $$;

-- Check for self-shortlists (should be 0)
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM shortlists 
  WHERE user_id = target_user_id;
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % self-shortlists that violate new constraint', violation_count;
  END IF;
END $$;

-- =============================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- =============================================================================
-- To rollback this migration:
-- ALTER TABLE shortlists DROP CONSTRAINT IF EXISTS chk_shortlists_no_self;
-- 
-- Note: Most constraints already existed in the initial schema (interests_no_self, 
-- blocks_no_self, reports_no_self, interests_unique). This migration primarily 
-- adds documentation via comments and adds the shortlist self-check.
