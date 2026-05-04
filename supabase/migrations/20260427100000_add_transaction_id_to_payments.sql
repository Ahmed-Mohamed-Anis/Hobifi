-- Add missing transaction_id column to payments table (stores Paymob order ID).
-- Without this column the early-save upsert in paymob-init silently failed,
-- causing every retry to hit Paymob's duplicate merchant_order_id error.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS transaction_id TEXT;

-- Clean up stale pending records with no order ID — they can never complete.
DELETE FROM payments
WHERE transaction_id IS NULL
  AND status IN ('pending', 'processing', 'failed');
