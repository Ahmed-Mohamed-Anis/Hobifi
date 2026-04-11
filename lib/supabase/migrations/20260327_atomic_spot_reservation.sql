-- Atomic Spot Reservation RPC
-- Locks the activity row, checks spots_left > 0, decrements atomically.
-- Returns JSON: { "ok": true/false, "remaining": N, "reason": "..." }

CREATE OR REPLACE FUNCTION reserve_spot(p_activity_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
BEGIN
  -- Lock the row to prevent race conditions
  SELECT spots_left INTO v_spots
  FROM activities
  WHERE id = p_activity_id
  FOR UPDATE;

  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;

  IF v_spots <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'no_spots');
  END IF;

  UPDATE activities
  SET spots_left = spots_left - 1, updated_at = NOW()
  WHERE id = p_activity_id;

  RETURN jsonb_build_object('ok', true, 'remaining', v_spots - 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Companion function to release a spot (e.g. on cancellation or payment failure)
CREATE OR REPLACE FUNCTION release_spot(p_activity_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_spots INTEGER;
  v_max INTEGER;
BEGIN
  SELECT spots_left, max_guests INTO v_spots, v_max
  FROM activities
  WHERE id = p_activity_id
  FOR UPDATE;

  IF v_spots IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'activity_not_found');
  END IF;

  IF v_spots >= v_max THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_full');
  END IF;

  UPDATE activities
  SET spots_left = spots_left + 1, updated_at = NOW()
  WHERE id = p_activity_id;

  RETURN jsonb_build_object('ok', true, 'remaining', v_spots + 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
