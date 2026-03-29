-- Add payment expiry column to bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS payment_expires_at TIMESTAMPTZ;

-- Backfill: set expiry for any existing pending bookings (15 min from creation)
UPDATE bookings
SET payment_expires_at = created_at + INTERVAL '15 minutes'
WHERE status = 'pending' AND payment_expires_at IS NULL;

-- Add CHECK constraint: spots_left must never go negative
ALTER TABLE activities
  ADD CONSTRAINT chk_spots_left_non_negative CHECK (spots_left >= 0);

-- Cleanup function: cancels expired pending bookings and releases spots
CREATE OR REPLACE FUNCTION cleanup_expired_bookings()
RETURNS JSONB AS $$
DECLARE
  v_booking RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_booking IN
    SELECT id, activity_id
    FROM bookings
    WHERE status = 'pending'
      AND payment_expires_at IS NOT NULL
      AND payment_expires_at < NOW()
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Cancel the booking
    UPDATE bookings SET status = 'cancelled' WHERE id = v_booking.id;

    -- Release the spot
    PERFORM release_spot(v_booking.activity_id);

    -- Fail any associated pending payment
    UPDATE payments SET status = 'failed'
    WHERE booking_id = v_booking.id AND status IN ('pending', 'processing');

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('cleaned_up', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule cleanup every 5 minutes via pg_cron
-- NOTE: pg_cron must be enabled in Supabase dashboard (Database > Extensions > pg_cron)
-- Run this in the SQL editor after enabling pg_cron:
-- SELECT cron.schedule('cleanup-expired-bookings', '*/5 * * * *', 'SELECT cleanup_expired_bookings()');
