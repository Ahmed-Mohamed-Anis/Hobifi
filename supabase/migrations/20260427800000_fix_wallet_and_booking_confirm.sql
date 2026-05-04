-- 1. SECURITY DEFINER function so the Flutter client can confirm a booking
--    after Paymob redirects with success=true. Validates the booking belongs
--    to the calling user before making any changes.
CREATE OR REPLACE FUNCTION confirm_booking_payment(p_booking_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_payment RECORD;
  v_activity RECORD;
BEGIN
  -- Verify caller owns this booking
  IF NOT EXISTS (
    SELECT 1 FROM bookings
    WHERE id = p_booking_id AND user_id = auth.uid()
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;

  -- Idempotent: already confirmed is fine
  IF EXISTS (
    SELECT 1 FROM bookings WHERE id = p_booking_id AND status = 'confirmed'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'reason', 'already_confirmed');
  END IF;

  -- Confirm the booking
  UPDATE bookings SET status = 'confirmed' WHERE id = p_booking_id;

  -- Find the associated pending payment
  SELECT p.id, p.activity_id, p.business_earnings
    INTO v_payment
    FROM payments p
   WHERE p.booking_id = p_booking_id AND p.status = 'pending'
   LIMIT 1;

  IF v_payment.id IS NOT NULL AND v_payment.business_earnings > 0 THEN
    UPDATE payments SET status = 'completed' WHERE id = v_payment.id;

    -- Credit business wallet only if no transaction exists yet for this booking
    IF NOT EXISTS (
      SELECT 1 FROM wallet_transactions WHERE reference_id = p_booking_id::text
    ) THEN
      SELECT a.business_id, a.title INTO v_activity
        FROM activities a WHERE a.id = v_payment.activity_id;

      IF v_activity.business_id IS NOT NULL THEN
        PERFORM credit_wallet(
          v_activity.business_id,
          v_payment.business_earnings,
          p_booking_id::text,
          'Earning from booking: ' || v_activity.title
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Back-fill: fix any confirmed/pending bookings from today that were missed.
DO $$
DECLARE
  r RECORD;
  v_activity RECORD;
BEGIN
  FOR r IN
    SELECT p.id, p.booking_id, p.activity_id, p.business_earnings
    FROM payments p
    WHERE p.status = 'pending'
      AND p.business_earnings > 0
      AND p.created_at > NOW() - INTERVAL '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM wallet_transactions wt WHERE wt.reference_id = p.booking_id::text
      )
  LOOP
    SELECT a.business_id, a.title INTO v_activity
    FROM activities a WHERE a.id = r.activity_id;

    IF v_activity.business_id IS NOT NULL THEN
      UPDATE bookings SET status = 'confirmed'
      WHERE id = r.booking_id AND status = 'pending';

      PERFORM credit_wallet(
        v_activity.business_id,
        r.business_earnings,
        r.booking_id::text,
        'Earning from booking: ' || v_activity.title
      );

      UPDATE payments SET status = 'completed' WHERE id = r.id;
    END IF;
  END LOOP;
END $$;
