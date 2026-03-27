-- Add image_urls column to activities table for multiple images
ALTER TABLE public.activities 
ADD COLUMN IF NOT EXISTS image_urls text[] DEFAULT '{}';

-- Create storage bucket for activity images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'activity-images',
  'activity-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for activity-images bucket
-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload activity images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'activity-images');

-- Allow public read access to activity images
CREATE POLICY "Public read access for activity images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'activity-images');

-- Allow users to update their own uploaded images
CREATE POLICY "Users can update their own activity images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'activity-images');

-- Allow users to delete their own uploaded images
CREATE POLICY "Users can delete their own activity images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'activity-images');
