create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz default now(),
  unique (user_id, token)
);

alter table device_tokens enable row level security;

create policy "Users manage own tokens"
  on device_tokens for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
