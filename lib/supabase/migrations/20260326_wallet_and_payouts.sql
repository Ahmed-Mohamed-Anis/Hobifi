-- Migration: Business wallets, wallet transactions, and payout requests
-- This powers the payment flow: user pays → platform holds → business requests payout

-- ============================================================
-- 1. Business Wallets — one per business, tracks current balance
-- ============================================================
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

-- Auto-update updated_at
CREATE TRIGGER update_business_wallets_updated_at
  BEFORE UPDATE ON business_wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE business_wallets ENABLE ROW LEVEL SECURITY;

-- Business can view their own wallet
CREATE POLICY "wallet_select_own" ON business_wallets
  FOR SELECT USING (auth.uid() = business_id);

-- Service role can insert/update (webhook credits the wallet)
CREATE POLICY "wallet_insert_service" ON business_wallets
  FOR INSERT WITH CHECK (true);

CREATE POLICY "wallet_update_service" ON business_wallets
  FOR UPDATE USING (true) WITH CHECK (true);


-- ============================================================
-- 2. Wallet Transactions — ledger of every money movement
-- ============================================================
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('earning', 'payout', 'refund_deduction')),
  amount DECIMAL(12,2) NOT NULL,
  reference_id TEXT,  -- booking_id for earnings, payout_request_id for payouts
  description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_business_id ON wallet_transactions(business_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

-- RLS
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Business can view their own transactions
CREATE POLICY "wallet_tx_select_own" ON wallet_transactions
  FOR SELECT USING (auth.uid() = business_id);

-- Service role can insert (webhook creates transactions)
CREATE POLICY "wallet_tx_insert_service" ON wallet_transactions
  FOR INSERT WITH CHECK (true);


-- ============================================================
-- 3. Payout Requests — business requests withdrawal
-- ============================================================
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

-- Auto-update updated_at
CREATE TRIGGER update_payout_requests_updated_at
  BEFORE UPDATE ON payout_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE payout_requests ENABLE ROW LEVEL SECURITY;

-- Business can view their own payout requests
CREATE POLICY "payout_select_own" ON payout_requests
  FOR SELECT USING (auth.uid() = business_id);

-- Business can create payout requests
CREATE POLICY "payout_insert_own" ON payout_requests
  FOR INSERT WITH CHECK (auth.uid() = business_id);

-- Service role / admin can update payout status
CREATE POLICY "payout_update_service" ON payout_requests
  FOR UPDATE USING (true) WITH CHECK (true);
