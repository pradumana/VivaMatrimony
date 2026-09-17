-- =============================================================================
-- Migration 016: Improve Age and Data Validation
-- =============================================================================
-- PURPOSE: Fix edge cases in date of birth validation and other data constraints
--
-- CHANGES:
--   1. Fix DOB constraint to properly enforce 18+ years (not 18 years from today)
--   2. Add more realistic height constraints (150cm-220cm for adults)
--   3. Add validation for children_count based on marital status logic
--   4. Add notes length limit for subscriptions
--
-- SAFETY: Replaces existing constraints with stricter but more correct versions
-- =============================================================================

-- 1. Drop and recreate DOB constraint with proper 18+ validation
-- Old constraint used INTERVAL '18 years' which doesn't account for leap years properly
-- New constraint ensures user is at least 18 years old TODAY
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_dob_range;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_dob_range 
  CHECK (
    date_of_birth >= '1940-01-01' 
    AND date_of_birth <= CURRENT_DATE - INTERVAL '18 years 1 day'
  );

COMMENT ON CONSTRAINT profiles_dob_range ON profiles IS
  'Ensures date of birth is between 1940 and at least 18 years + 1 day ago. '
  'The extra day ensures users are FULLY 18 years old, handling leap year edge cases.';

-- 2. Improve height validation - 150cm to 220cm is realistic for adults
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_height_range;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_height_range 
  CHECK (height_cm IS NULL OR (height_cm BETWEEN 150 AND 220));

COMMENT ON CONSTRAINT profiles_height_range ON profiles IS
  'Height must be between 150cm (4''11") and 220cm (7''3") - realistic adult range';

-- 3. Improve children count constraint - max 10 is more realistic
ALTER TABLE profiles 
  DROP CONSTRAINT IF EXISTS profiles_children_count;

ALTER TABLE profiles 
  ADD CONSTRAINT profiles_children_count 
  CHECK (children_count >= 0 AND children_count <= 10);

COMMENT ON CONSTRAINT profiles_children_count ON profiles IS
  'Maximum 10 children allowed (reduced from 20 for realism)';

-- 4. Add constraint for subscription notes length
ALTER TABLE member_subscriptions 
  ADD CONSTRAINT chk_subscription_notes_length 
  CHECK (notes IS NULL OR LENGTH(notes) <= 1000);

COMMENT ON CONSTRAINT chk_subscription_notes_length ON member_subscriptions IS
  'Subscription notes limited to 1000 characters';

-- 5. Add validation that children_count > 0 requires have_children = TRUE
ALTER TABLE profiles 
  ADD CONSTRAINT chk_children_count_consistency 
  CHECK (
    (children_count = 0 AND have_children = FALSE) 
    OR (children_count > 0 AND have_children = TRUE)
    OR (children_count = 0 AND have_children IS NULL)
  );

COMMENT ON CONSTRAINT chk_children_count_consistency ON profiles IS
  'If children_count > 0, have_children must be TRUE';

-- 6. Validate that languages_known array is not excessively large
ALTER TABLE profiles 
  ADD CONSTRAINT chk_languages_known_max 
  CHECK (languages_known IS NULL OR ARRAY_LENGTH(languages_known, 1) <= 10);

COMMENT ON CONSTRAINT chk_languages_known_max ON profiles IS
  'Maximum 10 languages allowed in languages_known array';

-- =============================================================================
-- DATA VALIDATION: Identify existing violations
-- =============================================================================

-- Check for profiles that would violate new DOB constraint
DO $$
DECLARE
  violation_count INTEGER;
  min_allowed_dob DATE := CURRENT_DATE - INTERVAL '18 years 1 day';
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM profiles 
  WHERE date_of_birth > min_allowed_dob;
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % profiles with DOB newer than % (under 18 years old)', 
      violation_count, min_allowed_dob;
  END IF;
END $$;

-- Check for invalid height values
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM profiles 
  WHERE height_cm IS NOT NULL 
    AND (height_cm < 150 OR height_cm > 220);
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % profiles with height outside realistic range (150-220cm)', 
      violation_count;
  END IF;
END $$;

-- Check for children_count inconsistencies
DO $$
DECLARE
  violation_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO violation_count 
  FROM profiles 
  WHERE (children_count > 0 AND have_children = FALSE);
  
  IF violation_count > 0 THEN
    RAISE WARNING 'Found % profiles where children_count > 0 but have_children = FALSE', 
      violation_count;
  END IF;
END $$;

-- =============================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- =============================================================================
-- To rollback this migration:
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_dob_range;
-- ALTER TABLE profiles ADD CONSTRAINT profiles_dob_range CHECK (date_of_birth BETWEEN '1940-01-01' AND CURRENT_DATE - INTERVAL '18 years');
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_height_range;
-- ALTER TABLE profiles ADD CONSTRAINT profiles_height_range CHECK (height_cm IS NULL OR (height_cm BETWEEN 100 AND 250));
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_children_count;
-- ALTER TABLE profiles ADD CONSTRAINT profiles_children_count CHECK (children_count >= 0 AND children_count <= 20);
-- ALTER TABLE member_subscriptions DROP CONSTRAINT IF EXISTS chk_subscription_notes_length;
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS chk_children_count_consistency;
-- ALTER TABLE profiles DROP CONSTRAINT IF EXISTS chk_languages_known_max;
