-- Remove the client-callable confirm_booking_payment RPC.
-- It could be called without actual payment, bypassing Paymob entirely.
-- The webhook is the sole trusted confirmation source.
DROP FUNCTION IF EXISTS confirm_booking_payment(UUID);
