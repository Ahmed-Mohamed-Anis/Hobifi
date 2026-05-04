-- Add missing transaction_id column to payments table (stores Paymob order ID).
-- Without this column the early-save upsert silently failed, causing every retry
-- to hit Paymob's duplicate merchant_order_id error.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS transaction_id TEXT;

-- Clean up stale pending records that have no order ID — they can never be retried.
DELETE FROM payments
WHERE transaction_id IS NULL
  AND status IN ('pending', 'processing', 'failed');
