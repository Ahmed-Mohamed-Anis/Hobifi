-- Requires pg_cron extension enabled in Supabase dashboard
select cron.schedule(
  'autocomplete-expired-bookings',
  '*/15 * * * *',
  $$
    update bookings
    set status = 'completed', updated_at = now()
    where status = 'confirmed'
      and exists (
        select 1 from activities a
        where a.id = bookings.activity_id
          and coalesce(a.end_at, a.date_time + interval '2 hours') < now() - interval '1 hour'
      );
  $$
);
