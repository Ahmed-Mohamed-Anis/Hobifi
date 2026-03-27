-- Fix likes schema and ensure business owners can read likes on their activities
-- Safe, idempotent migration

-- 1) Ensure required extension
create extension if not exists pgcrypto;

-- 2) Ensure likes table exists (noop if already there)
create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  activity_id uuid not null,
  created_at timestamp with time zone not null default now()
);

-- 3) Enable RLS on likes
alter table public.likes enable row level security;

-- 4) Convert activity_id to UUID if it was created as TEXT previously
--    Remove any rows with invalid uuid values to allow the type change
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'likes' AND column_name = 'activity_id' AND data_type <> 'uuid'
  ) THEN
    -- Drop dependent indexes temporarily if any (defensive; they will be recreated below)
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND tablename='likes' AND indexname='idx_likes_activity_id') THEN
      EXECUTE 'DROP INDEX IF EXISTS public.idx_likes_activity_id';
    END IF;

    -- Remove corrupt values that cannot be casted to uuid
    EXECUTE $$DELETE FROM public.likes WHERE activity_id !~* '^[0-9a-fA-F-]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'$$;

    -- Perform type change
    EXECUTE 'ALTER TABLE public.likes ALTER COLUMN activity_id TYPE uuid USING activity_id::uuid';
  END IF;
END$$;

-- 5) Ensure FKs exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'fk_likes_user' AND conrelid = 'public.likes'::regclass
  ) THEN
    ALTER TABLE public.likes
      ADD CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'fk_likes_activity' AND conrelid = 'public.likes'::regclass
  ) THEN
    ALTER TABLE public.likes
      ADD CONSTRAINT fk_likes_activity FOREIGN KEY (activity_id) REFERENCES public.activities(id) ON DELETE CASCADE;
  END IF;
END$$;

-- 6) Helpful indexes (idempotent)
create index if not exists idx_likes_user_id on public.likes(user_id);
create index if not exists idx_likes_activity_id on public.likes(activity_id);
create index if not exists idx_likes_created_at on public.likes((created_at::date));

-- 7) Base policies: users manage their own likes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='likes' AND policyname='likes_select_own'
  ) THEN
    CREATE POLICY likes_select_own ON public.likes FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='likes' AND policyname='likes_insert_own'
  ) THEN
    CREATE POLICY likes_insert_own ON public.likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='likes' AND policyname='likes_delete_own'
  ) THEN
    CREATE POLICY likes_delete_own ON public.likes FOR DELETE TO authenticated USING (auth.uid() = user_id);
  END IF;
END$$;

-- 8) Business owner read policy: allow business owners (activity owners) to read likes on their activities
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='likes' AND policyname='likes_select_for_business_owner'
  ) THEN
    CREATE POLICY likes_select_for_business_owner ON public.likes FOR SELECT TO authenticated
    USING (EXISTS (
      SELECT 1 FROM public.activities a
      WHERE a.id = likes.activity_id AND a.business_id = auth.uid()
    ));
  END IF;
END$$;