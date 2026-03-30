-- Add refund tracking to payments
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS refund_status TEXT NOT NULL DEFAULT 'none'
    CHECK (refund_status IN ('none', 'requested', 'processed'));

-- Debit wallet function (reverse of credit_wallet)
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
  -- Lock wallet row
  SELECT balance INTO v_balance
  FROM business_wallets
  WHERE business_id = p_business_id
  FOR UPDATE;

  IF v_balance IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'wallet_not_found');
  END IF;

  IF v_balance < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'insufficient_balance');
  END IF;

  -- Debit the wallet
  UPDATE business_wallets
  SET balance = balance - p_amount,
      total_withdrawn = total_withdrawn + p_amount,
      updated_at = NOW()
  WHERE business_id = p_business_id;

  -- Record the transaction
  INSERT INTO wallet_transactions (business_id, type, amount, reference_id, description)
  VALUES (p_business_id, 'refund_deduction', p_amount, p_booking_id, p_description);

  RETURN jsonb_build_object('ok', true, 'new_balance', v_balance - p_amount);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
