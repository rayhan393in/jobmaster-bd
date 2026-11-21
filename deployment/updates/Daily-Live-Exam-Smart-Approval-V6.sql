-- JobMaster BD V6 — Daily Live Exam system + Smart Question Approval + SQL Import + Admin Dashboard.
-- Additive only. Does not touch jobmaster_action/jobmaster_courses bodies, does not delete
-- existing questions/exams/attempts. Safe to re-run (idempotent create/alter/replace).
-- Run in Supabase SQL Editor (or via the Supabase migration tool) on the SAME project as
-- STEP-5-SUPABASE.sql + Admin-Courses-V3.sql + Subject-Topic-Subtopic-V2.sql.
begin;
do $guard$
begin
 if to_regclass('jobmaster_private.course_questions') is null then raise exception 'Install Admin-Courses-V3.sql first';end if;
 if to_regclass('jobmaster_private.question_classification') is null then raise exception 'Install Subject-Topic-Subtopic-V2.sql first';end if;
end $guard$;
select pg_advisory_xact_lock(hashtext('jobmaster-live-exam-v6'));

-- ───────────────────────── Super Admin flag (SQL import gate) ─────────────────────────
alter table jobmaster_private.profiles add column if not exists is_super_admin boolean not null default false;

-- ───────────────────────── 1) Daily Live Exam config (singleton) ─────────────────────────
create table if not exists jobmaster_private.live_exam_settings(
 id smallint primary key default 1 check(id=1),
 start_minute int not null default 600 check(start_minute between 0 and 1439),   -- 600 = 10:00
 end_minute int not null default 1320 check(end_minute between 1 and 1440),      -- 1320 = 22:00
 duration_seconds int not null default 3000 check(duration_seconds between 60 and 7200), -- 3000 = 50 min
 total_questions int not null default 100 check(total_questions between 1 and 200),
 negative_mark numeric(4,2) not null default 0.25 check(negative_mark>=0 and negative_mark<=1),
 track text not null default 'BCS' check(track in ('BCS','EEE')),
 updated_by uuid,
 updated timestamptz not null default now(),
 check(end_minute>start_minute)
);
insert into jobmaster_private.live_exam_settings(id) values(1) on conflict(id) do nothing;

-- ───────────────────────── Live Exam Question Bank (separate from practice pool) ─────────────────────────
create table if not exists jobmaster_private.live_exam_questions(
 id text primary key,
 track text not null default 'BCS' check(track in ('BCS','EEE')),
 subject text not null check(length(btrim(subject)) between 1 and 150),
 topic text not null check(length(btrim(topic)) between 1 and 150),
 difficulty text not null default 'standard' check(difficulty in ('easy','standard','hard')),
 q text not null check(length(btrim(q)) between 8 and 4000),
 o jsonb not null check(jsonb_array_length(o)=4),
 a int not null check(a between 0 and 3),
 e text not null check(length(btrim(e)) between 8 and 6000),
 exam_date date not null,
 fingerprint text not null unique,
 created timestamptz not null default now(),
 created_by uuid
);
create index if not exists live_exam_questions_date on jobmaster_private.live_exam_questions(exam_date,track);

-- ───────────────────────── Daily attempts (one per student per day) ─────────────────────────
create table if not exists jobmaster_private.live_exam_attempts(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 exam_date date not null,
 track text not null,
 question_ids jsonb not null check(jsonb_array_length(question_ids)>=1),
 started bigint not null,
 deadline bigint not null,
 total_marks numeric not null,
 negative_mark numeric not null,
 submitted int not null default 0 check(submitted in (0,1)),
 score numeric,correct int,wrong int,answered int,
 unique(user_id,exam_date)
);
create index if not exists live_exam_attempts_due on jobmaster_private.live_exam_attempts(deadline) where submitted=0;
create index if not exists live_exam_attempts_date on jobmaster_private.live_exam_attempts(exam_date);
create table if not exists jobmaster_private.live_exam_answers(
 attempt_id uuid references jobmaster_private.live_exam_attempts(id) on delete cascade,
 question int not null check(question>=0),
 choice int not null check(choice between 0 and 3),
 primary key(attempt_id,question)
);

do $$declare t text;begin foreach t in array array['live_exam_settings','live_exam_questions','live_exam_attempts','live_exam_answers'] loop
 execute format('alter table jobmaster_private.%I enable row level security',t);
 execute format('revoke all on jobmaster_private.%I from public,anon,authenticated',t);
end loop;end $$;

-- ───────────────────────── Finish / expire helpers ─────────────────────────
create or replace function jobmaster_private.live_exam_finish(aid uuid) returns void language plpgsql set search_path='' as $$
declare att jobmaster_private.live_exam_attempts; n int; c int;
begin
 select * into att from jobmaster_private.live_exam_attempts where id=aid for update;
 if not found or att.submitted=1 then return;end if;
 select count(*),count(*) filter(where lq.a=ans.choice) into n,c
  from jobmaster_private.live_exam_answers ans join jobmaster_private.live_exam_questions lq on lq.id=(att.question_ids->>ans.question) where ans.attempt_id=aid;
 update jobmaster_private.live_exam_attempts set submitted=1,answered=n,correct=c,wrong=n-c,score=c-(n-c)*att.negative_mark where id=aid;
end $$;
create or replace function jobmaster_private.live_exam_expire() returns void language plpgsql set search_path='' as $$
declare aid uuid;begin for aid in select id from jobmaster_private.live_exam_attempts where submitted=0 and deadline<=jobmaster_private.now_ms() for update skip locked loop perform jobmaster_private.live_exam_finish(aid);end loop;end $$;
create or replace function public.jobmaster_live_expire() returns void language sql security definer set search_path='' as $$select jobmaster_private.live_exam_expire()$$;
revoke all on function public.jobmaster_live_expire() from public,anon,authenticated;
grant execute on function public.jobmaster_live_expire() to service_role;

-- ───────────────────────── Student + Admin Daily Live Exam RPC ─────────────────────────
create or replace function public.jobmaster_live(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); who jobmaster_private.profiles; a text:=coalesce(p->>'action','status');
 cfg jobmaster_private.live_exam_settings; att jobmaster_private.live_exam_attempts;
 today date; ms bigint; win_start bigint; win_end bigint; ids jsonb; sid uuid; i int; c int; n int;
 v jsonb; fp text; newid text; cnt int:=0; dup int:=0; errs jsonb:='[]'; limhits int;
begin
 if u is null then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.profiles(id,name,email) select id,left(coalesce(nullif(raw_user_meta_data->>'name',''),split_part(email,'@',1),'Student'),80),coalesce(email,'') from auth.users where id=u on conflict(id) do nothing;
 select * into who from jobmaster_private.profiles where id=u;if not found then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.limits values('live:'||u::text,1,now()+interval '1 minute') on conflict(key) do update set hits=case when jobmaster_private.limits.reset_at<now() then 1 else jobmaster_private.limits.hits+1 end,reset_at=case when jobmaster_private.limits.reset_at<now() then now()+interval '1 minute' else jobmaster_private.limits.reset_at end returning hits into limhits;
 if limhits>300 then raise exception 'Too many requests';end if;
 perform jobmaster_private.live_exam_expire();
 select * into cfg from jobmaster_private.live_exam_settings where id=1;
 today:=(now() at time zone 'Asia/Dhaka')::date;ms:=jobmaster_private.now_ms();
 win_start:=(extract(epoch from ((today::timestamp+(cfg.start_minute||' minutes')::interval) at time zone 'Asia/Dhaka'))*1000)::bigint;
 win_end:=(extract(epoch from ((today::timestamp+(cfg.end_minute||' minutes')::interval) at time zone 'Asia/Dhaka'))*1000)::bigint;

 if a='status' then
  select * into att from jobmaster_private.live_exam_attempts where user_id=u and exam_date=today;
  select count(*) into n from jobmaster_private.live_exam_questions where exam_date=today and track=cfg.track;
  return jsonb_build_object('now',ms,'exam_date',today,'window_starts',win_start,'window_ends',win_end,'duration_seconds',cfg.duration_seconds,
   'total_questions',cfg.total_questions,'negative_mark',cfg.negative_mark,'track',cfg.track,'available_questions',n,
   'attempt_id',att.id,'submitted',coalesce(att.submitted,0),'deadline',att.deadline,
   'can_start',(att.id is null and ms>=win_start and ms<win_end and n>0));
 end if;

 if a='start' then
  perform pg_advisory_xact_lock(hashtext(u::text||':live'));
  select * into att from jobmaster_private.live_exam_attempts where user_id=u and exam_date=today for update;
  if found then return jsonb_build_object('id',att.id);end if;
  if ms<win_start then raise exception 'আজকের লাইভ পরীক্ষা এখনো শুরু হয়নি';end if;
  if ms>=win_end then raise exception 'আজকের লাইভ পরীক্ষা শুরুর সময় শেষ হয়ে গেছে';end if;
  select coalesce(jsonb_agg(x.id),'[]') into ids from(select id from jobmaster_private.live_exam_questions where exam_date=today and track=cfg.track order by random() limit cfg.total_questions)x;
  if jsonb_array_length(ids)=0 then raise exception 'আজকের জন্য কোনো লাইভ প্রশ্ন নির্ধারিত নেই';end if;
  insert into jobmaster_private.live_exam_attempts(user_id,exam_date,track,question_ids,started,deadline,total_marks,negative_mark)
   values(u,today,cfg.track,ids,ms,ms+cfg.duration_seconds::bigint*1000,jsonb_array_length(ids),cfg.negative_mark) returning id into sid;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'live:start',sid::text);
  return jsonb_build_object('id',sid);
 end if;

 if a in ('state','answer','submit') then
  select * into att from jobmaster_private.live_exam_attempts where id=(p->>'id')::uuid and user_id=u for update;
  if not found then raise exception 'Attempt not found';end if;
  if a='answer' then
   if att.submitted=1 or ms>=att.deadline then raise exception 'পরীক্ষার সময় শেষ';end if;
   i:=(p->>'question')::int;c:=(p->>'choice')::int;
   if i is null or c is null or i<0 or i>=jsonb_array_length(att.question_ids) or c not between 0 and 3 then raise exception 'Invalid answer';end if;
   insert into jobmaster_private.live_exam_answers values(att.id,i,c) on conflict(attempt_id,question) do update set choice=excluded.choice;
   return '{"ok":true}';
  end if;
  if a='submit' then
   perform jobmaster_private.live_exam_finish(att.id);select * into att from jobmaster_private.live_exam_attempts where id=att.id;
   insert into jobmaster_private.audit(actor,action,entity) values(u,'live:submit',att.id::text);
   return jsonb_build_object('result',jsonb_build_object('score',att.score,'correct',att.correct,'wrong',att.wrong,'answered',att.answered,'total',jsonb_array_length(att.question_ids)),
    'review',(select coalesce(jsonb_agg(jsonb_build_object('id',ord-1,'q',lq.q,'o',lq.o,'a',lq.a,'e',lq.e,'subject',lq.subject,'topic',lq.topic) order by ord),'[]')
     from jsonb_array_elements_text(att.question_ids) with ordinality z(qid,ord) join jobmaster_private.live_exam_questions lq on lq.id=z.qid));
  end if;
  return jsonb_build_object('id',att.id,'submitted',att.submitted,'deadline',att.deadline,'now',ms,'negative_mark',att.negative_mark,
   'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',ord-1,'q',lq.q,'o',lq.o,'subject',lq.subject,'topic',lq.topic) order by ord),'[]')
    from jsonb_array_elements_text(att.question_ids) with ordinality z(qid,ord) join jobmaster_private.live_exam_questions lq on lq.id=z.qid),
   'answers',(select coalesce(jsonb_agg(jsonb_build_object('question',question,'choice',choice)),'[]') from jobmaster_private.live_exam_answers where attempt_id=att.id),
   'result',case when att.submitted=1 then jsonb_build_object('score',att.score,'correct',att.correct,'wrong',att.wrong,'answered',att.answered,'total',jsonb_array_length(att.question_ids)) else null end,
   'review',case when att.submitted=1 then (select coalesce(jsonb_agg(jsonb_build_object('id',ord-1,'q',lq.q,'o',lq.o,'a',lq.a,'e',lq.e) order by ord),'[]') from jsonb_array_elements_text(att.question_ids) with ordinality z(qid,ord) join jobmaster_private.live_exam_questions lq on lq.id=z.qid) else null end);
 end if;

 -- ── Admin-only actions below ──
 if who.role<>'admin' then raise exception 'Admin access required';end if;

 if a='config_get' then return to_jsonb(cfg);end if;
 if a='config_save' then
  if (p->>'start_minute')::int not between 0 and 1439 or (p->>'end_minute')::int not between 1 and 1440 or (p->>'end_minute')::int<=(p->>'start_minute')::int then raise exception 'সময়সীমা সঠিক নয়';end if;
  if (p->>'duration_seconds')::int not between 60 and 7200 then raise exception 'Duration সঠিক নয়';end if;
  if (p->>'total_questions')::int not between 1 and 200 then raise exception 'Question count সঠিক নয়';end if;
  if (p->>'negative_mark')::numeric<0 or (p->>'negative_mark')::numeric>1 then raise exception 'Negative mark 0–1 এর মধ্যে দিন';end if;
  if p->>'track' not in ('BCS','EEE') then raise exception 'Invalid track';end if;
  update jobmaster_private.live_exam_settings set start_minute=(p->>'start_minute')::int,end_minute=(p->>'end_minute')::int,duration_seconds=(p->>'duration_seconds')::int,
   total_questions=(p->>'total_questions')::int,negative_mark=(p->>'negative_mark')::numeric,track=p->>'track',updated_by=u,updated=clock_timestamp() where id=1;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'live:config_save','1');
  return '{"ok":true}';
 end if;
 if a='bank_list' then
  return jsonb_build_object('rows',(select coalesce(jsonb_agg(to_jsonb(x) order by x.exam_date desc,x.id),'[]') from(
   select id,track,subject,topic,difficulty,q,exam_date,created from jobmaster_private.live_exam_questions
   where(coalesce(p->>'exam_date','')=''or exam_date=(p->>'exam_date')::date) order by exam_date desc limit 500)x));
 end if;
 if a='bank_delete' then
  if exists(select 1 from jobmaster_private.live_exam_attempts where question_ids @> jsonb_build_array(p->>'id')) then raise exception 'ব্যবহৃত প্রশ্ন মোছা যাবে না';end if;
  delete from jobmaster_private.live_exam_questions where id=p->>'id';
  insert into jobmaster_private.audit(actor,action,entity) values(u,'live:bank_delete',p->>'id');
  return '{"ok":true}';
 end if;
 if a='bank_import' then
  ids:=p->'rows';
  if jsonb_typeof(ids) is distinct from 'array' or jsonb_array_length(ids) not between 1 and 1000 then raise exception '১–১০০০ প্রশ্ন প্রতি ব্যাচে দিন';end if;
  for v in select value from jsonb_array_elements(ids) loop
   begin
    if coalesce(v->>'track','BCS') not in ('BCS','EEE') or length(btrim(coalesce(v->>'subject','')))<1 or length(btrim(coalesce(v->>'topic','')))<1
     or length(btrim(coalesce(v->>'q','')))<8 or jsonb_typeof(v->'o') is distinct from 'array' or jsonb_array_length(v->'o')<>4
     or (v->>'a')::int not between 0 and 3 or length(btrim(coalesce(v->>'e','')))<8
     or v->>'exam_date' is null or (v->>'exam_date')::date<today then
     errs:=errs||jsonb_build_object('row',v,'error','ভুল subject/topic/q/o/a/e অথবা exam_date অতীতের');continue;
    end if;
    fp:=jobmaster_private.fingerprint(v->>'q');
    if exists(select 1 from jobmaster_private.live_exam_questions where fingerprint=fp) then dup:=dup+1;continue;end if;
    newid:='live-'||replace(gen_random_uuid()::text,'-','');
    insert into jobmaster_private.live_exam_questions(id,track,subject,topic,difficulty,q,o,a,e,exam_date,fingerprint,created_by)
     values(newid,coalesce(v->>'track','BCS'),btrim(v->>'subject'),btrim(v->>'topic'),coalesce(v->>'difficulty','standard'),btrim(v->>'q'),v->'o',(v->>'a')::int,btrim(v->>'e'),(v->>'exam_date')::date,fp,u);
    cnt:=cnt+1;
   exception when others then errs:=errs||jsonb_build_object('row',v,'error',sqlerrm);
   end;
  end loop;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'live:bank_import',cnt::text);
  return jsonb_build_object('ok',true,'imported',cnt,'duplicates',dup,'errors',errs);
 end if;
 if a='today_summary' then
  return jsonb_build_object('exam_date',today,'available_questions',(select count(*) from jobmaster_private.live_exam_questions where exam_date=today and track=cfg.track),
   'participants',(select count(*) from jobmaster_private.live_exam_attempts where exam_date=today),
   'submitted',(select count(*) from jobmaster_private.live_exam_attempts where exam_date=today and submitted=1));
 end if;
 raise exception 'Unknown action';
end $$;
revoke all on function public.jobmaster_live(jsonb) from public,anon;
grant execute on function public.jobmaster_live(jsonb) to authenticated;

-- ───────────────────────── 2) Smart Question Approval (per course Subject→Topic bulk) ─────────────────────────
create or replace function public.jobmaster_approvals(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); who jobmaster_private.profiles; a text:=coalesce(p->>'action','pending_summary'); c text:=p->>'course_id'; cnt int; ids text[];
begin
 if u is null then raise exception 'Unauthorized';end if;
 select * into who from jobmaster_private.profiles where id=u;if not found or who.role<>'admin' then raise exception 'Admin access required';end if;
 if c is null or not exists(select 1 from jobmaster_private.courses where id=c) then raise exception 'Valid course_id required';end if;

 if a='pending_summary' then
  return jsonb_build_object(
   'course_pending',(select count(*) from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=c and not q.verified and m.subtopic_id is not null and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)),
   'course_unclassified_pending',(select count(*) from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=c and not q.verified and m.subtopic_id is null and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)),
   'subjects',(select coalesce(jsonb_agg(to_jsonb(x) order by x.subject_title),'[]') from(
    select s.id subject_id,s.title subject_title,count(*) pending
    from jobmaster_private.course_questions m
    join jobmaster_private.questions q on q.id=m.question_id and not q.verified and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)
    join jobmaster_private.course_nodes l on l.id=m.subtopic_id
    join jobmaster_private.course_nodes t on t.id=l.parent_id
    join jobmaster_private.course_nodes s on s.id=t.parent_id
    where m.course_id=c group by s.id,s.title)x),
   'topics',(select coalesce(jsonb_agg(to_jsonb(x) order by x.subject_title,x.topic_title),'[]') from(
    select s.id subject_id,s.title subject_title,t.id topic_id,t.title topic_title,count(*) pending
    from jobmaster_private.course_questions m
    join jobmaster_private.questions q on q.id=m.question_id and not q.verified and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)
    join jobmaster_private.course_nodes l on l.id=m.subtopic_id
    join jobmaster_private.course_nodes t on t.id=l.parent_id
    join jobmaster_private.course_nodes s on s.id=t.parent_id
    where m.course_id=c group by s.id,s.title,t.id,t.title)x));
 end if;

 if a='approve_many' then
  ids:=array(select jsonb_array_elements_text(coalesce(p->'ids','[]'::jsonb)));
  if ids is null or array_length(ids,1) is null or array_length(ids,1)>500 then raise exception '১–৫০০টি প্রশ্ন নির্বাচন করুন';end if;
  with target as(select m.question_id from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id
   where m.course_id=c and m.question_id=any(ids) and not q.verified and m.subtopic_id is not null)
  update jobmaster_private.questions set verified=true where id in(select question_id from target);
  get diagnostics cnt=row_count;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'approvals:approve_many',cnt::text);
  return jsonb_build_object('ok',true,'approved',cnt);
 end if;

 if a='approve_all' then
  with target as(
   select m.question_id from jobmaster_private.course_questions m
   join jobmaster_private.questions q on q.id=m.question_id and not q.verified and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)
   left join jobmaster_private.course_nodes l on l.id=m.subtopic_id
   left join jobmaster_private.course_nodes t on t.id=l.parent_id
   where m.course_id=c and m.subtopic_id is not null
    and(coalesce(p->>'subtopic_id','')=''or m.subtopic_id=p->>'subtopic_id')
    and(coalesce(p->>'topic_id','')=''or l.parent_id=p->>'topic_id')
    and(coalesce(p->>'subject_id','')=''or t.parent_id=p->>'subject_id'))
  update jobmaster_private.questions set verified=true where id in(select question_id from target);
  get diagnostics cnt=row_count;
  insert into jobmaster_private.audit(actor,action,entity) values(u,'approvals:approve_all',coalesce(nullif(p->>'subtopic_id',''),nullif(p->>'topic_id',''),nullif(p->>'subject_id',''),c));
  return jsonb_build_object('ok',true,'approved',cnt);
 end if;

 raise exception 'Unknown action';
end $$;
revoke all on function public.jobmaster_approvals(jsonb) from public,anon;
grant execute on function public.jobmaster_approvals(jsonb) to authenticated;

-- ───────────────────────── 4) Super-Admin SQL file bulk import ─────────────────────────
-- The uploaded .sql file is NEVER executed as SQL. It is parsed client-side into row objects
-- (see src/lib/sql-import.ts) and only this constrained RPC performs validated, logged writes.
create or replace function public.jobmaster_sql_import(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); who jobmaster_private.profiles; a text:=coalesce(p->>'action','fingerprints');
 rows jsonb; v jsonb; fp text; cnt int:=0; dup int:=0; errs jsonb:='[]'; newid text; leafid text;
begin
 if u is null then raise exception 'Unauthorized';end if;
 select * into who from jobmaster_private.profiles where id=u;if not found then raise exception 'Unauthorized';end if;
 if who.role<>'admin' then raise exception 'Admin access required';end if;
 if a='fingerprints' then
  return jsonb_build_object(
   'questions',(select coalesce(jsonb_agg(fingerprint),'[]') from jobmaster_private.questions),
   'live',(select coalesce(jsonb_agg(fingerprint),'[]') from jobmaster_private.live_exam_questions));
 end if;
 if not who.is_super_admin then raise exception 'শুধুমাত্র Super Admin SQL Import করতে পারবে';end if;
 if a<>'commit' then raise exception 'Unknown action';end if;
 rows:=p->'rows';
 if jsonb_typeof(rows) is distinct from 'array' or jsonb_array_length(rows) not between 1 and 500 then raise exception 'প্রতি ব্যাচে ১–৫০০ row দিন; বড় file একাধিক ব্যাচে পাঠান';end if;
 for v in select value from jsonb_array_elements(rows) loop
  begin
   if coalesce(v->>'status','pending') not in ('pending','approved','live_scheduled') then errs:=errs||jsonb_build_object('row',v,'error','Invalid status');continue;end if;
   if coalesce(v->>'track','BCS') not in ('BCS','EEE') then errs:=errs||jsonb_build_object('row',v,'error','Invalid track');continue;end if;
   if length(btrim(coalesce(v->>'q','')))<8 or jsonb_typeof(v->'o') is distinct from 'array' or jsonb_array_length(v->'o')<>4 or (v->>'a')::int not between 0 and 3 or length(btrim(coalesce(v->>'e','')))<8 then
    errs:=errs||jsonb_build_object('row',v,'error','Invalid question/options/answer/explanation');continue;
   end if;
   fp:=jobmaster_private.fingerprint(v->>'q');
   if v->>'status'='live_scheduled' then
    if v->>'exam_date' is null or (v->>'exam_date')::date<(now() at time zone 'Asia/Dhaka')::date then errs:=errs||jsonb_build_object('row',v,'error','live_scheduled needs a future exam_date');continue;end if;
    if exists(select 1 from jobmaster_private.live_exam_questions where fingerprint=fp) then dup:=dup+1;continue;end if;
    newid:='live-'||replace(gen_random_uuid()::text,'-','');
    insert into jobmaster_private.live_exam_questions(id,track,subject,topic,difficulty,q,o,a,e,exam_date,fingerprint,created_by)
     values(newid,coalesce(v->>'track','BCS'),coalesce(nullif(btrim(v->>'subject'),''),'Unspecified'),coalesce(nullif(btrim(v->>'topic'),''),'Unspecified'),coalesce(v->>'difficulty','standard'),btrim(v->>'q'),v->'o',(v->>'a')::int,btrim(v->>'e'),(v->>'exam_date')::date,fp,u);
    cnt:=cnt+1;
   else
    if exists(select 1 from jobmaster_private.questions where fingerprint=fp) then dup:=dup+1;continue;end if;
    newid:='sql-q-'||replace(gen_random_uuid()::text,'-','');
    insert into jobmaster_private.questions(id,data,fingerprint,verified) values(newid,
     jsonb_build_object('id',newid,'track',coalesce(v->>'track','BCS'),'subject',coalesce(nullif(btrim(v->>'subject'),''),'Unspecified'),'topic',v->>'topic','q',btrim(v->>'q'),'o',v->'o','a',(v->>'a')::int,'e',btrim(v->>'e'),'kind','original','source','SQL bulk import by super admin','difficulty',coalesce(v->>'difficulty','standard')),
     fp,(v->>'status')='approved');
    leafid:=null;
    select ls.id into leafid from jobmaster_private.exam_subtopics ls join jobmaster_private.exam_topics lt on lt.id=ls.topic_id join jobmaster_private.exam_subjects lsub on lsub.id=lt.subject_id
     where lsub.track=coalesce(v->>'track','BCS') and lower(btrim(lsub.title))=lower(btrim(coalesce(v->>'subject',''))) and lower(btrim(lt.title))=lower(btrim(coalesce(v->>'topic','')))
     order by(ls.id like '%:general')desc limit 1;
    if leafid is not null then insert into jobmaster_private.question_classification(question_id,subtopic_id,assigned_by) values(newid,leafid,u) on conflict(question_id) do nothing;end if;
    cnt:=cnt+1;
   end if;
  exception when others then errs:=errs||jsonb_build_object('row',v,'error',sqlerrm);
  end;
 end loop;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'sql_import:commit',cnt::text);
 return jsonb_build_object('ok',true,'imported',cnt,'duplicates',dup,'errors',errs);
end $$;
revoke all on function public.jobmaster_sql_import(jsonb) from public,anon;
grant execute on function public.jobmaster_sql_import(jsonb) to authenticated;

-- ───────────────────────── 5) Admin Dashboard stats ─────────────────────────
create or replace function public.jobmaster_admin_dashboard(p jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); who jobmaster_private.profiles; today date;
begin
 if u is null then raise exception 'Unauthorized';end if;
 select * into who from jobmaster_private.profiles where id=u;if not found or who.role<>'admin' then raise exception 'Admin access required';end if;
 today:=(now() at time zone 'Asia/Dhaka')::date;
 return jsonb_build_object(
  'total_questions',(select count(*) from jobmaster_private.questions q where not exists(select 1 from jobmaster_private.question_deleted d where d.id=q.id)),
  'pending_questions',(select count(*) from jobmaster_private.questions q where not q.verified and not exists(select 1 from jobmaster_private.question_deleted d where d.id=q.id)),
  'approved_questions',(select count(*) from jobmaster_private.questions q where q.verified and not exists(select 1 from jobmaster_private.question_deleted d where d.id=q.id)),
  'live_exam_questions',(select count(*) from jobmaster_private.live_exam_questions),
  'scheduled_questions',(select count(*) from jobmaster_private.live_exam_questions where exam_date>=today),
  'total_subjects',(select count(*) from jobmaster_private.course_nodes where level='subject'),
  'total_topics',(select count(*) from jobmaster_private.course_nodes where level='topic'),
  'today_participants',(select count(*) from jobmaster_private.live_exam_attempts where exam_date=today),
  'today_results',(select count(*) from jobmaster_private.live_exam_attempts where exam_date=today and submitted=1),
  'is_super_admin',who.is_super_admin);
end $$;
revoke all on function public.jobmaster_admin_dashboard(jsonb) from public,anon;
grant execute on function public.jobmaster_admin_dashboard(jsonb) to authenticated;

-- ───────────────────────── Cron: auto-finalize overdue daily live exam attempts ─────────────────────────
do $$
begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  if not exists(select 1 from cron.job where jobname='jobmaster-live-expiry') then
   perform cron.schedule('jobmaster-live-expiry','* * * * *','select public.jobmaster_live_expire();');
  end if;
 end if;
exception when others then null;
end $$;

commit;
-- Verify:
select * from jobmaster_private.live_exam_settings;
select count(*) live_exam_questions_total from jobmaster_private.live_exam_questions;
