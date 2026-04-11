-- Rating Sync Trigger
-- Automatically updates activities.rating and activities.review_count
-- whenever a rating is inserted, updated, or deleted.

CREATE OR REPLACE FUNCTION sync_activity_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_activity_id UUID;
BEGIN
  v_activity_id := COALESCE(NEW.activity_id, OLD.activity_id);

  UPDATE activities
  SET
    rating = COALESCE(
      (SELECT ROUND(AVG(rating)::numeric, 1) FROM ratings WHERE activity_id = v_activity_id),
      0.0
    ),
    review_count = (
      SELECT COUNT(*) FROM ratings WHERE activity_id = v_activity_id
    ),
    updated_at = NOW()
  WHERE id = v_activity_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Drop if exists to make migration idempotent
DROP TRIGGER IF EXISTS trg_sync_activity_rating ON ratings;

CREATE TRIGGER trg_sync_activity_rating
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW EXECUTE FUNCTION sync_activity_rating();
