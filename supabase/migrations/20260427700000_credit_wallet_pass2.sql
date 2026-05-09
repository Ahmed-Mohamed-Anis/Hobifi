-- Second pass: credit wallet for confirmed bookings whose payment is still pending.
-- Same logic as pass 1 — safe to run, skips if wallet_transaction already exists.
DO $$
DECLARE
  r RECORD;
  v_activity RECORD;
BEGIN
  FOR r IN
    SELECT p.id, p.booking_id, p.activity_id, p.business_earnings
    FROM payments p
    JOIN bookings b ON b.id = p.booking_id
    WHERE b.status IN ('confirmed', 'completed')
      AND p.status = 'pending'
      AND p.business_earnings > 0
      AND NOT EXISTS (
        SELECT 1 FROM wallet_transactions wt WHERE wt.reference_id = p.booking_id::text
      )
  LOOP
    SELECT a.business_id, a.title INTO v_activity
    FROM activities a WHERE a.id = r.activity_id;

    IF v_activity.business_id IS NOT NULL THEN
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
