-- Create likes table to track user-liked activities
-- Safe to run multiple times: guard with IF NOT EXISTS where possible

-- Ensure required extension for UUID generation
create extension if not exists pgcrypto;

-- Create table
create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  activity_id uuid not null,
  created_at timestamp with time zone not null default now(),
  constraint fk_likes_user foreign key (user_id) references public.users(id) on delete cascade,
  constraint fk_likes_activity foreign key (activity_id) references public.activities(id) on delete cascade,
  constraint uq_likes_user_activity unique (user_id, activity_id)
);

-- Helpful indexes
create index if not exists idx_likes_user_id on public.likes(user_id);
create index if not exists idx_likes_activity_id on public.likes(activity_id);
create index if not exists idx_likes_created_at on public.likes((created_at::date));

-- Enable Row Level Security
alter table public.likes enable row level security;

-- Policies: only the owner (auth.uid()) can manage their likes
-- SELECT: users can read their own likes
create policy if not exists likes_select_own
on public.likes for select
using (auth.uid() = user_id);

-- INSERT: users can insert rows for themselves
create policy if not exists likes_insert_own
on public.likes for insert
with check (auth.uid() = user_id);

-- DELETE: users can delete their own likes
create policy if not exists likes_delete_own
on public.likes for delete
using (auth.uid() = user_id);

-- Updates are not required for this table; omit update policy
