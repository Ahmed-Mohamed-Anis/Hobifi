-- Cancel pending bookings whose payment window has long expired.
-- These are leftover from test sessions; they block duplicate-booking checks
-- and clutter the user's booking list.
UPDATE bookings
SET status = 'cancelled'
WHERE status = 'pending'
  AND (
    payment_expires_at IS NULL
    OR payment_expires_at < NOW() - INTERVAL '1 hour'
  );
