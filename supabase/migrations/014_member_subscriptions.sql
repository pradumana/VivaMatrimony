-- =============================================================================
-- Migration 014: Member Subscriptions
-- Records manual payment entries made by admins.
-- Amount: 300–800 INR. Valid for 6 months from paid_at.
-- =============================================================================

CREATE TABLE member_subscriptions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Payment details
  amount          INTEGER NOT NULL,  -- INR, 300–800
  paid_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL
                    GENERATED ALWAYS AS (paid_at + INTERVAL '6 months') STORED,

  -- Recorded by which admin
  recorded_by     UUID NOT NULL REFERENCES admin_users(id),

  notes           TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT subscription_amount_range CHECK (amount BETWEEN 300 AND 800)
);

CREATE INDEX idx_subscriptions_user_id  ON member_subscriptions (user_id);
CREATE INDEX idx_subscriptions_paid_at  ON member_subscriptions (paid_at DESC);
CREATE INDEX idx_subscriptions_expires  ON member_subscriptions (expires_at);
