-- =============================================================================
-- VIVA MATRIMONY APP — SUPABASE STORAGE RLS POLICIES
-- Apply after creating storage buckets in Supabase dashboard.
-- =============================================================================

-- =============================================================================
-- BUCKET: profile-photos (public read, authenticated write)
-- =============================================================================

-- Anyone can view profile photos (public bucket)
CREATE POLICY "profile_photos_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

-- Authenticated users can upload their own photos
-- Path pattern: profile-photos/{user_id}/{filename}
CREATE POLICY "profile_photos_owner_insert"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'profile-photos'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::TEXT
);

-- Users can update/delete only their own photos
CREATE POLICY "profile_photos_owner_update"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'profile-photos'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::TEXT
);

CREATE POLICY "profile_photos_owner_delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'profile-photos'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::TEXT
);

-- =============================================================================
-- BUCKET: biodata-pdfs (owner read, backend write)
-- =============================================================================

-- Users can read their own biodata PDFs
-- Path pattern: biodata-pdfs/{user_id}/{filename}
CREATE POLICY "biodata_pdfs_owner_read"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'biodata-pdfs'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::TEXT
);

-- Only service role (backend) can insert/update biodata PDFs
CREATE POLICY "biodata_pdfs_service_write"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'biodata-pdfs'
  AND auth.role() = 'service_role'
);

CREATE POLICY "biodata_pdfs_service_update"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'biodata-pdfs'
  AND auth.role() = 'service_role'
);

CREATE POLICY "biodata_pdfs_service_delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'biodata-pdfs'
  AND auth.role() = 'service_role'
);

-- =============================================================================
-- BUCKET: verification-docs (PRIVATE — no direct client access)
-- All access is mediated through FastAPI backend using service_role key
-- =============================================================================

-- Users can upload their own documents (only during onboarding)
-- Backend validates before allowing; path: verification-docs/{user_id}/{filename}
CREATE POLICY "vdocs_owner_insert"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'verification-docs'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::TEXT
);

-- NO direct read access for users (backend generates signed URLs)
-- Admins access via service_role key (which bypasses RLS)

-- Block all direct SELECT from regular users
CREATE POLICY "vdocs_no_direct_select"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'verification-docs'
  AND auth.role() = 'service_role'
);

-- Block all direct updates/deletes from regular users
CREATE POLICY "vdocs_service_only_update"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'verification-docs'
  AND auth.role() = 'service_role'
);

CREATE POLICY "vdocs_service_only_delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'verification-docs'
  AND auth.role() = 'service_role'
);
