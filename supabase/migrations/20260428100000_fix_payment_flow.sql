-- Add unique constraint on wallet_transactions.reference_id to prevent double-crediting.
-- A partial index covers only non-null values (reference_id is optional for manual entries).
CREATE UNIQUE INDEX IF NOT EXISTS uix_wallet_transactions_reference_id
  ON wallet_transactions (reference_id)
  WHERE reference_id IS NOT NULL;

-- Atomic cancel_pending_booking RPC.
-- Cancels a booking and releases the spot in one transaction, but ONLY if the booking
-- is still pending. Returns TRUE if cancelled, FALSE if already past pending (e.g. confirmed).
-- This prevents the race condition where a user cancels a just-confirmed booking.
CREATE OR REPLACE FUNCTION cancel_pending_booking(
  p_booking_id UUID,
  p_activity_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_cancelled BOOLEAN := FALSE;
BEGIN
  WITH cancelled AS (
    UPDATE bookings
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_booking_id AND status = 'pending'
    RETURNING id
  )
  SELECT COUNT(*) > 0 INTO v_cancelled FROM cancelled;

  IF v_cancelled THEN
    PERFORM release_spot(p_activity_id);
  END IF;

  RETURN v_cancelled;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION cancel_pending_booking(UUID, UUID) TO authenticated;
