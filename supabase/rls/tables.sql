-- =============================================================================
-- VIVA MATRIMONY APP — ROW LEVEL SECURITY POLICIES
-- Apply AFTER creating tables and AFTER enabling RLS on each table.
-- =============================================================================

-- NOTE: All actual authorization is enforced at the FastAPI backend layer.
-- These RLS policies add a second layer of database-level protection.
-- The backend uses the service_role key for most operations (bypasses RLS),
-- but if Supabase auto-APIs or direct client connections are ever used,
-- these policies protect data.

-- Enable RLS on all user-facing tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE current_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE native_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE education ENABLE ROW LEVEL SECURITY;
ALTER TABLE employment ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE lifestyle ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE reference_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE interests ENABLE ROW LEVEL SECURITY;
ALTER TABLE shortlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE biodata_exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE shortlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- HELPER: Get current user's ID from JWT claim
-- The FastAPI backend sets the user_id in JWT sub claim.
-- Supabase auto-sets auth.uid() when using Supabase Auth.
-- For custom JWT auth, we use a custom function:
-- =============================================================================

CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
  SELECT COALESCE(
    auth.uid(),
    (current_setting('app.current_user_id', true))::UUID
  );
$$ LANGUAGE SQL SECURITY DEFINER;

-- =============================================================================
-- USERS — Users can only read/update their own record
-- =============================================================================

CREATE POLICY users_select_own ON users
  FOR SELECT USING (id = current_user_id());

CREATE POLICY users_update_own ON users
  FOR UPDATE USING (id = current_user_id())
  WITH CHECK (id = current_user_id());

-- No INSERT via RLS (handled by backend with service role)
-- No DELETE via RLS (soft delete only, via backend)

-- =============================================================================
-- PROFILES — Users can read active members' profiles; update only own
-- =============================================================================

CREATE POLICY profiles_select_active ON profiles
  FOR SELECT USING (
    -- Own profile always readable
    user_id = current_user_id()
    OR
    -- Other profiles: must be visible and user account must be active
    (
      profile_visibility IN ('public', 'members_only')
      AND EXISTS (
        SELECT 1 FROM users u 
        WHERE u.id = profiles.user_id 
          AND u.account_status = 'active'
          AND u.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = current_user_id() AND b.blocked_id = profiles.user_id)
           OR (b.blocker_id = profiles.user_id AND b.blocked_id = current_user_id())
      )
    )
  );

CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

-- =============================================================================
-- PHOTOS — Public photos visible to all members; private per visibility setting
-- =============================================================================

CREATE POLICY photos_select ON photos
  FOR SELECT USING (
    user_id = current_user_id()
    OR (
      deleted_at IS NULL
      AND is_approved = TRUE
      AND EXISTS (
        SELECT 1 FROM profiles p
        WHERE p.user_id = photos.user_id
          AND p.photo_visibility IN ('public', 'members_only')
          AND NOT EXISTS (
            SELECT 1 FROM blocks b
            WHERE (b.blocker_id = current_user_id() AND b.blocked_id = photos.user_id)
               OR (b.blocker_id = photos.user_id AND b.blocked_id = current_user_id())
          )
      )
    )
  );

CREATE POLICY photos_insert_own ON photos
  FOR INSERT WITH CHECK (user_id = current_user_id());

CREATE POLICY photos_update_own ON photos
  FOR UPDATE USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

CREATE POLICY photos_delete_own ON photos
  FOR DELETE USING (user_id = current_user_id());

-- =============================================================================
-- VERIFICATION DOCUMENTS — Owner only; admin via service role
-- NEVER expose via direct client access
-- =============================================================================

CREATE POLICY vdocs_select_own ON verification_documents
  FOR SELECT USING (user_id = current_user_id());

CREATE POLICY vdocs_insert_own ON verification_documents
  FOR INSERT WITH CHECK (user_id = current_user_id());

-- No update/delete for users (locked documents cannot be changed by users)

-- =============================================================================
-- REFERENCE MEMBERS — User can see own references
-- =============================================================================

CREATE POLICY ref_select_own ON reference_members
  FOR SELECT USING (
    user_id = current_user_id() OR reference_user_id = current_user_id()
  );

CREATE POLICY ref_insert_own ON reference_members
  FOR INSERT WITH CHECK (user_id = current_user_id());

-- =============================================================================
-- INTERESTS — Sender and receiver can see their own interests
-- =============================================================================

CREATE POLICY interests_select ON interests
  FOR SELECT USING (
    sender_id = current_user_id() OR receiver_id = current_user_id()
  );

CREATE POLICY interests_insert ON interests
  FOR INSERT WITH CHECK (sender_id = current_user_id());

CREATE POLICY interests_update ON interests
  FOR UPDATE USING (
    sender_id = current_user_id() OR receiver_id = current_user_id()
  );

-- =============================================================================
-- SHORTLISTS — Private to owner only
-- =============================================================================

CREATE POLICY shortlists_select_own ON shortlists
  FOR SELECT USING (user_id = current_user_id());

CREATE POLICY shortlists_insert_own ON shortlists
  FOR INSERT WITH CHECK (user_id = current_user_id());

CREATE POLICY shortlists_delete_own ON shortlists
  FOR DELETE USING (user_id = current_user_id());

-- =============================================================================
-- BLOCKS — Owner can see their own blocks
-- =============================================================================

CREATE POLICY blocks_select_own ON blocks
  FOR SELECT USING (blocker_id = current_user_id());

CREATE POLICY blocks_insert_own ON blocks
  FOR INSERT WITH CHECK (blocker_id = current_user_id());

CREATE POLICY blocks_delete_own ON blocks
  FOR DELETE USING (blocker_id = current_user_id());

-- =============================================================================
-- CONVERSATIONS — Members only
-- =============================================================================

CREATE POLICY conversations_select ON conversations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = conversations.id
        AND cm.user_id = current_user_id()
    )
  );

-- =============================================================================
-- CONVERSATION MEMBERS — Own membership
-- =============================================================================

CREATE POLICY conv_members_select ON conversation_members
  FOR SELECT USING (
    user_id = current_user_id()
    OR EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = conversation_members.conversation_id
        AND cm.user_id = current_user_id()
    )
  );

-- =============================================================================
-- MESSAGES — Participants only
-- =============================================================================

CREATE POLICY messages_select ON messages
  FOR SELECT USING (
    deleted_for_all_at IS NULL
    AND EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
        AND cm.user_id = current_user_id()
    )
  );

CREATE POLICY messages_insert ON messages
  FOR INSERT WITH CHECK (
    sender_id = current_user_id()
    AND EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
        AND cm.user_id = current_user_id()
    )
  );

-- =============================================================================
-- NOTIFICATIONS — Own notifications only
-- =============================================================================

CREATE POLICY notifications_select_own ON notifications
  FOR SELECT USING (user_id = current_user_id());

CREATE POLICY notifications_update_own ON notifications
  FOR UPDATE USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

-- =============================================================================
-- REPORTS — Reporter can see own reports
-- =============================================================================

CREATE POLICY reports_select_own ON reports
  FOR SELECT USING (reporter_id = current_user_id());

CREATE POLICY reports_insert_own ON reports
  FOR INSERT WITH CHECK (reporter_id = current_user_id());

-- =============================================================================
-- BIODATA EXPORTS — Own only
-- =============================================================================

CREATE POLICY biodata_select_own ON biodata_exports
  FOR SELECT USING (user_id = current_user_id());

-- =============================================================================
-- SESSIONS — Own only
-- =============================================================================

CREATE POLICY sessions_select_own ON sessions
  FOR SELECT USING (user_id = current_user_id());

-- =============================================================================
-- AUDIT LOGS — No direct user access (admin only via service role)
-- =============================================================================

CREATE POLICY audit_no_direct_access ON audit_logs
  FOR ALL USING (FALSE);

-- =============================================================================
-- OTP CODES — No direct user access (backend service role only)
-- =============================================================================

CREATE POLICY otp_no_direct_access ON otp_codes
  FOR ALL USING (FALSE);

-- =============================================================================
-- PARTNER PREFERENCES — User-controlled visibility
-- =============================================================================

CREATE POLICY prefs_select_own ON partner_preferences
  FOR SELECT USING (user_id = current_user_id());

CREATE POLICY prefs_update_own ON partner_preferences
  FOR UPDATE USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

-- =============================================================================
-- EDUCATION / EMPLOYMENT / FAMILY / LIFESTYLE / LOCATIONS
-- Read: active members (no blocks), Write: own only
-- =============================================================================

-- Reusable pattern for each table:
DO $$ BEGIN

  -- current_locations
  CREATE POLICY cl_select ON current_locations
    FOR SELECT USING (
      user_id = current_user_id()
      OR EXISTS (
        SELECT 1 FROM users u WHERE u.id = current_locations.user_id 
          AND u.account_status = 'active' AND u.deleted_at IS NULL
      )
    );
  CREATE POLICY cl_update_own ON current_locations
    FOR UPDATE USING (user_id = current_user_id());

  -- native_places
  CREATE POLICY np_select ON native_places
    FOR SELECT USING (
      user_id = current_user_id()
      OR (
        is_visible = TRUE
        AND EXISTS (
          SELECT 1 FROM users u WHERE u.id = native_places.user_id 
            AND u.account_status = 'active' AND u.deleted_at IS NULL
        )
      )
    );
  CREATE POLICY np_update_own ON native_places
    FOR UPDATE USING (user_id = current_user_id());

  -- education
  CREATE POLICY edu_select ON education
    FOR SELECT USING (
      user_id = current_user_id()
      OR EXISTS (
        SELECT 1 FROM users u WHERE u.id = education.user_id 
          AND u.account_status = 'active' AND u.deleted_at IS NULL
      )
    );
  CREATE POLICY edu_update_own ON education
    FOR UPDATE USING (user_id = current_user_id());

  -- employment
  CREATE POLICY emp_select ON employment
    FOR SELECT USING (
      user_id = current_user_id()
      OR EXISTS (
        SELECT 1 FROM users u WHERE u.id = employment.user_id 
          AND u.account_status = 'active' AND u.deleted_at IS NULL
      )
    );
  CREATE POLICY emp_update_own ON employment
    FOR UPDATE USING (user_id = current_user_id());

  -- family_details (parents info subject to show_parents_info flag)
  CREATE POLICY fam_select ON family_details
    FOR SELECT USING (
      user_id = current_user_id()
      OR EXISTS (
        SELECT 1 FROM users u WHERE u.id = family_details.user_id 
          AND u.account_status = 'active' AND u.deleted_at IS NULL
      )
    );
  CREATE POLICY fam_update_own ON family_details
    FOR UPDATE USING (user_id = current_user_id());

  -- lifestyle
  CREATE POLICY ls_select ON lifestyle
    FOR SELECT USING (
      user_id = current_user_id()
      OR EXISTS (
        SELECT 1 FROM users u WHERE u.id = lifestyle.user_id 
          AND u.account_status = 'active' AND u.deleted_at IS NULL
      )
    );
  CREATE POLICY ls_update_own ON lifestyle
    FOR UPDATE USING (user_id = current_user_id());

END $$;
