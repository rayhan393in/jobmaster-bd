-- Admin Courses V3. Requires STEP-5 and Subject-Topic-Subtopic-V2.
-- Additive. No automatic verification. No question/exam deletion.
begin;
do $$begin if to_regclass('jobmaster_private.question_classification') is null then raise exception 'Install Subject-Topic-Subtopic-V2 first';end if;end $$;
select pg_advisory_xact_lock(hashtext('jobmaster-admin-courses-v3'));
create table if not exists jobmaster_private.courses(id text primary key,title text not null check(length(title) between 2 and 150),description text not null default '',circular_url text not null default '',status text not null default 'draft' check(status in ('draft','published','archived')),legacy_track text not null default 'BCS' check(legacy_track in ('BCS','EEE')),updated timestamptz not null default now());
create table if not exists jobmaster_private.course_nodes(id text primary key,course_id text not null references jobmaster_private.courses(id),parent_id text references jobmaster_private.course_nodes(id),level text not null check(level in ('subject','topic','subtopic')),title text not null check(length(title) between 1 and 150),unique(course_id,parent_id,title));
create unique index if not exists course_node_unique_title on jobmaster_private.course_nodes(course_id,coalesce(parent_id,''),title);
create table if not exists jobmaster_private.course_questions(course_id text not null references jobmaster_private.courses(id),question_id text not null references jobmaster_private.questions(id) on delete cascade,subtopic_id text references jobmaster_private.course_nodes(id),primary key(course_id,question_id));
create index if not exists course_questions_leaf on jobmaster_private.course_questions(course_id,subtopic_id,question_id);
create table if not exists jobmaster_private.course_papers(id uuid primary key default gen_random_uuid(),course_id text not null references jobmaster_private.courses(id),title text not null,minutes int not null check(minutes between 1 and 180),snapshot jsonb not null,created_by uuid not null references auth.users(id),created timestamptz not null default now());
do $$declare t text;begin foreach t in array array['courses','course_nodes','course_questions','course_papers'] loop execute format('alter table jobmaster_private.%I enable row level security',t);execute format('revoke all on jobmaster_private.%I from public,anon,authenticated',t);end loop;end $$;
insert into jobmaster_private.courses(id,title,status,legacy_track) values('BCS','BCS প্রস্তুতি','published','BCS'),('EEE','EEE প্রস্তুতি','published','EEE') on conflict(id) do nothing;
insert into jobmaster_private.course_nodes select id,track,null,'subject',title from jobmaster_private.exam_subjects on conflict(id) do nothing;
insert into jobmaster_private.course_nodes select t.id,s.track,t.subject_id,'topic',t.title from jobmaster_private.exam_topics t join jobmaster_private.exam_subjects s on s.id=t.subject_id on conflict(id) do nothing;
insert into jobmaster_private.course_nodes select l.id,s.track,l.topic_id,'subtopic',l.title from jobmaster_private.exam_subtopics l join jobmaster_private.exam_topics t on t.id=l.topic_id join jobmaster_private.exam_subjects s on s.id=t.subject_id on conflict(id) do nothing;
create or replace function jobmaster_private.course_node_guard() returns trigger language plpgsql set search_path='' as $$
declare p jobmaster_private.course_nodes;begin
 if tg_op='UPDATE' and (new.course_id<>old.course_id or new.parent_id is distinct from old.parent_id or new.level<>old.level) then raise exception 'Node parent/course/level immutable; rename or create a new node';end if;
 if new.level='subject' then if new.parent_id is not null then raise exception 'Subject cannot have parent';end if;
 else select * into p from jobmaster_private.course_nodes where id=new.parent_id;
  if not found or p.course_id<>new.course_id or p.level<>(case when new.level='topic' then 'subject' else 'topic' end) then raise exception 'Invalid parent hierarchy';end if;
 end if;return new;end $$;
drop trigger if exists course_node_guard on jobmaster_private.course_nodes;
create trigger course_node_guard before insert or update on jobmaster_private.course_nodes for each row execute function jobmaster_private.course_node_guard();
create or replace function jobmaster_private.course_membership_guard() returns trigger language plpgsql set search_path='' as $$begin
 if new.subtopic_id is not null and not exists(select 1 from jobmaster_private.course_nodes where id=new.subtopic_id and course_id=new.course_id and level='subtopic') then raise exception 'Subtopic must belong to selected course';end if;return new;end $$;
drop trigger if exists course_membership_guard on jobmaster_private.course_questions;
create trigger course_membership_guard before insert or update on jobmaster_private.course_questions for each row execute function jobmaster_private.course_membership_guard();
-- Allow independent course IDs as physical question tracks; BCS/EEE legacy pools
-- therefore cannot accidentally include a custom course's own questions.
DO $track$declare r record;begin
 for r in select conname from pg_constraint where conrelid='jobmaster_private.questions'::regclass and contype='c' and pg_get_constraintdef(oid) like '%track%' and pg_get_constraintdef(oid) like '%BCS%' and pg_get_constraintdef(oid) like '%EEE%' loop
  execute format('alter table jobmaster_private.questions drop constraint %I',r.conname);
 end loop;
 if not exists(select 1 from pg_constraint where conrelid='jobmaster_private.questions'::regclass and conname='course_track_nonempty') then alter table jobmaster_private.questions add constraint course_track_nonempty check(length(coalesce(data->>'track','')) between 1 and 150);end if;
end $track$;
create or replace function jobmaster_private.course_normalize_track() returns trigger language plpgsql set search_path='' as $$declare c text;begin
 c:=coalesce(nullif(new.data->>'course_id',''),case when tg_op='UPDATE' then nullif(old.data->>'course_id','') else null end,new.data->>'track');
 if not exists(select 1 from jobmaster_private.courses where id=c) then raise exception 'Unknown course/track: %',c;end if;
 new.data:=new.data||jsonb_build_object('track',c);return new;end $$;
drop trigger if exists course_normalize_track on jobmaster_private.questions;
create trigger course_normalize_track before insert or update of data on jobmaster_private.questions for each row execute function jobmaster_private.course_normalize_track();
-- Preserve provenance when the legacy editor sends only its supported fields.
create or replace function jobmaster_private.course_preserve_metadata() returns trigger language plpgsql set search_path='' as $$begin
 new.data:=old.data||new.data;
 if (old.data-'course_id'-'subtopic_id'-'topic_id'-'subject_id'-'topic'-'subtopic') is distinct from (new.data-'course_id'-'subtopic_id'-'topic_id'-'subject_id'-'topic'-'subtopic') then new.verified:=false;end if;
 return new;end $$;
drop trigger if exists course_preserve_metadata on jobmaster_private.questions;
create trigger course_preserve_metadata before update of data on jobmaster_private.questions for each row execute function jobmaster_private.course_preserve_metadata();
create or replace function jobmaster_private.course_sync_question() returns trigger language plpgsql set search_path='' as $$
declare c text:=coalesce(nullif(new.data->>'course_id',''),new.data->>'track');leaf text;begin
 if not exists(select 1 from jobmaster_private.courses where id=c) then raise exception 'Unknown course_id: %',c;end if;
 leaf:=nullif(new.data->>'subtopic_id','');
 if tg_op='UPDATE' and new.data->>'subtopic_id' is not distinct from old.data->>'subtopic_id' and coalesce(new.data->>'course_id',new.data->>'track')=coalesce(old.data->>'course_id',old.data->>'track') then
  select coalesce(m.subtopic_id,leaf) into leaf from jobmaster_private.course_questions m where m.course_id=c and m.question_id=new.id;
 end if;
 if leaf is null then select subtopic_id into leaf from jobmaster_private.question_classification where question_id=new.id;end if;
 if leaf is not null and not exists(select 1 from jobmaster_private.course_nodes where id=leaf and course_id=c and level='subtopic') then raise exception 'Invalid course/subtopic pairing: %',new.id;end if;
 insert into jobmaster_private.course_questions values(c,new.id,leaf) on conflict(course_id,question_id) do update set subtopic_id=coalesce(excluded.subtopic_id,jobmaster_private.course_questions.subtopic_id);
 return new;end $$;
drop trigger if exists course_sync_question on jobmaster_private.questions;
create trigger course_sync_question after insert or update of data on jobmaster_private.questions for each row execute function jobmaster_private.course_sync_question();
create or replace function jobmaster_private.course_sync_classification() returns trigger language plpgsql set search_path='' as $$declare c text;begin
 select course_id into c from jobmaster_private.course_nodes where id=new.subtopic_id;
 if c is not null then insert into jobmaster_private.course_questions values(c,new.question_id,new.subtopic_id) on conflict(course_id,question_id) do update set subtopic_id=excluded.subtopic_id;end if;return new;end $$;
drop trigger if exists course_sync_classification on jobmaster_private.question_classification;
create trigger course_sync_classification after insert or update on jobmaster_private.question_classification for each row execute function jobmaster_private.course_sync_classification();
insert into jobmaster_private.course_questions(course_id,question_id,subtopic_id)
 select q.data->>'track',q.id,n.id from jobmaster_private.questions q left join jobmaster_private.question_classification c on c.question_id=q.id left join jobmaster_private.course_nodes n on n.id=c.subtopic_id and n.course_id=q.data->>'track'
 on conflict(course_id,question_id) do nothing;
create or replace function public.jobmaster_courses(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();a text:=coalesce(p->>'action','boot');isadmin boolean;c text:=p->>'course_id';v jsonb;q jsonb;old jsonb;outj jsonb;leaf text;par text;lev text;sid text;tid text;qid text;cid text;ids jsonb;part jsonb;grp jsonb;snap jsonb:='[]';n int;total int;pg int:=greatest(1,least(100000,coalesce((p->>'page')::int,1)));per int:=30;paper uuid;ms bigint;
begin
 if u is null then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.profiles(id,name,email) select id,left(coalesce(nullif(raw_user_meta_data->>'name',''),split_part(email,'@',1),'Student'),80),coalesce(email,'') from auth.users where id=u on conflict(id) do nothing;
 select role='admin' into isadmin from jobmaster_private.profiles where id=u;if isadmin is null then raise exception 'Unauthorized';end if;
 insert into jobmaster_private.limits(key,hits,reset_at) values('courses:'||u,1,clock_timestamp()+interval '1 minute') on conflict(key) do update set hits=case when jobmaster_private.limits.reset_at<clock_timestamp() then 1 else jobmaster_private.limits.hits+1 end,reset_at=case when jobmaster_private.limits.reset_at<clock_timestamp() then clock_timestamp()+interval '1 minute' else jobmaster_private.limits.reset_at end returning hits into n;
 if n>150 then raise exception 'Rate limit exceeded';end if;
 if a='catalog' then return jsonb_build_object('courses',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'description',description,'circular_url',circular_url,'available',(select count(*) from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=courses.id and q.verified)) order by title),'[]') from jobmaster_private.courses where status='published'),'nodes',(select coalesce(jsonb_agg(to_jsonb(cn)),'[]') from jobmaster_private.course_nodes cn join jobmaster_private.courses pc on pc.id=cn.course_id where pc.status='published'),'counts',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select m.course_id,m.subtopic_id,count(*) approved from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id join jobmaster_private.courses c on c.id=m.course_id where c.status='published' and q.verified group by m.course_id,m.subtopic_id)x));end if;
 -- Start a course practice session using the existing secure answer/timer/result API.
 if a='start' then
  if not exists(select 1 from jobmaster_private.courses where id=c and status='published') then raise exception 'Course not published';end if;
  leaf:=nullif(p->>'subtopic_id','');if leaf is not null and not exists(select 1 from jobmaster_private.course_nodes where id=leaf and course_id=c and level='subtopic') then raise exception 'Invalid course subtopic';end if;
  n:=coalesce((p->>'count')::int,20);ms:=coalesce((p->>'minutes')::int,20);
  if n not between 1 and 100 or ms not between 1 and 180 then raise exception 'Invalid count or minutes';end if;
  perform pg_advisory_xact_lock(hashtext(u::text));
  if exists(select 1 from jobmaster_private.sessions where user_id=u and submitted=0 and deadline>jobmaster_private.now_ms()) then raise exception 'Finish your active session first';end if;
  select coalesce(jsonb_agg(data),'[]') into snap from(select q.data||jsonb_build_object('course_id',c,'course_title',(select title from jobmaster_private.courses where id=c)) data from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=c and q.verified and (leaf is null or m.subtopic_id=leaf)
   and not exists(select 1 from jobmaster_private.exams e where e.ends>jobmaster_private.now_ms() and e.question_ids @> jsonb_build_array(q.id))
   and not exists(select 1 from jobmaster_private.bcs_plan_questions b join jobmaster_private.bcs_month_plan r on r.id=b.plan_id where b.question_id=q.id and r.ends>jobmaster_private.now_ms())
   order by random() limit n)x;
  if jsonb_array_length(snap)<>n then raise exception 'Insufficient approved, unreserved questions';end if;
  insert into jobmaster_private.sessions(user_id,track,started,deadline,snapshot) select u,legacy_track,jobmaster_private.now_ms(),jobmaster_private.now_ms()+ms*60000,snap from jobmaster_private.courses where id=c returning id into paper;
  return jsonb_build_object('id',paper,'count',n);
 end if;
 if not isadmin then raise exception 'Admin access required';end if;
 if a='boot' then return jsonb_build_object('courses',(select coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]') from jobmaster_private.courses x),'nodes',(select coalesce(jsonb_agg(to_jsonb(x) order by x.title),'[]') from jobmaster_private.course_nodes x), 'counts',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select m.course_id,m.subtopic_id,count(*) total,count(*) filter(where q.verified) approved from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id group by m.course_id,m.subtopic_id)x));end if;
 if a='course_save' then
  cid:=coalesce(nullif(p->>'id',''),'course-'||gen_random_uuid()::text);
  if length(btrim(coalesce(p->>'title','')))<2 or length(p->>'title')>150 or length(coalesce(p->>'description',''))>4000 or length(coalesce(p->>'circular_url',''))>1000 or (coalesce(p->>'circular_url','')<>'' and p->>'circular_url' !~ '^https://') then raise exception 'Valid title / HTTPS circular URL required';end if;
  if p->>'status' not in ('draft','published','archived') or p->>'legacy_track' not in ('BCS','EEE') then raise exception 'Invalid course settings';end if;
  insert into jobmaster_private.courses(id,title,description,circular_url,status,legacy_track) values(cid,btrim(p->>'title'),coalesce(p->>'description',''),coalesce(p->>'circular_url',''),p->>'status',p->>'legacy_track') on conflict(id) do update set title=excluded.title,description=excluded.description,circular_url=excluded.circular_url,status=excluded.status,updated=clock_timestamp();
  outj:=jsonb_build_object('ok',true,'id',cid);
 elsif a='node_save' then
  cid:=coalesce(nullif(p->>'id',''),'node-'||gen_random_uuid()::text);lev:=p->>'level';par:=nullif(p->>'parent_id','');
  if length(btrim(coalesce(p->>'title','')))<1 or length(p->>'title')>150 then raise exception 'Node title required';end if;
  if exists(select 1 from jobmaster_private.course_nodes where id=cid and course_id<>c) then raise exception 'Cross-course edit forbidden';end if;
  insert into jobmaster_private.course_nodes(id,course_id,parent_id,level,title) values(cid,c,par,lev,btrim(p->>'title')) on conflict(id) do update set title=excluded.title;
  outj:=jsonb_build_object('ok',true,'id',cid);
 elsif a='questions' then
  with pool as(select q.id,q.data,q.verified,m.course_id,m.subtopic_id,l.parent_id topic_id,t.parent_id subject_id from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id left join jobmaster_private.course_nodes l on l.id=m.subtopic_id left join jobmaster_private.course_nodes t on t.id=l.parent_id
   where (c is null or m.course_id=c) and (coalesce(p->>'subtopic_id','')='' or m.subtopic_id=p->>'subtopic_id') and (coalesce(p->>'topic_id','')='' or l.parent_id=p->>'topic_id') and (coalesce(p->>'subject_id','')='' or t.parent_id=p->>'subject_id')
   and (coalesce((p->>'unclassified')::boolean,false)=false or m.subtopic_id is null)
   and (coalesce(p->>'status','all')='all' or q.verified=(p->>'status'='approved'))
   and (coalesce(p->>'search','')='' or q.id ilike '%'||(p->>'search')||'%' or q.data->>'q' ilike '%'||(p->>'search')||'%' or q.data->>'batch' ilike '%'||(p->>'search')||'%'))
   select jsonb_build_object('total',(select count(*) from pool),'page',pg,'per_page',per,'questions',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select * from pool order by id,course_id limit per offset (pg-1)*per)x)) into outj;
  return outj;
 elsif a='verify' then
  if jsonb_typeof(p->'verified') is distinct from 'boolean' then raise exception 'Boolean verified required';end if;
  if not exists(select 1 from jobmaster_private.course_questions where course_id=c and question_id=p->>'id') then raise exception 'Question not in selected course';end if;
  if (p->>'verified')::boolean and not exists(select 1 from jobmaster_private.course_questions where course_id=c and question_id=p->>'id' and subtopic_id is not null) then raise exception 'Classify question before approval';end if;
  update jobmaster_private.questions set verified=(p->>'verified')::boolean where id=p->>'id';outj:='{"ok":true}';
 elsif a='assign' then
  leaf:=p->>'subtopic_id';
  if not exists(select 1 from jobmaster_private.course_questions where course_id=c and question_id=p->>'id') then raise exception 'Question not in selected course';end if;
  update jobmaster_private.course_questions set subtopic_id=leaf where course_id=c and question_id=p->>'id';
  if exists(select 1 from jobmaster_private.questions where id=p->>'id' and coalesce(data->>'course_id',data->>'track')=c) and exists(select 1 from jobmaster_private.exam_subtopics where id=leaf) then insert into jobmaster_private.question_classification(question_id,subtopic_id,assigned_by) values(p->>'id',leaf,u) on conflict(question_id) do update set subtopic_id=excluded.subtopic_id,assigned_by=u,updated=clock_timestamp();end if;
  update jobmaster_private.questions set verified=false where id=p->>'id';outj:='{"ok":true}';
 elsif a in ('question_save','import') then
  ids:=case when a='import' then p->'questions' else jsonb_build_array(p->'question') end;
  if jsonb_typeof(ids) is distinct from 'array' then raise exception 'Question array required';end if;
  if jsonb_array_length(ids) not between 1 and 500 then raise exception 'Import 1–500 questions per batch';end if;
  for v in select value from jsonb_array_elements(ids) loop
   leaf:=v->>'subtopic_id';
   select t.id,s.id into tid,sid from jobmaster_private.course_nodes l join jobmaster_private.course_nodes t on t.id=l.parent_id join jobmaster_private.course_nodes s on s.id=t.parent_id where l.id=leaf and l.course_id=c and l.level='subtopic';
   if not found then raise exception 'Choose a valid subtopic in this course';end if;
   qid:=case when a='question_save' and nullif(p->>'id','') is not null then p->>'id' else 'course-q-'||gen_random_uuid()::text end;
   old:=null;select data into old from jobmaster_private.questions where id=qid for update;
   if old is not null and not exists(select 1 from jobmaster_private.course_questions where question_id=qid and course_id=c) then raise exception 'Cross-course question edit forbidden';end if;
   if old is not null and coalesce(old->>'course_id',old->>'track')<>c then raise exception 'Shared question: edit content from original course; use assign for this membership';end if;
   q:=coalesce(old,'{}')||v||jsonb_build_object('id',qid,'course_id',c,'track',c,'subject_id',sid,'topic_id',tid,'subtopic_id',leaf,'subject',(select title from jobmaster_private.course_nodes where id=sid),'topic',(select title from jobmaster_private.course_nodes where id=tid),'subtopic',(select title from jobmaster_private.course_nodes where id=leaf));
   perform jobmaster_private.validate_question(q||jsonb_build_object('track',(select legacy_track from jobmaster_private.courses where id=c)));
   if old is null then insert into jobmaster_private.questions(id,data,fingerprint,verified) values(qid,q,jobmaster_private.fingerprint(q->>'q'),false);
   else update jobmaster_private.questions set data=q,fingerprint=jobmaster_private.fingerprint(q->>'q'),verified=false where id=qid;end if;
   if exists(select 1 from jobmaster_private.exam_subtopics where id=leaf) then insert into jobmaster_private.question_classification(question_id,subtopic_id,assigned_by) values(qid,leaf,u) on conflict(question_id) do update set subtopic_id=excluded.subtopic_id,assigned_by=u,updated=clock_timestamp();end if;
  end loop;outj:=jsonb_build_object('ok',true,'imported',jsonb_array_length(ids));
 elsif a='link' then
  if not exists(select 1 from jobmaster_private.questions where id=p->>'id') then raise exception 'Question not found';end if;
  insert into jobmaster_private.course_questions values(c,p->>'id',p->>'subtopic_id') on conflict(course_id,question_id) do update set subtopic_id=excluded.subtopic_id;
  update jobmaster_private.questions set verified=false where id=p->>'id';outj:='{"ok":true}';
 elsif a='paper_generate' then
  if length(btrim(coalesce(p->>'title','')))<3 or length(p->>'title')>200 or (p->>'minutes')::int not between 1 and 180 or p->>'minutes' is null then raise exception 'Valid title and 1–180 minutes required';end if;
  if jsonb_typeof(p->'selections') is distinct from 'array' then raise exception 'Selections required';end if;
  if jsonb_array_length(p->'selections') not between 1 and 30 then raise exception '1–30 selections required';end if;
  if (select count(distinct value->>'subtopic_id') from jsonb_array_elements(p->'selections'))<>jsonb_array_length(p->'selections') then raise exception 'Duplicate subtopic selection';end if;
  for grp in select value from jsonb_array_elements(p->'selections') loop
   n:=(grp->>'count')::int;leaf:=grp->>'subtopic_id';
   if n is null or n not between 1 and 100 or not exists(select 1 from jobmaster_private.course_nodes where id=leaf and course_id=c and level='subtopic') then raise exception 'Invalid selection';end if;
   select coalesce(jsonb_agg(data),'[]') into part from(select q.data from jobmaster_private.course_questions m join jobmaster_private.questions q on q.id=m.question_id where m.course_id=c and m.subtopic_id=leaf and q.verified
    and not exists(select 1 from jobmaster_private.exams e where e.ends>jobmaster_private.now_ms() and e.question_ids @> jsonb_build_array(q.id))
    and not exists(select 1 from jobmaster_private.bcs_plan_questions b join jobmaster_private.bcs_month_plan r on r.id=b.plan_id where b.question_id=q.id and r.ends>jobmaster_private.now_ms()) order by random() limit n)x;
   if jsonb_array_length(part)<>n then raise exception 'Not enough approved, unreserved questions in selected subtopic';end if;snap:=snap||part;
  end loop;
  if jsonb_array_length(snap)>100 then raise exception 'Maximum 100 questions per paper';end if;
  insert into jobmaster_private.course_papers(course_id,title,minutes,snapshot,created_by) values(c,p->>'title',(p->>'minutes')::int,snap,u) returning id into paper;
  outj:=jsonb_build_object('ok',true,'paper_id',paper,'count',jsonb_array_length(snap));
 elsif a='papers' then return jsonb_build_object('papers',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,course_id,title,minutes,created,jsonb_array_length(snapshot) count from jobmaster_private.course_papers where course_id=c order by created desc limit 100)x));
 elsif a='paper' then select to_jsonb(x) into outj from jobmaster_private.course_papers x where id=(p->>'id')::uuid and course_id=c;if outj is null then raise exception 'Paper not found';end if;return outj;
 else raise exception 'Unknown action';end if;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'courses:'||a,coalesce(p->>'id',c));return outj;
end $$;
revoke all on function public.jobmaster_courses(jsonb) from public,anon;
grant execute on function public.jobmaster_courses(jsonb) to authenticated;
revoke all on function jobmaster_private.course_normalize_track(),jobmaster_private.course_node_guard(),jobmaster_private.course_membership_guard(),jobmaster_private.course_preserve_metadata(),jobmaster_private.course_sync_question(),jobmaster_private.course_sync_classification() from public,anon,authenticated;
commit;
select id,title,status,(select count(*) from jobmaster_private.course_questions where course_id=c.id) questions from jobmaster_private.courses c order by id;
