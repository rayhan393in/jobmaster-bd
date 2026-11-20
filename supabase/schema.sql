-- Production architecture draft. Review and test in Supabase before deployment.
create extension if not exists pgcrypto;
create table public.profiles(id uuid primary key references auth.users on delete cascade,display_name text not null default '',tracks text[] default '{BCS}',created_at timestamptz default now());
-- Roles are server-managed only, never writable through profile updates.
create table public.user_roles(user_id uuid primary key references auth.users on delete cascade,role text not null check(role in ('student','admin')) default 'student');
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from user_roles where user_id=auth.uid() and role='admin') $$;
create table public.syllabus_versions(id uuid primary key default gen_random_uuid(),track text check(track in ('BCS','EEE')),title text not null,source_url text,document_path text,sha256 text,version_date date,verified boolean default false);
create table public.subjects(id uuid primary key default gen_random_uuid(),syllabus_id uuid references public.syllabus_versions,title text not null,sort_order integer default 0);
create table public.topics(id uuid primary key default gen_random_uuid(),subject_id uuid references public.subjects,parent_id uuid references public.topics,title text not null,source_page integer);
create table public.questions(id uuid primary key default gen_random_uuid(),track text not null check(track in ('BCS','EEE')),subject_id uuid references public.subjects,topic_id uuid references public.topics,body text not null,options jsonb not null check(jsonb_array_length(options)=4),kind text not null check(kind in ('original','ai_generated','verified_previous','conceptual','numerical')),difficulty smallint check(difficulty between 1 and 3),source_url text,exam_year integer,verification text default 'pending' check(verification in ('pending','verified','rejected')),tags text[] default '{}',fingerprint text unique not null,created_at timestamptz default now(),check(kind<>'verified_previous' or (source_url is not null and verification='verified')));
-- Isolated from candidate queries. Never grant student access to answer keys.
create table public.question_keys(question_id uuid primary key references public.questions on delete cascade,correct_index integer check(correct_index between 0 and 3),explanation text not null check(length(trim(explanation))>0));
create index questions_topic_idx on public.questions(topic_id,verification);
create index questions_track_idx on public.questions(track,subject_id);
create index questions_tags_idx on public.questions using gin(tags);
create table public.exams(id uuid primary key default gen_random_uuid(),title text not null,track text not null,starts_at timestamptz not null,ends_at timestamptz not null,results_at timestamptz not null,duration_seconds integer not null check(duration_seconds>0),negative_mark numeric not null default 0.5,published boolean default false,check(ends_at>starts_at),check(results_at>=ends_at));
create table public.exam_questions(exam_id uuid references public.exams,question_id uuid references public.questions,position integer not null,primary key(exam_id,question_id),unique(exam_id,position));
create table public.attempts(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users,exam_id uuid references public.exams,started_at timestamptz default now(),deadline timestamptz not null,submitted_at timestamptz,score numeric,unique(user_id,exam_id));
create table public.attempt_answers(attempt_id uuid references public.attempts,question_id uuid references public.questions,choice integer check(choice between 0 and 3),marked boolean default false,updated_at timestamptz default now(),primary key(attempt_id,question_id));
create table public.study_tasks(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users,topic_id uuid references public.topics,title text not null,scheduled_at timestamptz,minutes integer check(minutes>0),mcq_target integer default 0,completed_at timestamptz);
create table public.bookmarks(user_id uuid references auth.users,question_id uuid references public.questions,next_revision_at timestamptz,primary key(user_id,question_id));
create table public.question_reports(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users,question_id uuid references public.questions,reason text not null,status text default 'open',created_at timestamptz default now());
create table public.import_jobs(id uuid primary key default gen_random_uuid(),created_by uuid references auth.users,status text default 'preview',errors jsonb default '[]',created_at timestamptz default now());
-- Default deny across all tables. No broad writable admin bypass on exam scoring.
do $$ declare t text; begin foreach t in array array['profiles','user_roles','syllabus_versions','subjects','topics','questions','question_keys','exams','exam_questions','attempts','attempt_answers','study_tasks','bookmarks','question_reports','import_jobs'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy profile_read on public.profiles for select using(id=auth.uid());
create policy profile_update on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy role_read on public.user_roles for select using(user_id=auth.uid());
create policy syllabus_read on public.syllabus_versions for select using(verified or public.is_admin());
create policy subjects_read on public.subjects for select using(auth.uid() is not null);
create policy topics_read on public.topics for select using(auth.uid() is not null);
create policy exams_read on public.exams for select using(published or public.is_admin());
create policy attempts_read on public.attempts for select using(user_id=auth.uid() or public.is_admin());
create policy answers_read on public.attempt_answers for select using(exists(select 1 from public.attempts a where a.id=attempt_id and a.user_id=auth.uid()));
create policy tasks_owner on public.study_tasks for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy bookmarks_owner on public.bookmarks for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy reports_create on public.question_reports for insert with check(user_id=auth.uid());
-- Questions, keys, attempt writes and score publication require authenticated server APIs.
-- Implement transactional RPCs with row locks + deadline validation before production rollout.
