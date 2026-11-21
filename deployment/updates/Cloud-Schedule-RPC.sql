-- JobMaster Cloud Schedule RPC
-- Requires: STEP-5-SUPABASE.sql, BCS-Auto-Routine-Setup.sql,
-- BCS-Daywise-Import.sql, Subject-Topic-Subtopic-V2.sql,
-- Admin-Courses-V3.sql and Platform-V4.sql.
-- Additive and re-runnable. Does not auto-verify questions or publish empty exams.

begin;

create table if not exists jobmaster_private.schedule_routines (
 id uuid primary key default gen_random_uuid(),
 course_id text not null references jobmaster_private.courses(id),
 title text not null check(length(title) between 3 and 200),
 topics text not null check(length(topics) between 3 and 6000),
 kind text not null check(kind in ('DAILY_LIVE','WEEKLY_SPECIAL','MOCK')),
 starts bigint not null,
 ends bigint not null,
 publish bigint not null,
 duration integer not null check(duration between 60 and 14400),
 marks integer not null check(marks between 1 and 100),
 exam_id uuid unique references jobmaster_private.exams(id),
 visible boolean not null default false,
 removed boolean not null default false,
 check(ends>starts and ends-starts<=86400000),
 check(publish>=ends),
 check(duration*1000<=ends-starts)
);
create index if not exists schedule_routines_course_start
 on jobmaster_private.schedule_routines(course_id,starts)
 where removed=false;
alter table jobmaster_private.schedule_routines enable row level security;
revoke all on jobmaster_private.schedule_routines from public,anon,authenticated;

create or replace function public.jobmaster_schedule(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
 u uuid:=auth.uid();
 a text:=p->>'action';
 adm boolean;
 ms bigint:=jobmaster_private.now_ms();
 v jsonb;
 old jobmaster_private.schedule_routines;
 rid uuid;
 eid uuid;
 result jsonb;
 item jsonb;
 ids jsonb;
 st bigint;
 en bigint;
 mins integer;
 cnt integer;
 vtitle text;
 vtopics text;
 vkind text;
 vcourse text;
begin
 if u is null then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.profiles(id,name,email)
 select id,left(coalesce(nullif(raw_user_meta_data->>'name',''),split_part(email,'@',1),'Student'),80),coalesce(email,'')
 from auth.users where id=u on conflict(id) do nothing;
 select role='admin' into adm from jobmaster_private.profiles where id=u;

 if a='calendar' then
  return jsonb_build_object(
   'now',ms,
   'plans',coalesce((
    select jsonb_agg(to_jsonb(x) order by x.starts)
    from (
     select r.id,r.course_id,c.title as course_title,r.title,r.topics,r.kind,
       r.starts,r.ends,r.publish,r.duration,r.marks,r.exam_id,
       case when r.exam_id is null then 'DRAFT'
            when ms<r.starts then 'SCHEDULED'
            when ms<r.ends then 'LIVE' else 'ENDED' end as status
     from jobmaster_private.schedule_routines r
     join jobmaster_private.courses c on c.id=r.course_id
     where r.visible and not r.removed and c.status='published'
     union all
     select e.id,m.course_id,c.title as course_title,e.title,
       'Admin নির্ধারিত course syllabus অনুযায়ী প্রস্তুতি নিন।' as topics,
       case when m.kind='weekly' then 'WEEKLY_SPECIAL'
            when m.kind='mock' then 'MOCK' else 'DAILY_LIVE' end as kind,
       e.starts,e.ends,e.publish,e.duration,m.marks,e.id as exam_id,
       case when ms<e.starts then 'SCHEDULED'
            when ms<e.ends then 'LIVE' else 'ENDED' end as status
     from jobmaster_private.exams e
     join jobmaster_private.live_meta m on m.exam_id=e.id
     join jobmaster_private.courses c on c.id=m.course_id
     where c.status='published' and not m.cancelled
       and not exists(select 1 from jobmaster_private.schedule_routines r where r.exam_id=e.id)
    ) x
   ),'[]'::jsonb)
  );
 end if;

 if not coalesce(adm,false) then raise exception 'Admin access required';end if;
 perform pg_advisory_xact_lock(hashtext('jobmaster-cloud-schedule:'||u::text));

 if a='list' then
  vcourse:=p->>'course_id';
  if not exists(select 1 from jobmaster_private.courses where id=vcourse) then raise exception 'Unknown course';end if;
  return jsonb_build_object('now',ms,'rows',coalesce((
   select jsonb_agg(to_jsonb(r) order by r.starts)
   from jobmaster_private.schedule_routines r
   where r.course_id=vcourse and not r.removed
  ),'[]'::jsonb));
 end if;

 if a='import' then
  if jsonb_typeof(p->'rows') is distinct from 'array'
     or jsonb_array_length(p->'rows') not between 1 and 100 then
    raise exception 'Import requires 1–100 routine rows';
  end if;
  result:='[]'::jsonb;
  for item in select value from jsonb_array_elements(p->'rows') loop
   result:=result||jsonb_build_array(public.jobmaster_schedule(jsonb_build_object('action','save','row',item)));
  end loop;
  return jsonb_build_object('imported',jsonb_array_length(result));
 end if;

 if a='save' then
  v:=p->'row';
  if jsonb_typeof(v) is distinct from 'object' then raise exception 'Routine row required';end if;
  vcourse:=v->>'course_id';vtitle:=btrim(v->>'title');vtopics:=btrim(v->>'topics');
  st:=(v->>'starts')::bigint;en:=(v->>'ends')::bigint;
  mins:=(v->>'minutes')::integer;cnt:=(v->>'marks')::integer;
  vkind:=case v->>'kind' when 'weekly' then 'WEEKLY_SPECIAL' else 'DAILY_LIVE' end;
  if not exists(select 1 from jobmaster_private.courses where id=vcourse) then raise exception 'Unknown course';end if;
  if vtitle is null or length(vtitle) not between 3 and 200
    or vtopics is null or length(vtopics) not between 3 and 6000
    or st is null or en is null or st<=ms or en<=st or en-st>86400000
    or mins is null or mins not between 1 and 240 or mins*60000>en-st
    or cnt is null or cnt not between 1 and 100 then
    raise exception 'Invalid future schedule, title, marks or duration';
  end if;
  rid:=coalesce(nullif(v->>'id','')::uuid,gen_random_uuid());
  select * into old from jobmaster_private.schedule_routines where id=rid for update;
  if found then
   if old.course_id<>vcourse or old.starts<=ms then raise exception 'Past routine / cross-course edit blocked';end if;
   if old.exam_id is not null then
    if old.marks<>cnt or exists(select 1 from jobmaster_private.sessions where exam_id=old.exam_id) then
     raise exception 'Attempted exam locked; cancel/unlink before changing marks';
    end if;
    update jobmaster_private.exams set title=vtitle,starts=st,ends=en,publish=en,duration=mins*60 where id=old.exam_id;
   end if;
   update jobmaster_private.schedule_routines set title=vtitle,topics=vtopics,kind=vkind,
    starts=st,ends=en,publish=en,duration=mins*60,marks=cnt,
    visible=coalesce((v->>'published')::boolean,false),removed=false
   where id=rid;
  else
   insert into jobmaster_private.schedule_routines(id,course_id,title,topics,kind,starts,ends,publish,duration,marks,visible)
   values(rid,vcourse,vtitle,vtopics,vkind,st,en,en,mins*60,cnt,coalesce((v->>'published')::boolean,false));
  end if;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'schedule:save',rid::text);
  return jsonb_build_object('ok',true,'id',rid);
 end if;

 if a in ('remove','publish_exam','cancel_exam') then
  rid:=(p->>'id')::uuid;
  select * into old from jobmaster_private.schedule_routines where id=rid for update;
  if not found then raise exception 'Routine not found';end if;
  if a='remove' then
   if old.exam_id is not null then raise exception 'Cancel/unlink exam before removing routine';end if;
   update jobmaster_private.schedule_routines set removed=not coalesce((p->>'restore')::boolean,false) where id=rid;
  elsif a='cancel_exam' then
   if old.exam_id is null or old.starts<=ms
      or exists(select 1 from jobmaster_private.sessions where exam_id=old.exam_id) then
    raise exception 'Only unattempted future exams can be cancelled';
   end if;
   update jobmaster_private.live_meta set cancelled=true where exam_id=old.exam_id;
   update jobmaster_private.exams set question_ids='[]'::jsonb where id=old.exam_id;
   update jobmaster_private.schedule_routines set exam_id=null where id=rid;
  elsif a='publish_exam' then
   if old.removed or old.exam_id is not null then raise exception 'Removed or already published exam';end if;
   result:=public.jobmaster_upgrade(jsonb_build_object(
    'action','exam_save','course_id',old.course_id,'title',old.title,
    'kind',case old.kind when 'WEEKLY_SPECIAL' then 'weekly' when 'MOCK' then 'mock' else 'daily' end,
    'starts',old.starts,'ends',old.ends,'minutes',old.duration/60,'marks',old.marks,
    'occurrences',1
   )||case when nullif(p->>'subtopic_id','') is null then '{}'::jsonb
           else jsonb_build_object('subtopic_id',p->>'subtopic_id') end);
   ids:=result->'ids';
   eid:=nullif(ids->>0,'')::uuid;
   if eid is null then raise exception 'Exam creation failed';end if;
   update jobmaster_private.schedule_routines set exam_id=eid,visible=true where id=rid;
   insert into jobmaster_private.audit(actor,action,entity) values(u,'schedule:publish_exam',eid::text);
   return jsonb_build_object('ok',true,'id',rid,'exam_id',eid);
  end if;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'schedule:'||a,rid::text);
  return jsonb_build_object('ok',true,'id',rid);
 end if;

 raise exception 'Unknown schedule action';
end $$;

revoke all on function public.jobmaster_schedule(jsonb) from public,anon;
grant execute on function public.jobmaster_schedule(jsonb) to authenticated;
commit;

-- Verification: function should exist; no data is changed by this query.
select to_regprocedure('public.jobmaster_schedule(jsonb)') as installed_schedule_rpc;
