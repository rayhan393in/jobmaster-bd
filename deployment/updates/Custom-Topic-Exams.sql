-- Requires STEP-5-SUPABASE.sql + BCS-Auto-Routine-Setup.sql + BCS-Daywise-Import.sql.
-- Additive migration. Does not replace the existing exam engine or publish drafts.
begin;
create or replace function public.jobmaster_custom_exam(p jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); tr text:=p->>'track'; a text:=p->>'action'; pool jsonb; picked jsonb:='[]'; part jsonb; sel jsonb; n int; mins int; ms bigint; sid uuid; v text; seen text[]:='{}'; total_n int:=0;
begin
 if u is null then raise exception 'Unauthorized';end if;
 if tr is null or tr not in ('BCS','EEE') then raise exception 'Invalid track';end if;
 -- Reuse existing authenticated workspace profile initialization, overdue finalization and persistent rate limit.
 perform public.jobmaster_action(jsonb_build_object('action','workspace','track',tr));
 ms:=jobmaster_private.now_ms();
 -- Use only verified questions. Never expose a question reserved for an unfinished scheduled paper.
 select coalesce(jsonb_agg(jsonb_build_object('data',z.data,'subject',z.subject,'topic',z.topic,'key',md5(z.subject||chr(31)||z.topic))),'[]') into pool
 from (select q.data,q.data->>'subject' subject,
  coalesce((select nullif(btrim(s.metadata->>'topic'),'') from jobmaster_private.bcs_question_sources s where s.question_id=q.id order by s.plan_id limit 1),'বিষয়ভিত্তিক — টপিক অনির্ধারিত') topic
  from jobmaster_private.questions q where q.verified and q.data->>'track'=tr
  and not exists(select 1 from jobmaster_private.bcs_plan_questions l join jobmaster_private.bcs_month_plan m on m.id=l.plan_id where l.question_id=q.id and m.ends>ms)
  and not exists(select 1 from jobmaster_private.exams e where e.ends>ms and e.question_ids @> jsonb_build_array(q.id))
 )z;
 if a='catalog' then return jsonb_build_object('topics',(select coalesce(jsonb_agg(to_jsonb(t) order by t.subject,t.topic),'[]') from (select x->>'key' key,x->>'subject' subject,x->>'topic' topic,count(*) available from jsonb_array_elements(pool) x group by 1,2,3)t),'now',ms);end if;
 if a is distinct from 'start' then raise exception 'Unknown action';end if;
 if jsonb_typeof(p->'selections') is distinct from 'array' or jsonb_array_length(p->'selections') not between 1 and 30 then raise exception 'Select 1 to 30 topics';end if;
 if coalesce(p->>'minutes','') !~ '^[0-9]{1,3}$' then raise exception 'Invalid minutes';end if;
 mins:=(p->>'minutes')::int;if mins not between 1 and 180 then raise exception 'Minutes must be 1–180';end if;
 perform pg_advisory_xact_lock(hashtext(u::text));
 for sel in select value from jsonb_array_elements(p->'selections') loop
  v:=sel->>'key';if v is null or v=any(seen) then raise exception 'Duplicate or missing topic';end if;seen:=array_append(seen,v);
  if coalesce(sel->>'count','') !~ '^[0-9]{1,3}$' then raise exception 'Invalid question count';end if;
  n:=(sel->>'count')::int;if n not between 1 and 100 then raise exception 'Count must be 1–100';end if;
  total_n:=total_n+n;if total_n>100 then raise exception 'Maximum 100 questions per paper';end if;
  select coalesce(jsonb_agg(z.x->'data'),'[]') into part from(select x from jsonb_array_elements(pool) x where x->>'key'=v order by random() limit n)z;
  if jsonb_array_length(part)<>n then raise exception 'Not enough verified questions in selected topic; refresh availability';end if;
  picked:=picked||part;
 end loop;
 if (select count(distinct x->>'id') from jsonb_array_elements(picked) x)<>total_n then raise exception 'Duplicate question selection';end if;
 insert into jobmaster_private.sessions(user_id,track,started,deadline,snapshot) values(u,tr,ms,ms+mins::bigint*60000,picked) returning id into sid;
 return jsonb_build_object('id',sid,'count',total_n,'deadline',ms+mins::bigint*60000);
end $$;
revoke all on function public.jobmaster_custom_exam(jsonb) from public,anon;
grant execute on function public.jobmaster_custom_exam(jsonb) to authenticated;
commit;
