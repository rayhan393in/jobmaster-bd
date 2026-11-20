-- JobMaster Platform V4. Run AFTER Admin-Courses-V3.sql. Additive, rerunnable.
-- Existing BCS/EEE questions, accounts, attempts and routines are retained.
begin;
select pg_advisory_xact_lock(hashtext('jobmaster-platform-v4'));
create table if not exists jobmaster_private.exam_categories(id text primary key,title text not null unique check(length(title) between 2 and 100));
create table if not exists jobmaster_private.course_meta(course_id text primary key references jobmaster_private.courses(id),parent_id text references jobmaster_private.courses(id),category_id text references jobmaster_private.exam_categories(id));
create table if not exists jobmaster_private.question_deleted(id text primary key references jobmaster_private.questions(id) on delete cascade,actor uuid,created timestamptz default now());
create table if not exists jobmaster_private.live_meta(exam_id uuid primary key references jobmaster_private.exams(id),course_id text not null references jobmaster_private.courses(id),kind text not null check(kind in ('daily','weekly','mock')),marks int not null check(marks between 1 and 100),snapshot jsonb not null,cancelled boolean not null default false);
create index if not exists live_meta_course on jobmaster_private.live_meta(course_id,exam_id);
do $$declare t text;begin foreach t in array array['exam_categories','course_meta','question_deleted','live_meta'] loop execute format('alter table jobmaster_private.%I enable row level security',t);execute format('revoke all on jobmaster_private.%I from public,anon,authenticated',t);end loop;end $$;
insert into jobmaster_private.exam_categories values('job','Job Preparation') on conflict do nothing;
insert into jobmaster_private.courses(id,title,description,status,legacy_track) values('EEE-PETROBANGLA','PetroBangla — EEE','স্বতন্ত্র প্রশ্নব্যাংক; admin taxonomy ও প্রশ্ন যোগ করবেন।','published','EEE') on conflict do nothing;
insert into jobmaster_private.course_meta values('EEE-PETROBANGLA','EEE','job') on conflict do nothing;
-- Add a deleted-row exclusion to the existing V3 engine, without replacing it.
do $$declare def text;begin
 select pg_get_functiondef('public.jobmaster_courses(jsonb)'::regprocedure) into def;
 if position('question_deleted' in def)=0 then
 def:=replace(def,'join jobmaster_private.questions q on q.id=m.question_id','join jobmaster_private.questions q on q.id=m.question_id and not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id)');
 execute def;end if;
 select pg_get_functiondef('public.jobmaster_courses(jsonb)'::regprocedure) into def;
 if position('workspace_both' in def)=0 then
 def:=replace(def,'where (c is null or m.course_id=c)','where (coalesce((p->>''workspace_both'')::boolean,false)=false or m.course_id in (''BCS'',''EEE'')) and (c is null or m.course_id=c)');execute def;end if;
end $$;
-- Subject and topic practice are hierarchical filters, not fallback mixed pools.
do $$declare def text;begin
 select pg_get_functiondef('public.jobmaster_courses(jsonb)'::regprocedure) into def;
 if position('V4_START_SCOPE' in def)=0 then
 def:=replace(def,'(leaf is null or m.subtopic_id=leaf)','(leaf is null or m.subtopic_id=leaf) /* V4_START_SCOPE */ and (nullif(p->>''topic_id'','''') is null or m.subtopic_id in(select id from jobmaster_private.course_nodes where parent_id=p->>''topic_id'' and course_id=c)) and (nullif(p->>''subject_id'','''') is null or m.subtopic_id in(select l.id from jobmaster_private.course_nodes l join jobmaster_private.course_nodes t on t.id=l.parent_id where t.parent_id=p->>''subject_id'' and l.course_id=c))');execute def;end if;
end $$;
-- Prevent soft-deleted questions resurfacing in legacy mixed/custom practice.
do $$declare def text;begin
 select pg_get_functiondef('public.jobmaster_action(jsonb)'::regprocedure) into def;
 if position('question_deleted' in def)=0 then def:=replace(def,'from jobmaster_private.questions z where z.data','from jobmaster_private.questions z where not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=z.id) and z.data');execute def;end if;
 select pg_get_functiondef('public.jobmaster_custom_exam(jsonb)'::regprocedure) into def;
 if position('question_deleted' in def)=0 then def:=replace(def,'where q.verified and q.data','where not exists(select 1 from jobmaster_private.question_deleted dd where dd.id=q.id) and q.verified and q.data');execute def;end if;
end $$;
create or replace function public.jobmaster_upgrade(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();adm boolean;a text:=p->>'action';c text:=p->>'course_id';r record;ex record;x jsonb;snap jsonb;ids jsonb;result_ids jsonb:='[]';eid uuid;sid uuid;vtitle text;par text;cat text;seen text[];n int;i int;cnt int;mins int;occ int;st bigint;en bigint;ms bigint:=jobmaster_private.now_ms();step_ms bigint;key text;
begin
 if u is null then raise exception 'Unauthorized';end if;
 select role='admin' into adm from jobmaster_private.profiles where id=u;
 if adm is null then raise exception 'Unauthorized';end if;
 if a not in ('catalog','exams','live_start') and not adm then raise exception 'Admin access required';end if;
 key:=case when a='ai_authorize' then 'ai:' else 'upgrade:' end||u;
 insert into jobmaster_private.limits(key,hits,reset_at) values(key,1,clock_timestamp()+interval '1 minute') on conflict on constraint limits_pkey do update set hits=case when jobmaster_private.limits.reset_at<clock_timestamp() then 1 else jobmaster_private.limits.hits+1 end,reset_at=case when jobmaster_private.limits.reset_at<clock_timestamp() then clock_timestamp()+interval '1 minute' else jobmaster_private.limits.reset_at end returning hits into n;
 if n>(case when a='ai_authorize' then 10 else 100 end) then raise exception 'Rate limit exceeded';end if;
 if a in ('boot','catalog') then return jsonb_build_object('categories',(select coalesce(jsonb_agg(to_jsonb(t) order by t.title),'[]') from jobmaster_private.exam_categories t),'meta',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from jobmaster_private.course_meta t where adm or exists(select 1 from jobmaster_private.courses c where c.id=t.course_id and c.status='published')));end if;
 if a='ai_authorize' then return '{"ok":true}';end if;
 if a='exams' then return jsonb_build_object('now',ms,'exams',(select coalesce(jsonb_agg(to_jsonb(t) order by starts desc),'[]') from(select e.id,e.title,e.starts,e.ends,e.publish,e.duration,m.course_id,m.kind,m.marks,m.cancelled,c.title course_title from jobmaster_private.exams e join jobmaster_private.live_meta m on m.exam_id=e.id join jobmaster_private.courses c on c.id=m.course_id where (nullif(p->>'course_id','') is null or m.course_id=p->>'course_id') and (adm or (c.status='published' and not m.cancelled)) order by e.starts desc limit 300)t));end if;
 if a='category_save' then vtitle:=trim(p->>'title');if vtitle is null or length(vtitle) not between 2 and 100 then raise exception 'Invalid category title';end if;cat:=coalesce(nullif(p->>'id',''),gen_random_uuid()::text);insert into jobmaster_private.exam_categories values(cat,vtitle) on conflict(id) do update set title=excluded.title;insert into jobmaster_private.audit(actor,action,entity) values(u,'v4:category_save',cat);return jsonb_build_object('id',cat);end if;
 if a='course_meta' then
  if not exists(select 1 from jobmaster_private.courses where id=c) then raise exception 'Unknown course';end if;
  par:=nullif(p->>'parent_id','');cat:=nullif(p->>'category_id','');if c in ('BCS','EEE') and par is not null then raise exception 'Root workspace cannot have parent';end if;
  seen:=array[c];vtitle:=par;while vtitle is not null loop if vtitle=any(seen) then raise exception 'Course hierarchy cycle';end if;seen:=array_append(seen,vtitle);if not exists(select 1 from jobmaster_private.courses where id=vtitle) then raise exception 'Unknown parent';end if;select parent_id into vtitle from jobmaster_private.course_meta where course_id=vtitle;end loop;
  insert into jobmaster_private.course_meta values(c,par,cat) on conflict(course_id) do update set parent_id=excluded.parent_id,category_id=excluded.category_id;
 elsif a='question_delete' then
  if not exists(select 1 from jobmaster_private.questions where id=p->>'id' and coalesce(data->>'course_id',data->>'track')=c) then raise exception 'Original owning course required';end if;
  if (select count(*) from jobmaster_private.course_questions where question_id=p->>'id')>1 then raise exception 'Shared question: unpublish instead of deleting';end if;
  if coalesce((p->>'restore')::boolean,false) then delete from jobmaster_private.question_deleted where id=p->>'id';else insert into jobmaster_private.question_deleted(id,actor) values(p->>'id',u) on conflict do nothing;end if;
  update jobmaster_private.questions set verified=false where id=p->>'id';
 elsif a='exam_cancel' then
  select e.* into ex from jobmaster_private.exams e join jobmaster_private.live_meta m on m.exam_id=e.id where e.id=(p->>'id')::uuid for update of e;
  if not found or ms>=ex.starts then raise exception 'Only future exams may be cancelled';end if;
  update jobmaster_private.live_meta set cancelled=true where exam_id=ex.id;
  update jobmaster_private.exams set question_ids='[]'::jsonb where id=ex.id; -- release reservations; snapshot retained
 elsif a='exam_save' then
  perform pg_advisory_xact_lock(hashtext('jobmaster-v4-schedule'));
  select * into r from jobmaster_private.courses where id=c;if not found then raise exception 'Unknown course';end if;
  st:=(p->>'starts')::bigint;en:=(p->>'ends')::bigint;cnt:=(p->>'marks')::int;mins:=(p->>'minutes')::int;occ:=coalesce((p->>'occurrences')::int,1);vtitle:=trim(p->>'title');
  if st is null or en is null or st<=ms or en<=st or en-st>86400000 or cnt is null or cnt not between 1 and 100 or mins is null or mins not between 1 and 240 or mins*60000>en-st or occ not between 1 and 31 or vtitle is null or length(vtitle) not between 3 and 200 or p->>'kind' not in ('daily','weekly','mock') then raise exception 'Invalid future schedule, marks or duration';end if;
  if p->>'kind'='mock' and occ<>1 then raise exception 'Mock exam has one occurrence';end if;
  if p ? 'id' then if occ<>1 then raise exception 'Edit one exam at a time';end if;select e.* into ex from jobmaster_private.exams e join jobmaster_private.live_meta m on m.exam_id=e.id where e.id=(p->>'id')::uuid and m.course_id=c for update of e;if not found or ms>=ex.starts or exists(select 1 from jobmaster_private.sessions where exam_id=ex.id) then raise exception 'Only unattempted future exam may be edited';end if;end if;
  if nullif(p->>'subtopic_id','') is not null and not exists(select 1 from jobmaster_private.course_nodes where id=p->>'subtopic_id' and course_id=c and level='subtopic') then raise exception 'Invalid subtopic mapping';end if;
  step_ms:=case when p->>'kind'='weekly' then 604800000 else 86400000 end;
  for i in 0..occ-1 loop
   select coalesce(jsonb_agg(data),'[]'),coalesce(jsonb_agg(to_jsonb(id)),'[]') into snap,ids from(select q.id,q.data||jsonb_build_object('course_id',c,'course_title',r.title,'track',r.legacy_track) data from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=c and q.verified and not exists(select 1 from jobmaster_private.question_deleted d where d.id=q.id) and (nullif(p->>'subtopic_id','') is null or m.subtopic_id=p->>'subtopic_id') and not exists(select 1 from jobmaster_private.bcs_plan_questions bp join jobmaster_private.bcs_month_plan plan on plan.id=bp.plan_id where bp.question_id=q.id and plan.ends>ms) and not exists(select 1 from jobmaster_private.exams e where e.ends>ms and e.id::text<>coalesce(p->>'id','') and e.question_ids @> jsonb_build_array(q.id) and not exists(select 1 from jobmaster_private.live_meta lm where lm.exam_id=e.id and lm.cancelled)) order by random() limit cnt)t;
   if jsonb_array_length(snap)<>cnt then raise exception 'Insufficient approved, unreserved questions; no exam was saved';end if;
   eid:=coalesce((p->>'id')::uuid,gen_random_uuid());
   insert into jobmaster_private.exams(id,title,track,starts,ends,publish,duration,question_ids) values(eid,vtitle,r.legacy_track,st+i*step_ms,en+i*step_ms,en+i*step_ms,mins*60,ids) on conflict(id) do update set title=excluded.title,starts=excluded.starts,ends=excluded.ends,publish=excluded.publish,duration=excluded.duration,question_ids=excluded.question_ids;
   insert into jobmaster_private.live_meta values(eid,c,p->>'kind',cnt,snap,false) on conflict(exam_id) do update set kind=excluded.kind,marks=excluded.marks,snapshot=excluded.snapshot,cancelled=false;
   result_ids:=result_ids||jsonb_build_array(eid);
  end loop;insert into jobmaster_private.audit(actor,action,entity) values(u,'v4:exam_save',c);return jsonb_build_object('ok',true,'ids',result_ids);
 elsif a='live_start' then
  perform pg_advisory_xact_lock(hashtext(u::text));
  select e.*,m.snapshot,m.course_id,m.cancelled,c.status into ex from jobmaster_private.exams e join jobmaster_private.live_meta m on m.exam_id=e.id join jobmaster_private.courses c on c.id=m.course_id where e.id=(p->>'id')::uuid;
  if not found or ex.status<>'published' or ex.cancelled or ms<ex.starts or ms>=ex.ends then raise exception 'Outside scheduled exam window';end if;
  select id into sid from jobmaster_private.sessions where user_id=u and exam_id=ex.id;if found then return jsonb_build_object('id',sid);end if;
  if exists(select 1 from jobmaster_private.sessions where user_id=u and submitted=0 and deadline>ms) then raise exception 'Finish your active session first';end if;
  insert into jobmaster_private.sessions(user_id,track,started,deadline,snapshot,exam_id) values(u,ex.track,ms,least(ex.ends,ms+ex.duration*1000),ex.snapshot,ex.id) returning id into sid;return jsonb_build_object('id',sid);
 else raise exception 'Unknown upgrade action';end if;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'v4:'||a,coalesce(c,p->>'id',''));return '{"ok":true}';
end $$;
revoke all on function public.jobmaster_upgrade(jsonb) from public,anon;
grant execute on function public.jobmaster_upgrade(jsonb) to authenticated;
-- Guard legacy exam start entry points too. Snapshot and course visibility remain authoritative.
create or replace function jobmaster_private.live_session_guard() returns trigger language plpgsql set search_path='' as $$declare m record;begin
 if new.exam_id is not null then select lm.*,c.status,e.starts,e.ends into m from jobmaster_private.live_meta lm join jobmaster_private.courses c on c.id=lm.course_id join jobmaster_private.exams e on e.id=lm.exam_id where lm.exam_id=new.exam_id;
 if found then if m.cancelled or m.status<>'published' or jobmaster_private.now_ms()<m.starts or jobmaster_private.now_ms()>=m.ends then raise exception 'Outside scheduled exam window';end if;new.snapshot:=m.snapshot;new.deadline:=least(new.deadline,m.ends);end if;end if;return new;end $$;
drop trigger if exists live_session_guard on jobmaster_private.sessions;
create trigger live_session_guard before insert on jobmaster_private.sessions for each row execute function jobmaster_private.live_session_guard();
commit;
