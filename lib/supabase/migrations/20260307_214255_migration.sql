-- Migration: Add payments table for Paymob integration
-- This table tracks all payment transactions with 10% platform fee

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  platform_fee DECIMAL(10,2) NOT NULL,
  business_earnings DECIMAL(10,2) NOT NULL,
  transaction_id TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
  payment_method TEXT NOT NULL DEFAULT 'card' CHECK (payment_method IN ('card', 'wallet', 'applePay')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_activity_id ON payments(activity_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- Enable Row Level Security
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own payments
CREATE POLICY "payments_select_own" ON payments
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own payments
CREATE POLICY "payments_insert_own" ON payments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Business owners can view payments for their activities
CREATE POLICY "payments_select_business" ON payments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM activities
      WHERE activities.id = payments.activity_id
      AND activities.business_id = auth.uid()
    )
  );

-- Policy: Service role can update payment status (for webhook callbacks)
CREATE POLICY "payments_update_service" ON payments
  FOR UPDATE USING (true) WITH CHECK (true);

-- Add phone column to users table if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'phone'
  ) THEN
    ALTER TABLE users ADD COLUMN phone TEXT;
  END IF;
END $$;
