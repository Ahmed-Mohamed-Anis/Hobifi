-- Fix: Change default rating from 5.0 to 0.0 so new activities don't show
-- a misleading star rating before anyone has reviewed them.

ALTER TABLE activities ALTER COLUMN rating SET DEFAULT 0.0;

-- Also fix any existing activities that have the old 5.0 default with zero reviews
UPDATE activities SET rating = 0.0 WHERE review_count = 0 AND rating = 5.0;
