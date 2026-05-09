-- Prevent a user from booking the same activity more than once
-- (when they already have an active booking for it).
CREATE OR REPLACE FUNCTION create_booking_with_reservation(
  p_user_id UUID,
  p_activity_id UUID,
  p_activity_title TEXT,
  p_activity_image TEXT,
  p_location TEXT,
  p_price NUMERIC(10,2),
  p_date_time TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
  v_booking_id UUID;
  v_expires_at TIMESTAMPTZ;
  v_existing_count INTEGER;
BEGIN
  -- Reject if user already has an active booking for this activity
  SELECT COUNT(*) INTO v_existing_count
  FROM bookings
  WHERE user_id = p_user_id
    AND activity_id = p_activity_id
    AND status IN ('pending', 'confirmed', 'completed');

  IF v_existing_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_booked');
  END IF;

  SELECT spots_left INTO v_spots
  FROM activities WHERE id = p_activity_id FOR UPDATE;

  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;
  IF v_spots <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_spots');
  END IF;

  UPDATE activities SET spots_left = spots_left - 1, updated_at = NOW() WHERE id = p_activity_id;

  v_booking_id := gen_random_uuid();
  v_expires_at := NOW() + INTERVAL '15 minutes';

  INSERT INTO bookings (id, user_id, activity_id, activity_title, activity_image, location, price, date_time, status, payment_expires_at)
  VALUES (v_booking_id, p_user_id, p_activity_id, p_activity_title, p_activity_image, p_location, p_price, p_date_time, 'pending', v_expires_at);

  RETURN jsonb_build_object('ok', true, 'booking_id', v_booking_id, 'expires_at', v_expires_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
