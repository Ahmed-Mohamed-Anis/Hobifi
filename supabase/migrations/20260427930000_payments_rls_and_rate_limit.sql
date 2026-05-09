-- 1. Let users read their own payments (needed for ticket history, receipts).
DROP POLICY IF EXISTS "payments_select_own" ON payments;
CREATE POLICY "payments_select_own" ON payments
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 2. Rate-limit table: tracks payment init calls per user per minute.
--    The edge function inserts a row here and checks the count before proceeding.
CREATE TABLE IF NOT EXISTS payment_rate_limits (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_prl_user_created ON payment_rate_limits (user_id, created_at);

ALTER TABLE payment_rate_limits ENABLE ROW LEVEL SECURITY;
-- Only the service role (edge functions) can read/write this table.
CREATE POLICY "prl_service_only" ON payment_rate_limits
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Auto-clean entries older than 1 hour so the table doesn't grow unbounded.
CREATE OR REPLACE FUNCTION cleanup_payment_rate_limits()
RETURNS void AS $$
  DELETE FROM payment_rate_limits WHERE created_at < NOW() - INTERVAL '1 hour';
$$ LANGUAGE sql SECURITY DEFINER;
