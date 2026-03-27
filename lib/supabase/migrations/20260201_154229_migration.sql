-- Ensure image_urls column exists on activities for multiple images
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';

-- Ensure storage bucket exists for activity images with public read
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'activity-images',
  'activity-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Refine storage policies for activity-images bucket
-- Drop previous policies if they exist to avoid duplicates
DROP POLICY IF EXISTS "Authenticated users can upload activity images" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for activity images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own activity images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own activity images" ON storage.objects;

-- Allow authenticated users to upload to the activity-images bucket
CREATE POLICY "Authenticated users can upload activity images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'activity-images');

-- Allow public to read images from the activity-images bucket
CREATE POLICY "Public read access for activity images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'activity-images');

-- Restrict updates to the owner of the object within the activity-images bucket
CREATE POLICY "Users can update their own activity images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'activity-images' AND (owner = auth.uid()))
WITH CHECK (bucket_id = 'activity-images' AND (owner = auth.uid()));

-- Restrict deletes to the owner of the object within the activity-images bucket
CREATE POLICY "Users can delete their own activity images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'activity-images' AND (owner = auth.uid()));
