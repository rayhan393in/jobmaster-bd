-- JobMaster BD cloud backend v1. Run in a NEW Supabase project's SQL Editor.
-- Does not delete or alter unrelated tables. Safe to re-run this version.
-- Full answer keys and snapshots live in a NON-EXPOSED, deny-by-default schema.
begin;
create schema if not exists jobmaster_private;
revoke all on schema jobmaster_private from public, anon, authenticated;
create table if not exists jobmaster_private.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null, email text not null, role text not null default 'student' check(role in ('student','admin')), created timestamptz not null default now()
);
create table if not exists jobmaster_private.questions (
 id text primary key, data jsonb not null, fingerprint text unique not null, verified boolean not null default false,
 check(data->>'track' in ('BCS','EEE')), check(jsonb_array_length(data->'o')=4),
 check((data->>'a')::int between 0 and 3), check(length(btrim(data->>'e'))>=8)
);
create index if not exists cloud_questions_track on jobmaster_private.questions ((data->>'track'),verified);
create table if not exists jobmaster_private.tasks (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, track text not null check(track in ('BCS','EEE')),
 title text not null,subject text not null,minutes int not null check(minutes between 15 and 240),done int not null default 0 check(done in(0,1))
);
create index if not exists cloud_tasks_owner on jobmaster_private.tasks(user_id,track);
create table if not exists jobmaster_private.exams (
 id uuid primary key default gen_random_uuid(),title text not null,track text not null check(track in ('BCS','EEE')),
 starts bigint not null, ends bigint not null,publish bigint not null,duration int not null check(duration between 60 and 14400),question_ids jsonb not null,
 check(ends>starts),check(publish>=ends)
);
create table if not exists jobmaster_private.sessions (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users on delete cascade,track text not null,
 started bigint not null,deadline bigint not null,snapshot jsonb not null,submitted int not null default 0 check(submitted in(0,1)),
 score numeric,correct int,answered int,exam_id uuid references jobmaster_private.exams(id), unique(user_id,exam_id)
);
create index if not exists cloud_session_owner on jobmaster_private.sessions(user_id,track,submitted);
create index if not exists cloud_session_expiry on jobmaster_private.sessions(deadline) where submitted=0;
create table if not exists jobmaster_private.answers (
 session_id uuid references jobmaster_private.sessions on delete cascade,question int not null check(question>=0),choice int not null check(choice between 0 and 3),primary key(session_id,question)
);
create table if not exists jobmaster_private.bookmarks (
 user_id uuid references auth.users on delete cascade,question_id text references jobmaster_private.questions on delete cascade,primary key(user_id,question_id)
);
create table if not exists jobmaster_private.progress (
 user_id uuid references auth.users on delete cascade,topic_id text not null,done int not null check(done in(0,1)),primary key(user_id,topic_id)
);
create table if not exists jobmaster_private.topics(id text primary key);
create table if not exists jobmaster_private.limits(key text primary key,hits int not null,reset_at timestamptz not null);
create table if not exists jobmaster_private.audit (
 id bigint generated always as identity primary key, actor uuid,action text not null,entity text,at timestamptz not null default now()
);
do $$ declare t text; begin foreach t in array array['profiles','questions','tasks','exams','sessions','answers','bookmarks','progress','topics','limits','audit'] loop
 execute format('alter table jobmaster_private.%I enable row level security',t);
 execute format('revoke all on jobmaster_private.%I from public, anon, authenticated',t);
end loop;end $$;

create or replace function jobmaster_private.now_ms() returns bigint language sql volatile set search_path='' as $$select floor(extract(epoch from clock_timestamp())*1000)::bigint$$;
create or replace function jobmaster_private.fingerprint(q text) returns text language sql immutable set search_path='' as $$select md5(lower(regexp_replace(q,'[^[:alnum:]]','','g')))$$;
create or replace function jobmaster_private.finish(sid uuid) returns void language plpgsql set search_path='' as $$
declare s jobmaster_private.sessions; n int; c int;
begin
 select * into s from jobmaster_private.sessions where id=sid for update;
 if not found or s.submitted=1 then return;end if;
 select count(*),count(*) filter(where (s.snapshot->a.question->>'a')::int=a.choice) into n,c from jobmaster_private.answers a where a.session_id=sid;
 update jobmaster_private.sessions set submitted=1,answered=n,correct=c,score=c-(n-c)*0.5 where id=sid;
end $$;
create or replace function jobmaster_private.expire() returns void language plpgsql set search_path='' as $$
declare sid uuid;begin for sid in select id from jobmaster_private.sessions where submitted=0 and deadline<=jobmaster_private.now_ms() for update skip locked loop perform jobmaster_private.finish(sid);end loop;end $$;
create or replace function public.jobmaster_expire() returns void language sql security definer set search_path='' as $$ select jobmaster_private.expire() $$;
revoke all on function public.jobmaster_expire() from public, anon, authenticated;
grant execute on function public.jobmaster_expire() to service_role;
create or replace function jobmaster_private.reviewable(s jobmaster_private.sessions) returns boolean language sql stable set search_path='' as $$select s.exam_id is null or exists(select 1 from jobmaster_private.exams e where e.id=s.exam_id and e.publish<=jobmaster_private.now_ms())$$;
create or replace function jobmaster_private.result(s jobmaster_private.sessions) returns jsonb language sql stable set search_path='' as $$select jsonb_build_object('id',s.id,'score',s.score,'correct',s.correct,'total',jsonb_array_length(s.snapshot),'answered',s.answered,'created',to_timestamp(s.started/1000.0))$$;
create or replace function jobmaster_private.validate_question(q jsonb) returns void language plpgsql set search_path='' as $$
declare v jsonb;begin
 if q->>'track' not in ('BCS','EEE') or q->>'track' is null or length(btrim(coalesce(q->>'subject','')))<2 or length(btrim(coalesce(q->>'q','')))<8 or length(q->>'q')>4000 or length(btrim(coalesce(q->>'e','')))<8 or length(q->>'e')>6000 or length(btrim(coalesce(q->>'source','')))<3 then raise exception 'Invalid question fields';end if;
 if jsonb_typeof(q->'o') is distinct from 'array' then raise exception 'Four options required';end if;
 if jsonb_array_length(q->'o')<>4 or (q->>'a')::int not between 0 and 3 or q->>'a' is null then raise exception 'Invalid options or answer';end if;
 for v in select value from jsonb_array_elements(q->'o') loop if jsonb_typeof(v)<>'string' or length(btrim(v#>>'{}'))=0 or length(v#>>'{}')>1000 then raise exception 'Invalid option';end if;end loop;
 if (select count(distinct lower(btrim(value))) from jsonb_array_elements_text(q->'o'))<>4 then raise exception 'Options must be distinct';end if;
 if q->>'kind' not in ('original','ai_generated','previous') or q->>'kind' is null then raise exception 'Invalid question kind';end if;
 if q->>'kind'='previous' and q->>'source' !~ '^https://' then raise exception 'Previous question needs HTTPS source';end if;
end $$;

create or replace function public.jobmaster_action(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid(); who jobmaster_private.profiles; a text:=p->>'action'; tr text:=case when p->>'track'='EEE' then 'EEE' else 'BCS' end;
 s jobmaster_private.sessions; ex jobmaster_private.exams; qs jsonb; q jsonb; sid uuid; eid uuid; qid text; i int; n int; c int; mins int; ms bigint; dur bigint;
 outj jsonb; arr jsonb; weak jsonb; v text; subjects text[]; lim int; until_at timestamptz; cnt int;
begin
 if u is null then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.profiles(id,name,email) select id,left(coalesce(nullif(raw_user_meta_data->>'name',''),split_part(email,'@',1),'Student'),80),coalesce(email,'') from auth.users where id=u on conflict(id) do nothing;
 select * into who from jobmaster_private.profiles where id=u;if not found then raise exception 'Unauthorized';end if;
 -- Persistent per-user rate limit. Role never comes from client metadata.
 insert into jobmaster_private.limits values(u::text,1,now()+interval '1 minute') on conflict(key) do update set hits=case when jobmaster_private.limits.reset_at<now() then 1 else jobmaster_private.limits.hits+1 end,reset_at=case when jobmaster_private.limits.reset_at<now() then now()+interval '1 minute' else jobmaster_private.limits.reset_at end returning hits into cnt;
 if cnt>300 then raise exception 'Too many requests';end if;
 perform jobmaster_private.expire();
 if a='actor' then return to_jsonb(who)-'created';end if;
 if a='pdf' then
  insert into jobmaster_private.limits values(u::text||':pdf',1,now()+interval '1 minute') on conflict(key) do update set hits=case when jobmaster_private.limits.reset_at<now() then 1 else jobmaster_private.limits.hits+1 end,reset_at=case when jobmaster_private.limits.reset_at<now() then now()+interval '1 minute' else jobmaster_private.limits.reset_at end returning hits into cnt;
  if cnt>8 then raise exception 'Too many PDF requests';end if;a:='workspace';
 end if;
 if a='workspace' then
  select coalesce(jsonb_agg(jobmaster_private.result(ss) order by ss.started desc),'[]') into arr from jobmaster_private.sessions ss where ss.user_id=u and ss.track=tr and ss.submitted=1 and jobmaster_private.reviewable(ss);
  select coalesce(jsonb_agg(to_jsonb(w) order by w.accuracy),'[]') into weak from (
   select ss.snapshot->aa.question->>'subject' subject,count(*) total,count(*) filter(where (ss.snapshot->aa.question->>'a')::int<>aa.choice) wrong,
   round(100.0*count(*) filter(where (ss.snapshot->aa.question->>'a')::int=aa.choice)/count(*)) accuracy from jobmaster_private.sessions ss join jobmaster_private.answers aa on aa.session_id=ss.id where ss.user_id=u and ss.track=tr and ss.submitted=1 and jobmaster_private.reviewable(ss) group by 1
  )w;
  return jsonb_build_object('user',to_jsonb(who)-'created','tasks',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from jobmaster_private.tasks t where t.user_id=u and t.track=tr),'results',arr,'weakness',weak,
   'exams',(select coalesce(jsonb_agg(to_jsonb(e) - 'question_ids' order by starts desc),'[]') from jobmaster_private.exams e where track=tr),
   'active',(select jsonb_build_object('id',ss.id,'deadline',ss.deadline) from jobmaster_private.sessions ss where ss.user_id=u and ss.track=tr and ss.submitted=0 order by ss.started desc limit 1),
   'bookmarks',(select coalesce(jsonb_agg(jsonb_build_object('question_id',b.question_id)),'[]') from jobmaster_private.bookmarks b where b.user_id=u),
   'questionCount',(select count(*) from jobmaster_private.questions x where x.data->>'track'=tr));
 end if;
 if a='progress' then return jsonb_build_object('progress',(select coalesce(jsonb_agg(jsonb_build_object('topic_id',r.topic_id,'done',r.done)),'[]') from jobmaster_private.progress r where r.user_id=u));end if;
 if a='topic' then
  if not exists(select 1 from jobmaster_private.topics where id=p->>'topicId') then raise exception 'Unknown topic';end if;
  insert into jobmaster_private.progress values(u,p->>'topicId',case when (p->>'done')::boolean then 1 else 0 end) on conflict(user_id,topic_id) do update set done=excluded.done;return '{"ok":true}';
 end if;
 if a='routine' then
  mins:=(p->>'minutes')::int;if mins is null or mins not between 15 and 240 then raise exception 'Minutes must be 15–240';end if;
  select array_agg(subject order by wrong desc) into subjects from(select ss.snapshot->aa.question->>'subject' subject,count(*) wrong from jobmaster_private.sessions ss join jobmaster_private.answers aa on aa.session_id=ss.id where ss.user_id=u and ss.track=tr and ss.submitted=1 and jobmaster_private.reviewable(ss) and (ss.snapshot->aa.question->>'a')::int<>aa.choice group by 1 order by 2 desc limit 3) w;
  subjects:=coalesce(subjects,'{}'::text[])||case when tr='EEE' then array['Electrical Machines','Circuits','Power Systems'] else array['বাংলা','English','গাণিতিক যুক্তি'] end;
  delete from jobmaster_private.tasks where user_id=u and track=tr;i:=0;
  for v in select x from unnest(subjects) with ordinality z(x,ord) group by x order by min(ord) limit 3 loop i:=i+1;insert into jobmaster_private.tasks(user_id,track,title,subject,minutes) values(u,tr,(array['থিওরি ও দুর্বল ধারণা ঝালাই','২০টি MCQ অনুশীলন','পূর্বের ভুল ও রিভিশন'])[i],v,mins);end loop;return '{"ok":true}';
 end if;
 if a='toggle' then update jobmaster_private.tasks set done=1-done where id=(p->>'id')::uuid and user_id=u;return '{"ok":true}';end if;
 if a='bookmark' then
  qid:=p->>'questionId';if not exists(select 1 from jobmaster_private.questions where id=qid) then raise exception 'Question not found';end if;
  if exists(select 1 from jobmaster_private.bookmarks where user_id=u and question_id=qid) then delete from jobmaster_private.bookmarks where user_id=u and question_id=qid;return '{"bookmarked":false}';end if;
  insert into jobmaster_private.bookmarks values(u,qid);return '{"bookmarked":true}';
 end if;
 if a='start' then
  perform pg_advisory_xact_lock(hashtext(u::text));ms:=jobmaster_private.now_ms();eid:=null;
  if coalesce(p->>'examId','')<>'' then
   select * into ex from jobmaster_private.exams where id=(p->>'examId')::uuid;
   if not found or ms<ex.starts or ms>=ex.ends then raise exception 'Outside scheduled exam window';end if;
   select id into sid from jobmaster_private.sessions where user_id=u and exam_id=ex.id;if found then return jsonb_build_object('id',sid);end if;
   select jsonb_agg(x.data order by z.ord) into qs from jsonb_array_elements_text(ex.question_ids) with ordinality z(qid,ord) join jobmaster_private.questions x on x.id=z.qid;
   tr:=ex.track;dur:=least(ex.duration::bigint*1000,ex.ends-ms);eid:=ex.id;
  else
   n:=coalesce((p->>'count')::int,30);if n not between 1 and 100 then raise exception 'Count must be 1–100';end if;
   select jsonb_agg(x.data) into qs from(select z.data from jobmaster_private.questions z where z.data->>'track'=tr
    and (coalesce(p->>'mode','all')<>'bookmarked' or exists(select 1 from jobmaster_private.bookmarks b where b.user_id=u and b.question_id=z.id))
    and (coalesce(p->>'mode','all')<>'incorrect' or exists(select 1 from jobmaster_private.sessions ss join jobmaster_private.answers aa on aa.session_id=ss.id where ss.user_id=u and ss.submitted=1 and jobmaster_private.reviewable(ss) and ss.snapshot->aa.question->>'id'=z.id and (ss.snapshot->aa.question->>'a')::int<>aa.choice))
    order by random() limit n)x;
   dur:=greatest(600000,coalesce(jsonb_array_length(qs),0)*60000);
  end if;
  if qs is null or jsonb_array_length(qs)=0 then raise exception 'No questions in this mode';end if;
  insert into jobmaster_private.sessions(user_id,track,started,deadline,snapshot,exam_id) values(u,tr,ms,ms+dur,qs,eid) returning id into sid;return jsonb_build_object('id',sid);
 end if;
 if a in ('attempt','answer','submit') then
  select * into s from jobmaster_private.sessions where id=(p->>'id')::uuid and user_id=u for update;if not found then raise exception 'Attempt not found';end if;
  if a='answer' then
   if s.submitted=1 or jobmaster_private.now_ms()>=s.deadline then raise exception 'Session closed';end if;
   i:=(p->>'question')::int;c:=(p->>'choice')::int;
   if i is null or c is null or i<0 or i>=jsonb_array_length(s.snapshot) or c not between 0 and 3 then raise exception 'Invalid answer';end if;
   insert into jobmaster_private.answers values(s.id,i,c) on conflict(session_id,question) do update set choice=excluded.choice;return '{"ok":true}';
  end if;
  if a='submit' then perform jobmaster_private.finish(s.id);select * into s from jobmaster_private.sessions where id=s.id;
   if not jobmaster_private.reviewable(s) then return '{"pending":true,"result":null,"review":[]}';end if;
   return jsonb_build_object('result',jobmaster_private.result(s),'review',s.snapshot);
  end if;
  return jsonb_build_object('id',s.id,'submitted',s.submitted,'deadline',s.deadline,'now',jobmaster_private.now_ms(),
   'questions',(select jsonb_agg(jsonb_build_object('id',ord-1,'questionId',value->>'id','q',value->>'q','o',value->'o') order by ord) from jsonb_array_elements(s.snapshot) with ordinality t(value,ord)),
   'answers',(select coalesce(jsonb_agg(jsonb_build_object('question',aa.question,'choice',aa.choice)),'[]') from jobmaster_private.answers aa where aa.session_id=s.id),
   'result',case when s.submitted=1 and jobmaster_private.reviewable(s) then jobmaster_private.result(s) else null end,
   'review',case when s.submitted=1 and jobmaster_private.reviewable(s) then s.snapshot else null end);
 end if;
 if a='leaderboard' then
  select * into ex from jobmaster_private.exams where id=(p->>'exam')::uuid;if not found then return '{"rows":[]}';end if;
  if ex.publish>jobmaster_private.now_ms() then return '{"rows":[],"pending":true}';end if;
  return jsonb_build_object('title',ex.title,'rows',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select pr.name,ss.score,ss.correct,ss.started from jobmaster_private.sessions ss join jobmaster_private.profiles pr on pr.id=ss.user_id where ss.exam_id=ex.id and ss.submitted=1 order by ss.score desc,ss.started limit 100)x));
 end if;
 -- Everything below is admin-only, even for direct RPC callers.
 if who.role<>'admin' then raise exception 'Admin access required';end if;
 if a='admin' then
  return jsonb_build_object('questions',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select qx.id,qx.data->>'q' body,qx.data->>'subject' subject,qx.data->>'track' track,(qx.data->'o')::text options,(qx.data->>'a')::int answer,qx.data->>'e' explanation,qx.data->>'kind' kind,qx.data->>'source' source,case when qx.verified then 1 else 0 end verified from jobmaster_private.questions qx order by qx.id desc limit 200)x),
   'students',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,email,role,created from jobmaster_private.profiles order by created desc limit 200)x),
   'exams',(select coalesce(jsonb_agg(to_jsonb(e)-'question_ids' order by e.starts desc),'[]') from jobmaster_private.exams e),
   'stats',jsonb_build_object('questions',(select count(*) from jobmaster_private.questions),'students',(select count(*) from jobmaster_private.profiles),'active',(select count(*) from jobmaster_private.sessions where submitted=0)));
 end if;
 if a='fingerprints' then return jsonb_build_object('items',(select coalesce(jsonb_agg(jsonb_build_object('id',qx.id,'q',qx.data->>'q')),'[]') from jobmaster_private.questions qx));end if;
 if a in ('question','update','import') then
  qs:=case when a='import' then p->'questions' else jsonb_build_array(p->'question') end;
  if jsonb_typeof(qs) is distinct from 'array' then raise exception 'Invalid question list';end if;
  if jsonb_array_length(qs) not between 1 and 10000 then raise exception 'Maximum 10000 questions per import';end if;
  for q in select value from jsonb_array_elements(qs) loop
   perform jobmaster_private.validate_question(q);qid:=case when a='update' then p->>'id' else gen_random_uuid()::text end;q:=q||jsonb_build_object('id',qid);
   if a='update' then update jobmaster_private.questions set data=q,fingerprint=jobmaster_private.fingerprint(q->>'q'),verified=false where id=qid;if not found then raise exception 'Question not found';end if;
   else insert into jobmaster_private.questions(id,data,fingerprint) values(qid,q,jobmaster_private.fingerprint(q->>'q'));end if;
   insert into jobmaster_private.audit(actor,action,entity) values(u,a,qid);
  end loop;return jsonb_build_object('ok',true,'imported',jsonb_array_length(qs));
 end if;
 if a='verify' then update jobmaster_private.questions set verified=(p->>'verified')::boolean where id=p->>'id';if not found then raise exception 'Question not found';end if;insert into jobmaster_private.audit(actor,action,entity) values(u,a,p->>'id');return '{"ok":true}';end if;
 if a='schedule' then
  ms:=jobmaster_private.now_ms();n:=(p->>'count')::int;
  if p->>'starts' is null or p->>'ends' is null or p->>'publish' is null or p->>'duration' is null or n is null or length(btrim(coalesce(p->>'title','')))<4 or (p->>'starts')::bigint<ms or (p->>'ends')::bigint<=(p->>'starts')::bigint or (p->>'publish')::bigint<(p->>'ends')::bigint or (p->>'duration')::int not between 60 and 14400 or n not between 1 and 200 then raise exception 'Invalid future exam schedule';end if;
  select jsonb_agg(x.id) into qs from(select qx.id from jobmaster_private.questions qx where qx.data->>'track'=tr and qx.verified order by qx.id limit n)x;
  if coalesce(jsonb_array_length(qs),0)<n then raise exception 'Not enough verified questions';end if;
  insert into jobmaster_private.exams(title,track,starts,ends,publish,duration,question_ids) values(p->>'title',tr,(p->>'starts')::bigint,(p->>'ends')::bigint,(p->>'publish')::bigint,(p->>'duration')::int,qs) returning id into eid;
  insert into jobmaster_private.audit(actor,action,entity) values(u,a,eid::text);return '{"ok":true}';
 end if;
 raise exception 'Unknown action';
end $$;
revoke all on all functions in schema jobmaster_private from public,anon,authenticated;
revoke all on function public.jobmaster_action(jsonb) from public,anon;
grant execute on function public.jobmaster_action(jsonb) to authenticated;
-- Each RPC is a DB transaction; clients receive no direct table/key access.
commit;
