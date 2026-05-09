-- The upsert onConflict:"booking_id" was silently failing because there was no
-- full UNIQUE constraint on booking_id — only a partial index. This caused every
-- payment record creation to fail, leaving the payments table empty.

-- 1. Add the full unique constraint so upserts work going forward.
ALTER TABLE payments ADD CONSTRAINT payments_booking_id_unique UNIQUE (booking_id);

-- 2. Create payment records for confirmed bookings that have none, then credit wallet.
DO $$
DECLARE
  r RECORD;
  v_payment_id UUID;
  v_earnings DECIMAL(12,2);
  v_fee DECIMAL(12,2);
BEGIN
  FOR r IN
    SELECT b.id AS booking_id, b.activity_id, b.user_id, b.price,
           a.business_id, a.title
    FROM bookings b
    JOIN activities a ON a.id = b.activity_id
    WHERE b.status IN ('confirmed', 'completed')
      AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.booking_id = b.id)
  LOOP
    v_fee     := ROUND(r.price * 0.10, 2);
    v_earnings := ROUND(r.price * 0.90, 2);
    v_payment_id := gen_random_uuid();

    INSERT INTO payments (id, booking_id, user_id, activity_id, amount,
                          platform_fee, business_earnings, status, payment_method)
    VALUES (v_payment_id, r.booking_id, r.user_id, r.activity_id, r.price,
            v_fee, v_earnings, 'completed', 'card');

    -- Credit wallet if not already credited
    IF NOT EXISTS (
      SELECT 1 FROM wallet_transactions WHERE reference_id = r.booking_id::text
    ) THEN
      PERFORM credit_wallet(
        r.business_id,
        v_earnings,
        r.booking_id::text,
        'Earning from booking: ' || r.title
      );
      RAISE NOTICE 'Credited % EGP for booking % (%)', v_earnings, r.booking_id, r.title;
    END IF;
  END LOOP;
END $$;
