-- Add comment field to ratings table for text reviews
-- Run this in Supabase SQL Editor

ALTER TABLE ratings
ADD COLUMN IF NOT EXISTS comment TEXT DEFAULT NULL;

-- Optional: add an index for activities with reviews (comments)
CREATE INDEX IF NOT EXISTS idx_ratings_activity_comment
ON ratings (activity_id)
WHERE comment IS NOT NULL;
