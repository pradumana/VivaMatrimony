# Viva — Backup & Recovery Strategy

## Backup Components

| Component | Method | Frequency | Retention |
|-----------|--------|-----------|-----------|
| PostgreSQL (Supabase) | pg_dump | Daily (2 AM) | 30 days |
| Supabase Storage | Supabase dashboard / CLI | Weekly | 4 weeks |
| Application config | Git | On change | Forever |
| .env secrets | Manual (encrypted) | On change | Forever |

## Automated Database Backup Script

Located at `scripts/backup.sh`:

```bash
#!/bin/bash
set -e

BACKUP_DIR=/opt/viva/backups
DATE=$(date +%Y%m%d_%H%M%S)
DB_URL="$DATABASE_URL"
S3_BUCKET=""  # Optional: set for offsite backup

mkdir -p "$BACKUP_DIR"

# Dump
pg_dump "$DB_URL" \
  --format=custom \
  --no-acl \
  --no-owner \
  -f "$BACKUP_DIR/viva_$DATE.dump"

echo "Backup created: viva_$DATE.dump"

# Retain last 30 files only
ls -t "$BACKUP_DIR"/*.dump | tail -n +31 | xargs -r rm

echo "Cleanup done. $(ls $BACKUP_DIR/*.dump | wc -l) backups retained."
```

## Restore Procedure

```bash
# 1. Download or locate backup
ls /opt/viva/backups/

# 2. Restore to database
pg_restore \
  --no-acl \
  --no-owner \
  -d "$DATABASE_URL" \
  /opt/viva/backups/viva_20240101_020000.dump

# 3. Verify critical tables
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM profiles;"
```

## Periodic Restore Test

Every 30 days, verify backup integrity:

```bash
# Create test database
createdb viva_restore_test

# Restore backup
pg_restore \
  --no-acl \
  --no-owner \
  -d viva_restore_test \
  /opt/viva/backups/latest.dump

# Check row counts match production
# Document result and drop test database
dropdb viva_restore_test
```

## Supabase Pro Backup (Recommended at Scale)

When upgrading to Supabase Pro:
- Automated daily backups (7-day retention)
- Point-in-time recovery available
- One-click restore from dashboard

## Recovery Time Objective (RTO)

| Scenario | RTO |
|----------|-----|
| Application crash | < 5 minutes (Docker restart) |
| Data corruption (small) | < 30 minutes |
| Full database restore | < 2 hours |
| Full server loss | < 4 hours |

## Recovery Point Objective (RPO)

| Tier | RPO |
|------|-----|
| Free (manual backup) | Up to 24 hours data loss |
| Pro (automated daily) | Up to 24 hours |
| Pro (PITR enabled) | Near-zero |

## Storage Backup

Supabase Storage files (profile photos, certificates) are stored in Supabase-managed S3-compatible storage. Supabase handles redundancy internally.

For additional protection at scale, periodically export storage metadata and sync important buckets to a secondary location.

## Incident Response

1. Identify scope of data loss
2. Notify affected users if personal data involved (per privacy policy)
3. Restore from most recent clean backup
4. Replay transactions if audit_logs available
5. Verify data integrity post-restore
6. Document incident and improve backup frequency if needed
