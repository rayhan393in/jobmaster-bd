-- Use ONLY in Supabase SQL Editor after YOU signed up and verified your email.
-- Find your UUID at Authentication > Users. Replace the UUID below with your own.
-- This file intentionally does NOT run until you replace that UUID.
begin;
insert into jobmaster_private.profiles(id,name,email)
select id,coalesce(raw_user_meta_data->>'name','Owner'),email from auth.users
where id='REPLACE-WITH-YOUR-VERIFIED-USER-UUID'::uuid and email_confirmed_at is not null
on conflict(id) do nothing;
update jobmaster_private.profiles set role='admin'
where id='REPLACE-WITH-YOUR-VERIFIED-USER-UUID'::uuid
and exists(select 1 from auth.users u where u.id=jobmaster_private.profiles.id and u.email_confirmed_at is not null);
commit;
-- Confirm one matching row:
-- select id,name,email,role from jobmaster_private.profiles where role='admin';
