-- Fix overly permissive RLS policies on financial tables.
-- These were using WITH CHECK (true) which allowed ANY authenticated user
-- to write to wallets, payments, and payouts. Restrict to service_role only.

-- ============================================================
-- 1. business_wallets — only service_role can insert/update
-- ============================================================
DROP POLICY IF EXISTS "wallet_insert_service" ON business_wallets;
DROP POLICY IF EXISTS "wallet_update_service" ON business_wallets;

CREATE POLICY "wallet_insert_service" ON business_wallets
  FOR INSERT TO service_role
  WITH CHECK (true);

CREATE POLICY "wallet_update_service" ON business_wallets
  FOR UPDATE TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================
-- 2. wallet_transactions — only service_role can insert
-- ============================================================
DROP POLICY IF EXISTS "wallet_tx_insert_service" ON wallet_transactions;

CREATE POLICY "wallet_tx_insert_service" ON wallet_transactions
  FOR INSERT TO service_role
  WITH CHECK (true);

-- ============================================================
-- 3. payments — only service_role can update status
-- ============================================================
DROP POLICY IF EXISTS "payments_update_service" ON payments;

CREATE POLICY "payments_update_service" ON payments
  FOR UPDATE TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================
-- 4. payout_requests — only service_role can update status
--    (business can still INSERT their own via payout_insert_own)
-- ============================================================
DROP POLICY IF EXISTS "payout_update_service" ON payout_requests;

CREATE POLICY "payout_update_service" ON payout_requests
  FOR UPDATE TO service_role
  USING (true) WITH CHECK (true);
