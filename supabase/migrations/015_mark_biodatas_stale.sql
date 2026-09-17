-- Migration: Mark all cached biodatas as stale (Biodata Engine 3.0 redesign)
-- Date: 2026-01-17
-- Reason: New template designs rolled out, all cached PDFs must be regenerated

UPDATE biodata_exports
SET is_stale = true
WHERE is_stale = false;

-- Log migration execution
INSERT INTO migration_log (migration_name, executed_at, description)
VALUES (
  '015_mark_biodatas_stale',
  NOW(),
  'Marked all cached biodatas as stale for Biodata Engine 3.0 template redesign'
);
