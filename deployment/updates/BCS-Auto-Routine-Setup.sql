-- JobMaster BD: BCS-only monthly exam plan, 20 Nov–19 Dec 2026.
-- Run the WHOLE file in YOUR Supabase SQL Editor (project-owner context).
-- Requires the earlier STEP-5-SUPABASE.sql schema. No keys/passwords needed.
-- Stores 30 Daily Live (50 marks) + 4 Weekly Special (100 marks) plans.
-- DOES NOT auto-verify questions, invent questions or publish an empty paper.
-- Existing application shows ONLY exams actually published into private.exams.
-- With the accompanying Vercel UI patch, draft AND published plans appear in the calendar.
-- Re-run is non-destructive; previously saved plans/published exams are retained.

begin;
create table if not exists jobmaster_private.bcs_month_plan (
 id uuid primary key default gen_random_uuid(),
 plan_key text not null,
 exam_date date not null,
 kind text not null check(kind in ('DAILY_LIVE','WEEKLY_SPECIAL')),
 title text not null,
 topics text not null,
 starts bigint not null,
 ends bigint not null,
 publish bigint not null,
 duration integer not null,
 marks integer not null,
 exam_id uuid unique references jobmaster_private.exams(id),
 unique(plan_key,exam_date,kind),
 check(ends>starts and publish>=ends),
 check((kind='DAILY_LIVE' and marks=50 and duration=2400)
    or (kind='WEEKLY_SPECIAL' and marks=100 and duration=3600))
);
create table if not exists jobmaster_private.bcs_plan_questions (
 plan_id uuid not null references jobmaster_private.bcs_month_plan(id) on delete cascade,
 question_id text not null references jobmaster_private.questions(id),
 topic_match_checked boolean not null default false,
 primary key(plan_id,question_id)
);
alter table jobmaster_private.bcs_month_plan enable row level security;
alter table jobmaster_private.bcs_plan_questions enable row level security;
revoke all on jobmaster_private.bcs_month_plan from public,anon,authenticated;
revoke all on jobmaster_private.bcs_plan_questions from public,anon,authenticated;

-- Exact Bangladesh dates/times; no dependence on browser or DB session timezone.
with config as (
 select * from jsonb_to_recordset($monthly_config$
[
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-20",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 01",
    "topics": "বাংলা ভাষা ও সাহিত্য — ধ্বনি-বর্ণ, পদ ও শুদ্ধ বানান; গাণিতিক যুক্তি — শতকরা ও অনুপাত। এই দুই অংশে ২০+২০ প্রশ্ন; মিশ্র baseline থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-21",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 02",
    "topics": "ইংরেজি ভাষা ও সাহিত্য — Parts of speech, subject–verb agreement; বাংলাদেশ বিষয়াবলি — ভাষা আন্দোলন ও মুক্তিযুদ্ধের ধারাবাহিকতা। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-22",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 03",
    "topics": "সাধারণ বিজ্ঞান — ভৌত রাশি, একক, গতি ও বল; কম্পিউটার ও তথ্যপ্রযুক্তি — হার্ডওয়্যার, সফটওয়্যার ও সংখ্যা পদ্ধতি। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-23",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 04",
    "topics": "আন্তর্জাতিক বিষয়াবলি — জাতিসংঘ, আন্তর্জাতিক ও আঞ্চলিক সংস্থা; ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা — বাংলাদেশের অবস্থান, নদী ও ভূপ্রকৃতি। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-24",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 05",
    "topics": "মানসিক দক্ষতা — সংখ্যা ধারা, সাদৃশ্য ও ভাষাগত যুক্তি; নৈতিকতা, মূল্যবোধ ও সুশাসন — নৈতিকতা, মূল্যবোধ, সততা ও জবাবদিহি। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-25",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 06",
    "topics": "বাংলা ভাষা ও সাহিত্য — প্রাচীন-মধ্যযুগের বাংলা সাহিত্য ও গ্রন্থ; ইংরেজি ভাষা ও সাহিত্য — Literary terms ও major English authors। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-26",
    "kind": "WEEKLY_SPECIAL",
    "title": "Weekly Special Exam — সপ্তাহ 1",
    "topics": "দিন ১–৬: বাংলা—ধ্বনি-বর্ণ, পদ, বানান, প্রাচীন-মধ্যযুগ; ইংরেজি—parts of speech, agreement, literary terms; বাংলাদেশ—ভাষা আন্দোলন ও মুক্তিযুদ্ধ; গণিত—শতকরা ও অনুপাত; বিজ্ঞান—একক, গতি ও বল; ICT—হার্ডওয়্যার ও সংখ্যা পদ্ধতি; আন্তর্জাতিক—সংস্থা; ভূগোল—অবস্থান ও নদী; মানসিক দক্ষতা—ধারা ও সাদৃশ্য; নৈতিকতা—সততা ও জবাবদিহি।",
    "starts": "15:00",
    "ends": "16:00",
    "publish": "16:10",
    "duration": 3600,
    "marks": 100
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-26",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 07",
    "topics": "গত ৬ দিনের পড়া টপিকের মিশ্র রিভিশন; Weekly Special-এর একই প্রশ্ন নয়। পরিধি: বাংলা—ধ্বনি-বর্ণ, পদ, বানান, প্রাচীন-মধ্যযুগ; ইংরেজি—parts of speech, agreement, literary terms; বাংলাদেশ—ভাষা আন্দোলন ও মুক্তিযুদ্ধ; গণিত—শতকরা ও অনুপাত; বিজ্ঞান—একক, গতি ও বল; ICT—হার্ডওয়্যার ও সংখ্যা পদ্ধতি; আন্তর্জাতিক—সংস্থা; ভূগোল—অবস্থান ও নদী; মানসিক দক্ষতা—ধারা ও সাদৃশ্য; নৈতিকতা—সততা ও জবাবদিহি।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-27",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 08",
    "topics": "বাংলা ভাষা ও সাহিত্য — সন্ধি, সমাস, কারক ও বিভক্তি; গাণিতিক যুক্তি — লাভ-ক্ষতি ও সরল/চক্রবৃদ্ধি সুদ। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-28",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 09",
    "topics": "ইংরেজি ভাষা ও সাহিত্য — Tense, articles, prepositions; বাংলাদেশ বিষয়াবলি — সংবিধানের কাঠামো, রাষ্ট্রের অঙ্গ ও সরকার। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-29",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 10",
    "topics": "সাধারণ বিজ্ঞান — তাপ, আলো, শব্দ ও বিদ্যুৎ; কম্পিউটার ও তথ্যপ্রযুক্তি — অপারেটিং সিস্টেম, ডেটাবেজ ও নেটওয়ার্ক। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-11-30",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 11",
    "topics": "আন্তর্জাতিক বিষয়াবলি — আন্তর্জাতিক সম্পর্ক, চুক্তি ও নিরাপত্তা; ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা — পরিবেশ, বাস্তুতন্ত্র ও জলবায়ু পরিবর্তন। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-01",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 12",
    "topics": "মানসিক দক্ষতা — দিকনির্ণয়, সম্পর্ক ও স্থানিক দক্ষতা; নৈতিকতা, মূল্যবোধ ও সুশাসন — স্বচ্ছতা, আইনের শাসন ও স্বার্থের সংঘাত। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-02",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 13",
    "topics": "বাংলা ভাষা ও সাহিত্য — আধুনিক বাংলা সাহিত্য: লেখক–গ্রন্থ–চরিত্র; ইংরেজি ভাষা ও সাহিত্য — Vocabulary, idioms, sentence correction। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-03",
    "kind": "WEEKLY_SPECIAL",
    "title": "Weekly Special Exam — সপ্তাহ 2",
    "topics": "দিন ৮–১৩ থেকে ৭০ প্রশ্ন + দিন ১–৬ থেকে ৩০: বাংলা—সন্ধি, সমাস, কারক, আধুনিক সাহিত্য; ইংরেজি—tense, article, preposition, vocabulary; বাংলাদেশ—সংবিধান ও সরকার; গণিত—লাভ-ক্ষতি ও সুদ; বিজ্ঞান—তাপ, আলো ও বিদ্যুৎ; ICT—OS, database ও network; আন্তর্জাতিক—চুক্তি ও নিরাপত্তা; পরিবেশ—জলবায়ু; মানসিক দক্ষতা—দিক ও সম্পর্ক; সুশাসন—স্বচ্ছতা ও আইনের শাসন।",
    "starts": "15:00",
    "ends": "16:00",
    "publish": "16:10",
    "duration": 3600,
    "marks": 100
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-03",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 14",
    "topics": "গত ৬ দিনের পড়া টপিকের মিশ্র রিভিশন; Weekly Special-এর একই প্রশ্ন নয়। পরিধি: বাংলা—সন্ধি, সমাস, কারক, আধুনিক সাহিত্য; ইংরেজি—tense, article, preposition, vocabulary; বাংলাদেশ—সংবিধান ও সরকার; গণিত—লাভ-ক্ষতি ও সুদ; বিজ্ঞান—তাপ, আলো ও বিদ্যুৎ; ICT—OS, database ও network; আন্তর্জাতিক—চুক্তি ও নিরাপত্তা; পরিবেশ—জলবায়ু; মানসিক দক্ষতা—দিক ও সম্পর্ক; সুশাসন—স্বচ্ছতা ও আইনের শাসন।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-04",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 15",
    "topics": "বাংলা ভাষা ও সাহিত্য — বাক্য, বাগধারা ও বানান প্রয়োগ; গাণিতিক যুক্তি — সমীকরণ, অসমতা, সূচক ও লগারিদম। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-05",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 16",
    "topics": "ইংরেজি ভাষা ও সাহিত্য — Voice, narration, clauses ও phrases; বাংলাদেশ বিষয়াবলি — অর্থনীতি, কৃষি, শিল্প ও বাণিজ্য। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-06",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 17",
    "topics": "সাধারণ বিজ্ঞান — কোষ, পুষ্টি, স্বাস্থ্য, জিন ও জীবপ্রক্রিয়া; কম্পিউটার ও তথ্যপ্রযুক্তি — ইন্টারনেট, সাইবার নিরাপত্তা ও ডিজিটাল সেবা। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-07",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 18",
    "topics": "আন্তর্জাতিক বিষয়াবলি — বিশ্ব ইতিহাস ও আন্তর্জাতিক ঘটনাপ্রবাহ; ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা — দুর্যোগ ঝুঁকি, প্রস্তুতি ও প্রশমন। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-08",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 19",
    "topics": "মানসিক দক্ষতা — যান্ত্রিক যুক্তি ও বিশ্লেষণধর্মী সমস্যা; নৈতিকতা, মূল্যবোধ ও সুশাসন — সুশাসন, জনসেবা ও সিদ্ধান্তের নৈতিকতা। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-09",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 20",
    "topics": "গাণিতিক যুক্তি — রেখা-কোণ, ত্রিভুজ, বৃত্ত ও পরিমিতি; বাংলা ভাষা ও সাহিত্য + ইংরেজি ভাষা ও সাহিত্য — বাংলা/English সাহিত্যের দুর্বল অংশ। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-10",
    "kind": "WEEKLY_SPECIAL",
    "title": "Weekly Special Exam — সপ্তাহ 3",
    "topics": "দিন ১৫–২০ থেকে ৬০ প্রশ্ন + আগের দুই সপ্তাহ থেকে ৪০: বাংলা—বাক্য, বাগধারা ও প্রয়োগ; ইংরেজি—voice, narration ও clauses; বাংলাদেশ—অর্থনীতি, কৃষি ও শিল্প; গণিত—বীজগণিত ও জ্যামিতি; বিজ্ঞান—কোষ, স্বাস্থ্য ও জিন; ICT—ইন্টারনেট ও নিরাপত্তা; আন্তর্জাতিক—বিশ্ব ইতিহাস; ভূগোল—দুর্যোগ; মানসিক দক্ষতা—যান্ত্রিক যুক্তি; নৈতিকতা—জনসেবা।",
    "starts": "15:00",
    "ends": "16:00",
    "publish": "16:10",
    "duration": 3600,
    "marks": 100
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-10",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 21",
    "topics": "গত ৬ দিনের পড়া টপিকের মিশ্র রিভিশন; Weekly Special-এর একই প্রশ্ন নয়। পরিধি: বাংলা—বাক্য, বাগধারা ও প্রয়োগ; ইংরেজি—voice, narration ও clauses; বাংলাদেশ—অর্থনীতি, কৃষি ও শিল্প; গণিত—বীজগণিত ও জ্যামিতি; বিজ্ঞান—কোষ, স্বাস্থ্য ও জিন; ICT—ইন্টারনেট ও নিরাপত্তা; আন্তর্জাতিক—বিশ্ব ইতিহাস; ভূগোল—দুর্যোগ; মানসিক দক্ষতা—যান্ত্রিক যুক্তি; নৈতিকতা—জনসেবা।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-11",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 22",
    "topics": "বাংলা ভাষা ও সাহিত্য — বাংলা ব্যাকরণ-সাহিত্য দুর্বল টপিক; গাণিতিক যুক্তি — সেট, বিন্যাস-সমাবেশ ও সম্ভাবনা। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-12",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 23",
    "topics": "ইংরেজি ভাষা ও সাহিত্য — English mixed grammar ও literature revision; বাংলাদেশ বিষয়াবলি — বাংলাদেশ: সংস্কৃতি, প্রতিষ্ঠান ও জাতীয় অর্জন। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-13",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 24",
    "topics": "সাধারণ বিজ্ঞান — বিজ্ঞান: ভুল হওয়া সূত্র ও ধারণা; কম্পিউটার ও তথ্যপ্রযুক্তি — ICT: দুর্বল টপিক ও প্রযুক্তির মৌলিক ধারণা। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-14",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 25",
    "topics": "আন্তর্জাতিক বিষয়াবলি — আন্তর্জাতিক বিষয়াবলি: source-dated update; ভূগোল, পরিবেশ ও দুর্যোগ ব্যবস্থাপনা — ভূগোল–পরিবেশ–দুর্যোগ মিশ্র রিভিশন। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-15",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 26",
    "topics": "মানসিক দক্ষতা — মানসিক দক্ষতা: timed problem set; নৈতিকতা, মূল্যবোধ ও সুশাসন — নৈতিকতা ও সুশাসন: পরিস্থিতিভিত্তিক প্রশ্ন। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-16",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 27",
    "topics": "বাংলা ভাষা ও সাহিত্য + ইংরেজি ভাষা ও সাহিত্য — মাসের ভুলের খাতা: বাংলা ও English; গাণিতিক যুক্তি + বাংলাদেশ বিষয়াবলি — মাসের ভুলের খাতা: গণিত ও বাংলাদেশ। এই দুই অংশে ২০+২০ প্রশ্ন; আগের পড়া থেকে ১০।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-17",
    "kind": "WEEKLY_SPECIAL",
    "title": "Weekly Special Exam — সপ্তাহ 4",
    "topics": "দিন ১–২৭-এর cumulative: বাংলা ভাষা ও সাহিত্য; ইংরেজি ভাষা ও সাহিত্য; বাংলাদেশ বিষয়াবলি; আন্তর্জাতিক বিষয়াবলি; ভূগোল–পরিবেশ–দুর্যোগ; সাধারণ বিজ্ঞান; কম্পিউটার ও ICT; গাণিতিক যুক্তি; মানসিক দক্ষতা; নৈতিকতা ও সুশাসন। শুধু পড়া টপিক; ভুল হওয়া টপিককে অগ্রাধিকার।",
    "starts": "15:00",
    "ends": "16:00",
    "publish": "16:10",
    "duration": 3600,
    "marks": 100
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-17",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 28",
    "topics": "গত ৬ দিনের পড়া টপিকের মিশ্র রিভিশন; Weekly Special-এর একই প্রশ্ন নয়। পরিধি: বাংলা ভাষা ও সাহিত্য; ইংরেজি ভাষা ও সাহিত্য; বাংলাদেশ বিষয়াবলি; আন্তর্জাতিক বিষয়াবলি; ভূগোল–পরিবেশ–দুর্যোগ; সাধারণ বিজ্ঞান; কম্পিউটার ও ICT; গাণিতিক যুক্তি; মানসিক দক্ষতা; নৈতিকতা ও সুশাসন। শুধু পড়া টপিক; ভুল হওয়া টপিককে অগ্রাধিকার।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-18",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 29",
    "topics": "গত চার Weekly Special-এর ফল অনুযায়ী সবচেয়ে দুর্বল বিষয় ১—২৫ প্রশ্ন; সবচেয়ে দুর্বল বিষয় ২—২৫ প্রশ্ন। বিষয় ও টপিক ফলাফল দেখে নির্ধারণ করতে হবে।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  },
  {
    "plan_key": "bcs-2026-11-20-30days",
    "date": "2026-12-19",
    "kind": "DAILY_LIVE",
    "title": "Daily Live Exam — দিন 30",
    "topics": "মাসজুড়ে পড়া সব ১০টি BCS বিষয়ের মিশ্র ৫০ প্রশ্ন; ভুলের খাতা, সূত্র ও দুর্বল ধারণার পুনঃমূল্যায়ন।",
    "starts": "20:00",
    "ends": "20:40",
    "publish": "20:50",
    "duration": 2400,
    "marks": 50
  }
]
$monthly_config$::jsonb) as c(
 plan_key text,date date,kind text,title text,topics text,
 starts text,ends text,publish text,duration integer,marks integer
 )
)
insert into jobmaster_private.bcs_month_plan
 (plan_key,exam_date,kind,title,topics,starts,ends,publish,duration,marks)
select plan_key,date,kind,title,topics,
 floor(extract(epoch from ((date+starts::time) at time zone 'Asia/Dhaka'))*1000)::bigint,
 floor(extract(epoch from ((date+ends::time) at time zone 'Asia/Dhaka'))*1000)::bigint,
 floor(extract(epoch from ((date+publish::time) at time zone 'Asia/Dhaka'))*1000)::bigint,
 duration,marks
from config
on conflict(plan_key,exam_date,kind) do nothing;

-- Project-owner SQL helper, NOT a browser endpoint. No SECURITY DEFINER bypass.
-- A question's verified=true AND explicit topic_match_checked=true are required.
-- Fixed marking in the current app: correct +1, wrong -0.5, unanswered 0.
create or replace function jobmaster_private.publish_ready_bcs_month(
 target_plan text default 'bcs-2026-11-20-30days'
) returns table(plan_id uuid,exam_name text,outcome text,linked_questions integer,required_questions integer)
language plpgsql security invoker set search_path='' as $$
declare
 p jobmaster_private.bcs_month_plan;
 n integer; invalid_n integer; ids jsonb; new_exam uuid;
begin
 -- Serialize publication to prevent simultaneous same-day question reuse.
 perform pg_advisory_xact_lock(hashtext('jobmaster-bcs-month-publication'));
 for p in select * from jobmaster_private.bcs_month_plan m
   where m.plan_key=target_plan order by m.exam_date,m.starts for update
 loop
  plan_id:=p.id;exam_name:=p.title;required_questions:=p.marks;
  select count(*) into n from jobmaster_private.bcs_plan_questions l where l.plan_id=p.id;
  linked_questions:=n;
  if p.exam_id is not null then
   outcome:='ALREADY_PUBLISHED';return next;continue;
  end if;
  if p.starts<=jobmaster_private.now_ms() then
   outcome:='PAST_START_NOT_PUBLISHED';return next;continue;
  end if;
  if n<>p.marks then
   outcome:='QUESTIONS_PENDING';return next;continue;
  end if;
  select count(*) into invalid_n
   from jobmaster_private.bcs_plan_questions l
   join jobmaster_private.questions q on q.id=l.question_id
   where l.plan_id=p.id
     and (q.verified is distinct from true or q.data->>'track' is distinct from 'BCS'
       or l.topic_match_checked is distinct from true);
  if invalid_n>0 then
   outcome:='VERIFICATION_OR_TOPIC_REVIEW_PENDING';return next;continue;
  end if;
  -- Do not leak today's daily answers into a weekly exam or vice versa.
  if exists(
   select 1 from jobmaster_private.exams e
   cross join lateral jsonb_array_elements_text(e.question_ids) eid(qid)
   join jobmaster_private.bcs_plan_questions l on l.question_id=eid.qid and l.plan_id=p.id
   where e.track='BCS'
    and (to_timestamp(e.starts/1000.0) at time zone 'Asia/Dhaka')::date=p.exam_date
  ) then
   outcome:='SAME_DAY_QUESTION_REUSE_BLOCKED';return next;continue;
  end if;
  select jsonb_agg(l.question_id order by random()) into ids
   from jobmaster_private.bcs_plan_questions l where l.plan_id=p.id;
  insert into jobmaster_private.exams(title,track,starts,ends,publish,duration,question_ids)
   values(left(p.title||' | '||p.topics,200),'BCS',p.starts,p.ends,p.publish,p.duration,ids)
   returning id into new_exam;
  update jobmaster_private.bcs_month_plan set exam_id=new_exam where id=p.id;
  insert into jobmaster_private.audit(actor,action,entity)
   values(auth.uid(),'bcs_month_publish',new_exam::text);
  outcome:='PUBLISHED';return next;
 end loop;
end $$;
revoke all on function jobmaster_private.publish_ready_bcs_month(text) from public,anon,authenticated;
commit;

-- Publishes only complete, verified and explicitly topic-reviewed papers.
-- On first Run, QUESTIONS_PENDING is expected if question links have not been assigned.
select * from jobmaster_private.publish_ready_bcs_month();

-- Human-readable routine. No answer keys or secret values are returned.
select
 p.id as plan_id,
 p.exam_date as date_bangladesh,
 p.title as exam,
 p.topics as subjects_and_topics,
 p.marks as total_marks,
 p.duration/60 as duration_minutes,
 to_char(to_timestamp(p.starts/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as starts_bangladesh,
 to_char(to_timestamp(p.ends/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as ends_bangladesh,
 to_char(to_timestamp(p.publish/1000.0) at time zone 'Asia/Dhaka','HH24:MI') as results_bangladesh,
 (select count(*) from jobmaster_private.bcs_plan_questions l where l.plan_id=p.id) as assigned_questions,
 case when p.exam_id is null then 'DRAFT — QUESTIONS/REVIEW PENDING' else 'PUBLISHED' end as status
from jobmaster_private.bcs_month_plan p
where p.plan_key='bcs-2026-11-20-30days'
order by p.exam_date,p.starts;

-- HOW TO ASSIGN QUESTIONS LATER (owner/editorial work, intentionally not automatic):
-- 1. Select a plan_id from the result and identify exact suitable BCS question IDs.
-- 2. Review their subject/topic match and correctness/source first.
-- 3. Link exactly 50/100 distinct questions. Example SHAPE only, not runnable values:
--    insert into jobmaster_private.bcs_plan_questions(plan_id,question_id,topic_match_checked)
--    values ('ACTUAL-PLAN-UUID'::uuid,'ACTUAL-QUESTION-ID',true);
-- 4. Verify reviewed questions in Admin; then run:
--    select * from jobmaster_private.publish_ready_bcs_month();
-- Never mass-verify or mark topic_match_checked=true without editorial review.
-- A weekly 100 + daily 50 on the same day needs 150 distinct appropriate verified questions.
-- Across days, repeat questions are possible; use fresh links if no repeat is desired.
-- This plan is an editorial practice schedule, NOT official BPSC marks distribution.

-- NEW: authenticated, read-only calendar feed for the Vercel UI.
-- Does not expose question IDs, answers, profiles, or admin credentials.
create or replace function public.jobmaster_calendar()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Unauthorized';end if;
 return jsonb_build_object(
  'now',jobmaster_private.now_ms(),
  'timezone','Asia/Dhaka',
  'plans',coalesce((select jsonb_agg(jsonb_build_object(
   'id',p.id,'date',p.exam_date,'kind',p.kind,'title',p.title,'topics',p.topics,
   'starts',p.starts,'ends',p.ends,'publish',p.publish,'duration',p.duration,
   'marks',p.marks,'exam_id',p.exam_id,
   'status',case when p.exam_id is null then 'DRAFT'
      when jobmaster_private.now_ms()<p.starts then 'SCHEDULED'
      when jobmaster_private.now_ms()<p.ends then 'LIVE' else 'ENDED' end
  ) order by p.exam_date,p.starts)
  from jobmaster_private.bcs_month_plan p
  where p.plan_key='bcs-2026-11-20-30days'),'[]'::jsonb)
 );
end $$;
revoke all on function public.jobmaster_calendar() from public,anon;
grant execute on function public.jobmaster_calendar() to authenticated;

-- Expected: 30 daily + 4 weekly = 34. These exist even before question papers are ready.
select kind,count(*) as planned_exams
from jobmaster_private.bcs_month_plan
where plan_key='bcs-2026-11-20-30days'
group by kind;

-- If pg_cron was enabled in the earlier scheduler step, publish complete ready papers
-- every minute without another manual SQL call. No questions are auto-verified or auto-linked.
do $$
begin
 if to_regclass('cron.job') is not null then
  if not exists(select 1 from cron.job where jobname='jobmaster-bcs-ready-publish') then
   perform cron.schedule(
    'jobmaster-bcs-ready-publish','* * * * *',
    'select * from jobmaster_private.publish_ready_bcs_month();'
   );
  end if;
 else
  raise notice 'pg_cron not enabled: calendar works; automatic ready-paper publication needs the scheduler extension.';
 end if;
end $$;
