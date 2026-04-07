-- Enable RLS on ratings table
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read ratings
DROP POLICY IF EXISTS "Authenticated users can view all ratings" ON ratings;
CREATE POLICY "Authenticated users can view all ratings"
  ON ratings FOR SELECT
  TO authenticated
  USING (true);

-- Users can only rate activities they have a completed booking for
DROP POLICY IF EXISTS "Users can rate activities they completed" ON ratings;
CREATE POLICY "Users can rate activities they completed"
  ON ratings FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM bookings
      WHERE bookings.user_id = auth.uid()
        AND bookings.activity_id = ratings.activity_id
        AND bookings.status = 'completed'
    )
  );

-- Users can update only their own ratings
DROP POLICY IF EXISTS "Users can update their own ratings" ON ratings;
CREATE POLICY "Users can update their own ratings"
  ON ratings FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete only their own ratings
DROP POLICY IF EXISTS "Users can delete their own ratings" ON ratings;
CREATE POLICY "Users can delete their own ratings"
  ON ratings FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Enforce rating value 1-5
DO $$ BEGIN
  ALTER TABLE ratings ADD CONSTRAINT chk_rating_range CHECK (rating BETWEEN 1 AND 5);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Enforce comment max length 500
DO $$ BEGIN
  ALTER TABLE ratings ADD CONSTRAINT chk_comment_length CHECK (comment IS NULL OR length(comment) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
