create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  body text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on notifications(user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on notifications(user_id) where not read;

alter table notifications enable row level security;

create policy "Users can view own notifications"
  on notifications for select
  using (auth.uid() = user_id);

create policy "Users can mark own notifications read"
  on notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Service role can insert notifications"
  on notifications for insert
  with check (true);
