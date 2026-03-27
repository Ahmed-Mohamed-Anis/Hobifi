-- Add gallery images and explicit schedule columns to activities
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS image_urls text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS start_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS end_at timestamptz NULL;

-- Ensure storage bucket for activity images exists and is public
INSERT INTO storage.buckets (id, name, public)
VALUES ('activity-images', 'activity-images', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Policies for public read and authenticated write on the bucket's objects
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'obj_read_activity_images'
  ) THEN
    CREATE POLICY obj_read_activity_images ON storage.objects
      FOR SELECT TO anon, authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'obj_insert_activity_images'
  ) THEN
    CREATE POLICY obj_insert_activity_images ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'obj_update_activity_images'
  ) THEN
    CREATE POLICY obj_update_activity_images ON storage.objects
      FOR UPDATE TO authenticated
      USING (bucket_id = 'activity-images')
      WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy WHERE polname = 'obj_delete_activity_images'
  ) THEN
    CREATE POLICY obj_delete_activity_images ON storage.objects
      FOR DELETE TO authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;
