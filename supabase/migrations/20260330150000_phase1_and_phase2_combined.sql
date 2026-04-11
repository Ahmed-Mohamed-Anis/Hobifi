-- ═══════════════════════════════════════════════════════════
-- COMPREHENSIVE MIGRATION: All pending schema changes
-- Every statement is idempotent — safe to re-run
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════
-- PREREQUISITE: Missing columns on users and activities
-- (added via dashboard, no migration existed)
-- ═══════════════════════════════════════════════════════════

-- Users table: bio, interests, city
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'bio') THEN
    ALTER TABLE users ADD COLUMN bio TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'interests') THEN
    ALTER TABLE users ADD COLUMN interests TEXT[] NOT NULL DEFAULT ARRAY[]::text[];
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'city') THEN
    ALTER TABLE users ADD COLUMN city TEXT;
  END IF;
END $$;

-- Activities table: gallery_images
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'activities' AND column_name = 'gallery_images') THEN
    ALTER TABLE activities ADD COLUMN gallery_images TEXT[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════
-- PREREQUISITE: Wallet tables + review comment + triggers
-- (from lib/supabase/migrations 20260326-20260329)
-- ═══════════════════════════════════════════════════════════

-- Wallet tables
CREATE TABLE IF NOT EXISTS business_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_earned DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_withdrawn DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_business_wallets_business_id ON business_wallets(business_id);

DROP TRIGGER IF EXISTS update_business_wallets_updated_at ON business_wallets;
CREATE TRIGGER update_business_wallets_updated_at
  BEFORE UPDATE ON business_wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE business_wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_select_own" ON business_wallets;
CREATE POLICY "wallet_select_own" ON business_wallets
  FOR SELECT USING (auth.uid() = business_id);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('earning', 'payout', 'refund_deduction')),
  amount DECIMAL(12,2) NOT NULL,
  reference_id TEXT,
  description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_business_id ON wallet_transactions(business_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_tx_select_own" ON wallet_transactions;
CREATE POLICY "wallet_tx_select_own" ON wallet_transactions
  FOR SELECT USING (auth.uid() = business_id);

CREATE TABLE IF NOT EXISTS payout_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
  bank_name TEXT NOT NULL DEFAULT '',
  account_number TEXT NOT NULL DEFAULT '',
  account_holder_name TEXT NOT NULL DEFAULT '',
  admin_note TEXT DEFAULT '',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payout_requests_business_id ON payout_requests(business_id);
CREATE INDEX IF NOT EXISTS idx_payout_requests_status ON payout_requests(status);

DROP TRIGGER IF EXISTS update_payout_requests_updated_at ON payout_requests;
CREATE TRIGGER update_payout_requests_updated_at
  BEFORE UPDATE ON payout_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payout_select_own" ON payout_requests;
CREATE POLICY "payout_select_own" ON payout_requests
  FOR SELECT USING (auth.uid() = business_id);

DROP POLICY IF EXISTS "payout_insert_own" ON payout_requests;
CREATE POLICY "payout_insert_own" ON payout_requests
  FOR INSERT WITH CHECK (auth.uid() = business_id);

-- Add comment column to ratings
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS comment TEXT DEFAULT NULL;
CREATE INDEX IF NOT EXISTS idx_ratings_activity_comment ON ratings (activity_id) WHERE comment IS NOT NULL;

-- Rating sync trigger
CREATE OR REPLACE FUNCTION sync_activity_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_id UUID;
BEGIN
  v_activity_id := COALESCE(NEW.activity_id, OLD.activity_id);
  UPDATE activities
  SET
    rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 1) FROM ratings WHERE activity_id = v_activity_id),
      0.0
    ),
    review_count = (
      SELECT COUNT(*) FROM ratings WHERE activity_id = v_activity_id
    ),
    updated_at = NOW()
  WHERE id = v_activity_id;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_activity_rating ON ratings;
CREATE TRIGGER trg_sync_activity_rating
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION sync_activity_rating();

-- Atomic spot reservation functions
CREATE OR REPLACE FUNCTION reserve_spot(p_activity_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
BEGIN
  SELECT spots_left INTO v_spots
  FROM activities WHERE id = p_activity_id FOR UPDATE;
  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;
  IF v_spots <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_spots');
  END IF;
  UPDATE activities SET spots_left = spots_left - 1, updated_at = NOW() WHERE id = p_activity_id;
  RETURN jsonb_build_object('ok', true, 'remaining', v_spots - 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION release_spot(p_activity_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
  v_max INTEGER;
BEGIN
  SELECT spots_left, max_guests INTO v_spots, v_max
  FROM activities WHERE id = p_activity_id FOR UPDATE;
  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;
  IF v_spots >= v_max THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_full');
  END IF;
  UPDATE activities SET spots_left = spots_left + 1, updated_at = NOW() WHERE id = p_activity_id;
  RETURN jsonb_build_object('ok', true, 'remaining', v_spots + 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix RLS on financial tables (service_role only)
DROP POLICY IF EXISTS "wallet_insert_service" ON business_wallets;
CREATE POLICY "wallet_insert_service" ON business_wallets
  FOR INSERT TO service_role WITH CHECK (true);

DROP POLICY IF EXISTS "wallet_update_service" ON business_wallets;
CREATE POLICY "wallet_update_service" ON business_wallets
  FOR UPDATE TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "wallet_tx_insert_service" ON wallet_transactions;
CREATE POLICY "wallet_tx_insert_service" ON wallet_transactions
  FOR INSERT TO service_role WITH CHECK (true);

DROP POLICY IF EXISTS "payments_update_service" ON payments;
CREATE POLICY "payments_update_service" ON payments
  FOR UPDATE TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "payout_update_service" ON payout_requests;
CREATE POLICY "payout_update_service" ON payout_requests
  FOR UPDATE TO service_role USING (true) WITH CHECK (true);

-- Atomic wallet credit
CREATE OR REPLACE FUNCTION credit_wallet(
  p_business_id UUID,
  p_amount DECIMAL(12,2),
  p_booking_id TEXT,
  p_description TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_wallet_id UUID;
  v_new_balance DECIMAL(12,2);
BEGIN
  UPDATE business_wallets
  SET balance = balance + p_amount,
      total_earned = total_earned + p_amount,
      updated_at = NOW()
  WHERE business_id = p_business_id
  RETURNING id, balance INTO v_wallet_id, v_new_balance;

  IF v_wallet_id IS NULL THEN
    INSERT INTO business_wallets (business_id, balance, total_earned, total_withdrawn)
    VALUES (p_business_id, p_amount, p_amount, 0)
    ON CONFLICT (business_id) DO UPDATE
      SET balance = business_wallets.balance + p_amount,
          total_earned = business_wallets.total_earned + p_amount,
          updated_at = NOW()
    RETURNING id, balance INTO v_wallet_id, v_new_balance;
  END IF;

  INSERT INTO wallet_transactions (business_id, type, amount, reference_id, description)
  VALUES (p_business_id, 'earning', p_amount, p_booking_id, p_description);

  RETURN jsonb_build_object('ok', true, 'new_balance', v_new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════
-- PHASE 1: CRITICAL BUGS + PAYMENT FLOW
-- ═══════════════════════════════════════════════════════════

-- Booking expiry column
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_expires_at TIMESTAMPTZ;

UPDATE bookings
SET payment_expires_at = created_at + INTERVAL '15 minutes'
WHERE status = 'pending' AND payment_expires_at IS NULL;

DO $$ BEGIN
  ALTER TABLE activities ADD CONSTRAINT chk_spots_left_non_negative CHECK (spots_left >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Cleanup expired bookings
CREATE OR REPLACE FUNCTION cleanup_expired_bookings()
RETURNS JSONB AS $$
DECLARE
  v_booking RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_booking IN
    SELECT id, activity_id
    FROM bookings
    WHERE status = 'pending'
      AND payment_expires_at IS NOT NULL
      AND payment_expires_at < NOW()
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE bookings SET status = 'cancelled' WHERE id = v_booking.id;
    PERFORM release_spot(v_booking.activity_id);
    UPDATE payments SET status = 'failed'
    WHERE booking_id = v_booking.id AND status IN ('pending', 'processing');
    v_count := v_count + 1;
  END LOOP;
  RETURN jsonb_build_object('cleaned_up', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atomic booking creation
CREATE OR REPLACE FUNCTION create_booking_with_reservation(
  p_user_id UUID,
  p_activity_id UUID,
  p_activity_title TEXT,
  p_activity_image TEXT,
  p_location TEXT,
  p_price NUMERIC(10,2),
  p_date_time TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
  v_booking_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  SELECT spots_left INTO v_spots
  FROM activities WHERE id = p_activity_id FOR UPDATE;

  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;
  IF v_spots <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_spots');
  END IF;

  UPDATE activities SET spots_left = spots_left - 1, updated_at = NOW() WHERE id = p_activity_id;

  v_booking_id := gen_random_uuid();
  v_expires_at := NOW() + INTERVAL '15 minutes';

  INSERT INTO bookings (id, user_id, activity_id, activity_title, activity_image, location, price, date_time, status, payment_expires_at)
  VALUES (v_booking_id, p_user_id, p_activity_id, p_activity_title, p_activity_image, p_location, p_price, p_date_time, 'pending', v_expires_at);

  RETURN jsonb_build_object('ok', true, 'booking_id', v_booking_id, 'expires_at', v_expires_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Unique pending payment index
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_booking_active
  ON payments (booking_id)
  WHERE status IN ('pending', 'processing');

-- Refund support
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_status TEXT NOT NULL DEFAULT 'none';

DO $$ BEGIN
  ALTER TABLE payments ADD CONSTRAINT payments_refund_status_check CHECK (refund_status IN ('none', 'requested', 'processed'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Debit wallet (for refunds)
CREATE OR REPLACE FUNCTION debit_wallet(
  p_business_id UUID,
  p_amount DECIMAL(12,2),
  p_booking_id TEXT,
  p_description TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_balance DECIMAL(12,2);
BEGIN
  SELECT balance INTO v_balance
  FROM business_wallets WHERE business_id = p_business_id FOR UPDATE;

  IF v_balance IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'wallet_not_found');
  END IF;
  IF v_balance < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'insufficient_balance');
  END IF;

  UPDATE business_wallets
  SET balance = balance - p_amount,
      total_withdrawn = total_withdrawn + p_amount,
      updated_at = NOW()
  WHERE business_id = p_business_id;

  INSERT INTO wallet_transactions (business_id, type, amount, reference_id, description)
  VALUES (p_business_id, 'refund_deduction', p_amount, p_booking_id, p_description);

  RETURN jsonb_build_object('ok', true, 'new_balance', v_balance - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix users INSERT/UPDATE RLS
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ═══════════════════════════════════════════════════════════
-- PHASE 2: SECURITY HARDENING
-- ═══════════════════════════════════════════════════════════

-- Ratings RLS + booking verification gate
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view all ratings" ON ratings;
CREATE POLICY "Authenticated users can view all ratings"
  ON ratings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can rate activities they completed" ON ratings;
CREATE POLICY "Users can rate activities they completed"
  ON ratings FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.user_id = auth.uid()
        AND bookings.activity_id = ratings.activity_id
        AND bookings.status = 'completed'
    )
  );

DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
CREATE POLICY "Users can update their own ratings"
  ON ratings FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;
CREATE POLICY "Users can delete their own ratings"
  ON ratings FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DO $$ BEGIN
  ALTER TABLE ratings ADD CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE ratings ADD CONSTRAINT chk_comment_length CHECK (comment IS NULL OR length(comment) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Input validation constraints
DO $$ BEGIN
  ALTER TABLE activities ADD CONSTRAINT chk_activity_title_length CHECK (length(title) BETWEEN 3 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE activities ADD CONSTRAINT chk_activity_description_length CHECK (description IS NULL OR length(description) <= 2000);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT chk_user_bio_length CHECK (bio IS NULL OR length(bio) <= 200);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE users ADD CONSTRAINT chk_user_name_length CHECK (length(name) BETWEEN 1 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
