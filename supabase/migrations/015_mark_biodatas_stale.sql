-- Mark all existing biodata exports as stale to force regeneration with new templates
-- Run this after deploying the new template designs

UPDATE biodata_exports 
SET is_stale = TRUE,
    updated_at = NOW()
WHERE is_stale = FALSE;

-- Add comment for future reference
COMMENT ON TABLE biodata_exports IS 'Biodata PDF generation tracking. is_stale=TRUE forces regeneration on next download.';
