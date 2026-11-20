-- Prerequisites: existing month-plan setup. Additive schedule change; no question deletion.
-- Daily entry window = 19:00–22:00 Asia/Dhaka; duration remains 40 min, hard close 22:00.
-- Existing attempts/history are NEVER rewritten. Weekly slots are unchanged.
begin;
do $guard$
begin
 if to_regclass('jobmaster_private.bcs_month_plan') is null then raise exception 'Run BCS-Auto-Routine-Setup.sql first';end if;
end $guard$;
select pg_advisory_xact_lock(hashtext('jobmaster-bcs-month-publication'));
lock table jobmaster_private.sessions in share row exclusive mode;
with eligible as (
 select p.id,
 (extract(epoch from ((p.exam_date+time '19:00') at time zone 'Asia/Dhaka'))*1000)::bigint new_starts,
 (extract(epoch from ((p.exam_date+time '22:00') at time zone 'Asia/Dhaka'))*1000)::bigint new_ends
 from jobmaster_private.bcs_month_plan p
 where p.plan_key='bcs-2026-11-20-30days' and p.kind='DAILY_LIVE'
 and (extract(epoch from ((p.exam_date+time '22:00') at time zone 'Asia/Dhaka'))*1000)::bigint>jobmaster_private.now_ms()
 and not exists(select 1 from jobmaster_private.sessions s where s.exam_id=p.exam_id)
), changed as (
 update jobmaster_private.bcs_month_plan p set starts=e.new_starts,ends=e.new_ends,publish=e.new_ends,duration=2400
 from eligible e where p.id=e.id returning p.exam_id,p.starts,p.ends,p.publish,p.duration
)
update jobmaster_private.exams e set starts=c.starts,ends=c.ends,publish=c.publish,duration=c.duration
from changed c where e.id=c.exam_id;
commit;
select p.exam_date,p.title,
 to_char(to_timestamp(p.starts/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as entry_from,
 to_char(to_timestamp(p.ends/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as hard_close,
 p.duration/60 as duration_minutes,
 to_char(to_timestamp(p.publish/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as result_at,
 case when exists(select 1 from jobmaster_private.sessions s where s.exam_id=p.exam_id) then 'EXISTING_ATTEMPTS_PRESERVED'
 when p.ends<=jobmaster_private.now_ms() then 'PAST_HISTORY_PRESERVED' else 'SCHEDULE_UPDATED' end as migration_state
from jobmaster_private.bcs_month_plan p where p.plan_key='bcs-2026-11-20-30days' and p.kind='DAILY_LIVE' order by p.exam_date;
