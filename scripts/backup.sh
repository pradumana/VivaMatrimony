#!/usr/bin/env bash
# =============================================================================
# VIVA — Automated PostgreSQL Backup Script
# Run daily via cron: 0 2 * * * /opt/viva/scripts/backup.sh
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/opt/viva/backups}"
RETAIN_DAYS="${RETAIN_DAYS:-30}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/viva_${DATE}.dump"
LOG_FILE="$BACKUP_DIR/backup.log"

# Load DATABASE_URL from .env if not already set
if [ -z "${DATABASE_URL:-}" ] && [ -f /opt/viva/.env ]; then
  export $(grep -E "^DATABASE_URL=" /opt/viva/.env | xargs)
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "[$(date)] ERROR: DATABASE_URL not set" | tee -a "$LOG_FILE"
  exit 1
fi

# ── Run backup ────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup → $BACKUP_FILE" | tee -a "$LOG_FILE"

pg_dump "$DATABASE_URL" \
  --format=custom \
  --no-acl \
  --no-owner \
  --compress=9 \
  -f "$BACKUP_FILE"

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup complete. Size: $SIZE" | tee -a "$LOG_FILE"

# ── Retain only RETAIN_DAYS days of backups ───────────────────────────────────
find "$BACKUP_DIR" -name "viva_*.dump" -mtime +"$RETAIN_DAYS" -delete
COUNT=$(ls "$BACKUP_DIR"/viva_*.dump 2>/dev/null | wc -l)
echo "[$(date)] Cleanup done. $COUNT backups retained (last $RETAIN_DAYS days)." | tee -a "$LOG_FILE"

# ── Verify backup integrity ───────────────────────────────────────────────────
pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1 && \
  echo "[$(date)] Integrity check PASSED." | tee -a "$LOG_FILE" || \
  echo "[$(date)] WARNING: Integrity check FAILED for $BACKUP_FILE" | tee -a "$LOG_FILE"

echo "[$(date)] Done." | tee -a "$LOG_FILE"
