-- HOBIFI Row Level Security Policies
-- Enable RLS and create policies for all tables

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Users table policies
-- Allow users to read all profiles
CREATE POLICY "Users can view all profiles"
  ON users FOR SELECT
  TO authenticated
  USING (true);

-- Allow users to insert their own profile (for signup)
CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (true);

-- Allow users to delete their own profile
CREATE POLICY "Users can delete their own profile"
  ON users FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- Activities table policies
-- Allow all authenticated users to view public activities
CREATE POLICY "Authenticated users can view public activities"
  ON activities FOR SELECT
  TO authenticated
  USING (is_public = true OR business_id = auth.uid());

-- Allow businesses to create activities
CREATE POLICY "Businesses can create activities"
  ON activities FOR INSERT
  TO authenticated
  WITH CHECK (business_id = auth.uid());

-- Allow businesses to update their own activities
CREATE POLICY "Businesses can update their own activities"
  ON activities FOR UPDATE
  TO authenticated
  USING (business_id = auth.uid())
  WITH CHECK (business_id = auth.uid());

-- Allow businesses to delete their own activities
CREATE POLICY "Businesses can delete their own activities"
  ON activities FOR DELETE
  TO authenticated
  USING (business_id = auth.uid());

-- Bookings table policies
-- Allow users to view their own bookings
CREATE POLICY "Users can view their own bookings"
  ON bookings FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR activity_id IN (
    SELECT id FROM activities WHERE business_id = auth.uid()
  ));

-- Allow users to create bookings
CREATE POLICY "Users can create bookings"
  ON bookings FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Allow users and businesses to update bookings
CREATE POLICY "Users and businesses can update bookings"
  ON bookings FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR activity_id IN (
    SELECT id FROM activities WHERE business_id = auth.uid()
  ))
  WITH CHECK (user_id = auth.uid() OR activity_id IN (
    SELECT id FROM activities WHERE business_id = auth.uid()
  ));

-- Allow users to delete their own bookings
CREATE POLICY "Users can delete their own bookings"
  ON bookings FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
