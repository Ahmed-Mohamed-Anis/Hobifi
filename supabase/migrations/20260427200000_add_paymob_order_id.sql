-- Add dedicated column for the stable Paymob order ID.
-- transaction_id was dual-purpose (order ID + payment event ID); split concerns:
--   paymob_order_id = stable Paymob order ID (set at init, never overwritten)
--   transaction_id  = Paymob payment event ID (set by webhook on completion)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS paymob_order_id TEXT;
CREATE INDEX IF NOT EXISTS idx_payments_paymob_order_id ON payments (paymob_order_id) WHERE paymob_order_id IS NOT NULL;
