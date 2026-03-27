-- Migration: Add friendships table for friends feature
-- This migration creates the friendships table to manage friend relationships between users

-- Create friendships table
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')) DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Prevent duplicate friendships
  CONSTRAINT unique_friendship UNIQUE (user_id, friend_id),
  -- Prevent self-friendship
  CONSTRAINT no_self_friendship CHECK (user_id != friend_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);
CREATE INDEX idx_friendships_user_friend ON friendships(user_id, friend_id);

-- Apply updated_at trigger
CREATE TRIGGER update_friendships_updated_at BEFORE UPDATE ON friendships
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS on friendships table
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view friendships where they are either the user or the friend
CREATE POLICY "Users can view their friendships"
  ON friendships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Policy: Users can create friendship requests
CREATE POLICY "Users can create friendship requests"
  ON friendships FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update friendships where they are involved
CREATE POLICY "Users can update their friendships"
  ON friendships FOR UPDATE
  USING (auth.uid() = user_id OR auth.uid() = friend_id)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);

-- Policy: Users can delete their friendships
CREATE POLICY "Users can delete their friendships"
  ON friendships FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);
