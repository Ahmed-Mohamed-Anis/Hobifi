-- Revert bookings that were confirmed by the client but have no completed payment.
-- This fixes bookings wrongly confirmed due to the is_voided=false detection bug.
UPDATE bookings
SET status = 'cancelled'
WHERE status = 'confirmed'
  AND id NOT IN (
    SELECT booking_id FROM payments WHERE status = 'completed'
  );
