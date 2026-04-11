-- Atomic wallet credit function.
-- Uses row-level locking to prevent race conditions when two concurrent
-- webhooks credit the same business wallet simultaneously.

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
  -- Try to lock and update existing wallet
  UPDATE business_wallets
  SET balance = balance + p_amount,
      total_earned = total_earned + p_amount,
      updated_at = NOW()
  WHERE business_id = p_business_id
  RETURNING id, balance INTO v_wallet_id, v_new_balance;

  -- If no wallet exists, create one
  IF v_wallet_id IS NULL THEN
    INSERT INTO business_wallets (business_id, balance, total_earned, total_withdrawn)
    VALUES (p_business_id, p_amount, p_amount, 0)
    ON CONFLICT (business_id) DO UPDATE
      SET balance = business_wallets.balance + p_amount,
          total_earned = business_wallets.total_earned + p_amount,
          updated_at = NOW()
    RETURNING id, balance INTO v_wallet_id, v_new_balance;
  END IF;

  -- Record the transaction in the ledger
  INSERT INTO wallet_transactions (business_id, type, amount, reference_id, description)
  VALUES (p_business_id, 'earning', p_amount, p_booking_id, p_description);

  RETURN jsonb_build_object('ok', true, 'new_balance', v_new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
