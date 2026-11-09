-- =============================================================================
-- RLS Isolation Tests (manual verification script — do NOT apply to production)
--
-- Run in a Supabase SQL editor session AFTER migrations 020 and 021.
-- Uses SET LOCAL to simulate different JWT sub claims.
-- Expected: every SELECT returns 0 rows for cross-user queries.
--
-- Replace the placeholder UIDs with real firebase_uid values from your
-- user_identity_map table before running.
-- =============================================================================

-- Prerequisites: two test users must exist in user_identity_map.
-- Replace these with real values:
-- USER_A_FIREBASE_UID = 'firebaseUidOfUserA'
-- USER_A_UUID         = (supabase_user_id of user A)
-- USER_B_UUID         = (supabase_user_id of user B)

-- ── Test 1: User A cannot read User B's profile ───────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Simulate User A's JWT sub
    PERFORM set_config('request.jwt.claims',
        '{"sub": "firebaseUidOfUserA", "role": "authenticated"}', true);

    SELECT COUNT(*) INTO v_count
    FROM profiles
    WHERE user_id = 'USER_B_UUID_HERE'::UUID;

    ASSERT v_count = 0,
        'FAIL: User A can read User B''s profile (' || v_count || ' rows)';
    RAISE NOTICE 'PASS: User A cannot read User B''s profile';
END $$;

-- ── Test 2: User A can read their own profile ─────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM set_config('request.jwt.claims',
        '{"sub": "firebaseUidOfUserA", "role": "authenticated"}', true);

    SELECT COUNT(*) INTO v_count
    FROM profiles
    WHERE user_id = 'USER_A_UUID_HERE'::UUID;

    -- May be 0 if profile doesn't exist yet — that's OK (not an RLS failure)
    RAISE NOTICE 'INFO: User A profile row count = %', v_count;
END $$;

-- ── Test 3: Anonymous access returns 0 rows ───────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- No JWT claims — anonymous session
    PERFORM set_config('request.jwt.claims', '{}', true);

    SELECT COUNT(*) INTO v_count FROM profiles;

    ASSERT v_count = 0,
        'FAIL: Anonymous user can read profiles (' || v_count || ' rows)';
    RAISE NOTICE 'PASS: Anonymous access denied on profiles';

    SELECT COUNT(*) INTO v_count FROM users;
    ASSERT v_count = 0,
        'FAIL: Anonymous user can read users (' || v_count || ' rows)';
    RAISE NOTICE 'PASS: Anonymous access denied on users';

    SELECT COUNT(*) INTO v_count FROM messages;
    ASSERT v_count = 0,
        'FAIL: Anonymous user can read messages (' || v_count || ' rows)';
    RAISE NOTICE 'PASS: Anonymous access denied on messages';
END $$;

-- ── Test 4: User A cannot read User B's messages ─────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    PERFORM set_config('request.jwt.claims',
        '{"sub": "firebaseUidOfUserA", "role": "authenticated"}', true);

    -- Count messages in conversations User A is NOT a member of
    SELECT COUNT(*) INTO v_count
    FROM messages m
    WHERE NOT EXISTS (
        SELECT 1 FROM conversation_members cm
        WHERE cm.conversation_id = m.conversation_id
          AND cm.user_id = current_user_id()
    );

    ASSERT v_count = 0,
        'FAIL: User A can read messages from conversations they are not in (' || v_count || ')';
    RAISE NOTICE 'PASS: User A cannot read others'' messages';
END $$;

-- ── Test 5: current_firebase_uid() returns correct value ─────────────────────
DO $$
DECLARE
    v_uid TEXT;
BEGIN
    PERFORM set_config('request.jwt.claims',
        '{"sub": "firebaseUidOfUserA", "role": "authenticated"}', true);

    SELECT current_firebase_uid() INTO v_uid;

    ASSERT v_uid = 'firebaseUidOfUserA',
        'FAIL: current_firebase_uid() returned ' || COALESCE(v_uid, 'NULL');
    RAISE NOTICE 'PASS: current_firebase_uid() = %', v_uid;
END $$;

-- ── Test 6: current_user_id() maps Firebase UID to correct UUID ──────────────
DO $$
DECLARE
    v_uuid UUID;
BEGIN
    PERFORM set_config('request.jwt.claims',
        '{"sub": "firebaseUidOfUserA", "role": "authenticated"}', true);

    SELECT current_user_id() INTO v_uuid;

    ASSERT v_uuid = 'USER_A_UUID_HERE'::UUID,
        'FAIL: current_user_id() returned ' || COALESCE(v_uuid::TEXT, 'NULL');
    RAISE NOTICE 'PASS: current_user_id() = %', v_uuid;
END $$;
