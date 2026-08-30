# Viva — Supabase Setup Guide

## 1. Create Supabase Project

1. Go to https://supabase.com and sign in
2. Click "New Project"
3. Choose organization, name it "viva", set database password
4. Select region closest to your users (e.g., South Asia / Singapore)
5. Wait for project to spin up (~2 minutes)

## 2. Get Credentials

From Project Settings → API:
- Copy `Project URL` → `SUPABASE_URL`
- Copy `anon public` key → `SUPABASE_ANON_KEY`
- Copy `service_role` key → `SUPABASE_SERVICE_ROLE_KEY` (keep secret!)

From Project Settings → Database:
- Copy connection string → `DATABASE_URL`

## 3. Apply Database Migrations

Option A — Supabase SQL Editor (recommended for first setup):
1. Open SQL Editor in Supabase dashboard
2. Paste contents of `supabase/migrations/001_initial_schema.sql`
3. Click Run
4. Repeat for each migration file in order

Option B — Supabase CLI:
```bash
npm install -g supabase
supabase login
supabase link --project-ref your-project-ref
supabase db push
```

## 4. Create Storage Buckets

In Supabase Storage dashboard:

### Profile Photos (public read)
- Name: `profile-photos`
- Public: YES
- File size limit: 10MB
- Allowed MIME types: image/jpeg, image/png, image/webp

### Biodata PDFs (authenticated read)
- Name: `biodata-pdfs`
- Public: NO
- File size limit: 20MB
- Allowed MIME types: application/pdf

### Verification Documents (private — admin only)
- Name: `verification-docs`
- Public: NO
- File size limit: 20MB
- Allowed MIME types: application/pdf, image/jpeg, image/png

## 5. Apply RLS Policies

After creating buckets, apply the RLS policies from:
- `supabase/rls/tables.sql`
- `supabase/rls/storage.sql`

## 6. Enable Realtime (optional for messaging)

In Database → Replication:
- Enable `messages` table for realtime
- Enable `notifications` table for realtime

## 7. Database Backups (Supabase)

**Free tier**: Manual backups only (download from dashboard)
**Pro tier**: Daily automated backups with 7-day retention

### Manual backup via CLI:
```bash
pg_dump "postgresql://postgres:password@db.xxx.supabase.co:5432/postgres" \
  --format=custom \
  --no-acl \
  --no-owner \
  -f backup_$(date +%Y%m%d_%H%M%S).dump
```

Set up a cron job for automated backups:
```bash
# Add to /etc/cron.d/viva-backup
0 2 * * * root /opt/viva/scripts/backup.sh >> /var/log/viva-backup.log 2>&1
```

## 8. Verify Setup

```bash
curl https://your-project.supabase.co/rest/v1/
# Should return API metadata
```

## 9. Project Configuration Checklist

- [ ] Project created
- [ ] Credentials in .env
- [ ] Migrations applied (all tables created)
- [ ] Storage buckets created (3 buckets)
- [ ] RLS policies applied
- [ ] Realtime enabled for messages
- [ ] Backup strategy configured
- [ ] Service role key kept secret
