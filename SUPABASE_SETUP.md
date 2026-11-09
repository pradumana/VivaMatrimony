# Supabase Setup Guide
**Project:** `qzjxluqbqlziqimgadgl` (Supabase)
**Firebase Project:** `viva-analytics-135d4`

All steps below require manual action in the Supabase dashboard or CLI.
Items marked **NOT VERIFIED** must be confirmed in `manual-checklist.md`.

---

## 1. Apply database migrations (in order)

Run these in the Supabase SQL Editor or via the Supabase CLI (`supabase db push`).
Apply to **staging first**, then production.

| Migration | What it does |
|-----------|-------------|
| `020_firebase_uid.sql` | Adds `firebase_uid TEXT` to `users`; creates `user_identity_map` table; backfills from `supabase_uid` |
| `021_rls_firebase_uid.sql` | Replaces `current_user_id()` helper with Firebase UID → UUID mapping; rewrites storage policies |

**IMPORTANT:** Run migration 020 before 021.

**NOT VERIFIED — manual SQL execution required.**

---

## 2. Configure Third-Party Auth (Firebase)

Supabase Third-Party Auth allows Supabase to accept Firebase ID tokens as
the auth source, bypassing Supabase Auth entirely.

### Steps

1. Supabase Dashboard → **Authentication** → **Third-Party Auth** (or **Sign In with Firebase**)
2. Click **Add provider** → select **Firebase**
3. Enter Firebase Project ID: `viva-analytics-135d4`
4. Save

### Plan requirement

**Third-Party Auth requires the Supabase Pro plan or above.**
Free/Starter plan does NOT support this feature.
Confirm your plan before proceeding. **(OQ-2 — answer required)**

**NOT VERIFIED — manual dashboard step required.**

---

## 3. Verify `role: "authenticated"` in JWT

Supabase RLS policies use `auth.role()` to check that the JWT carrier is
authenticated. With Third-Party Auth, Supabase reads this from the JWT's
custom claims.

**Option A (recommended if Identity Platform is available):** Deploy the
`beforeSignIn` Cloud Function (see `FIREBASE_SETUP.md` step 9) which injects
`role: "authenticated"` into every Firebase token.

**Option B:** Check if Supabase Third-Party Auth sets `role` automatically
from the JWT issuer. Check the Supabase dashboard after configuring step 2 —
test a real login and decode the token claims (use the debug decoder in the app,
debug mode only) to confirm `"role": "authenticated"` is present.

**(OQ-8 — answer required before deploying to production)**

**NOT VERIFIED — manual verification required.**

---

## 4. Verify RLS policy parity

Confirm that the policies in `supabase/rls/tables.sql` and `storage.sql`
exactly match what is currently applied on the live database.

If any policies were created or modified directly in the dashboard (not via
migration files), export them first:

```bash
# Export current policies (requires Supabase CLI + DB credentials)
supabase db dump --schema public --schema storage > current_policies.sql
```

Then compare against the files in this repo before applying migrations 020–021.

**(OQ-1 — answer required before applying Phase 5 migrations)**

**NOT VERIFIED — manual export and comparison required.**

---

## 5. Run RLS isolation tests

After migrations 020 and 021 are applied, run the manual test script:

```sql
-- Edit placeholders in the file first, then run in Supabase SQL Editor:
-- supabase/migrations/022_rls_isolation_tests.sql
```

Expected output: all `PASS` notices, no `FAIL` assertions.

**NOT VERIFIED — manual SQL test execution required.**

---

## 6. Existing user migration

Run the migration script in dry-run mode first:

```bash
cd scripts
pip install firebase-admin asyncpg python-dotenv
export DATABASE_URL="postgresql://postgres:<password>@db.qzjxluqbqlziqimgadgl.supabase.co:5432/postgres"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
python migrate_users_to_firebase.py --dry-run
```

Review the output. Then decide:
- **bcrypt import** (preserves existing passwords): run `--no-dry-run`
- **forced password reset** (simpler): run `--no-dry-run --force-reset`

**NEVER commit `service-account.json` to the repository.**

**(OQ-6 — existing user count needed to estimate migration time)**

**NOT VERIFIED — manual migration execution required.**

---

## 7. Environment variables to update on the backend

After migration, the `SUPABASE_JWT_SECRET` environment variable is no longer
used (the backend now validates Firebase RS256 tokens). It can be left in place
(it's ignored) or removed.

Add/confirm these variables on your deployment platform (Render/Railway/etc.):

| Variable | Value | Notes |
|----------|-------|-------|
| `FIREBASE_PROJECT_ID` | `viva-analytics-135d4` | New — required |
| `DATABASE_URL` | unchanged | Still needed for Postgres |
| `SUPABASE_JWT_SECRET` | can be left or removed | No longer used |

**NOT VERIFIED — deployment platform update required.**
