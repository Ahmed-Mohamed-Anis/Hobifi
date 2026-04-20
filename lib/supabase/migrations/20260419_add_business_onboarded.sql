-- Adds business onboarding completion flag for the business signup wizard.
alter table public.users
  add column if not exists business_onboarded boolean not null default false;

-- Existing business accounts (pre-feature) are treated as already onboarded
-- so they don't get forced through the new wizard retroactively.
update public.users
   set business_onboarded = true
 where role = 'business';
