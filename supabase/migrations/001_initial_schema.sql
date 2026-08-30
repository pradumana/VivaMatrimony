-- =============================================================================
-- VIVA MATRIMONY APP — INITIAL DATABASE SCHEMA
-- Migration: 001_initial_schema.sql
-- Apply via: Supabase SQL Editor or CLI
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- For fuzzy text search
CREATE EXTENSION IF NOT EXISTS "unaccent";       -- For accent-insensitive search
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- For composite GIN indexes

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE marital_status_type AS ENUM ('never_married', 'divorced', 'widowed', 'separated');
CREATE TYPE account_status_type AS ENUM ('active', 'suspended', 'banned', 'deleted', 'pending_verification');
CREATE TYPE verification_status_type AS ENUM ('unverified', 'pending', 'verified', 'rejected');
CREATE TYPE diet_type AS ENUM ('vegetarian', 'non_vegetarian', 'eggetarian', 'vegan', 'jain', 'other');
CREATE TYPE smoking_type AS ENUM ('never', 'occasionally', 'regularly');
CREATE TYPE drinking_type AS ENUM ('never', 'occasionally', 'socially', 'regularly');
CREATE TYPE employment_type AS ENUM ('salaried', 'self_employed', 'business', 'government', 'not_working', 'student', 'other');
CREATE TYPE family_type AS ENUM ('nuclear', 'joint', 'extended');
CREATE TYPE family_values_type AS ENUM ('traditional', 'moderate', 'liberal');
CREATE TYPE interest_status_type AS ENUM ('sent', 'accepted', 'declined', 'withdrawn');
CREATE TYPE reference_status_type AS ENUM ('pending', 'confirmed', 'rejected', 'revoked');
CREATE TYPE cert_status_type AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE verification_method_type AS ENUM ('reference', 'certificate', 'both');
CREATE TYPE report_status_type AS ENUM ('open', 'under_review', 'resolved', 'dismissed');
CREATE TYPE notification_type AS ENUM (
  'interest_received', 'interest_accepted', 'new_message',
  'match_found', 'verification_approved', 'verification_rejected',
  'certificate_approved', 'certificate_rejected', 'profile_viewed',
  'reference_request', 'account_action', 'system'
);
CREATE TYPE preference_importance AS ENUM ('must_have', 'preferred', 'doesnt_matter');
CREATE TYPE photo_visibility_type AS ENUM ('public', 'members_only', 'on_interest', 'private');
CREATE TYPE profile_visibility_type AS ENUM ('public', 'members_only', 'hidden');
CREATE TYPE message_status_type AS ENUM ('sent', 'delivered', 'read');
CREATE TYPE admin_role_type AS ENUM ('super_admin', 'admin', 'moderator', 'support');
CREATE TYPE biodata_export_status AS ENUM ('pending', 'generating', 'ready', 'failed');
CREATE TYPE profile_completion_step AS ENUM (
  'basic', 'bio', 'education', 'employment', 'family', 'lifestyle', 
  'native_place', 'preferences', 'photos', 'verification'
);

-- =============================================================================
-- USERS TABLE
-- Core authentication and account management
-- =============================================================================

CREATE TABLE users (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone                 VARCHAR(20) NOT NULL,
  phone_country_code    VARCHAR(5) NOT NULL DEFAULT '+91',
  phone_normalized      VARCHAR(25) NOT NULL,   -- E.164 format e.g. +919876543210
  
  account_status        account_status_type NOT NULL DEFAULT 'pending_verification',
  verification_status   verification_status_type NOT NULL DEFAULT 'unverified',
  
  -- Onboarding state tracking
  onboarding_completed  BOOLEAN NOT NULL DEFAULT FALSE,
  onboarding_step       profile_completion_step,
  
  -- FCM token for push notifications
  fcm_token             TEXT,
  
  -- Privacy & consent
  privacy_policy_accepted     BOOLEAN NOT NULL DEFAULT FALSE,
  privacy_policy_accepted_at  TIMESTAMPTZ,
  terms_accepted              BOOLEAN NOT NULL DEFAULT FALSE,
  terms_accepted_at           TIMESTAMPTZ,
  
  last_active_at        TIMESTAMPTZ,
  suspended_at          TIMESTAMPTZ,
  suspended_reason      TEXT,
  banned_at             TIMESTAMPTZ,
  banned_reason         TEXT,
  deleted_at            TIMESTAMPTZ,
  deleted_reason        TEXT,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT users_phone_normalized_unique UNIQUE (phone_normalized),
  CONSTRAINT users_phone_format CHECK (phone_normalized ~ '^\+[1-9]\d{6,14}$')
);

CREATE INDEX idx_users_phone_normalized ON users (phone_normalized);
CREATE INDEX idx_users_account_status ON users (account_status);
CREATE INDEX idx_users_last_active ON users (last_active_at DESC);
CREATE INDEX idx_users_deleted_at ON users (deleted_at) WHERE deleted_at IS NULL;

-- =============================================================================
-- OTP TABLE
-- One-time password for WhatsApp authentication
-- =============================================================================

CREATE TABLE otp_codes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_normalized  VARCHAR(25) NOT NULL,
  otp_hash          VARCHAR(255) NOT NULL,       -- bcrypt hash of OTP
  
  expires_at        TIMESTAMPTZ NOT NULL,
  attempts          INTEGER NOT NULL DEFAULT 0,
  max_attempts      INTEGER NOT NULL DEFAULT 5,
  
  is_used           BOOLEAN NOT NULL DEFAULT FALSE,
  used_at           TIMESTAMPTZ,
  
  -- Track invalidation when new OTP is sent
  invalidated_at    TIMESTAMPTZ,
  
  ip_address        INET,
  user_agent        TEXT,
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT otp_attempts_limit CHECK (attempts <= max_attempts)
);

CREATE INDEX idx_otp_phone ON otp_codes (phone_normalized, created_at DESC);
CREATE INDEX idx_otp_expires ON otp_codes (expires_at) WHERE is_used = FALSE AND invalidated_at IS NULL;

-- =============================================================================
-- SESSIONS TABLE
-- JWT session management
-- =============================================================================

CREATE TABLE sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  refresh_token_hash  VARCHAR(255) NOT NULL,
  device_info         TEXT,
  ip_address          INET,
  
  expires_at      TIMESTAMPTZ NOT NULL,
  revoked_at      TIMESTAMPTZ,
  revoked_reason  TEXT,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions (user_id);
CREATE INDEX idx_sessions_refresh_hash ON sessions (refresh_token_hash);
CREATE INDEX idx_sessions_expires ON sessions (expires_at) WHERE revoked_at IS NULL;

-- =============================================================================
-- ADMIN USERS TABLE
-- =============================================================================

CREATE TABLE admin_users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           VARCHAR(255) NOT NULL,
  password_hash   VARCHAR(255) NOT NULL,
  full_name       VARCHAR(255) NOT NULL,
  role            admin_role_type NOT NULL DEFAULT 'support',
  
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at   TIMESTAMPTZ,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT admin_users_email_unique UNIQUE (email)
);

-- =============================================================================
-- PROFILES TABLE
-- Core matrimonial profile data
-- =============================================================================

CREATE TABLE profiles (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Identity
  full_name         VARCHAR(255) NOT NULL,
  gender            gender_type NOT NULL,
  date_of_birth     DATE NOT NULL,
  -- age is computed, never stored
  
  -- Physical
  height_cm         INTEGER,      -- stored as cm, displayed as ft/cm
  
  -- Marital
  marital_status    marital_status_type NOT NULL DEFAULT 'never_married',
  have_children     BOOLEAN DEFAULT FALSE,
  children_count    INTEGER DEFAULT 0,
  
  -- Language
  mother_tongue     VARCHAR(100),
  languages_known   TEXT[],        -- array of language names
  
  -- Religion / Community (sensitive — user-provided, not independently verified)
  religion          VARCHAR(100),
  caste             VARCHAR(100),
  sub_caste         VARCHAR(100),
  
  -- About
  about_me          TEXT,
  
  -- Profile completion & visibility
  profile_visibility    profile_visibility_type NOT NULL DEFAULT 'members_only',
  photo_visibility      photo_visibility_type NOT NULL DEFAULT 'members_only',
  completion_percentage INTEGER NOT NULL DEFAULT 0,
  
  -- Timestamps
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT profiles_user_unique UNIQUE (user_id),
  CONSTRAINT profiles_height_range CHECK (height_cm IS NULL OR (height_cm BETWEEN 100 AND 250)),
  CONSTRAINT profiles_dob_range CHECK (date_of_birth BETWEEN '1940-01-01' AND CURRENT_DATE - INTERVAL '18 years'),
  CONSTRAINT profiles_children_count CHECK (children_count >= 0 AND children_count <= 20)
);

-- Computed age function
CREATE OR REPLACE FUNCTION get_age(dob DATE) RETURNS INTEGER AS $$
  SELECT DATE_PART('year', AGE(NOW(), dob))::INTEGER;
$$ LANGUAGE SQL IMMUTABLE;

CREATE INDEX idx_profiles_user_id ON profiles (user_id);
CREATE INDEX idx_profiles_gender ON profiles (gender);
CREATE INDEX idx_profiles_dob ON profiles (date_of_birth);
CREATE INDEX idx_profiles_marital_status ON profiles (marital_status);
CREATE INDEX idx_profiles_mother_tongue ON profiles (mother_tongue);
CREATE INDEX idx_profiles_religion ON profiles (religion);
CREATE INDEX idx_profiles_caste ON profiles (caste);

-- =============================================================================
-- CURRENT LOCATION TABLE
-- =============================================================================

CREATE TABLE current_locations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  country     VARCHAR(100) NOT NULL DEFAULT 'India',
  state       VARCHAR(100),
  district    VARCHAR(100),
  city        VARCHAR(100),
  
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT current_locations_user_unique UNIQUE (user_id)
);

CREATE INDEX idx_current_locations_state ON current_locations (state);
CREATE INDEX idx_current_locations_district ON current_locations (district);
CREATE INDEX idx_current_locations_city ON current_locations (city);

-- =============================================================================
-- NATIVE PLACE TABLE
-- =============================================================================

CREATE TABLE native_places (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  country     VARCHAR(100) NOT NULL DEFAULT 'India',
  state       VARCHAR(100),
  district    VARCHAR(100),
  city        VARCHAR(100),   -- town / village / city
  
  -- Privacy: user can hide native place details
  is_visible  BOOLEAN NOT NULL DEFAULT TRUE,
  
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT native_places_user_unique UNIQUE (user_id)
);

CREATE INDEX idx_native_places_state ON native_places (state);
CREATE INDEX idx_native_places_district ON native_places (district);

-- =============================================================================
-- EDUCATION TABLE
-- =============================================================================

CREATE TABLE education (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  highest_qualification   VARCHAR(100),   -- e.g. Bachelor's, Master's, PhD
  degree                  VARCHAR(255),   -- e.g. B.Tech, MBA, MBBS
  field_of_study          VARCHAR(255),   -- e.g. Computer Science
  college_university      VARCHAR(255),
  graduation_year         INTEGER,
  
  additional_qualifications   TEXT,       -- free text for extra certs
  
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT education_user_unique UNIQUE (user_id),
  CONSTRAINT education_year_range CHECK (
    graduation_year IS NULL OR graduation_year BETWEEN 1960 AND EXTRACT(YEAR FROM NOW())::INTEGER + 10
  )
);

CREATE INDEX idx_education_qualification ON education (highest_qualification);
CREATE INDEX idx_education_field ON education (field_of_study);

-- =============================================================================
-- EMPLOYMENT TABLE
-- =============================================================================

CREATE TABLE employment (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  profession            VARCHAR(255),
  job_title             VARCHAR(255),
  company               VARCHAR(255),
  industry              VARCHAR(255),
  employment_type       employment_type,
  work_location         VARCHAR(255),
  
  -- Income stored as range (min, max in INR per annum)
  income_min_lpa        NUMERIC(10, 2),  -- lakhs per annum
  income_max_lpa        NUMERIC(10, 2),
  
  -- Privacy controls
  show_company          BOOLEAN NOT NULL DEFAULT TRUE,
  show_income           BOOLEAN NOT NULL DEFAULT FALSE,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT employment_user_unique UNIQUE (user_id),
  CONSTRAINT employment_income_range CHECK (
    (income_min_lpa IS NULL AND income_max_lpa IS NULL) OR
    (income_min_lpa >= 0 AND income_max_lpa >= income_min_lpa)
  )
);

CREATE INDEX idx_employment_profession ON employment (profession);
CREATE INDEX idx_employment_industry ON employment (industry);
CREATE INDEX idx_employment_type ON employment (employment_type);

-- =============================================================================
-- FAMILY DETAILS TABLE
-- =============================================================================

CREATE TABLE family_details (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  father_name           VARCHAR(255),
  father_occupation     VARCHAR(255),
  father_is_alive       BOOLEAN DEFAULT TRUE,
  
  mother_name           VARCHAR(255),
  mother_occupation     VARCHAR(255),
  mother_is_alive       BOOLEAN DEFAULT TRUE,
  
  brothers_count        INTEGER DEFAULT 0,
  brothers_married      INTEGER DEFAULT 0,
  sisters_count         INTEGER DEFAULT 0,
  sisters_married       INTEGER DEFAULT 0,
  
  family_type           family_type,
  family_values         family_values_type,
  family_location       VARCHAR(255),     -- brief description / city
  
  additional_info       TEXT,
  
  -- Privacy
  show_parents_info     BOOLEAN NOT NULL DEFAULT TRUE,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT family_details_user_unique UNIQUE (user_id),
  CONSTRAINT family_siblings_non_negative CHECK (
    brothers_count >= 0 AND brothers_married >= 0 AND
    sisters_count >= 0 AND sisters_married >= 0
  ),
  CONSTRAINT family_siblings_married_max CHECK (
    brothers_married <= brothers_count AND sisters_married <= sisters_count
  )
);

-- =============================================================================
-- LIFESTYLE TABLE
-- =============================================================================

CREATE TABLE lifestyle (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  diet            diet_type,
  smoking         smoking_type,
  drinking        drinking_type,
  
  fitness         VARCHAR(100),   -- e.g. Regular gym, yoga, none
  hobbies         TEXT[],         -- array
  interests       TEXT[],         -- array
  travel          VARCHAR(100),   -- e.g. Frequent, occasional, rarely
  pets            BOOLEAN DEFAULT FALSE,
  pet_types       TEXT[],
  
  other_info      TEXT,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT lifestyle_user_unique UNIQUE (user_id)
);

-- =============================================================================
-- PARTNER PREFERENCES TABLE
-- =============================================================================

CREATE TABLE partner_preferences (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Age
  min_age               INTEGER,
  max_age               INTEGER,
  age_importance        preference_importance DEFAULT 'preferred',
  
  -- Height
  min_height_cm         INTEGER,
  max_height_cm         INTEGER,
  height_importance     preference_importance DEFAULT 'doesnt_matter',
  
  -- Location
  preferred_countries   TEXT[],
  preferred_states      TEXT[],
  preferred_cities      TEXT[],
  location_importance   preference_importance DEFAULT 'preferred',
  
  -- Native place
  preferred_native_states     TEXT[],
  preferred_native_districts  TEXT[],
  native_place_importance     preference_importance DEFAULT 'preferred',
  
  -- Education
  min_education         VARCHAR(100),
  preferred_fields      TEXT[],
  education_importance  preference_importance DEFAULT 'preferred',
  
  -- Profession & income
  preferred_professions TEXT[],
  min_income_lpa        NUMERIC(10, 2),
  income_importance     preference_importance DEFAULT 'doesnt_matter',
  
  -- Personal
  preferred_marital_status    marital_status_type[],
  preferred_mother_tongues    TEXT[],
  preferred_religions         TEXT[],
  preferred_castes            TEXT[],
  
  -- Lifestyle
  preferred_diet          diet_type[],
  smoking_preference      smoking_type,
  drinking_preference     drinking_type,
  lifestyle_importance    preference_importance DEFAULT 'preferred',
  
  -- Family
  preferred_family_types    family_type[],
  preferred_family_values   family_values_type[],
  
  -- Life expectations
  open_to_relocation      BOOLEAN DEFAULT TRUE,
  want_children           BOOLEAN,
  
  other_expectations      TEXT,
  
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT partner_prefs_user_unique UNIQUE (user_id),
  CONSTRAINT partner_prefs_age_range CHECK (
    (min_age IS NULL AND max_age IS NULL) OR
    (min_age >= 18 AND max_age <= 80 AND min_age <= max_age)
  ),
  CONSTRAINT partner_prefs_height_range CHECK (
    (min_height_cm IS NULL AND max_height_cm IS NULL) OR
    (min_height_cm >= 100 AND max_height_cm <= 250 AND min_height_cm <= max_height_cm)
  )
);

-- =============================================================================
-- PHOTOS TABLE
-- =============================================================================

CREATE TABLE photos (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  storage_path      VARCHAR(1024) NOT NULL,  -- Supabase storage path
  storage_bucket    VARCHAR(255) NOT NULL DEFAULT 'profile-photos',
  
  -- Thumbnail path (auto-generated)
  thumbnail_path    VARCHAR(1024),
  
  file_name         VARCHAR(255) NOT NULL,
  file_size_bytes   INTEGER NOT NULL,
  mime_type         VARCHAR(100) NOT NULL,
  width_px          INTEGER,
  height_px         INTEGER,
  
  is_primary        BOOLEAN NOT NULL DEFAULT FALSE,
  display_order     INTEGER NOT NULL DEFAULT 0,
  
  -- Moderation
  is_approved       BOOLEAN NOT NULL DEFAULT TRUE,
  is_flagged        BOOLEAN NOT NULL DEFAULT FALSE,
  flag_reason       TEXT,
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ,
  
  CONSTRAINT photos_mime_check CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  CONSTRAINT photos_size_check CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760),  -- 10MB
  CONSTRAINT photos_one_primary UNIQUE NULLS NOT DISTINCT (user_id, is_primary) 
    DEFERRABLE INITIALLY DEFERRED
);

-- Only one primary photo per user (partial unique index)
CREATE UNIQUE INDEX idx_photos_primary_unique ON photos (user_id) 
  WHERE is_primary = TRUE AND deleted_at IS NULL;

CREATE INDEX idx_photos_user_id ON photos (user_id, display_order) WHERE deleted_at IS NULL;

-- =============================================================================
-- VERIFICATION DOCUMENTS TABLE
-- Caste certificates stored in private Supabase bucket
-- =============================================================================

CREATE TABLE verification_documents (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Stored in PRIVATE bucket 'verification-docs'
  storage_path          VARCHAR(1024) NOT NULL,
  storage_bucket        VARCHAR(255) NOT NULL DEFAULT 'verification-docs',
  
  file_name             VARCHAR(255) NOT NULL,
  file_size_bytes       INTEGER NOT NULL,
  mime_type             VARCHAR(100) NOT NULL,
  
  document_type         VARCHAR(50) NOT NULL DEFAULT 'caste_certificate',
  
  status                cert_status_type NOT NULL DEFAULT 'pending',
  
  -- Admin review
  reviewed_by           UUID REFERENCES admin_users(id),
  reviewed_at           TIMESTAMPTZ,
  rejection_reason      TEXT,
  
  -- Lock after approval (can only be unlocked by admin)
  is_locked             BOOLEAN NOT NULL DEFAULT FALSE,
  locked_at             TIMESTAMPTZ,
  locked_by             UUID REFERENCES admin_users(id),
  
  -- Soft deletion for audit trail
  deleted_at            TIMESTAMPTZ,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT vdocs_mime_check CHECK (
    mime_type IN ('application/pdf', 'image/jpeg', 'image/png')
  ),
  CONSTRAINT vdocs_size_check CHECK (
    file_size_bytes > 0 AND file_size_bytes <= 20971520  -- 20MB
  )
);

CREATE INDEX idx_vdocs_user_id ON verification_documents (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_vdocs_status ON verification_documents (status) WHERE deleted_at IS NULL;

-- =============================================================================
-- REFERENCE MEMBERS TABLE
-- User-provided references (existing registered members)
-- =============================================================================

CREATE TABLE reference_members (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reference_user_id     UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  
  status                reference_status_type NOT NULL DEFAULT 'pending',
  
  -- Optional confirmation by referenced member
  confirmation_requested_at   TIMESTAMPTZ,
  confirmed_at                TIMESTAMPTZ,
  rejected_at                 TIMESTAMPTZ,
  rejection_reason            TEXT,
  revoked_at                  TIMESTAMPTZ,
  revoked_by                  UUID REFERENCES admin_users(id),
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT ref_no_self_reference CHECK (user_id <> reference_user_id),
  CONSTRAINT ref_unique UNIQUE (user_id, reference_user_id)
);

CREATE INDEX idx_ref_user_id ON reference_members (user_id);
CREATE INDEX idx_ref_reference_user_id ON reference_members (reference_user_id);

-- =============================================================================
-- VERIFICATION REQUESTS TABLE
-- Tracks the overall verification state (which method chosen)
-- =============================================================================

CREATE TABLE verification_requests (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  method                verification_method_type NOT NULL,
  status                cert_status_type NOT NULL DEFAULT 'pending',
  
  -- Reference to whichever verification asset was used
  document_id           UUID REFERENCES verification_documents(id),
  reference_id          UUID REFERENCES reference_members(id),
  
  admin_notes           TEXT,
  reviewed_by           UUID REFERENCES admin_users(id),
  reviewed_at           TIMESTAMPTZ,
  
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT verification_user_unique UNIQUE (user_id)
);

-- =============================================================================
-- INTERESTS TABLE
-- Interest / connection requests between users
-- =============================================================================

CREATE TABLE interests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  status          interest_status_type NOT NULL DEFAULT 'sent',
  
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at     TIMESTAMPTZ,
  declined_at     TIMESTAMPTZ,
  withdrawn_at    TIMESTAMPTZ,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT interests_no_self CHECK (sender_id <> receiver_id),
  CONSTRAINT interests_unique UNIQUE (sender_id, receiver_id)
);

CREATE INDEX idx_interests_sender ON interests (sender_id, status);
CREATE INDEX idx_interests_receiver ON interests (receiver_id, status);
CREATE INDEX idx_interests_mutual ON interests (sender_id, receiver_id, status);

-- =============================================================================
-- SHORTLISTS TABLE
-- =============================================================================

CREATE TABLE shortlists (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  private_notes   TEXT,   -- NEVER visible to target user
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT shortlists_no_self CHECK (user_id <> target_user_id),
  CONSTRAINT shortlists_unique UNIQUE (user_id, target_user_id)
);

CREATE INDEX idx_shortlists_user_id ON shortlists (user_id);

-- =============================================================================
-- BLOCKS TABLE
-- =============================================================================

CREATE TABLE blocks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  blocker_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  reason          TEXT,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT blocks_no_self CHECK (blocker_id <> blocked_id),
  CONSTRAINT blocks_unique UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX idx_blocks_blocker ON blocks (blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks (blocked_id);

-- =============================================================================
-- CONVERSATIONS TABLE
-- =============================================================================

CREATE TABLE conversations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- The mutual interest that enabled this conversation
  interest_id     UUID REFERENCES interests(id) ON DELETE SET NULL,
  
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  
  last_message_at TIMESTAMPTZ,
  last_message_preview  VARCHAR(500),
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- CONVERSATION MEMBERS TABLE
-- =============================================================================

CREATE TABLE conversation_members (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id     UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  joined_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at        TIMESTAMPTZ,
  is_muted            BOOLEAN NOT NULL DEFAULT FALSE,
  
  unread_count        INTEGER NOT NULL DEFAULT 0,
  
  CONSTRAINT conv_members_unique UNIQUE (conversation_id, user_id)
);

CREATE INDEX idx_conv_members_user ON conversation_members (user_id, conversation_id);
CREATE INDEX idx_conv_members_conv ON conversation_members (conversation_id);

-- =============================================================================
-- MESSAGES TABLE
-- =============================================================================

CREATE TABLE messages (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id     UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Idempotency key (client-generated, prevents duplicate sends)
  client_message_id   VARCHAR(100),
  
  content             TEXT,
  message_type        VARCHAR(20) NOT NULL DEFAULT 'text',  -- text, image, emoji
  
  -- For image messages
  attachment_path     VARCHAR(1024),
  attachment_type     VARCHAR(100),
  
  status              message_status_type NOT NULL DEFAULT 'sent',
  
  deleted_at          TIMESTAMPTZ,     -- soft delete for sender
  deleted_for_all_at  TIMESTAMPTZ,     -- delete for both parties
  
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT messages_content_not_empty CHECK (
    (message_type = 'text' AND content IS NOT NULL AND LENGTH(TRIM(content)) > 0) OR
    (message_type != 'text')
  ),
  CONSTRAINT messages_content_length CHECK (
    content IS NULL OR LENGTH(content) <= 5000
  ),
  CONSTRAINT messages_client_id_unique UNIQUE (conversation_id, client_message_id)
);

CREATE INDEX idx_messages_conversation ON messages (conversation_id, created_at DESC) 
  WHERE deleted_for_all_at IS NULL;
CREATE INDEX idx_messages_sender ON messages (sender_id);
CREATE INDEX idx_messages_client_id ON messages (client_message_id) WHERE client_message_id IS NOT NULL;

-- =============================================================================
-- NOTIFICATIONS TABLE
-- =============================================================================

CREATE TABLE notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  type            notification_type NOT NULL,
  title           VARCHAR(255) NOT NULL,
  body            TEXT NOT NULL,
  
  -- Actor (who triggered this notification)
  actor_user_id   UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Related entity
  entity_type     VARCHAR(50),   -- e.g. 'interest', 'message', 'verification'
  entity_id       UUID,
  
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  read_at         TIMESTAMPTZ,
  
  -- FCM delivery
  fcm_sent        BOOLEAN NOT NULL DEFAULT FALSE,
  fcm_sent_at     TIMESTAMPTZ,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications (user_id, is_read, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications (user_id) WHERE is_read = FALSE;

-- =============================================================================
-- REPORTS TABLE
-- =============================================================================

CREATE TABLE reports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  reason          VARCHAR(100) NOT NULL,
  description     TEXT,
  
  status          report_status_type NOT NULL DEFAULT 'open',
  
  reviewed_by     UUID REFERENCES admin_users(id),
  reviewed_at     TIMESTAMPTZ,
  resolution_note TEXT,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT reports_no_self CHECK (reporter_id <> reported_id)
);

CREATE INDEX idx_reports_reported ON reports (reported_id, status);
CREATE INDEX idx_reports_status ON reports (status, created_at DESC);

-- =============================================================================
-- BIODATA EXPORTS TABLE
-- Track generated PDF biodatas
-- =============================================================================

CREATE TABLE biodata_exports (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  storage_path    VARCHAR(1024),
  storage_bucket  VARCHAR(255) DEFAULT 'biodata-pdfs',
  
  status          biodata_export_status NOT NULL DEFAULT 'pending',
  
  -- Invalidate cached PDF when profile is updated
  profile_hash    VARCHAR(64),    -- hash of profile data used to generate this PDF
  is_stale        BOOLEAN NOT NULL DEFAULT FALSE,
  
  error_message   TEXT,
  
  generated_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,   -- signed URL expiry
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_biodata_exports_user ON biodata_exports (user_id, created_at DESC);

-- =============================================================================
-- AUDIT LOGS TABLE
-- Sensitive admin and user actions
-- =============================================================================

CREATE TABLE audit_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Actor (can be user or admin)
  actor_type      VARCHAR(20) NOT NULL,   -- 'user' | 'admin' | 'system'
  actor_id        UUID,
  
  -- Target
  target_type     VARCHAR(50),
  target_id       UUID,
  
  action          VARCHAR(100) NOT NULL,
  details         JSONB,
  
  ip_address      INET,
  user_agent      TEXT,
  
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_actor ON audit_logs (actor_type, actor_id, created_at DESC);
CREATE INDEX idx_audit_target ON audit_logs (target_type, target_id, created_at DESC);
CREATE INDEX idx_audit_action ON audit_logs (action, created_at DESC);

-- =============================================================================
-- PROFILE VIEWS TABLE
-- Track who viewed whose profile (for analytics + notifications)
-- =============================================================================

CREATE TABLE profile_views (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  viewer_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  viewed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT profile_views_no_self CHECK (viewer_id <> viewed_id)
);

CREATE INDEX idx_profile_views_viewed ON profile_views (viewed_id, viewed_at DESC);
CREATE INDEX idx_profile_views_viewer ON profile_views (viewer_id, viewed_at DESC);

-- =============================================================================
-- HELPER: Auto-update updated_at trigger
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN 
    SELECT table_name FROM information_schema.columns 
    WHERE column_name = 'updated_at' 
      AND table_schema = 'public'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%I_updated_at 
       BEFORE UPDATE ON %I 
       FOR EACH ROW EXECUTE FUNCTION update_updated_at()',
      t, t
    );
  END LOOP;
END;
$$;

-- =============================================================================
-- HELPER: Invalidate biodata when profile changes
-- =============================================================================

CREATE OR REPLACE FUNCTION invalidate_biodata_on_profile_change()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE biodata_exports 
  SET is_stale = TRUE, updated_at = NOW()
  WHERE user_id = NEW.user_id AND is_stale = FALSE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_invalidate_biodata_profile
  AFTER UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION invalidate_biodata_on_profile_change();

CREATE TRIGGER trg_invalidate_biodata_education
  AFTER UPDATE ON education
  FOR EACH ROW EXECUTE FUNCTION invalidate_biodata_on_profile_change();

CREATE TRIGGER trg_invalidate_biodata_employment
  AFTER UPDATE ON employment
  FOR EACH ROW EXECUTE FUNCTION invalidate_biodata_on_profile_change();

-- =============================================================================
-- HELPER: Update conversation last_message_at
-- =============================================================================

CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations SET 
    last_message_at = NEW.created_at,
    last_message_preview = LEFT(NEW.content, 100),
    updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_conversation_last_message
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION update_conversation_last_message();

-- =============================================================================
-- HELPER: Update user last_active_at
-- =============================================================================

CREATE OR REPLACE FUNCTION update_user_last_active()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE users SET last_active_at = NOW() WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_message_last_active
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION update_user_last_active();

-- =============================================================================
-- FULL TEXT SEARCH — Profile search index
-- =============================================================================

CREATE INDEX idx_profiles_fts ON profiles 
  USING gin(to_tsvector('english', 
    COALESCE(full_name, '') || ' ' ||
    COALESCE(religion, '') || ' ' ||
    COALESCE(caste, '') || ' ' ||
    COALESCE(mother_tongue, '')
  ));

CREATE INDEX idx_education_fts ON education
  USING gin(to_tsvector('english',
    COALESCE(degree, '') || ' ' ||
    COALESCE(field_of_study, '') || ' ' ||
    COALESCE(highest_qualification, '')
  ));

CREATE INDEX idx_employment_fts ON employment
  USING gin(to_tsvector('english',
    COALESCE(profession, '') || ' ' ||
    COALESCE(job_title, '') || ' ' ||
    COALESCE(industry, '')
  ));

-- Trigram indexes for fuzzy name search
CREATE INDEX idx_profiles_name_trgm ON profiles USING gin(full_name gin_trgm_ops);
CREATE INDEX idx_current_loc_city_trgm ON current_locations USING gin(city gin_trgm_ops);
CREATE INDEX idx_native_place_city_trgm ON native_places USING gin(city gin_trgm_ops);
