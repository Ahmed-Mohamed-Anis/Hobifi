-- Allow business owners (activity owners) to read likes for their activities
-- This complements existing policies that let users manage their own likes

create policy if not exists likes_select_for_business_owner
on public.likes for select
using (
  exists (
    select 1 from public.activities a
    where a.id = likes.activity_id and a.business_id = auth.uid()
  )
);
