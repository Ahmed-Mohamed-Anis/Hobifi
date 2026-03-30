-- Prevent duplicate pending/processing payments for the same booking.
-- Only one active payment per booking at a time.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_booking_active
  ON payments (booking_id)
  WHERE status IN ('pending', 'processing');
