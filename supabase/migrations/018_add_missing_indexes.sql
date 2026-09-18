-- Migration 018: add missing indexes identified in audit
-- These were missing and causing full-table scans on hot paths.

-- interests(sender_id, created_at DESC) — used by daily rate-limit COUNT on every send_interest
CREATE INDEX IF NOT EXISTS idx_interests_sender_created_at
    ON interests (sender_id, created_at DESC);

-- member_subscriptions(user_id, paid_at) — used by 60-second idempotency check
CREATE INDEX IF NOT EXISTS idx_member_subscriptions_user_paid_at
    ON member_subscriptions (user_id, paid_at DESC);

-- notifications(user_id, created_at DESC) — used by unread count and list queries
-- The existing idx_notifications_user covers (user_id, is_read, created_at DESC);
-- add a covering index for the common "all notifications newest first" path.
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at
    ON notifications (user_id, created_at DESC);
