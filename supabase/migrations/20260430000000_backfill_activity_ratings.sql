-- Backfill rating and review_count on activities from the ratings table.
-- Needed when ratings existed before the sync trigger or were submitted
-- while the Flutter cache was stale (review_count stayed 0 in DB).
UPDATE activities
SET
  rating = COALESCE(
    (SELECT ROUND(AVG(r.rating)::numeric, 1) FROM ratings r WHERE r.activity_id = activities.id),
    0.0
  ),
  review_count = (
    SELECT COUNT(*) FROM ratings r WHERE r.activity_id = activities.id
  );
