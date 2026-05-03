create table if not exists review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references ratings(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (length(reason) <= 500),
  created_at timestamptz default now(),
  unique (review_id, reporter_id)
);

alter table review_reports enable row level security;

create policy "Users can report reviews"
  on review_reports for insert
  to authenticated
  with check (reporter_id = auth.uid());

create policy "Admins can view reports"
  on review_reports for select
  to authenticated
  using (reporter_id = auth.uid());
