-- Fix: users INSERT policy was WITH CHECK (true) — any authenticated user
-- could create a profile for any user_id. Restrict to own ID only.
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;

CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Also tighten UPDATE's WITH CHECK to match USING
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
