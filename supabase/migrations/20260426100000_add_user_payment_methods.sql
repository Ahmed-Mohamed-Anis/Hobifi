CREATE TABLE IF NOT EXISTS user_payment_methods (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_token  TEXT NOT NULL,
  masked_pan  TEXT,
  card_type   TEXT,
  is_default  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, card_token)
);

ALTER TABLE user_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_cards" ON user_payment_methods
  FOR ALL USING (auth.uid() = user_id);
