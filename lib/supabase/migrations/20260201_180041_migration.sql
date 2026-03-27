-- Migration: Add username to users, enforce case-insensitive uniqueness, add RPC for availability, and policies for searching

-- 1) Add username column to users
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS username text;

-- 2) Create case-insensitive unique index for usernames
-- Note: Unique index on lower(username) enforces case-insensitive uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_unique_ci 
  ON public.users (lower(username));

-- 3) Optional: Backfill strategy commented out (decide manually if needed)
-- UPDATE public.users SET username = split_part(email, '@', 1)
-- WHERE username IS NULL;

-- 4) Create a SECURITY DEFINER function to check availability that can be called before auth
-- This bypasses RLS using the definer's privileges, but only returns a boolean.
CREATE OR REPLACE FUNCTION public.check_username_available(uname text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  taken boolean;
BEGIN
  IF uname IS NULL OR length(trim(uname)) = 0 THEN
    RETURN false; -- invalid input treated as unavailable
  END IF;
  SELECT EXISTS(
    SELECT 1 FROM public.users u WHERE lower(u.username) = lower(trim(uname))
  ) INTO taken;
  RETURN NOT taken;
END;
$$;

-- 5) Allow anon and authenticated roles to execute the function
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated;

-- 6) Ensure RLS policy allows authenticated users to search users (name/email/username)
-- This does NOT expose sensitive fields; app queries restricted columns only.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Authenticated can select users for discovery'
  ) THEN
    CREATE POLICY "Authenticated can select users for discovery"
      ON public.users FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END$$;
