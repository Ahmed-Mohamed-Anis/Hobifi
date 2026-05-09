-- Find the "bus test" business and forcefully credit any confirmed booking
-- where no wallet transaction exists yet.
DO $$
DECLARE
  v_business_id UUID;
  v_booking RECORD;
  v_activity RECORD;
  v_count INT := 0;
BEGIN
  -- Find business by name
  SELECT id INTO v_business_id FROM users
  WHERE LOWER(name) LIKE '%bus%test%' OR LOWER(name) LIKE '%bustest%'
  LIMIT 1;

  IF v_business_id IS NULL THEN
    RAISE NOTICE 'Business "bus test" not found — trying any business user';
    SELECT id INTO v_business_id FROM users WHERE role = 'business' LIMIT 1;
  END IF;

  RAISE NOTICE 'Business ID: %', v_business_id;

  -- Check existing wallet
  RAISE NOTICE 'Wallet row: %', (
    SELECT row_to_json(bw) FROM business_wallets bw WHERE business_id = v_business_id
  );

  -- Check payments via activities
  FOR v_booking IN
    SELECT p.id AS payment_id, p.booking_id, p.business_earnings, p.status AS payment_status,
           b.status AS booking_status, a.title
    FROM activities a
    JOIN bookings b ON b.activity_id = a.id
    LEFT JOIN payments p ON p.booking_id = b.id
    WHERE a.business_id = v_business_id
      AND b.created_at > NOW() - INTERVAL '7 days'
  LOOP
    RAISE NOTICE 'Booking: %, Payment status: %, Booking status: %, Earnings: %, Activity: %',
      v_booking.booking_id, v_booking.payment_status, v_booking.booking_status,
      v_booking.business_earnings, v_booking.title;

    -- Credit if payment exists with earnings and no wallet tx yet
    IF v_booking.payment_id IS NOT NULL
       AND v_booking.business_earnings > 0
       AND NOT EXISTS (
         SELECT 1 FROM wallet_transactions wt WHERE wt.reference_id = v_booking.booking_id::text
       )
    THEN
      UPDATE bookings SET status = 'confirmed' WHERE id = v_booking.booking_id;
      UPDATE payments SET status = 'completed' WHERE id = v_booking.payment_id;

      SELECT a2.business_id, a2.title INTO v_activity
      FROM activities a2
      JOIN bookings b2 ON b2.activity_id = a2.id
      WHERE b2.id = v_booking.booking_id LIMIT 1;

      PERFORM credit_wallet(
        v_activity.business_id,
        v_booking.business_earnings,
        v_booking.booking_id::text,
        'Earning from booking: ' || v_booking.title
      );
      v_count := v_count + 1;
      RAISE NOTICE 'Credited wallet: %', v_booking.business_earnings;
    END IF;
  END LOOP;

  RAISE NOTICE 'Total credited: % bookings', v_count;

  -- Final wallet state
  RAISE NOTICE 'Final wallet: %', (
    SELECT row_to_json(bw) FROM business_wallets bw WHERE business_id = v_business_id
  );
END $$;
