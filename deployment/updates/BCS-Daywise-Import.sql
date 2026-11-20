-- Requires STEP-5-SUPABASE.sql + BCS-Auto-Routine-Setup.sql. Run whole file.
begin;
create table if not exists jobmaster_private.bcs_question_sources(
 plan_id uuid not null,question_id text not null, metadata jsonb not null,
 reviewed_hash text,primary key(plan_id,question_id),
 foreign key(plan_id,question_id) references jobmaster_private.bcs_plan_questions(plan_id,question_id) on delete cascade
);
alter table jobmaster_private.bcs_question_sources enable row level security;
revoke all on jobmaster_private.bcs_question_sources from public,anon,authenticated;
create table if not exists jobmaster_private.bcs_admin_rate(actor uuid primary key, window_start timestamptz not null, hits integer not null);
alter table jobmaster_private.bcs_admin_rate enable row level security;
revoke all on jobmaster_private.bcs_admin_rate from public,anon,authenticated;
create or replace function public.jobmaster_daywise(p jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a text:=p->>'action'; m jobmaster_private.bcs_month_plan; q jsonb; meta jsonb; x jsonb; qid text; n int; prev int; standard_n int; easy_n int; hard_n int; result jsonb;
begin
 if u is null then raise exception 'Unauthorized';end if;
 if not exists(select 1 from jobmaster_private.profiles where id=u and role='admin') then raise exception 'Admin access required';end if;
 insert into jobmaster_private.bcs_admin_rate values(u,clock_timestamp(),1)
 on conflict(actor) do update set hits=case when jobmaster_private.bcs_admin_rate.window_start<clock_timestamp()-interval '1 minute' then 1 else jobmaster_private.bcs_admin_rate.hits+1 end,
 window_start=case when jobmaster_private.bcs_admin_rate.window_start<clock_timestamp()-interval '1 minute' then clock_timestamp() else jobmaster_private.bcs_admin_rate.window_start end;
 if (select hits from jobmaster_private.bcs_admin_rate where actor=u)>180 then return jsonb_build_object('error','Rate limit: wait one minute');end if;
 perform pg_advisory_xact_lock(hashtext('jobmaster-bcs-month-publication'));
 if a='plans' then
 return jsonb_build_object('plans',(select coalesce(jsonb_agg(to_jsonb(t) order by t.starts),'[]') from (select b.*, (select count(*) from jobmaster_private.bcs_plan_questions l where l.plan_id=b.id) linked from jobmaster_private.bcs_month_plan b)t));end if;
 select * into m from jobmaster_private.bcs_month_plan where id=(p->>'plan_id')::uuid for update;
 if not found then raise exception 'Plan not found';end if;
 if a='list' then
 return jsonb_build_object('plan',to_jsonb(m),'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'data',q.data,'metadata',s.metadata,'reviewed',coalesce(s.reviewed_hash=md5(q.data::text||s.metadata::text),false)) order by q.id),'[]') from jobmaster_private.bcs_plan_questions l join jobmaster_private.questions q on q.id=l.question_id left join jobmaster_private.bcs_question_sources s on s.plan_id=l.plan_id and s.question_id=l.question_id where l.plan_id=m.id));end if;
 if m.exam_id is not null or m.starts<=jobmaster_private.now_ms() then raise exception 'Published or past-start paper is locked';end if;
 if a in ('preview','import') then
 if jsonb_typeof(p->'questions') is distinct from 'array' then raise exception 'Question array required';end if;
 n:=jsonb_array_length(p->'questions');if n<>m.marks then raise exception 'Expected exactly % questions',m.marks;end if;
 if exists(select 1 from jobmaster_private.bcs_plan_questions where plan_id=m.id) then raise exception 'Slot already has questions; do not re-import';end if;
 prev:=0;standard_n:=0;easy_n:=0;hard_n:=0;
 for x in select value from jsonb_array_elements(p->'questions') loop
 q:=x->'question';meta:=x->'metadata';perform jobmaster_private.validate_question(q);
 if q->>'track' is distinct from 'BCS' then raise exception 'BCS only';end if;
 if meta is null or length(btrim(coalesce(meta->>'topic','')))<2 or length(btrim(coalesce(meta->>'source_title','')))<3 or length(btrim(coalesce(meta->>'source_locator','')))<1 or coalesce(meta->>'source_url','') !~ '^https://[^[:space:]]+$' then raise exception 'Topic, source title, page/question locator and HTTPS source URL required';end if;
 if meta->>'source_type'='previous' then
 if q->>'kind' is distinct from 'previous' or length(btrim(coalesce(meta->>'exam_name','')))<3 or coalesce(meta->>'exam_year','') !~ '^[12][0-9]{3}$' then raise exception 'Previous requires exam name and 4-digit year';end if;
 if (meta->>'exam_year')::int>extract(year from current_date) then raise exception 'Future previous-year source';end if;prev:=prev+1;
 elsif meta->>'source_type'='book' then
 if q->>'kind' is distinct from 'original' or length(btrim(coalesce(meta->>'author','')))<2 or length(btrim(coalesce(meta->>'edition','')))<1 then raise exception 'Book requires author/publisher and edition';end if;
 else raise exception 'source_type must be previous or book';end if;
 case meta->>'difficulty' when 'standard' then standard_n:=standard_n+1;when 'easy' then easy_n:=easy_n+1;when 'hard' then hard_n:=hard_n+1;else raise exception 'Invalid difficulty';end case;
 end loop;
 if prev<>n/2 or standard_n<>n*9/10 or easy_n=0 or hard_n=0 then raise exception 'Need 50%% previous, 50%% book, 90%% standard plus easy and hard';end if;
 if (select count(distinct jobmaster_private.fingerprint(value->'question'->>'q')) from jsonb_array_elements(p->'questions'))<>n or exists(select 1 from jsonb_array_elements(p->'questions') z(item) join jobmaster_private.questions bank on bank.fingerprint=jobmaster_private.fingerprint(z.item->'question'->>'q')) then raise exception 'Duplicate question in CSV or bank';end if;
 if a='preview' then return jsonb_build_object('ok',true,'count',n,'previous',prev,'book',n-prev,'standard',standard_n,'easy',easy_n,'hard',hard_n);end if;
 for x in select value from jsonb_array_elements(p->'questions') loop
 qid:=gen_random_uuid()::text;q:=(x->'question')||jsonb_build_object('id',qid);
 insert into jobmaster_private.questions(id,data,fingerprint,verified) values(qid,q,jobmaster_private.fingerprint(q->>'q'),false);
 insert into jobmaster_private.bcs_plan_questions values(m.id,qid,false);
 insert into jobmaster_private.bcs_question_sources(plan_id,question_id,metadata) values(m.id,qid,x->'metadata');
 end loop;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'daywise_import',m.id::text);
 return jsonb_build_object('ok',true,'imported',n);
 elsif a='review' then
 if p->'confirmed' is distinct from 'true'::jsonb then raise exception 'Explicit answer/source/topic/difficulty review required';end if;
 qid:=p->>'question_id';
 update jobmaster_private.bcs_question_sources s set reviewed_hash=md5(q.data::text||s.metadata::text) from jobmaster_private.questions q where s.plan_id=m.id and s.question_id=qid and q.id=qid;
 if not found then raise exception 'Question source missing';end if;
 update jobmaster_private.questions set verified=true where id=qid;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'daywise_review',qid);
 return '{"ok":true}'::jsonb;
 elsif a='publish' then
 select count(*) into n from jobmaster_private.bcs_plan_questions where plan_id=m.id;
 if n<>m.marks then raise exception 'Incomplete question count';end if;
 if exists(select 1 from jobmaster_private.bcs_plan_questions l join jobmaster_private.questions q on q.id=l.question_id left join jobmaster_private.bcs_question_sources s on s.plan_id=l.plan_id and s.question_id=l.question_id where l.plan_id=m.id and (s.reviewed_hash is distinct from md5(q.data::text||s.metadata::text) or s.reviewed_hash is null or not q.verified or q.data->>'kind' is distinct from case when s.metadata->>'source_type'='previous' then 'previous' else 'original' end or q.data->>'track' is distinct from 'BCS')) then raise exception 'Every question needs source/answer/topic review; edited questions need re-review';end if;
 update jobmaster_private.bcs_plan_questions set topic_match_checked=true where plan_id=m.id;
 select to_jsonb(r) into result from jobmaster_private.publish_ready_bcs_month(m.plan_key) r where r.plan_id=m.id;
 if result->>'outcome' not in ('PUBLISHED','ALREADY_PUBLISHED') then raise exception 'Publication blocked: %',result->>'outcome';end if;
 return result;
 end if;
 raise exception 'Unknown action';
end $$;
revoke all on function public.jobmaster_daywise(jsonb) from public,anon;
grant execute on function public.jobmaster_daywise(jsonb) to authenticated;
commit;
