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

-- 60 AI-assisted practice questions; NOT verified previous papers.
begin;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-1','{"id":"original-BCS-1","q":"“অগ্নিবীণা” কার রচনা?","o":["নজরুল","রবীন্দ্রনাথ","জসীমউদ্দীন","সুকান্ত"],"a":0,"e":"কাজী নজরুল ইসলামের প্রথম কাব্যগ্রন্থ অগ্নিবীণা।","subject":"বাংলা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('“অগ্নিবীণা” কার রচনা?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-2','{"id":"original-BCS-2","q":"Choose the correct spelling.","o":["Accomodation","Acommodation","Accommodation","Accommadation"],"a":2,"e":"Accommodation contains double c and double m.","subject":"English","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Choose the correct spelling.')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-3','{"id":"original-BCS-3","q":"বাংলাদেশের সংবিধান কার্যকর হয় কবে?","o":["২৬ মার্চ ১৯৭১","১৬ ডিসেম্বর ১৯৭২","৪ নভেম্বর ১৯৭২","১০ জানুয়ারি ১৯৭২"],"a":1,"e":"গৃহীত হয় ৪ নভেম্বর, কার্যকর হয় ১৬ ডিসেম্বর ১৯৭২।","subject":"বাংলাদেশ বিষয়াবলি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('বাংলাদেশের সংবিধান কার্যকর হয় কবে?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-4','{"id":"original-BCS-4","q":"একটি সংখ্যার ২৫% হলো ২০। সংখ্যাটি কত?","o":["৪০","৬০","৮০","১০০"],"a":2,"e":"২০/০.২৫ = ৮০।","subject":"গাণিতিক যুক্তি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('একটি সংখ্যার ২৫% হলো ২০। সংখ্যাটি কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-5','{"id":"original-BCS-5","q":"Which sentence is correct?","o":["He go to school.","He goes to school.","He going to school.","He gone to school."],"a":1,"e":"Third-person singular takes goes in the present simple.","subject":"English","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Which sentence is correct?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-6','{"id":"original-BCS-6","q":"CPU-এর পূর্ণরূপ কী?","o":["Central Process Utility","Computer Processing Unit","Central Processing Unit","Control Program Unit"],"a":2,"e":"CPU অর্থ Central Processing Unit।","subject":"কম্পিউটার","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('CPU-এর পূর্ণরূপ কী?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-7','{"id":"original-BCS-7","q":"বাংলা স্বরবর্ণ কতটি?","o":["৯","১০","১১","১২"],"a":2,"e":"প্রমিত বাংলা বর্ণমালায় স্বরবর্ণ ১১টি।","subject":"বাংলা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('বাংলা স্বরবর্ণ কতটি?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-8','{"id":"original-BCS-8","q":"অনুপাত ২:৩, যোগফল ৫০। ছোট সংখ্যাটি কত?","o":["১০","২০","২৫","৩০"],"a":1,"e":"৫০×২/৫ = ২০।","subject":"গাণিতিক যুক্তি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('অনুপাত ২:৩, যোগফল ৫০। ছোট সংখ্যাটি কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-9','{"id":"original-BCS-9","q":"“গীতাঞ্জলি” কার রচনা?","o":["রবীন্দ্রনাথ ঠাকুর","বঙ্কিমচন্দ্র","শরৎচন্দ্র","মাইকেল মধুসূদন"],"a":0,"e":"রবীন্দ্রনাথ ঠাকুর গীতাঞ্জলির রচয়িতা।","subject":"বাংলা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('“গীতাঞ্জলি” কার রচনা?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-10','{"id":"original-BCS-10","q":"“পদ্মা নদীর মাঝি” কোন ধরনের রচনা?","o":["নাটক","উপন্যাস","প্রবন্ধ","মহাকাব্য"],"a":1,"e":"মানিক বন্দ্যোপাধ্যায়ের পদ্মা নদীর মাঝি একটি উপন্যাস।","subject":"বাংলা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('“পদ্মা নদীর মাঝি” কোন ধরনের রচনা?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-11','{"id":"original-BCS-11","q":"সন্ধি বলতে কী বোঝায়?","o":["বাক্যের মিলন","পাশাপাশি ধ্বনির মিলন","শব্দের বিপরীত","ক্রিয়ার কাল"],"a":1,"e":"পাশাপাশি দুটি ধ্বনির মিলনকে সন্ধি বলে।","subject":"বাংলা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('সন্ধি বলতে কী বোঝায়?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-12','{"id":"original-BCS-12","q":"Plural of “criterion” is—","o":["criterions","criteria","criterias","criteriones"],"a":1,"e":"Criterion is singular; criteria is plural.","subject":"English","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Plural of “criterion” is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-13','{"id":"original-BCS-13","q":"Antonym of “scarce” is—","o":["rare","limited","abundant","few"],"a":2,"e":"Abundant means plentiful, the opposite of scarce.","subject":"English","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Antonym of “scarce” is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-14','{"id":"original-BCS-14","q":"He is good ___ mathematics.","o":["in","at","on","by"],"a":1,"e":"The idiomatic phrase is good at a subject.","subject":"English","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('He is good ___ mathematics.')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-15','{"id":"original-BCS-15","q":"১৫০ টাকার ১০% ছাড়ে মূল্য কত?","o":["১৩৫","১৪০","১২৫","১২০"],"a":0,"e":"ছাড় ১৫ টাকা; মূল্য ১৫০−১৫ = ১৩৫।","subject":"গাণিতিক যুক্তি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('১৫০ টাকার ১০% ছাড়ে মূল্য কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-16','{"id":"original-BCS-16","q":"১২ ও ১৮-এর গসাগু কত?","o":["৩","৬","১২","৩৬"],"a":1,"e":"উভয় সংখ্যার বৃহত্তম সাধারণ গুণনীয়ক ৬।","subject":"গাণিতিক যুক্তি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('১২ ও ১৮-এর গসাগু কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-17','{"id":"original-BCS-17","q":"ত্রিভুজের তিন কোণের সমষ্টি কত?","o":["৯০°","১৮০°","২৭০°","৩৬০°"],"a":1,"e":"ইউক্লিডীয় সমতলে ত্রিভুজের অন্তঃকোণের সমষ্টি ১৮০°।","subject":"গাণিতিক যুক্তি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('ত্রিভুজের তিন কোণের সমষ্টি কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-18','{"id":"original-BCS-18","q":"২, ৪, ৮, ১৬, পরের সংখ্যা কত?","o":["১৮","২৪","৩২","৬৪"],"a":2,"e":"প্রতিবার পূর্বের সংখ্যাকে ২ দিয়ে গুণ করা হয়েছে।","subject":"মানসিক দক্ষতা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('২, ৪, ৮, ১৬, পরের সংখ্যা কত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-19','{"id":"original-BCS-19","q":"১ কিলোবাইট (দশমিক সংজ্ঞা) কত বাইট?","o":["১০০","১০০০","১০২৪","১০০০০"],"a":1,"e":"SI দশমিক সংজ্ঞায় kB = ১০০০ বাইট; KiB = ১০২৪ বাইট।","subject":"কম্পিউটার","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('১ কিলোবাইট (দশমিক সংজ্ঞা) কত বাইট?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-20','{"id":"original-BCS-20","q":"HTML মূলত কী?","o":["Operating system","Markup language","Database","Antivirus"],"a":1,"e":"HTML হলো HyperText Markup Language।","subject":"কম্পিউটার","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('HTML মূলত কী?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-21','{"id":"original-BCS-21","q":"পানির রাসায়নিক সংকেত কী?","o":["CO₂","O₂","H₂O","NaCl"],"a":2,"e":"পানির অণুতে দুটি হাইড্রোজেন ও একটি অক্সিজেন পরমাণু থাকে।","subject":"সাধারণ বিজ্ঞান","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('পানির রাসায়নিক সংকেত কী?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-22','{"id":"original-BCS-22","q":"উদ্ভিদের সালোকসংশ্লেষণে কোন গ্যাস গ্রহণ করা হয়?","o":["অক্সিজেন","কার্বন ডাই-অক্সাইড","হিলিয়াম","নিয়ন"],"a":1,"e":"সালোকসংশ্লেষণে CO₂ ও পানি ব্যবহার করে শর্করা তৈরি হয়।","subject":"সাধারণ বিজ্ঞান","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('উদ্ভিদের সালোকসংশ্লেষণে কোন গ্যাস গ্রহণ করা হয়?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-23','{"id":"original-BCS-23","q":"বল পরিমাপের SI একক কী?","o":["জুল","ওয়াট","নিউটন","পাস্কাল"],"a":2,"e":"বল = ভর × ত্বরণ; একক kg·m/s² বা নিউটন।","subject":"সাধারণ বিজ্ঞান","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('বল পরিমাপের SI একক কী?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-24','{"id":"original-BCS-24","q":"ওজোন স্তর মূলত কোন স্তরে অবস্থিত?","o":["ট্রপোস্ফিয়ার","স্ট্র্যাটোস্ফিয়ার","মেসোস্ফিয়ার","এক্সোস্ফিয়ার"],"a":1,"e":"ওজোনের প্রধান ঘনত্ব স্ট্র্যাটোস্ফিয়ারে।","subject":"ভূগোল","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('ওজোন স্তর মূলত কোন স্তরে অবস্থিত?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-25','{"id":"original-BCS-25","q":"ভূমিকম্পের উৎসবিন্দুর ঠিক উপরের ভূ-পৃষ্ঠের স্থানকে কী বলে?","o":["উপকেন্দ্র","কেন্দ্র","অক্ষ","মেরু"],"a":0,"e":"ভূগর্ভস্থ focus-এর ঠিক উপরে পৃষ্ঠের বিন্দু epicenter বা উপকেন্দ্র।","subject":"ভূগোল","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('ভূমিকম্পের উৎসবিন্দুর ঠিক উপরের ভূ-পৃষ্ঠের স্থানকে কী বলে?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-26','{"id":"original-BCS-26","q":"জাতিসংঘ প্রতিষ্ঠিত হয় কোন সালে?","o":["১৯১৯","১৯৪৫","১৯৪৮","১৯৫২"],"a":1,"e":"জাতিসংঘ সনদ কার্যকর হয় ২৪ অক্টোবর ১৯৪৫।","subject":"আন্তর্জাতিক বিষয়াবলি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('জাতিসংঘ প্রতিষ্ঠিত হয় কোন সালে?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-27','{"id":"original-BCS-27","q":"SAARC-এর সদর দপ্তর কোথায়?","o":["ঢাকা","দিল্লি","কাঠমান্ডু","কলম্বো"],"a":2,"e":"দক্ষিণ এশীয় আঞ্চলিক সহযোগিতা সংস্থার সচিবালয় কাঠমান্ডুতে।","subject":"আন্তর্জাতিক বিষয়াবলি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('SAARC-এর সদর দপ্তর কোথায়?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-28','{"id":"original-BCS-28","q":"বাংলাদেশের জাতীয় সংসদ ভবনের স্থপতি কে?","o":["লুই আই কান","এফ আর খান","মাজহারুল ইসলাম","লে করবুসিয়ে"],"a":0,"e":"জাতীয় সংসদ ভবনের নকশা করেন Louis I. Kahn।","subject":"বাংলাদেশ বিষয়াবলি","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('বাংলাদেশের জাতীয় সংসদ ভবনের স্থপতি কে?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-29','{"id":"original-BCS-29","q":"রাষ্ট্রীয় কাজে জবাবদিহি বলতে কী বোঝায়?","o":["ইচ্ছামতো সিদ্ধান্ত","কাজের ব্যাখ্যা ও দায় গ্রহণ","গোপনীয়তা বৃদ্ধি","শুধু আদেশ পালন"],"a":1,"e":"জবাবদিহিতে কর্তৃপক্ষকে সিদ্ধান্ত ও কাজের ব্যাখ্যা দিতে এবং দায় নিতে হয়।","subject":"নৈতিকতা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('রাষ্ট্রীয় কাজে জবাবদিহি বলতে কী বোঝায়?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-BCS-30','{"id":"original-BCS-30","q":"স্বার্থের সংঘাত হলে উত্তম করণীয় কী?","o":["গোপন রাখা","ব্যক্তিগত লাভ নেওয়া","স্বার্থ প্রকাশ করে সিদ্ধান্ত থেকে সরে দাঁড়ানো","নথি মুছে ফেলা"],"a":2,"e":"স্বার্থ প্রকাশ ও সিদ্ধান্তপ্রক্রিয়া থেকে বিরত থাকা নিরপেক্ষতা রক্ষায় সহায়ক।","subject":"নৈতিকতা","track":"BCS","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('স্বার্থের সংঘাত হলে উত্তম করণীয় কী?')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-1','{"id":"original-EEE-1","q":"A 10 Ω resistor carries 2 A. Power is—","o":["20 W","40 W","10 W","5 W"],"a":1,"e":"P = I²R = 4×10 = 40 W.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A 10 Ω resistor carries 2 A. Power is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-2','{"id":"original-EEE-2","q":"The SI unit of resistance is—","o":["volt","ampere","ohm","watt"],"a":2,"e":"Resistance is measured in ohms (Ω).","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('The SI unit of resistance is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-3','{"id":"original-EEE-3","q":"Two 6 Ω resistors in parallel give—","o":["12 Ω","6 Ω","3 Ω","1 Ω"],"a":2,"e":"Equal parallel resistors give R/2 = 3 Ω.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Two 6 Ω resistors in parallel give—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-4','{"id":"original-EEE-4","q":"Kirchhoff’s current law follows conservation of—","o":["charge","energy","momentum","power factor"],"a":0,"e":"The algebraic sum of currents at a node is zero because charge is conserved.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Kirchhoff’s current law follows conservation of—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-5','{"id":"original-EEE-5","q":"Kirchhoff’s voltage law follows conservation of—","o":["mass","energy","frequency","flux density"],"a":1,"e":"The algebraic sum of potential changes around a closed loop is zero.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Kirchhoff’s voltage law follows conservation of—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-6','{"id":"original-EEE-6","q":"Capacitive reactance equals—","o":["2πfC","1/(2πfC)","f/C","C/f"],"a":1,"e":"For a capacitor Xc = 1/(ωC).","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Capacitive reactance equals—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-7','{"id":"original-EEE-7","q":"Inductive reactance increases when—","o":["frequency rises","frequency falls","inductance is zero","DC steady state is reached"],"a":0,"e":"XL = 2πfL, proportional to frequency.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Inductive reactance increases when—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-8','{"id":"original-EEE-8","q":"At series RLC resonance, impedance is—","o":["zero always","purely resistive","purely capacitive","infinite always"],"a":1,"e":"XL = XC, so net reactance is zero and impedance is R.","subject":"Circuits","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('At series RLC resonance, impedance is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-9','{"id":"original-EEE-9","q":"An ideal transformer conserves—","o":["voltage","current","power","resistance"],"a":2,"e":"With no losses, input and output real power are equal.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('An ideal transformer conserves—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-10','{"id":"original-EEE-10","q":"Transformer turns ratio Np/Ns = 2. If Vp = 220 V, Vs is—","o":["440 V","220 V","110 V","55 V"],"a":2,"e":"Vp/Vs = Np/Ns, so Vs = 110 V.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Transformer turns ratio Np/Ns = 2. If Vp = 220 V, Vs is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-11','{"id":"original-EEE-11","q":"DC motor back EMF primarily—","o":["aids supply","opposes supply","is always zero","is unrelated to speed"],"a":1,"e":"Back EMF opposes the applied voltage by Lenz’s law.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('DC motor back EMF primarily—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-12','{"id":"original-EEE-12","q":"Synchronous speed for 50 Hz, 4 poles is—","o":["750 rpm","1000 rpm","1500 rpm","3000 rpm"],"a":2,"e":"Ns = 120f/P = 120×50/4 = 1500 rpm.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Synchronous speed for 50 Hz, 4 poles is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-13','{"id":"original-EEE-13","q":"Induction motor slip at synchronous speed is—","o":["0","0.5","1","2"],"a":0,"e":"s = (Ns−Nr)/Ns; Nr = Ns gives zero slip.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Induction motor slip at synchronous speed is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-14','{"id":"original-EEE-14","q":"A DC generator converts—","o":["electrical to mechanical","mechanical to electrical","AC to DC only","heat to light"],"a":1,"e":"Mechanical shaft energy is converted to electrical energy.","subject":"Electrical Machines","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A DC generator converts—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-15','{"id":"original-EEE-15","q":"Three-phase balanced real power equals—","o":["VL IL","√3 VL IL cosφ","3 VL IL sinφ","VL/IL"],"a":1,"e":"For a balanced load P = √3 VL IL cosφ.","subject":"Power Systems","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Three-phase balanced real power equals—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-16','{"id":"original-EEE-16","q":"Power factor of an ideal resistor is—","o":["0","0.5","1","−1"],"a":2,"e":"Current and voltage are in phase, so cosφ = 1.","subject":"Power Systems","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Power factor of an ideal resistor is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-17','{"id":"original-EEE-17","q":"Transmission at higher voltage reduces losses for fixed power mainly by reducing—","o":["frequency","current","distance","insulation"],"a":1,"e":"For fixed power and power factor, current falls as voltage rises; I²R loss falls.","subject":"Transmission","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Transmission at higher voltage reduces losses for fixed power mainly by reducing—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-18','{"id":"original-EEE-18","q":"A fuse protects mainly against—","o":["overcurrent","low frequency","poor illumination","low power factor"],"a":0,"e":"Excess current heats and melts the fuse element.","subject":"Protection","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A fuse protects mainly against—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-19','{"id":"original-EEE-19","q":"A current transformer secondary should not be—","o":["shorted during maintenance","open-circuited under primary current","connected to a rated burden","earthed appropriately"],"a":1,"e":"An open CT secondary may develop dangerous high voltage.","subject":"Measurements","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A current transformer secondary should not be—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-20','{"id":"original-EEE-20","q":"A voltmeter is connected—","o":["in series","in parallel","only to earth","without leads"],"a":1,"e":"A voltmeter measures potential difference across two points.","subject":"Measurements","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A voltmeter is connected—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-21','{"id":"original-EEE-21","q":"Ideal op-amp input impedance is—","o":["zero","one ohm","infinite","negative always"],"a":2,"e":"The ideal op-amp draws no input current, implying infinite input impedance.","subject":"Analog Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Ideal op-amp input impedance is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-22','{"id":"original-EEE-22","q":"A silicon diode forward voltage is often approximated as—","o":["0.1 V","0.7 V","7 V","70 V"],"a":1,"e":"The common constant-drop approximation is around 0.7 V; actual drop depends on current and temperature.","subject":"Analog Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A silicon diode forward voltage is often approximated as—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-23','{"id":"original-EEE-23","q":"A NAND gate outputs zero when—","o":["both inputs are 0","exactly one input is 1","both inputs are 1","always"],"a":2,"e":"NAND is NOT(AND); only input 11 produces output 0.","subject":"Digital Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A NAND gate outputs zero when—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-24','{"id":"original-EEE-24","q":"Binary 1010 equals decimal—","o":["8","9","10","12"],"a":2,"e":"1×8 + 0×4 + 1×2 + 0 = 10.","subject":"Digital Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Binary 1010 equals decimal—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-25','{"id":"original-EEE-25","q":"A buck converter ideally—","o":["steps DC voltage down","steps DC voltage up only","converts DC to 50 Hz AC","needs no switch"],"a":0,"e":"In continuous conduction, ideal buck Vout = D Vin for 0≤D≤1.","subject":"Power Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A buck converter ideally—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-26','{"id":"original-EEE-26","q":"An SCR is turned on conventionally by—","o":["gate pulse under forward bias","reverse bias only","opening anode","removing all supply"],"a":0,"e":"A gate trigger under forward bias initiates conduction.","subject":"Power Electronics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('An SCR is turned on conventionally by—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-27','{"id":"original-EEE-27","q":"Negative feedback generally improves—","o":["sensitivity to parameter variation","robustness to parameter variation","open-loop gain always","sensor noise always"],"a":1,"e":"Negative feedback reduces closed-loop sensitivity to plant parameter changes.","subject":"Control Systems","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Negative feedback generally improves—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-28','{"id":"original-EEE-28","q":"The Laplace transform of 1 for t≥0 is—","o":["s","1/s","1/s²","0"],"a":1,"e":"The integral of e^(−st) from 0 to infinity equals 1/s for Re(s)>0.","subject":"Engineering Mathematics","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('The Laplace transform of 1 for t≥0 is—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-29','{"id":"original-EEE-29","q":"Protective earthing is intended to—","o":["increase touch voltage","provide a fault-current path","replace all fuses","increase insulation failure"],"a":1,"e":"Earthing provides a low-impedance fault path and helps protective devices operate.","subject":"Safety","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('Protective earthing is intended to—')) on conflict do nothing;
insert into jobmaster_private.questions(id,data,fingerprint) values('original-EEE-30','{"id":"original-EEE-30","q":"A solar photovoltaic cell converts—","o":["heat to shaft power","light to electrical energy","wind to electricity","DC to AC"],"a":1,"e":"The photovoltaic effect converts incident light into electrical energy.","subject":"Renewable Energy","track":"EEE","kind":"ai_generated","source":"JobMaster AI-assisted practice • editorial review pending"}'::jsonb,jobmaster_private.fingerprint('A solar photovoltaic cell converts—')) on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:7') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:8') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:9') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:0:10') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bangla:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:7') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:8') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:0:9') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:english:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:bd:1:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:international:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:geography:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:science:1:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ict:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:math:2:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:mental:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('BCS:ethics:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:circuit:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:machines:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:generation:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:transmission:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:power-electronics:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:control:1:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:measurement:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:analog:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:digital:0:7') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:safety:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:protection:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:renewable:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:micro:0:7') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:0') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:1') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:2') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:3') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:4') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:5') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:6') on conflict do nothing;
insert into jobmaster_private.topics values('EEE:eng-math:0:7') on conflict do nothing;
commit;
