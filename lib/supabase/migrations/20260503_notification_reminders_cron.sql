-- Requires pg_cron + pg_net extensions enabled in Supabase dashboard
-- Set app.supabase_url and app.service_role_key in Supabase database configuration
select cron.schedule(
  'send-activity-reminders',
  '*/5 * * * *',
  $$
    select net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/send-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'reminder',
        'booking_ids', (
          select jsonb_agg(b.id)
          from bookings b
          join activities a on a.id = b.activity_id
          where b.status = 'confirmed'
            and a.date_time between now() + interval '23 hours' and now() + interval '25 hours'
        )
      )
    )
    where (
      select count(*) from bookings b
      join activities a on a.id = b.activity_id
      where b.status = 'confirmed'
        and a.date_time between now() + interval '23 hours' and now() + interval '25 hours'
    ) > 0;
  $$
);
