-- Run AFTER 001 and 002 in Supabase SQL Editor.
-- Supabase supports pg_cron; a DB owner must enable this extension.
-- This job performs authoritative expiry finalization without a browser or Vercel process.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('jobmaster-expiry','* * * * *','select public.jobmaster_expire();')
where not exists(select 1 from cron.job where jobname='jobmaster-expiry');
-- Verify: select jobname,schedule,active from cron.job where jobname='jobmaster-expiry';
