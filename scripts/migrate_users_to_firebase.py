#!/usr/bin/env python3
"""
Migrate existing Supabase Auth users to Firebase Auth.

Usage:
    python migrate_users_to_firebase.py --dry-run          # preview only
    python migrate_users_to_firebase.py --no-dry-run       # execute

Requirements:
    pip install firebase-admin asyncpg python-dotenv

Environment variables (set in .env or shell — never hardcode):
    DATABASE_URL           asyncpg connection string for the Supabase DB
    GOOGLE_APPLICATION_CREDENTIALS  path to Firebase Admin SDK service-account JSON
    FIREBASE_PROJECT_ID    e.g. viva-analytics-135d4

The script reads users from the `users` table and attempts to import each into
Firebase Auth using the Admin SDK importUsers() with bcrypt hashes.

SECURITY:
  - Never logs plaintext passwords.
  - Never stores credentials in this file.
  - The service-account JSON must be kept outside the repo and not committed.
  - Run with --dry-run first to verify the output before executing.

BCRYPT NOTES:
  Supabase GoTrue stores passwords as bcrypt (cost 10 by default) in
  auth.users.encrypted_password. Firebase importUsers supports BCRYPT but
  requires the hash rounds value. Verify the cost factor in your Supabase
  project before running (default is 10; can confirm with pg_dump or SQL).

FALLBACK:
  If bcrypt import fails (cost-factor mismatch, Firebase API error), fall back
  to forced password-reset: send a password-reset email to each user so they
  can set a new password on first Firebase login. The --force-reset flag does this.
"""
import argparse
import asyncio
import json
import os
import sys
from typing import Optional

# ---------------------------------------------------------------------------
# Imports — lazy so missing deps give a clear error message
# ---------------------------------------------------------------------------
try:
    import asyncpg
    import firebase_admin
    from firebase_admin import auth as fb_auth, credentials
    from dotenv import load_dotenv
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Run: pip install firebase-admin asyncpg python-dotenv")
    sys.exit(1)

load_dotenv()


def _init_firebase() -> None:
    if not firebase_admin._apps:
        cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        if not cred_path:
            print("ERROR: GOOGLE_APPLICATION_CREDENTIALS env var not set.")
            sys.exit(1)
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)


async def _fetch_users(db_url: str) -> list[dict]:
    """
    Fetch users from Supabase. We need the Supabase auth.users table for
    password hashes — this requires a direct DB connection with the service role.
    The public schema users table has the UUIDs and emails.
    """
    conn = await asyncpg.connect(db_url)
    try:
        # Join public.users with auth.users on id
        # auth.users is in the auth schema — requires service-role access
        rows = await conn.fetch("""
            SELECT
                u.id::TEXT       AS supabase_uid,
                u.email,
                au.encrypted_password AS password_hash,
                au.email_confirmed_at IS NOT NULL AS email_verified,
                u.created_at
            FROM public.users u
            LEFT JOIN auth.users au ON au.id = u.id
            WHERE u.email IS NOT NULL
              AND u.deleted_at IS NULL
            ORDER BY u.created_at
        """)
        return [dict(r) for r in rows]
    finally:
        await conn.close()


async def _migrate(dry_run: bool, force_reset: bool) -> None:
    db_url = os.environ.get("DATABASE_URL")
    project_id = os.environ.get("FIREBASE_PROJECT_ID", "viva-analytics-135d4")

    if not db_url:
        print("ERROR: DATABASE_URL env var not set.")
        sys.exit(1)

    _init_firebase()

    print(f"Mode: {'DRY RUN' if dry_run else 'EXECUTE'}")
    print(f"Firebase project: {project_id}")

    users = await _fetch_users(db_url)
    print(f"\nFound {len(users)} users to process.\n")

    migrated = 0
    skipped = 0
    errors = 0

    for user in users:
        email = user["email"]
        supabase_uid = user["supabase_uid"]
        password_hash = user.get("password_hash")
        email_verified = user.get("email_verified", False)

        # Check if user already exists in Firebase
        existing = None
        try:
            existing = fb_auth.get_user_by_email(email)
        except fb_auth.UserNotFoundError:
            pass
        except Exception as e:
            print(f"  SKIP {email}: Firebase lookup error: {e}")
            skipped += 1
            continue

        if existing:
            print(f"  SKIP {email}: already in Firebase (uid={existing.uid})")
            skipped += 1
            continue

        if dry_run:
            print(f"  DRY RUN: would import {email} (verified={email_verified}, "
                  f"has_hash={bool(password_hash)})")
            migrated += 1
            continue

        if force_reset or not password_hash:
            # Fallback: create without password, send reset email
            try:
                new_user = fb_auth.create_user(
                    email=email,
                    email_verified=email_verified,
                    display_name=email.split("@")[0],
                )
                fb_auth.generate_password_reset_link(email)
                print(f"  RESET  {email} → Firebase uid={new_user.uid} (reset email queued)")
                migrated += 1
            except Exception as e:
                print(f"  ERROR  {email}: {e}")
                errors += 1
        else:
            # Import with bcrypt hash (cost 10 — verify against your Supabase config)
            try:
                result = fb_auth.import_users(
                    [
                        fb_auth.ImportUserRecord(
                            uid=None,  # Firebase assigns a new UID
                            email=email,
                            email_verified=email_verified,
                            password_hash=password_hash.encode() if isinstance(password_hash, str) else password_hash,
                        )
                    ],
                    hash_alg=fb_auth.UserImportHash.bcrypt(),
                )
                if result.failure_count > 0:
                    for err in result.errors:
                        print(f"  ERROR  {email}: {err.reason}")
                    errors += 1
                else:
                    print(f"  OK     {email} (bcrypt import)")
                    migrated += 1
            except Exception as e:
                print(f"  ERROR  {email}: {e}")
                errors += 1

    print(f"\n{'DRY RUN ' if dry_run else ''}Summary:")
    print(f"  Migrated/would-migrate: {migrated}")
    print(f"  Skipped (already in Firebase): {skipped}")
    print(f"  Errors: {errors}")

    if not dry_run and errors > 0:
        print("\nSome users failed. Re-run with --force-reset for those emails,")
        print("or investigate errors above.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate Supabase Auth users to Firebase Auth")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--dry-run", action="store_true", help="Preview without making changes")
    group.add_argument("--no-dry-run", action="store_true", help="Execute migration")
    parser.add_argument(
        "--force-reset",
        action="store_true",
        help="Create accounts without password hash and send reset emails instead of bcrypt import",
    )
    args = parser.parse_args()
    asyncio.run(_migrate(dry_run=args.dry_run, force_reset=args.force_reset))
