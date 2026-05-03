alter table activities
  add column if not exists cancellation_hours int not null default 24
  check (cancellation_hours >= 0);
