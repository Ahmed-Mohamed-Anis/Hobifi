-- Migration: Create likes table for user activity likes

-- Create likes table
CREATE TABLE IF NOT EXISTS public.likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  activity_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_activity_like UNIQUE (user_id, activity_id)
);

-- Indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON public.likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_activity_id ON public.likes(activity_id);
CREATE INDEX IF NOT EXISTS idx_likes_created_at ON public.likes(created_at);

-- Enable RLS
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

-- Policies: authenticated users can manage their own likes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'likes' AND policyname = 'Users can select their likes'
  ) THEN
    CREATE POLICY "Users can select their likes"
      ON public.likes FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'likes' AND policyname = 'Users can insert their likes'
  ) THEN
    CREATE POLICY "Users can insert their likes"
      ON public.likes FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'likes' AND policyname = 'Users can delete their likes'
  ) THEN
    CREATE POLICY "Users can delete their likes"
      ON public.likes FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END$$;
