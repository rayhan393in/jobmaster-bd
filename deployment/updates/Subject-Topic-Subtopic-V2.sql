-- Requires existing STEP-5, BCS-Auto-Routine-Setup and BCS-Daywise-Import.
-- Additive taxonomy. Does not approve drafts, change question content or attempts.
begin;
DO $$begin if to_regclass('jobmaster_private.bcs_question_sources') is null then raise exception 'Install existing month-plan/daywise prerequisites first';end if;end $$;
select pg_advisory_xact_lock(hashtext('jobmaster-exam-taxonomy-v2'));
create table if not exists jobmaster_private.exam_subjects(id text primary key,track text not null check(track in ('BCS','EEE')),title text not null);
create table if not exists jobmaster_private.exam_topics(id text primary key,subject_id text not null references jobmaster_private.exam_subjects(id),chapter text not null,title text not null);
create table if not exists jobmaster_private.exam_subtopics(id text primary key,topic_id text not null references jobmaster_private.exam_topics(id),title text not null);
create table if not exists jobmaster_private.question_classification(question_id text primary key references jobmaster_private.questions(id) on delete cascade,subtopic_id text not null references jobmaster_private.exam_subtopics(id),assigned_by uuid,updated timestamptz not null default clock_timestamp());
create index if not exists exam_classification_leaf on jobmaster_private.question_classification(subtopic_id);
DO $$declare t text;begin foreach t in array array['exam_subjects','exam_topics','exam_subtopics','question_classification'] loop execute format('alter table jobmaster_private.%I enable row level security',t);execute format('revoke all on jobmaster_private.%I from public,anon,authenticated',t);end loop;end $$;
insert into jobmaster_private.exam_subjects values('bcs:bangla','BCS','বাংলা ভাষা ও সাহিত্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:720507debcc9','bcs:bangla','ব্যাকরণ','ধ্বনি ও বর্ণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:720507debcc9:general','bcs:bangla:720507debcc9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:720507debcc9:b6a5166d1a97','bcs:bangla:720507debcc9','ধ্বনিবিজ্ঞান') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:43e40ad87110','bcs:bangla','ব্যাকরণ','সন্ধি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:43e40ad87110:general','bcs:bangla:43e40ad87110','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:f7945cc097f9','bcs:bangla','ব্যাকরণ','সমাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:f7945cc097f9:general','bcs:bangla:f7945cc097f9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:0fd695d9ac47','bcs:bangla','ব্যাকরণ','কারক ও বিভক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:0fd695d9ac47:general','bcs:bangla:0fd695d9ac47','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:0fd695d9ac47:f54d9047f82a','bcs:bangla:0fd695d9ac47','কারক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:bc828a8c0c12','bcs:bangla','ব্যাকরণ','প্রত্যয়') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:bc828a8c0c12:general','bcs:bangla:bc828a8c0c12','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:e42e9ec37b46','bcs:bangla','ব্যাকরণ','উপসর্গ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:e42e9ec37b46:general','bcs:bangla:e42e9ec37b46','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:7bd1fd78926f','bcs:bangla','ব্যাকরণ','পদ ও পদপ্রকরণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:7bd1fd78926f:general','bcs:bangla:7bd1fd78926f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:c5870d9f96d7','bcs:bangla','ব্যাকরণ','বাক্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:c5870d9f96d7:general','bcs:bangla:c5870d9f96d7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:9ebc5e3d9216','bcs:bangla','ব্যাকরণ','শুদ্ধ বানান ও প্রয়োগ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:9ebc5e3d9216:general','bcs:bangla:9ebc5e3d9216','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:9ebc5e3d9216:6e3bdc4fe39b','bcs:bangla:9ebc5e3d9216','বানান') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:0c4abd08e928','bcs:bangla','ব্যাকরণ','বাগধারা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:0c4abd08e928:general','bcs:bangla:0c4abd08e928','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:3d64b0304971','bcs:bangla','ব্যাকরণ','সমার্থক ও বিপরীত শব্দ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:3d64b0304971:general','bcs:bangla:3d64b0304971','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:b3bfde7cf157','bcs:bangla','সাহিত্য','প্রাচীন যুগ ও চর্যাপদ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:b3bfde7cf157:general','bcs:bangla:b3bfde7cf157','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:b3bfde7cf157:a15084ae6d43','bcs:bangla:b3bfde7cf157','প্রাচীন সাহিত্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:6bc6f3122499','bcs:bangla','সাহিত্য','মধ্যযুগের সাহিত্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:6bc6f3122499:general','bcs:bangla:6bc6f3122499','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:86e5581acefe','bcs:bangla','সাহিত্য','আধুনিক যুগ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:86e5581acefe:general','bcs:bangla:86e5581acefe','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:818d9d8fa992','bcs:bangla','সাহিত্য','কবি ও সাহিত্যিক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:818d9d8fa992:general','bcs:bangla:818d9d8fa992','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:818d9d8fa992:431e9b9f4085','bcs:bangla:818d9d8fa992','কবিতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bangla:5379b522c084','bcs:bangla','সাহিত্য','বিখ্যাত গ্রন্থ ও চরিত্র') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:5379b522c084:general','bcs:bangla:5379b522c084','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bangla:5379b522c084:f4a529991ee0','bcs:bangla:5379b522c084','উপন্যাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:english','BCS','English Language & Literature') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:771046687efa','bcs:english','Language','Parts of speech') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:771046687efa:general','bcs:english:771046687efa','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:45b80ee2fedb','bcs:english','Language','Tense and aspect') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:45b80ee2fedb:general','bcs:english:45b80ee2fedb','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:45b80ee2fedb:2cacf6c14ec8','bcs:english:45b80ee2fedb','Tense') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:45b80ee2fedb:abe00e9c9c31','bcs:english:45b80ee2fedb','Finished past time') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:45b80ee2fedb:3597ef1f9fe2','bcs:english:45b80ee2fedb','Inversion') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:45b80ee2fedb:a52bb78d5609','bcs:english:45b80ee2fedb','Paired conjunctions') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:9f473d774945','bcs:english','Language','Subject-verb agreement') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:9f473d774945:general','bcs:english:9f473d774945','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:9f473d774945:fc31779117de','bcs:english:9f473d774945','Subject–verb agreement') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:6658e9b36c34','bcs:english','Language','Articles and determiners') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:6658e9b36c34:general','bcs:english:6658e9b36c34','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:6658e9b36c34:b14ac78a46e9','bcs:english:6658e9b36c34','Articles') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:f6bcda8b4f94','bcs:english','Language','Prepositions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:f6bcda8b4f94:general','bcs:english:f6bcda8b4f94','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:f6bcda8b4f94:a0d846a0e9c6','bcs:english:f6bcda8b4f94','Time expressions') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:87bf2bc08589','bcs:english','Language','Voice') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:87bf2bc08589:general','bcs:english:87bf2bc08589','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:d90a31d7b565','bcs:english','Language','Narration') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:general','bcs:english:d90a31d7b565','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:28104b8f1375','bcs:english:d90a31d7b565','Pronouns') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:3671fc2f9e7f','bcs:english:d90a31d7b565','Reporting verbs') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:77ae9160b827','bcs:english:d90a31d7b565','Backshift') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:40c1aeb77c4e','bcs:english:d90a31d7b565','Present reporting verb') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:29fbda27d46a','bcs:english:d90a31d7b565','Reported facts') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:7c3295f7f169','bcs:english:d90a31d7b565','Reported modals') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:21086ed44d58','bcs:english:d90a31d7b565','Time references') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:d11eedfc27fb','bcs:english:d90a31d7b565','Place references') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:39cbc15b8fca','bcs:english:d90a31d7b565','Indirect questions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:6cab2d8cd0db','bcs:english:d90a31d7b565','Word order') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:b7e8acdd522e','bcs:english:d90a31d7b565','Orders') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:d65c09e289ea','bcs:english:d90a31d7b565','Prohibitions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:ada27592c957','bcs:english:d90a31d7b565','Requests') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:305f5e5463e1','bcs:english:d90a31d7b565','Advice') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:16c1d601fc66','bcs:english:d90a31d7b565','Suggestions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:1627c4947843','bcs:english:d90a31d7b565','Permission requests') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:403cc21502eb','bcs:english:d90a31d7b565','Wishes') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:5799f08aa568','bcs:english:d90a31d7b565','Prayers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:d19e3194b388','bcs:english:d90a31d7b565','Exclamations') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:5e883e98cf79','bcs:english:d90a31d7b565','Apologies') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:d90a31d7b565:ed7a9987f264','bcs:english:d90a31d7b565','Congratulations') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:565dfca4a5bd','bcs:english','Language','Clauses and phrases') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:565dfca4a5bd:general','bcs:english:565dfca4a5bd','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:565dfca4a5bd:126995365015','bcs:english:565dfca4a5bd','Conditionals') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:547efd6bc280','bcs:english','Language','Sentence correction') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:general','bcs:english:547efd6bc280','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:3138cdacb043','bcs:english:547efd6bc280','Modals') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:5cbb4f06c6fd','bcs:english:547efd6bc280','Auxiliary verbs') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:10a0d424f76e','bcs:english:547efd6bc280','Infinitives') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:365c8947d85c','bcs:english:547efd6bc280','Gerunds') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:740ded6936a6','bcs:english:547efd6bc280','Perfect forms') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:a3db25569b22','bcs:english:547efd6bc280','Continuous forms') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:b2a2075aa145','bcs:english:547efd6bc280','Passive forms') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:e75e2900dd2a','bcs:english:547efd6bc280','Bare infinitives') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:7825ae82af79','bcs:english:547efd6bc280','Causatives') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:ed320a989e48','bcs:english:547efd6bc280','Passive causatives') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:5ffb5737db16','bcs:english:547efd6bc280','Verb patterns') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:88cceadb438b','bcs:english:547efd6bc280','Preference clauses') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:fc0f8a512b9d','bcs:english:547efd6bc280','Past habits') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:85e4d9f5bbea','bcs:english:547efd6bc280','Accustomed actions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:0c06ea20ec0c','bcs:english:547efd6bc280','Prepositional to') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:868f2b9d42d3','bcs:english:547efd6bc280','Unreal past form') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:547efd6bc280:403cc21502eb','bcs:english:547efd6bc280','Wishes') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:8aeb948188e6','bcs:english','Language','Vocabulary, idioms and spelling') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:8aeb948188e6:general','bcs:english:8aeb948188e6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:8aeb948188e6:eebd90a046c6','bcs:english:8aeb948188e6','Vocabulary') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:8aeb948188e6:4e1495cb16ac','bcs:english:8aeb948188e6','Idioms') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:5092f78525f7','bcs:english','Literature','Literary periods') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:5092f78525f7:general','bcs:english:5092f78525f7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:b993ca685399','bcs:english','Literature','Major authors and works') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:b993ca685399:general','bcs:english:b993ca685399','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:b993ca685399:da72bf5bbca4','bcs:english:b993ca685399','Drama') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:b993ca685399:a6f10bde1cb3','bcs:english:b993ca685399','Poetry') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:ee8bd7d1ee80','bcs:english','Literature','Literary terms') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:ee8bd7d1ee80:general','bcs:english:ee8bd7d1ee80','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:english:8e925b5c1133','bcs:english','Literature','Poetry, drama and fiction') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:english:8e925b5c1133:general','bcs:english:8e925b5c1133','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:bd','BCS','বাংলাদেশ বিষয়াবলি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:3481ca6f86d3','bcs:bd','ইতিহাস ও রাষ্ট্র','প্রাচীন ও মধ্যযুগের ইতিহাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:3481ca6f86d3:general','bcs:bd:3481ca6f86d3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:baad1f4397bf','bcs:bd','ইতিহাস ও রাষ্ট্র','ভাষা আন্দোলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:baad1f4397bf:general','bcs:bd:baad1f4397bf','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:66662d5eb1a4','bcs:bd','ইতিহাস ও রাষ্ট্র','মুক্তিযুদ্ধ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:66662d5eb1a4:general','bcs:bd:66662d5eb1a4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:570709e5e859','bcs:bd','ইতিহাস ও রাষ্ট্র','সংবিধান') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:570709e5e859:general','bcs:bd:570709e5e859','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:570709e5e859:998118b96e82','bcs:bd:570709e5e859','সংবিধানের ইতিহাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:d543a2100e1c','bcs:bd','ইতিহাস ও রাষ্ট্র','রাজনৈতিক ও সরকার ব্যবস্থা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:d543a2100e1c:general','bcs:bd:d543a2100e1c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:d543a2100e1c:2950915a19a0','bcs:bd:d543a2100e1c','ছয় দফা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:a246d599459e','bcs:bd','সমাজ ও অর্থনীতি','ভূপ্রকৃতি ও সম্পদ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:a246d599459e:general','bcs:bd:a246d599459e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:a246d599459e:e9f2dc05114a','bcs:bd:a246d599459e','ভৌগোলিক অবস্থান') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:18ce88ebeba4','bcs:bd','সমাজ ও অর্থনীতি','জনসংখ্যা ও সংস্কৃতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:18ce88ebeba4:general','bcs:bd:18ce88ebeba4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:18ce88ebeba4:51af6f13c484','bcs:bd:18ce88ebeba4','সংস্কৃতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:811bce8dfdad','bcs:bd','সমাজ ও অর্থনীতি','কৃষি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:811bce8dfdad:general','bcs:bd:811bce8dfdad','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:27ca1d4ccf26','bcs:bd','সমাজ ও অর্থনীতি','শিল্প ও বাণিজ্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:27ca1d4ccf26:general','bcs:bd:27ca1d4ccf26','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:a3f141453df7','bcs:bd','সমাজ ও অর্থনীতি','অর্থনীতি ও বাজেট') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:a3f141453df7:general','bcs:bd:a3f141453df7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:bd:bb5ccc21e697','bcs:bd','সমাজ ও অর্থনীতি','জাতীয় প্রতিষ্ঠান ও অর্জন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:bb5ccc21e697:general','bcs:bd:bb5ccc21e697','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:bd:bb5ccc21e697:9d7353c17b6e','bcs:bd:bb5ccc21e697','অর্থনীতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:international','BCS','আন্তর্জাতিক বিষয়াবলি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:d12f661162b0','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','বিশ্ব ইতিহাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:d12f661162b0:general','bcs:international:d12f661162b0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:e5b52119c755','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','ভূরাজনীতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:e5b52119c755:general','bcs:international:e5b52119c755','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:e5b52119c755:412080858647','bcs:international:e5b52119c755','সমুদ্রপথ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:a56b781492fc','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','আন্তর্জাতিক নিরাপত্তা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:a56b781492fc:general','bcs:international:a56b781492fc','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:c99dd5704a8e','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','জাতিসংঘ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:c99dd5704a8e:general','bcs:international:c99dd5704a8e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:c99dd5704a8e:520da8f86df8','bcs:international:c99dd5704a8e','আন্তর্জাতিক বিচারব্যবস্থা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:c99dd5704a8e:bcd13c79e3e7','bcs:international:c99dd5704a8e','বিশ্ব স্বাস্থ্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:c99dd5704a8e:d0f6c7c7007e','bcs:international:c99dd5704a8e','মানবাধিকার') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:c99dd5704a8e:2f8ed2460be0','bcs:international:c99dd5704a8e','টেকসই উন্নয়ন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:e5f34824197d','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','আঞ্চলিক ও অর্থনৈতিক সংস্থা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:e5f34824197d:general','bcs:international:e5f34824197d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:e5f34824197d:819981f81412','bcs:international:e5f34824197d','আঞ্চলিক সংস্থা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:e5f34824197d:91fe75ae64a5','bcs:international:e5f34824197d','বাণিজ্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:542a021d6b0e','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','আন্তর্জাতিক চুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:542a021d6b0e:general','bcs:international:542a021d6b0e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:542a021d6b0e:887d68894230','bcs:international:542a021d6b0e','জলবায়ু কূটনীতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:international:65edb15084ea','bcs:international','বিশ্ব ও আন্তর্জাতিক সম্পর্ক','সমসাময়িক ঘটনা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:international:65edb15084ea:general','bcs:international:65edb15084ea','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:geography','BCS','ভূগোল, পরিবেশ ও দুর্যোগ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:aa339cb5bd11','bcs:geography','ভূগোল','বাংলাদেশের অবস্থান ও ভূপ্রকৃতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:aa339cb5bd11:general','bcs:geography:aa339cb5bd11','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:aa339cb5bd11:78dce84d2e0f','bcs:geography:aa339cb5bd11','নদীভূমি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:1644479ad6b5','bcs:geography','ভূগোল','বিশ্ব ভূগোল') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:1644479ad6b5:general','bcs:geography:1644479ad6b5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:1644479ad6b5:99c825a1422f','bcs:geography:1644479ad6b5','স্থানাঙ্ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:8a66ea49bc3e','bcs:geography','ভূগোল','জলবায়ু') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:8a66ea49bc3e:general','bcs:geography:8a66ea49bc3e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:8a66ea49bc3e:a0c311d05236','bcs:geography:8a66ea49bc3e','ঋতু') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:8a66ea49bc3e:f90c60bf7d9f','bcs:geography:8a66ea49bc3e','বায়ুমণ্ডল') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:7d15f9f2739c','bcs:geography','ভূগোল','প্রাকৃতিক সম্পদ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:7d15f9f2739c:general','bcs:geography:7d15f9f2739c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:09c709ec86b6','bcs:geography','পরিবেশ ও দুর্যোগ','বাস্তুতন্ত্র') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:09c709ec86b6:general','bcs:geography:09c709ec86b6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:8cab1abb2de7','bcs:geography','পরিবেশ ও দুর্যোগ','দূষণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:8cab1abb2de7:general','bcs:geography:8cab1abb2de7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:8cab1abb2de7:6b7fe6081b61','bcs:geography:8cab1abb2de7','পরিবেশ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:4dcd871b12f2','bcs:geography','পরিবেশ ও দুর্যোগ','জলবায়ু পরিবর্তন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:4dcd871b12f2:general','bcs:geography:4dcd871b12f2','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:c1cb496af13f','bcs:geography','পরিবেশ ও দুর্যোগ','দুর্যোগ ঝুঁকি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:c1cb496af13f:general','bcs:geography:c1cb496af13f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:c1cb496af13f:aea17e4f99a2','bcs:geography:c1cb496af13f','ভূমিকম্প') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:c1cb496af13f:d4e80b351a04','bcs:geography:c1cb496af13f','ঘূর্ণিঝড়') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:geography:1bd2cb940a84','bcs:geography','পরিবেশ ও দুর্যোগ','প্রস্তুতি ও প্রশমন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:1bd2cb940a84:general','bcs:geography:1bd2cb940a84','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:geography:1bd2cb940a84:15db76ffc233','bcs:geography:1bd2cb940a84','দুর্যোগ প্রস্তুতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:science','BCS','সাধারণ বিজ্ঞান') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:a17f73157029','bcs:science','ভৌত বিজ্ঞান','ভৌত রাশি ও একক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a17f73157029:general','bcs:science:a17f73157029','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a17f73157029:9b426deb1c88','bcs:science:a17f73157029','পরিমাপ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:b5c3e35138b9','bcs:science','ভৌত বিজ্ঞান','গতি ও বল') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:b5c3e35138b9:general','bcs:science:b5c3e35138b9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:58fbf2103113','bcs:science','ভৌত বিজ্ঞান','কাজ, শক্তি ও ক্ষমতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:58fbf2103113:general','bcs:science:58fbf2103113','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:58fbf2103113:7bd89f5cd9a4','bcs:science:58fbf2103113','কাজ ও শক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:6879f11f1e4d','bcs:science','ভৌত বিজ্ঞান','তাপ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:6879f11f1e4d:general','bcs:science:6879f11f1e4d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:48fd4f2d32b2','bcs:science','ভৌত বিজ্ঞান','আলো ও শব্দ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:48fd4f2d32b2:general','bcs:science:48fd4f2d32b2','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:48fd4f2d32b2:a24c09a18d30','bcs:science:48fd4f2d32b2','আলো') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:35722c11b79a','bcs:science','ভৌত বিজ্ঞান','বিদ্যুৎ ও চুম্বক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:35722c11b79a:general','bcs:science:35722c11b79a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:35722c11b79a:848b3a7dd002','bcs:science:35722c11b79a','বিদ্যুৎ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:6a8f53327ff5','bcs:science','ভৌত বিজ্ঞান','পরমাণু ও রাসায়নিক বিক্রিয়া') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:6a8f53327ff5:general','bcs:science:6a8f53327ff5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:6a8f53327ff5:38d2d9aa1a80','bcs:science:6a8f53327ff5','অম্ল ও ক্ষার') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:6a8f53327ff5:11807c752703','bcs:science:6a8f53327ff5','পরমাণু') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:26e67e116026','bcs:science','জীব ও আধুনিক বিজ্ঞান','কোষ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:26e67e116026:general','bcs:science:26e67e116026','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:a526aeb62e8a','bcs:science','জীব ও আধুনিক বিজ্ঞান','জীবপ্রক্রিয়া') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a526aeb62e8a:general','bcs:science:a526aeb62e8a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a526aeb62e8a:f431a2370588','bcs:science:a526aeb62e8a','উদ্ভিদবিজ্ঞান') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a526aeb62e8a:27416aa044ef','bcs:science:a526aeb62e8a','মানবদেহ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:10628f53805c','bcs:science','জীব ও আধুনিক বিজ্ঞান','পুষ্টি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:10628f53805c:general','bcs:science:10628f53805c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:31601d548685','bcs:science','জীব ও আধুনিক বিজ্ঞান','রোগ ও স্বাস্থ্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:31601d548685:general','bcs:science:31601d548685','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:31601d548685:b67b9ec4675f','bcs:science:31601d548685','সংক্রামক রোগ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:a29b59a2d20b','bcs:science','জীব ও আধুনিক বিজ্ঞান','জিন ও বংশগতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a29b59a2d20b:general','bcs:science:a29b59a2d20b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:science:a81709bb2cd8','bcs:science','জীব ও আধুনিক বিজ্ঞান','আধুনিক প্রযুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:science:a81709bb2cd8:general','bcs:science:a81709bb2cd8','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:ict','BCS','কম্পিউটার ও তথ্যপ্রযুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:c1ccacfd7c52','bcs:ict','কম্পিউটার','হার্ডওয়্যার') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:c1ccacfd7c52:general','bcs:ict:c1ccacfd7c52','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:c2c2ff567efa','bcs:ict','কম্পিউটার','সফটওয়্যার') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:c2c2ff567efa:general','bcs:ict:c2c2ff567efa','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:c2c2ff567efa:2ab377bad512','bcs:ict:c2c2ff567efa','স্প্রেডশিট') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:c2c2ff567efa:4a98d421c372','bcs:ict:c2c2ff567efa','প্রোগ্রামিং') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:f4a3a6bc619a','bcs:ict','কম্পিউটার','সংখ্যা পদ্ধতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:f4a3a6bc619a:general','bcs:ict:f4a3a6bc619a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:f4a3a6bc619a:4bfbca2f0e57','bcs:ict:f4a3a6bc619a','সংখ্যাপদ্ধতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:95aea70c07b0','bcs:ict','কম্পিউটার','ডেটা ও মেমোরি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:95aea70c07b0:general','bcs:ict:95aea70c07b0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:95aea70c07b0:f4ca4cf03d9d','bcs:ict:95aea70c07b0','মেমরি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:95aea70c07b0:9a66c2ef1d18','bcs:ict:95aea70c07b0','ডেটার একক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:2064bda18a22','bcs:ict','কম্পিউটার','অপারেটিং সিস্টেম') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:2064bda18a22:general','bcs:ict:2064bda18a22','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:6c805050a42a','bcs:ict','কম্পিউটার','ডেটাবেজ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:6c805050a42a:general','bcs:ict:6c805050a42a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:6c805050a42a:fca3b7cc9e3c','bcs:ict:6c805050a42a','ডেটাবেস') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:83c3543cb233','bcs:ict','তথ্যপ্রযুক্তি','নেটওয়ার্ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:83c3543cb233:general','bcs:ict:83c3543cb233','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:7dc8e73e7b92','bcs:ict','তথ্যপ্রযুক্তি','ইন্টারনেট ও ওয়েব') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:7dc8e73e7b92:general','bcs:ict:7dc8e73e7b92','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:7dc8e73e7b92:f914e5a95460','bcs:ict:7dc8e73e7b92','ইন্টারনেট') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:b6d7ad7943ff','bcs:ict','তথ্যপ্রযুক্তি','সাইবার নিরাপত্তা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:b6d7ad7943ff:general','bcs:ict:b6d7ad7943ff','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:df256def7adb','bcs:ict','তথ্যপ্রযুক্তি','ডিজিটাল সেবা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:df256def7adb:general','bcs:ict:df256def7adb','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ict:992d5c220407','bcs:ict','তথ্যপ্রযুক্তি','উদীয়মান প্রযুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ict:992d5c220407:general','bcs:ict:992d5c220407','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:math','BCS','গাণিতিক যুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:7a6ff78f9440','bcs:math','পাটিগণিত','বাস্তব সংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:general','bcs:math:7a6ff78f9440','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:4f3ef4b22679','bcs:math:7a6ff78f9440','জোড়-বিজোড়') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:39aa511048b3','bcs:math:7a6ff78f9440','মৌলিক সংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:99023d9a86c6','bcs:math:7a6ff78f9440','মৌলিকতা পরীক্ষা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:0271932f47cb','bcs:math:7a6ff78f9440','সহমৌলিক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:a15b7a5422db','bcs:math:7a6ff78f9440','মূলদ সংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:1ab573e2f3df','bcs:math:7a6ff78f9440','অমূলদ সংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:3cb6fd291852','bcs:math:7a6ff78f9440','আবৃত্ত দশমিক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:d8b0eec235d9','bcs:math:7a6ff78f9440','অমূলদ রাশি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:b38d24590f24','bcs:math:7a6ff78f9440','সংখ্যার শ্রেণি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:82fcb3b4025c','bcs:math:7a6ff78f9440','ক্রমিক পূর্ণসংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:687ec8ad63e0','bcs:math:7a6ff78f9440','অঙ্কবিন্যাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:828c9bed753c','bcs:math:7a6ff78f9440','মৌলিক উৎপাদক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:991d77dc6844','bcs:math:7a6ff78f9440','যৌগিক সংখ্যা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:53ef464f21bd','bcs:math:7a6ff78f9440','মৌলিক সংখ্যার গুণফল') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7a6ff78f9440:f7925d3633fb','bcs:math:7a6ff78f9440','সহমৌলিক ও যৌগিক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:350babbe7e25','bcs:math','পাটিগণিত','গসাগু ও লসাগু') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:general','bcs:math:350babbe7e25','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:615d3e6009ea','bcs:math:350babbe7e25','গসাগু') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:569da25a3e5a','bcs:math:350babbe7e25','লসাগু') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:53b71b2f6791','bcs:math:350babbe7e25','গসাগু-লসাগুর সম্পর্ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:478281098e7e','bcs:math:350babbe7e25','সাধারণ গুণনীয়ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:6327d5be0056','bcs:math:350babbe7e25','সাধারণ গুণিতক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:b762bacc9a80','bcs:math:350babbe7e25','ভাগশেষ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:0b3f02377b2d','bcs:math:350babbe7e25','সমবণ্টন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:c8ffc5878410','bcs:math:350babbe7e25','সমাপতন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:58691e9774ae','bcs:math:350babbe7e25','গসাগু ও অনুপাত') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:3f0bce23855a','bcs:math:350babbe7e25','লসাগু ও অনুপাত') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:8960a9305ebf','bcs:math:350babbe7e25','ইউক্লিডীয় সম্পর্ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:c61b76a00621','bcs:math:350babbe7e25','গুণনীয়ক-গুণিতক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:5870f9e0bf58','bcs:math:350babbe7e25','সমান টুকরা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:630c34e0a59a','bcs:math:350babbe7e25','একই ভাগশেষ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:350babbe7e25:97297d21d83d','bcs:math:350babbe7e25','সংখ্যাজোড়া') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:add785eba681','bcs:math','পাটিগণিত','শতকরা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:add785eba681:general','bcs:math:add785eba681','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:bd518d8f1bc5','bcs:math','পাটিগণিত','লাভ-ক্ষতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:bd518d8f1bc5:general','bcs:math:bd518d8f1bc5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:bd518d8f1bc5:d258bf587038','bcs:math:bd518d8f1bc5','লাভ ও ক্ষতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:828f02bff557','bcs:math','পাটিগণিত','অনুপাত') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:828f02bff557:general','bcs:math:828f02bff557','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:ecc48a566f76','bcs:math','পাটিগণিত','সরল ও চক্রবৃদ্ধি সুদ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:ecc48a566f76:general','bcs:math:ecc48a566f76','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:ecc48a566f76:e2680f19c733','bcs:math:ecc48a566f76','সরল সুদ') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:3026c1ceff24','bcs:math','বীজগণিত','সমীকরণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:3026c1ceff24:general','bcs:math:3026c1ceff24','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:3026c1ceff24:af71ec46a593','bcs:math:3026c1ceff24','বীজগণিত') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:21e4a538491d','bcs:math','বীজগণিত','অসমতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:21e4a538491d:general','bcs:math:21e4a538491d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:ebd2ae682f50','bcs:math','বীজগণিত','সূচক ও লগারিদম') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:ebd2ae682f50:general','bcs:math:ebd2ae682f50','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:ebd2ae682f50:e6484abfc3b1','bcs:math:ebd2ae682f50','সূচক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:8f31cb1c66dd','bcs:math','বীজগণিত','ধারা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:8f31cb1c66dd:general','bcs:math:8f31cb1c66dd','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:57d41b4388de','bcs:math','বীজগণিত','বিন্যাস ও সমাবেশ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:57d41b4388de:general','bcs:math:57d41b4388de','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:af3313c1f7fe','bcs:math','জ্যামিতি ও পরিসংখ্যান','রেখা ও কোণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:af3313c1f7fe:general','bcs:math:af3313c1f7fe','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:407104a84c63','bcs:math','জ্যামিতি ও পরিসংখ্যান','ত্রিভুজ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:407104a84c63:general','bcs:math:407104a84c63','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:407104a84c63:00cd2f9eb85d','bcs:math:407104a84c63','জ্যামিতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:b26626d51891','bcs:math','জ্যামিতি ও পরিসংখ্যান','বৃত্ত') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:b26626d51891:general','bcs:math:b26626d51891','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:b26626d51891:7be2f5e9f87c','bcs:math:b26626d51891','পরিমিতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:7be2f5e9f87c','bcs:math','জ্যামিতি ও পরিসংখ্যান','পরিমিতি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:7be2f5e9f87c:general','bcs:math:7be2f5e9f87c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:8c1a0e43eca4','bcs:math','জ্যামিতি ও পরিসংখ্যান','সেট') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:8c1a0e43eca4:general','bcs:math:8c1a0e43eca4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:c8b0e47b891e','bcs:math','জ্যামিতি ও পরিসংখ্যান','সম্ভাবনা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:c8b0e47b891e:general','bcs:math:c8b0e47b891e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:math:fd0a4697570f','bcs:math','জ্যামিতি ও পরিসংখ্যান','কেন্দ্রীয় প্রবণতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:fd0a4697570f:general','bcs:math:fd0a4697570f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:math:fd0a4697570f:db7e14f70f82','bcs:math:fd0a4697570f','গড়') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:mental','BCS','মানসিক দক্ষতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:bcde0e51bb3e','bcs:mental','যুক্তি ও বিশ্লেষণ','ভাষাগত যুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:bcde0e51bb3e:general','bcs:mental:bcde0e51bb3e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:bcde0e51bb3e:a21fcf7d6224','bcs:mental:bcde0e51bb3e','বর্ণধারা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:bcde0e51bb3e:2749d19fdf77','bcs:mental:bcde0e51bb3e','সাংকেতিক ভাষা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:bcde0e51bb3e:7c2741a3c81d','bcs:mental:bcde0e51bb3e','যৌক্তিক সিদ্ধান্ত') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:a4ba3d3f1e21','bcs:mental','যুক্তি ও বিশ্লেষণ','সংখ্যা ধারা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:a4ba3d3f1e21:general','bcs:mental:a4ba3d3f1e21','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:a4ba3d3f1e21:e32ddf9118c0','bcs:mental:a4ba3d3f1e21','সংখ্যাধারা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:3fa413572d83','bcs:mental','যুক্তি ও বিশ্লেষণ','সাদৃশ্য') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:3fa413572d83:general','bcs:mental:3fa413572d83','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:d749f377a317','bcs:mental','যুক্তি ও বিশ্লেষণ','সম্পর্ক ও দিক') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:d749f377a317:general','bcs:mental:d749f377a317','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:d749f377a317:4a29387c35d3','bcs:mental:d749f377a317','দিক নির্ণয়') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:d749f377a317:61e3ff8658c7','bcs:mental:d749f377a317','রক্তের সম্পর্ক') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:a9a19f27fa05','bcs:mental','যুক্তি ও বিশ্লেষণ','স্থানিক দক্ষতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:a9a19f27fa05:general','bcs:mental:a9a19f27fa05','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:4eb2b1975345','bcs:mental','যুক্তি ও বিশ্লেষণ','যান্ত্রিক যুক্তি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:4eb2b1975345:general','bcs:mental:4eb2b1975345','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:mental:471ea4eef405','bcs:mental','যুক্তি ও বিশ্লেষণ','সমস্যা সমাধান') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:471ea4eef405:general','bcs:mental:471ea4eef405','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:471ea4eef405:683ecdbce3fb','bcs:mental:471ea4eef405','ক্রমবিন্যাস') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:471ea4eef405:1d60a8fca191','bcs:mental:471ea4eef405','ক্যালেন্ডার') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:mental:471ea4eef405:86185c882f2d','bcs:mental:471ea4eef405','ঘড়ি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('bcs:ethics','BCS','নৈতিকতা, মূল্যবোধ ও সুশাসন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:7a803ff05514','bcs:ethics','নৈতিকতা ও সুশাসন','নৈতিকতার ধারণা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:7a803ff05514:general','bcs:ethics:7a803ff05514','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:7a803ff05514:a24f2f983d6f','bcs:ethics:7a803ff05514','তথ্যের দায়িত্বশীল ব্যবহার') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:9d86ab6dc7cc','bcs:ethics','নৈতিকতা ও সুশাসন','মূল্যবোধ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:9d86ab6dc7cc:general','bcs:ethics:9d86ab6dc7cc','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:9d86ab6dc7cc:c73ae6e31e6c','bcs:ethics:9d86ab6dc7cc','সমতা ও ন্যায্যতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:35449ab19bd9','bcs:ethics','নৈতিকতা ও সুশাসন','সততা ও জবাবদিহি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:35449ab19bd9:general','bcs:ethics:35449ab19bd9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:35449ab19bd9:35caff077514','bcs:ethics:35449ab19bd9','জবাবদিহি') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:35449ab19bd9:69976515377c','bcs:ethics:35449ab19bd9','সততা') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:a0cd13792bb6','bcs:ethics','নৈতিকতা ও সুশাসন','আইনের শাসন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:a0cd13792bb6:general','bcs:ethics:a0cd13792bb6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:c08a9bf3a60c','bcs:ethics','নৈতিকতা ও সুশাসন','স্বচ্ছতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:c08a9bf3a60c:general','bcs:ethics:c08a9bf3a60c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:75e50837eb87','bcs:ethics','নৈতিকতা ও সুশাসন','স্বার্থের সংঘাত') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:75e50837eb87:general','bcs:ethics:75e50837eb87','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('bcs:ethics:3b3922ca874e','bcs:ethics','নৈতিকতা ও সুশাসন','সুশাসন ও উন্নয়ন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:3b3922ca874e:general','bcs:ethics:3b3922ca874e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:3b3922ca874e:cf63450fe35d','bcs:ethics:3b3922ca874e','অংশগ্রহণ') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:3b3922ca874e:7bcec646b7d9','bcs:ethics:3b3922ca874e','কর্তব্যনিষ্ঠা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('bcs:ethics:3b3922ca874e:a2ebbce1d7d7','bcs:ethics:3b3922ca874e','টেকসই নৈতিকতা') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:circuit','EEE','Electrical Circuit Analysis') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:60d6f88fd6a0','eee:circuit','DC networks','Ohm’s law') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:60d6f88fd6a0:general','eee:circuit:60d6f88fd6a0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:baff70a9975b','eee:circuit','DC networks','KCL and KVL') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:baff70a9975b:general','eee:circuit:baff70a9975b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:0cc704a33351','eee:circuit','DC networks','Nodal analysis') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:0cc704a33351:general','eee:circuit:0cc704a33351','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:82ba760db125','eee:circuit','DC networks','Mesh analysis') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:82ba760db125:general','eee:circuit:82ba760db125','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:6d84400fc29d','eee:circuit','DC networks','Thevenin and Norton') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:6d84400fc29d:general','eee:circuit:6d84400fc29d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:efd1c1b5a408','eee:circuit','DC networks','Superposition') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:efd1c1b5a408:general','eee:circuit:efd1c1b5a408','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:651e17a99ccb','eee:circuit','AC and transients','Phasors') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:651e17a99ccb:general','eee:circuit:651e17a99ccb','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:08cf512b3099','eee:circuit','AC and transients','Impedance') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:08cf512b3099:general','eee:circuit:08cf512b3099','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:86b3a069372a','eee:circuit','AC and transients','RLC resonance') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:86b3a069372a:general','eee:circuit:86b3a069372a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:b435d939fe5a','eee:circuit','AC and transients','First-order transients') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:b435d939fe5a:general','eee:circuit:b435d939fe5a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:circuit:de4c706e8e47','eee:circuit','AC and transients','Three-phase circuits') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:circuit:de4c706e8e47:general','eee:circuit:de4c706e8e47','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:machines','EEE','Electrical Machines') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:d56fd5a709c0','eee:machines','Transformers','Equivalent circuit') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:d56fd5a709c0:general','eee:machines:d56fd5a709c0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:9e8f1fb7b540','eee:machines','Transformers','Losses and efficiency') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:9e8f1fb7b540:general','eee:machines:9e8f1fb7b540','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:5a4828036ae9','eee:machines','Transformers','Regulation') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:5a4828036ae9:general','eee:machines:5a4828036ae9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:cc0cc617a808','eee:machines','Transformers','OC and SC tests') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:cc0cc617a808:general','eee:machines:cc0cc617a808','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:29b6942dc8d3','eee:machines','Rotating machines','DC machines') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:29b6942dc8d3:general','eee:machines:29b6942dc8d3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:929762b7a12d','eee:machines','Rotating machines','Induction motors') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:929762b7a12d:general','eee:machines:929762b7a12d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:bb0eed0b70ce','eee:machines','Rotating machines','Synchronous machines') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:bb0eed0b70ce:general','eee:machines:bb0eed0b70ce','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:machines:225832b35b31','eee:machines','Rotating machines','Starting and speed control') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:machines:225832b35b31:general','eee:machines:225832b35b31','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:power','EEE','Power Systems') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:675f7a46c506','eee:power','System analysis','Per-unit system') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:675f7a46c506:general','eee:power:675f7a46c506','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:ed51f6b5dac3','eee:power','System analysis','Load flow') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:ed51f6b5dac3:general','eee:power:ed51f6b5dac3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:503591b06ece','eee:power','System analysis','Fault analysis') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:503591b06ece:general','eee:power:503591b06ece','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:9b57260124a7','eee:power','System analysis','Symmetrical components') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:9b57260124a7:general','eee:power:9b57260124a7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:1e42d0c86af7','eee:power','System analysis','Stability') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:1e42d0c86af7:general','eee:power:1e42d0c86af7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power:0cf90110ca17','eee:power','System analysis','Power factor correction') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power:0cf90110ca17:general','eee:power:0cf90110ca17','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:generation','EEE','Power Generation') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:0bcb9fd183c6','eee:generation','Generation fundamentals','Thermal stations') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:0bcb9fd183c6:general','eee:generation:0bcb9fd183c6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:7bbe36e3ae98','eee:generation','Generation fundamentals','Hydroelectric stations') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:7bbe36e3ae98:general','eee:generation:7bbe36e3ae98','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:3084312d812a','eee:generation','Generation fundamentals','Gas turbines') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:3084312d812a:general','eee:generation:3084312d812a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:97c61e5b1dc9','eee:generation','Generation fundamentals','Nuclear basics') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:97c61e5b1dc9:general','eee:generation:97c61e5b1dc9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:caaa9f429e2c','eee:generation','Generation fundamentals','Load curves') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:caaa9f429e2c:general','eee:generation:caaa9f429e2c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:generation:9cf369add69c','eee:generation','Generation fundamentals','Economic dispatch') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:generation:9cf369add69c:general','eee:generation:9cf369add69c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:transmission','EEE','Transmission and Distribution') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:e60326c53497','eee:transmission','Networks','Line parameters') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:e60326c53497:general','eee:transmission:e60326c53497','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:08e1e2c60367','eee:transmission','Networks','Short and long lines') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:08e1e2c60367:general','eee:transmission:08e1e2c60367','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:753cdb88284c','eee:transmission','Networks','Corona') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:753cdb88284c:general','eee:transmission:753cdb88284c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:b7299f382a86','eee:transmission','Networks','Insulators') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:b7299f382a86:general','eee:transmission:b7299f382a86','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:2f75d2e1c15c','eee:transmission','Networks','Cables') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:2f75d2e1c15c:general','eee:transmission:2f75d2e1c15c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:787807596912','eee:transmission','Networks','Distribution feeders') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:787807596912:general','eee:transmission:787807596912','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:transmission:c4409da83bd3','eee:transmission','Networks','Voltage regulation') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:transmission:c4409da83bd3:general','eee:transmission:c4409da83bd3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:power-electronics','EEE','Power Electronics') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:9c5faba39e67','eee:power-electronics','Devices and converters','Diodes and SCRs') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:9c5faba39e67:general','eee:power-electronics:9c5faba39e67','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:1976651c237f','eee:power-electronics','Devices and converters','MOSFET and IGBT') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:1976651c237f:general','eee:power-electronics:1976651c237f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:f73b73f2119e','eee:power-electronics','Devices and converters','Rectifiers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:f73b73f2119e:general','eee:power-electronics:f73b73f2119e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:1cb20c689677','eee:power-electronics','Devices and converters','DC choppers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:1cb20c689677:general','eee:power-electronics:1cb20c689677','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:4add2850e52c','eee:power-electronics','Devices and converters','Inverters') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:4add2850e52c:general','eee:power-electronics:4add2850e52c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:c37490c37e59','eee:power-electronics','Devices and converters','PWM') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:c37490c37e59:general','eee:power-electronics:c37490c37e59','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:power-electronics:35f69a05559f','eee:power-electronics','Devices and converters','Converter losses') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:power-electronics:35f69a05559f:general','eee:power-electronics:35f69a05559f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:control','EEE','Control Systems') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:d32f7be66c42','eee:control','Modeling and response','Transfer functions') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:d32f7be66c42:general','eee:control:d32f7be66c42','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:94804e447bcf','eee:control','Modeling and response','Block diagrams') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:94804e447bcf:general','eee:control:94804e447bcf','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:6a9ec993393d','eee:control','Modeling and response','Time response') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:6a9ec993393d:general','eee:control:6a9ec993393d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:11dc66b7bce3','eee:control','Modeling and response','Steady-state error') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:11dc66b7bce3:general','eee:control:11dc66b7bce3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:2a0fc865cf7b','eee:control','Stability and design','Routh criterion') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:2a0fc865cf7b:general','eee:control:2a0fc865cf7b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:70f8d86992a9','eee:control','Stability and design','Root locus') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:70f8d86992a9:general','eee:control:70f8d86992a9','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:f39d624d67b4','eee:control','Stability and design','Bode plots') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:f39d624d67b4:general','eee:control:f39d624d67b4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:60629ce7449c','eee:control','Stability and design','Nyquist criterion') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:60629ce7449c:general','eee:control:60629ce7449c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:3f302a2a7158','eee:control','Stability and design','PID') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:3f302a2a7158:general','eee:control:3f302a2a7158','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:control:4b8dd6799a0b','eee:control','Stability and design','State space') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:control:4b8dd6799a0b:general','eee:control:4b8dd6799a0b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:measurement','EEE','Electrical Measurements') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:937f8eccb989','eee:measurement','Instruments','Measurement errors') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:937f8eccb989:general','eee:measurement:937f8eccb989','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:1947f48319e6','eee:measurement','Instruments','PMMC and MI') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:1947f48319e6:general','eee:measurement:1947f48319e6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:d982f029f5c8','eee:measurement','Instruments','Bridges') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:d982f029f5c8:general','eee:measurement:d982f029f5c8','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:6a30533739ef','eee:measurement','Instruments','Power measurement') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:6a30533739ef:general','eee:measurement:6a30533739ef','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:5f2ec3ac5b3b','eee:measurement','Instruments','Energy meters') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:5f2ec3ac5b3b:general','eee:measurement:5f2ec3ac5b3b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:dc9acddc3be3','eee:measurement','Instruments','CT and PT') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:dc9acddc3be3:general','eee:measurement:dc9acddc3be3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:measurement:a14fe7a76de0','eee:measurement','Instruments','Oscilloscopes') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:measurement:a14fe7a76de0:general','eee:measurement:a14fe7a76de0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:analog','EEE','Analog Electronics') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:b908b3481812','eee:analog','Semiconductors and amplifiers','PN junction') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:b908b3481812:general','eee:analog:b908b3481812','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:23818cf15796','eee:analog','Semiconductors and amplifiers','Rectifiers and filters') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:23818cf15796:general','eee:analog:23818cf15796','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:6bdf2d448ece','eee:analog','Semiconductors and amplifiers','BJT biasing') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:6bdf2d448ece:general','eee:analog:6bdf2d448ece','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:7b6994083ff7','eee:analog','Semiconductors and amplifiers','MOSFET') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:7b6994083ff7:general','eee:analog:7b6994083ff7','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:d71ba138c6e4','eee:analog','Semiconductors and amplifiers','Small-signal amplifiers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:d71ba138c6e4:general','eee:analog:d71ba138c6e4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:f28bccc3d65e','eee:analog','Semiconductors and amplifiers','Op-amps') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:f28bccc3d65e:general','eee:analog:f28bccc3d65e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:analog:0c150c8ffa2d','eee:analog','Semiconductors and amplifiers','Oscillators') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:analog:0c150c8ffa2d:general','eee:analog:0c150c8ffa2d','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:digital','EEE','Digital Electronics') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:cc4a451a9f29','eee:digital','Logic design','Number systems') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:cc4a451a9f29:general','eee:digital:cc4a451a9f29','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:db0daa5bbcd2','eee:digital','Logic design','Boolean algebra') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:db0daa5bbcd2:general','eee:digital:db0daa5bbcd2','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:3b84cf23d368','eee:digital','Logic design','Karnaugh maps') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:3b84cf23d368:general','eee:digital:3b84cf23d368','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:b254c84c7ad4','eee:digital','Logic design','Combinational logic') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:b254c84c7ad4:general','eee:digital:b254c84c7ad4','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:d821a10c508b','eee:digital','Logic design','Flip-flops') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:d821a10c508b:general','eee:digital:d821a10c508b','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:e5a4fa99e74a','eee:digital','Logic design','Counters') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:e5a4fa99e74a:general','eee:digital:e5a4fa99e74a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:048713a5001f','eee:digital','Logic design','Registers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:048713a5001f:general','eee:digital:048713a5001f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:digital:9437d291dfeb','eee:digital','Logic design','ADC and DAC') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:digital:9437d291dfeb:general','eee:digital:9437d291dfeb','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:safety','EEE','Electrical Installation and Safety') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:71b76aa12ef0','eee:safety','Safe installations','Earthing and bonding') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:71b76aa12ef0:general','eee:safety:71b76aa12ef0','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:1c02df7058d3','eee:safety','Safe installations','Wiring systems') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:1c02df7058d3:general','eee:safety:1c02df7058d3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:09b900c0faef','eee:safety','Safe installations','Cable sizing') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:09b900c0faef:general','eee:safety:09b900c0faef','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:42e94f5adb28','eee:safety','Safe installations','Protective devices') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:42e94f5adb28:general','eee:safety:42e94f5adb28','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:9396c33ee0fc','eee:safety','Safe installations','RCD') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:9396c33ee0fc:general','eee:safety:9396c33ee0fc','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:9b03de359e15','eee:safety','Safe installations','Isolation and lockout') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:9b03de359e15:general','eee:safety:9b03de359e15','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:safety:e5deaba2f04c','eee:safety','Safe installations','Electrical hazards') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:safety:e5deaba2f04c:general','eee:safety:e5deaba2f04c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:protection','EEE','Switchgear and Protection') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:69e4c96df7e3','eee:protection','Protection systems','Fuse characteristics') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:69e4c96df7e3:general','eee:protection:69e4c96df7e3','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:8d6075961dd1','eee:protection','Protection systems','Circuit breakers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:8d6075961dd1:general','eee:protection:8d6075961dd1','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:e7f66a86507f','eee:protection','Protection systems','Overcurrent relays') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:e7f66a86507f:general','eee:protection:e7f66a86507f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:f49b07d1fca5','eee:protection','Protection systems','Differential protection') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:f49b07d1fca5:general','eee:protection:f49b07d1fca5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:7e74140960df','eee:protection','Protection systems','Distance protection') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:7e74140960df:general','eee:protection:7e74140960df','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:9c0f7ed16a6e','eee:protection','Protection systems','Coordination') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:9c0f7ed16a6e:general','eee:protection:9c0f7ed16a6e','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:protection:963154524fa5','eee:protection','Protection systems','Surge protection') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:protection:963154524fa5:general','eee:protection:963154524fa5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:renewable','EEE','Renewable Energy') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:1e4a0186ae8f','eee:renewable','Renewable systems','Solar PV') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:1e4a0186ae8f:general','eee:renewable:1e4a0186ae8f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:4c00a8091fb6','eee:renewable','Renewable systems','MPPT') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:4c00a8091fb6:general','eee:renewable:4c00a8091fb6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:0ec61d998089','eee:renewable','Renewable systems','Wind conversion') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:0ec61d998089:general','eee:renewable:0ec61d998089','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:a69c4dece144','eee:renewable','Renewable systems','Storage') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:a69c4dece144:general','eee:renewable:a69c4dece144','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:88e619ac757f','eee:renewable','Renewable systems','Grid integration') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:88e619ac757f:general','eee:renewable:88e619ac757f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:a8bba50d7887','eee:renewable','Renewable systems','Inverter control') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:a8bba50d7887:general','eee:renewable:a8bba50d7887','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:renewable:9b9ab8ef8f3c','eee:renewable','Renewable systems','Energy yield') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:renewable:9b9ab8ef8f3c:general','eee:renewable:9b9ab8ef8f3c','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:micro','EEE','Microprocessors and Microcontrollers') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:cd74053c5481','eee:micro','Embedded fundamentals','Architecture') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:cd74053c5481:general','eee:micro:cd74053c5481','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:1041f5ae3628','eee:micro','Embedded fundamentals','Instruction cycle') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:1041f5ae3628:general','eee:micro:1041f5ae3628','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:4a7438f6c909','eee:micro','Embedded fundamentals','Memory map') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:4a7438f6c909:general','eee:micro:4a7438f6c909','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:7c87ab37b6e6','eee:micro','Embedded fundamentals','GPIO') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:7c87ab37b6e6:general','eee:micro:7c87ab37b6e6','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:cca94c56deb8','eee:micro','Embedded fundamentals','Timers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:cca94c56deb8:general','eee:micro:cca94c56deb8','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:395f8e35fb98','eee:micro','Embedded fundamentals','Interrupts') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:395f8e35fb98:general','eee:micro:395f8e35fb98','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:a34330e2477f','eee:micro','Embedded fundamentals','UART SPI I²C') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:a34330e2477f:general','eee:micro:a34330e2477f','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:micro:cfa77b17e649','eee:micro','Embedded fundamentals','ADC interfacing') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:micro:cfa77b17e649:general','eee:micro:cfa77b17e649','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_subjects values('eee:eng-math','EEE','Engineering Mathematics') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:a425679f2362','eee:eng-math','Mathematical tools','Complex numbers') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:a425679f2362:general','eee:eng-math:a425679f2362','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:6009efe95f18','eee:eng-math','Mathematical tools','Matrices') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:6009efe95f18:general','eee:eng-math:6009efe95f18','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:26e732f5bd6a','eee:eng-math','Mathematical tools','Differentiation') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:26e732f5bd6a:general','eee:eng-math:26e732f5bd6a','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:9a42d40a3f31','eee:eng-math','Mathematical tools','Integration') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:9a42d40a3f31:general','eee:eng-math:9a42d40a3f31','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:37b733d9c9e5','eee:eng-math','Mathematical tools','Differential equations') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:37b733d9c9e5:general','eee:eng-math:37b733d9c9e5','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:2ec276573e02','eee:eng-math','Mathematical tools','Laplace transforms') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:2ec276573e02:general','eee:eng-math:2ec276573e02','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:02bf87b02e59','eee:eng-math','Mathematical tools','Fourier analysis') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:02bf87b02e59:general','eee:eng-math:02bf87b02e59','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.exam_topics values('eee:eng-math:9c9be01ba212','eee:eng-math','Mathematical tools','Probability') on conflict(id) do nothing;
insert into jobmaster_private.exam_subtopics values('eee:eng-math:9c9be01ba212:general','eee:eng-math:9c9be01ba212','সাধারণ অনুশীলন') on conflict(id) do nothing;
insert into jobmaster_private.question_classification(question_id,subtopic_id) select q.id,a.subtopic_id from (values
('BCS-MODEL-0001','bcs:bangla:720507debcc9:general','bcs-model-part01-100'),
('BCS-MODEL-0002','bcs:bangla:720507debcc9:b6a5166d1a97','bcs-model-part01-100'),
('BCS-MODEL-0003','bcs:bangla:43e40ad87110:general','bcs-model-part01-100'),
('BCS-MODEL-0004','bcs:bangla:f7945cc097f9:general','bcs-model-part01-100'),
('BCS-MODEL-0005','bcs:bangla:0fd695d9ac47:f54d9047f82a','bcs-model-part01-100'),
('BCS-MODEL-0006','bcs:bangla:c5870d9f96d7:general','bcs-model-part01-100'),
('BCS-MODEL-0007','bcs:bangla:9ebc5e3d9216:6e3bdc4fe39b','bcs-model-part01-100'),
('BCS-MODEL-0008','bcs:bangla:b3bfde7cf157:a15084ae6d43','bcs-model-part01-100'),
('BCS-MODEL-0009','bcs:bangla:5379b522c084:f4a529991ee0','bcs-model-part01-100'),
('BCS-MODEL-0010','bcs:bangla:818d9d8fa992:431e9b9f4085','bcs-model-part01-100'),
('BCS-MODEL-0011','bcs:english:6658e9b36c34:b14ac78a46e9','bcs-model-part01-100'),
('BCS-MODEL-0012','bcs:english:9f473d774945:fc31779117de','bcs-model-part01-100'),
('BCS-MODEL-0013','bcs:english:45b80ee2fedb:2cacf6c14ec8','bcs-model-part01-100'),
('BCS-MODEL-0014','bcs:english:565dfca4a5bd:126995365015','bcs-model-part01-100'),
('BCS-MODEL-0015','bcs:english:f6bcda8b4f94:general','bcs-model-part01-100'),
('BCS-MODEL-0016','bcs:english:87bf2bc08589:general','bcs-model-part01-100'),
('BCS-MODEL-0017','bcs:english:8aeb948188e6:eebd90a046c6','bcs-model-part01-100'),
('BCS-MODEL-0018','bcs:english:8aeb948188e6:4e1495cb16ac','bcs-model-part01-100'),
('BCS-MODEL-0019','bcs:english:b993ca685399:da72bf5bbca4','bcs-model-part01-100'),
('BCS-MODEL-0020','bcs:english:b993ca685399:a6f10bde1cb3','bcs-model-part01-100'),
('BCS-MODEL-0021','bcs:bd:baad1f4397bf:general','bcs-model-part01-100'),
('BCS-MODEL-0022','bcs:bd:d543a2100e1c:2950915a19a0','bcs-model-part01-100'),
('BCS-MODEL-0023','bcs:bd:66662d5eb1a4:general','bcs-model-part01-100'),
('BCS-MODEL-0024','bcs:bd:66662d5eb1a4:general','bcs-model-part01-100'),
('BCS-MODEL-0025','bcs:bd:570709e5e859:998118b96e82','bcs-model-part01-100'),
('BCS-MODEL-0026','bcs:bd:570709e5e859:general','bcs-model-part01-100'),
('BCS-MODEL-0027','bcs:bd:a246d599459e:e9f2dc05114a','bcs-model-part01-100'),
('BCS-MODEL-0028','bcs:bd:bb5ccc21e697:9d7353c17b6e','bcs-model-part01-100'),
('BCS-MODEL-0029','bcs:bd:811bce8dfdad:general','bcs-model-part01-100'),
('BCS-MODEL-0030','bcs:bd:18ce88ebeba4:51af6f13c484','bcs-model-part01-100'),
('BCS-MODEL-0031','bcs:international:c99dd5704a8e:general','bcs-model-part01-100'),
('BCS-MODEL-0032','bcs:international:c99dd5704a8e:general','bcs-model-part01-100'),
('BCS-MODEL-0033','bcs:international:c99dd5704a8e:520da8f86df8','bcs-model-part01-100'),
('BCS-MODEL-0034','bcs:international:e5f34824197d:819981f81412','bcs-model-part01-100'),
('BCS-MODEL-0035','bcs:international:c99dd5704a8e:bcd13c79e3e7','bcs-model-part01-100'),
('BCS-MODEL-0036','bcs:international:e5f34824197d:91fe75ae64a5','bcs-model-part01-100'),
('BCS-MODEL-0037','bcs:international:c99dd5704a8e:d0f6c7c7007e','bcs-model-part01-100'),
('BCS-MODEL-0038','bcs:international:c99dd5704a8e:2f8ed2460be0','bcs-model-part01-100'),
('BCS-MODEL-0039','bcs:international:542a021d6b0e:887d68894230','bcs-model-part01-100'),
('BCS-MODEL-0040','bcs:international:e5b52119c755:412080858647','bcs-model-part01-100'),
('BCS-MODEL-0041','bcs:geography:1644479ad6b5:99c825a1422f','bcs-model-part01-100'),
('BCS-MODEL-0042','bcs:geography:8a66ea49bc3e:a0c311d05236','bcs-model-part01-100'),
('BCS-MODEL-0043','bcs:geography:8a66ea49bc3e:general','bcs-model-part01-100'),
('BCS-MODEL-0044','bcs:geography:aa339cb5bd11:78dce84d2e0f','bcs-model-part01-100'),
('BCS-MODEL-0045','bcs:geography:8a66ea49bc3e:f90c60bf7d9f','bcs-model-part01-100'),
('BCS-MODEL-0046','bcs:geography:8cab1abb2de7:6b7fe6081b61','bcs-model-part01-100'),
('BCS-MODEL-0047','bcs:geography:4dcd871b12f2:general','bcs-model-part01-100'),
('BCS-MODEL-0048','bcs:geography:c1cb496af13f:aea17e4f99a2','bcs-model-part01-100'),
('BCS-MODEL-0049','bcs:geography:c1cb496af13f:d4e80b351a04','bcs-model-part01-100'),
('BCS-MODEL-0050','bcs:geography:1bd2cb940a84:15db76ffc233','bcs-model-part01-100'),
('BCS-MODEL-0051','bcs:science:a17f73157029:9b426deb1c88','bcs-model-part01-100'),
('BCS-MODEL-0052','bcs:science:58fbf2103113:7bd89f5cd9a4','bcs-model-part01-100'),
('BCS-MODEL-0053','bcs:science:35722c11b79a:848b3a7dd002','bcs-model-part01-100'),
('BCS-MODEL-0054','bcs:science:48fd4f2d32b2:a24c09a18d30','bcs-model-part01-100'),
('BCS-MODEL-0055','bcs:science:6a8f53327ff5:38d2d9aa1a80','bcs-model-part01-100'),
('BCS-MODEL-0056','bcs:science:6a8f53327ff5:11807c752703','bcs-model-part01-100'),
('BCS-MODEL-0057','bcs:science:a526aeb62e8a:f431a2370588','bcs-model-part01-100'),
('BCS-MODEL-0058','bcs:science:a526aeb62e8a:27416aa044ef','bcs-model-part01-100'),
('BCS-MODEL-0059','bcs:science:10628f53805c:general','bcs-model-part01-100'),
('BCS-MODEL-0060','bcs:science:31601d548685:b67b9ec4675f','bcs-model-part01-100'),
('BCS-MODEL-0061','bcs:ict:c1ccacfd7c52:general','bcs-model-part01-100'),
('BCS-MODEL-0062','bcs:ict:95aea70c07b0:f4ca4cf03d9d','bcs-model-part01-100'),
('BCS-MODEL-0063','bcs:ict:f4a3a6bc619a:4bfbca2f0e57','bcs-model-part01-100'),
('BCS-MODEL-0064','bcs:ict:95aea70c07b0:9a66c2ef1d18','bcs-model-part01-100'),
('BCS-MODEL-0065','bcs:ict:2064bda18a22:general','bcs-model-part01-100'),
('BCS-MODEL-0066','bcs:ict:6c805050a42a:fca3b7cc9e3c','bcs-model-part01-100'),
('BCS-MODEL-0067','bcs:ict:7dc8e73e7b92:f914e5a95460','bcs-model-part01-100'),
('BCS-MODEL-0068','bcs:ict:b6d7ad7943ff:general','bcs-model-part01-100'),
('BCS-MODEL-0069','bcs:ict:c2c2ff567efa:2ab377bad512','bcs-model-part01-100'),
('BCS-MODEL-0070','bcs:ict:c2c2ff567efa:4a98d421c372','bcs-model-part01-100'),
('BCS-MODEL-0071','bcs:math:add785eba681:general','bcs-model-part01-100'),
('BCS-MODEL-0072','bcs:math:828f02bff557:general','bcs-model-part01-100'),
('BCS-MODEL-0073','bcs:math:bd518d8f1bc5:d258bf587038','bcs-model-part01-100'),
('BCS-MODEL-0074','bcs:math:ecc48a566f76:e2680f19c733','bcs-model-part01-100'),
('BCS-MODEL-0075','bcs:math:3026c1ceff24:af71ec46a593','bcs-model-part01-100'),
('BCS-MODEL-0076','bcs:math:ebd2ae682f50:e6484abfc3b1','bcs-model-part01-100'),
('BCS-MODEL-0077','bcs:math:407104a84c63:00cd2f9eb85d','bcs-model-part01-100'),
('BCS-MODEL-0078','bcs:math:b26626d51891:7be2f5e9f87c','bcs-model-part01-100'),
('BCS-MODEL-0079','bcs:math:c8b0e47b891e:general','bcs-model-part01-100'),
('BCS-MODEL-0080','bcs:math:fd0a4697570f:db7e14f70f82','bcs-model-part01-100'),
('BCS-MODEL-0081','bcs:mental:a4ba3d3f1e21:e32ddf9118c0','bcs-model-part01-100'),
('BCS-MODEL-0082','bcs:mental:bcde0e51bb3e:a21fcf7d6224','bcs-model-part01-100'),
('BCS-MODEL-0083','bcs:mental:3fa413572d83:general','bcs-model-part01-100'),
('BCS-MODEL-0084','bcs:mental:d749f377a317:4a29387c35d3','bcs-model-part01-100'),
('BCS-MODEL-0085','bcs:mental:d749f377a317:61e3ff8658c7','bcs-model-part01-100'),
('BCS-MODEL-0086','bcs:mental:bcde0e51bb3e:2749d19fdf77','bcs-model-part01-100'),
('BCS-MODEL-0087','bcs:mental:bcde0e51bb3e:7c2741a3c81d','bcs-model-part01-100'),
('BCS-MODEL-0088','bcs:mental:471ea4eef405:683ecdbce3fb','bcs-model-part01-100'),
('BCS-MODEL-0089','bcs:mental:471ea4eef405:1d60a8fca191','bcs-model-part01-100'),
('BCS-MODEL-0090','bcs:mental:471ea4eef405:86185c882f2d','bcs-model-part01-100'),
('BCS-MODEL-0091','bcs:ethics:75e50837eb87:general','bcs-model-part01-100'),
('BCS-MODEL-0092','bcs:ethics:35449ab19bd9:35caff077514','bcs-model-part01-100'),
('BCS-MODEL-0093','bcs:ethics:a0cd13792bb6:general','bcs-model-part01-100'),
('BCS-MODEL-0094','bcs:ethics:c08a9bf3a60c:general','bcs-model-part01-100'),
('BCS-MODEL-0095','bcs:ethics:35449ab19bd9:69976515377c','bcs-model-part01-100'),
('BCS-MODEL-0096','bcs:ethics:9d86ab6dc7cc:c73ae6e31e6c','bcs-model-part01-100'),
('BCS-MODEL-0097','bcs:ethics:3b3922ca874e:cf63450fe35d','bcs-model-part01-100'),
('BCS-MODEL-0098','bcs:ethics:7a803ff05514:a24f2f983d6f','bcs-model-part01-100'),
('BCS-MODEL-0099','bcs:ethics:3b3922ca874e:7bcec646b7d9','bcs-model-part01-100'),
('BCS-MODEL-0100','bcs:ethics:3b3922ca874e:a2ebbce1d7d7','bcs-model-part01-100'),
('BCS-MODEL-0101','bcs:english:547efd6bc280:3138cdacb043','bcs-model-part02-drive-100'),
('BCS-MODEL-0102','bcs:english:547efd6bc280:5cbb4f06c6fd','bcs-model-part02-drive-100'),
('BCS-MODEL-0103','bcs:english:547efd6bc280:10a0d424f76e','bcs-model-part02-drive-100'),
('BCS-MODEL-0104','bcs:english:547efd6bc280:365c8947d85c','bcs-model-part02-drive-100'),
('BCS-MODEL-0105','bcs:english:547efd6bc280:740ded6936a6','bcs-model-part02-drive-100'),
('BCS-MODEL-0106','bcs:english:547efd6bc280:a3db25569b22','bcs-model-part02-drive-100'),
('BCS-MODEL-0107','bcs:english:547efd6bc280:b2a2075aa145','bcs-model-part02-drive-100'),
('BCS-MODEL-0108','bcs:english:547efd6bc280:e75e2900dd2a','bcs-model-part02-drive-100'),
('BCS-MODEL-0109','bcs:english:547efd6bc280:7825ae82af79','bcs-model-part02-drive-100'),
('BCS-MODEL-0110','bcs:english:547efd6bc280:ed320a989e48','bcs-model-part02-drive-100'),
('BCS-MODEL-0111','bcs:english:547efd6bc280:5ffb5737db16','bcs-model-part02-drive-100'),
('BCS-MODEL-0112','bcs:english:547efd6bc280:5ffb5737db16','bcs-model-part02-drive-100'),
('BCS-MODEL-0113','bcs:english:547efd6bc280:88cceadb438b','bcs-model-part02-drive-100'),
('BCS-MODEL-0114','bcs:english:547efd6bc280:fc0f8a512b9d','bcs-model-part02-drive-100'),
('BCS-MODEL-0115','bcs:english:547efd6bc280:85e4d9f5bbea','bcs-model-part02-drive-100'),
('BCS-MODEL-0116','bcs:english:547efd6bc280:365c8947d85c','bcs-model-part02-drive-100'),
('BCS-MODEL-0117','bcs:english:547efd6bc280:365c8947d85c','bcs-model-part02-drive-100'),
('BCS-MODEL-0118','bcs:english:547efd6bc280:365c8947d85c','bcs-model-part02-drive-100'),
('BCS-MODEL-0119','bcs:english:547efd6bc280:0c06ea20ec0c','bcs-model-part02-drive-100'),
('BCS-MODEL-0120','bcs:english:547efd6bc280:0c06ea20ec0c','bcs-model-part02-drive-100'),
('BCS-MODEL-0121','bcs:english:45b80ee2fedb:abe00e9c9c31','bcs-model-part02-drive-100'),
('BCS-MODEL-0122','bcs:english:f6bcda8b4f94:a0d846a0e9c6','bcs-model-part02-drive-100'),
('BCS-MODEL-0123','bcs:english:f6bcda8b4f94:a0d846a0e9c6','bcs-model-part02-drive-100'),
('BCS-MODEL-0124','bcs:english:547efd6bc280:868f2b9d42d3','bcs-model-part02-drive-100'),
('BCS-MODEL-0125','bcs:english:45b80ee2fedb:3597ef1f9fe2','bcs-model-part02-drive-100'),
('BCS-MODEL-0126','bcs:english:45b80ee2fedb:a52bb78d5609','bcs-model-part02-drive-100'),
('BCS-MODEL-0127','bcs:english:565dfca4a5bd:126995365015','bcs-model-part02-drive-100'),
('BCS-MODEL-0128','bcs:english:565dfca4a5bd:126995365015','bcs-model-part02-drive-100'),
('BCS-MODEL-0129','bcs:english:565dfca4a5bd:126995365015','bcs-model-part02-drive-100'),
('BCS-MODEL-0130','bcs:english:547efd6bc280:403cc21502eb','bcs-model-part02-drive-100'),
('BCS-MODEL-0131','bcs:english:d90a31d7b565:28104b8f1375','bcs-model-part02-drive-100'),
('BCS-MODEL-0132','bcs:english:d90a31d7b565:3671fc2f9e7f','bcs-model-part02-drive-100'),
('BCS-MODEL-0133','bcs:english:d90a31d7b565:77ae9160b827','bcs-model-part02-drive-100'),
('BCS-MODEL-0134','bcs:english:d90a31d7b565:77ae9160b827','bcs-model-part02-drive-100'),
('BCS-MODEL-0135','bcs:english:d90a31d7b565:77ae9160b827','bcs-model-part02-drive-100'),
('BCS-MODEL-0136','bcs:english:d90a31d7b565:77ae9160b827','bcs-model-part02-drive-100'),
('BCS-MODEL-0137','bcs:english:d90a31d7b565:40c1aeb77c4e','bcs-model-part02-drive-100'),
('BCS-MODEL-0138','bcs:english:d90a31d7b565:29fbda27d46a','bcs-model-part02-drive-100'),
('BCS-MODEL-0139','bcs:english:d90a31d7b565:7c3295f7f169','bcs-model-part02-drive-100'),
('BCS-MODEL-0140','bcs:english:d90a31d7b565:7c3295f7f169','bcs-model-part02-drive-100'),
('BCS-MODEL-0141','bcs:english:d90a31d7b565:21086ed44d58','bcs-model-part02-drive-100'),
('BCS-MODEL-0142','bcs:english:d90a31d7b565:21086ed44d58','bcs-model-part02-drive-100'),
('BCS-MODEL-0143','bcs:english:d90a31d7b565:21086ed44d58','bcs-model-part02-drive-100'),
('BCS-MODEL-0144','bcs:english:d90a31d7b565:d11eedfc27fb','bcs-model-part02-drive-100'),
('BCS-MODEL-0145','bcs:english:d90a31d7b565:39cbc15b8fca','bcs-model-part02-drive-100'),
('BCS-MODEL-0146','bcs:english:d90a31d7b565:6cab2d8cd0db','bcs-model-part02-drive-100'),
('BCS-MODEL-0147','bcs:english:d90a31d7b565:39cbc15b8fca','bcs-model-part02-drive-100'),
('BCS-MODEL-0148','bcs:english:d90a31d7b565:39cbc15b8fca','bcs-model-part02-drive-100'),
('BCS-MODEL-0149','bcs:english:d90a31d7b565:b7e8acdd522e','bcs-model-part02-drive-100'),
('BCS-MODEL-0150','bcs:english:d90a31d7b565:d65c09e289ea','bcs-model-part02-drive-100'),
('BCS-MODEL-0151','bcs:english:d90a31d7b565:ada27592c957','bcs-model-part02-drive-100'),
('BCS-MODEL-0152','bcs:english:d90a31d7b565:305f5e5463e1','bcs-model-part02-drive-100'),
('BCS-MODEL-0153','bcs:english:d90a31d7b565:16c1d601fc66','bcs-model-part02-drive-100'),
('BCS-MODEL-0154','bcs:english:d90a31d7b565:1627c4947843','bcs-model-part02-drive-100'),
('BCS-MODEL-0155','bcs:english:d90a31d7b565:403cc21502eb','bcs-model-part02-drive-100'),
('BCS-MODEL-0156','bcs:english:d90a31d7b565:5799f08aa568','bcs-model-part02-drive-100'),
('BCS-MODEL-0157','bcs:english:d90a31d7b565:d19e3194b388','bcs-model-part02-drive-100'),
('BCS-MODEL-0158','bcs:english:d90a31d7b565:d19e3194b388','bcs-model-part02-drive-100'),
('BCS-MODEL-0159','bcs:english:d90a31d7b565:5e883e98cf79','bcs-model-part02-drive-100'),
('BCS-MODEL-0160','bcs:english:d90a31d7b565:ed7a9987f264','bcs-model-part02-drive-100'),
('BCS-MODEL-0161','bcs:math:7a6ff78f9440:4f3ef4b22679','bcs-model-part02-drive-100'),
('BCS-MODEL-0162','bcs:math:7a6ff78f9440:4f3ef4b22679','bcs-model-part02-drive-100'),
('BCS-MODEL-0163','bcs:math:7a6ff78f9440:4f3ef4b22679','bcs-model-part02-drive-100'),
('BCS-MODEL-0164','bcs:math:7a6ff78f9440:39aa511048b3','bcs-model-part02-drive-100'),
('BCS-MODEL-0165','bcs:math:7a6ff78f9440:39aa511048b3','bcs-model-part02-drive-100'),
('BCS-MODEL-0166','bcs:math:7a6ff78f9440:39aa511048b3','bcs-model-part02-drive-100'),
('BCS-MODEL-0167','bcs:math:7a6ff78f9440:99023d9a86c6','bcs-model-part02-drive-100'),
('BCS-MODEL-0168','bcs:math:7a6ff78f9440:0271932f47cb','bcs-model-part02-drive-100'),
('BCS-MODEL-0169','bcs:math:7a6ff78f9440:0271932f47cb','bcs-model-part02-drive-100'),
('BCS-MODEL-0170','bcs:math:7a6ff78f9440:0271932f47cb','bcs-model-part02-drive-100'),
('BCS-MODEL-0171','bcs:math:7a6ff78f9440:a15b7a5422db','bcs-model-part02-drive-100'),
('BCS-MODEL-0172','bcs:math:7a6ff78f9440:1ab573e2f3df','bcs-model-part02-drive-100'),
('BCS-MODEL-0173','bcs:math:7a6ff78f9440:a15b7a5422db','bcs-model-part02-drive-100'),
('BCS-MODEL-0174','bcs:math:7a6ff78f9440:3cb6fd291852','bcs-model-part02-drive-100'),
('BCS-MODEL-0175','bcs:math:7a6ff78f9440:d8b0eec235d9','bcs-model-part02-drive-100'),
('BCS-MODEL-0176','bcs:math:7a6ff78f9440:b38d24590f24','bcs-model-part02-drive-100'),
('BCS-MODEL-0177','bcs:math:7a6ff78f9440:82fcb3b4025c','bcs-model-part02-drive-100'),
('BCS-MODEL-0178','bcs:math:7a6ff78f9440:82fcb3b4025c','bcs-model-part02-drive-100'),
('BCS-MODEL-0179','bcs:math:7a6ff78f9440:687ec8ad63e0','bcs-model-part02-drive-100'),
('BCS-MODEL-0180','bcs:math:7a6ff78f9440:687ec8ad63e0','bcs-model-part02-drive-100'),
('BCS-MODEL-0181','bcs:math:350babbe7e25:615d3e6009ea','bcs-model-part02-drive-100'),
('BCS-MODEL-0182','bcs:math:350babbe7e25:569da25a3e5a','bcs-model-part02-drive-100'),
('BCS-MODEL-0183','bcs:math:350babbe7e25:53b71b2f6791','bcs-model-part02-drive-100'),
('BCS-MODEL-0184','bcs:math:350babbe7e25:478281098e7e','bcs-model-part02-drive-100'),
('BCS-MODEL-0185','bcs:math:350babbe7e25:6327d5be0056','bcs-model-part02-drive-100'),
('BCS-MODEL-0186','bcs:math:350babbe7e25:b762bacc9a80','bcs-model-part02-drive-100'),
('BCS-MODEL-0187','bcs:math:350babbe7e25:b762bacc9a80','bcs-model-part02-drive-100'),
('BCS-MODEL-0188','bcs:math:350babbe7e25:0b3f02377b2d','bcs-model-part02-drive-100'),
('BCS-MODEL-0189','bcs:math:350babbe7e25:c8ffc5878410','bcs-model-part02-drive-100'),
('BCS-MODEL-0190','bcs:math:350babbe7e25:58691e9774ae','bcs-model-part02-drive-100'),
('BCS-MODEL-0191','bcs:math:350babbe7e25:3f0bce23855a','bcs-model-part02-drive-100'),
('BCS-MODEL-0192','bcs:math:350babbe7e25:8960a9305ebf','bcs-model-part02-drive-100'),
('BCS-MODEL-0193','bcs:math:7a6ff78f9440:828c9bed753c','bcs-model-part02-drive-100'),
('BCS-MODEL-0194','bcs:math:7a6ff78f9440:991d77dc6844','bcs-model-part02-drive-100'),
('BCS-MODEL-0195','bcs:math:7a6ff78f9440:53ef464f21bd','bcs-model-part02-drive-100'),
('BCS-MODEL-0196','bcs:math:7a6ff78f9440:f7925d3633fb','bcs-model-part02-drive-100'),
('BCS-MODEL-0197','bcs:math:350babbe7e25:c61b76a00621','bcs-model-part02-drive-100'),
('BCS-MODEL-0198','bcs:math:350babbe7e25:5870f9e0bf58','bcs-model-part02-drive-100'),
('BCS-MODEL-0199','bcs:math:350babbe7e25:630c34e0a59a','bcs-model-part02-drive-100'),
('BCS-MODEL-0200','bcs:math:350babbe7e25:97297d21d83d','bcs-model-part02-drive-100')) a(question_id,subtopic_id,batch) join jobmaster_private.questions q on q.id=a.question_id and q.data->>'track'='BCS' and q.data->>'batch'=a.batch on conflict(question_id) do nothing;
create or replace function public.jobmaster_taxonomy_admin(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); qid text:=p->>'question_id'; leaf text:=p->>'subtopic_id'; tr text; expected_track text;
begin
 if u is null then raise exception 'Unauthorized';end if;
 if not exists(select 1 from jobmaster_private.profiles where id=u and role='admin') then raise exception 'Admin access required';end if;
 perform public.jobmaster_action(jsonb_build_object('action','workspace','track','BCS'));
 if p->>'action'='list' then return jsonb_build_object('assignments',(select coalesce(jsonb_agg(to_jsonb(a)),'[]') from (select question_id,subtopic_id from jobmaster_private.question_classification order by question_id)a));end if;
 if p->>'action' is distinct from 'assign' then raise exception 'Unknown action';end if;
 select data->>'track' into tr from jobmaster_private.questions where id=qid for update;
 if not found then raise exception 'Question not found';end if;
 select s.track into expected_track from jobmaster_private.exam_subtopics l join jobmaster_private.exam_topics t on t.id=l.topic_id join jobmaster_private.exam_subjects s on s.id=t.subject_id where l.id=leaf;
 if expected_track is null or tr<>expected_track then raise exception 'Invalid subtopic or track mismatch';end if;
 if exists(select 1 from jobmaster_private.exams where question_ids @> jsonb_build_array(qid)) or exists(select 1 from jobmaster_private.bcs_plan_questions where question_id=qid) then raise exception 'Scheduled/routine question classification is protected';end if;
 if exists(select 1 from jobmaster_private.question_classification where question_id=qid and subtopic_id=leaf) then return '{"ok":true,"unchanged":true}'::jsonb;end if;
 insert into jobmaster_private.question_classification(question_id,subtopic_id,assigned_by) values(qid,leaf,u) on conflict(question_id) do update set subtopic_id=excluded.subtopic_id,assigned_by=u,updated=clock_timestamp();
 update jobmaster_private.questions set verified=false where id=qid;
 insert into jobmaster_private.audit(actor,action,entity) values(u,'question_classification',qid);
 return '{"ok":true,"review_required":true}'::jsonb;
end $$;
revoke all on function public.jobmaster_taxonomy_admin(jsonb) from public,anon;
grant execute on function public.jobmaster_taxonomy_admin(jsonb) to authenticated;

create or replace function public.jobmaster_custom_exam(p jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();tr text:=p->>'track';a text:=p->>'action';pool jsonb;catalog jsonb;picked jsonb:='[]';candidates jsonb;part jsonb;sel jsonb;n int;mins int;ms bigint;sid uuid;v text;seen text[]:='{}';used_ids text[]:='{}';candidate_ids text[];total_n int:=0;
begin
 if u is null then raise exception 'Unauthorized';end if;
 if tr is null or tr not in ('BCS','EEE') then raise exception 'Invalid track';end if;
 perform public.jobmaster_action(jsonb_build_object('action','workspace','track',tr));ms:=jobmaster_private.now_ms();
 select coalesce(jsonb_agg(jsonb_build_object('data',case when s.id is not null then q.data||jsonb_build_object('subject',s.title,'topic',t.title,'subtopic',l.title,'subject_id',s.id,'topic_id',t.id,'subtopic_id',l.id) else q.data end,'subject_id',s.id,'topic_id',t.id,'subtopic_id',l.id,
  'subject',coalesce(s.title,q.data->>'subject'),'topic',coalesce(t.title,
   (select nullif(btrim(z.metadata->>'topic'),'') from jobmaster_private.bcs_question_sources z where z.question_id=q.id order by z.plan_id limit 1),nullif(q.data->>'topic',''),'টপিক অনির্ধারিত'),
  'subtopic',coalesce(l.title,'Mapping বাকি'))),'[]') into pool
 from jobmaster_private.questions q
 left join jobmaster_private.question_classification c on c.question_id=q.id
 left join jobmaster_private.exam_subtopics l on l.id=c.subtopic_id
 left join jobmaster_private.exam_topics t on t.id=l.topic_id
 left join jobmaster_private.exam_subjects s on s.id=t.subject_id and s.track=tr
 where q.verified and q.data->>'track'=tr and (c.question_id is null or s.id is not null)
 and not exists(select 1 from jobmaster_private.bcs_plan_questions b join jobmaster_private.bcs_month_plan m on m.id=b.plan_id where b.question_id=q.id and m.ends>ms)
 and not exists(select 1 from jobmaster_private.exams e where e.ends>ms and e.question_ids @> jsonb_build_array(q.id));
 if a='catalog' then
  select coalesce(jsonb_agg(to_jsonb(z) order by z.subject,z.topic,z.level,z.subtopic),'[]') into catalog from (
   select 'topic:'||(x->>'topic_id') key,'topic' level,x->>'subject_id' subject_id,x->>'topic_id' topic_id,null::text subtopic_id,x->>'subject' subject,x->>'topic' topic,null::text subtopic,count(*) available
   from jsonb_array_elements(pool) x where x->>'topic_id' is not null group by 1,3,4,6,7
   union all
   select 'sub:'||(x->>'subtopic_id'),'subtopic',x->>'subject_id',x->>'topic_id',x->>'subtopic_id',x->>'subject',x->>'topic',x->>'subtopic',count(*)
   from jsonb_array_elements(pool) x where x->>'subtopic_id' is not null group by 1,3,4,5,6,7,8
   union all
   select 'legacy:'||md5((x->>'subject')||chr(31)||(x->>'topic')),'legacy',null,null,null,x->>'subject',x->>'topic',null,count(*)
   from jsonb_array_elements(pool) x where x->>'topic_id' is null group by 1,6,7
  )z;
  return jsonb_build_object('version',2,'topics',catalog,'now',ms);
 end if;
 if a is distinct from 'start' then raise exception 'Unknown action';end if;
 if jsonb_typeof(p->'selections') is distinct from 'array' or jsonb_array_length(p->'selections') not between 1 and 30 then raise exception 'Select 1 to 30 groups';end if;
 if coalesce(p->>'minutes','') !~ '^[0-9]{1,3}$' then raise exception 'Invalid minutes';end if;
 mins:=(p->>'minutes')::int;if mins not between 1 and 180 then raise exception 'Minutes must be 1–180';end if;
 perform pg_advisory_xact_lock(hashtext(u::text));
 for sel in select value from jsonb_array_elements(p->'selections') loop
  v:=sel->>'key';if v is null or v=any(seen) then raise exception 'Duplicate or missing group';end if;seen:=array_append(seen,v);
  if coalesce(sel->>'count','') !~ '^[0-9]{1,3}$' then raise exception 'Invalid question count';end if;
  n:=(sel->>'count')::int;if n not between 1 and 100 then raise exception 'Count must be 1–100';end if;
  total_n:=total_n+n;if total_n>100 then raise exception 'Maximum 100 questions per paper';end if;
  select coalesce(jsonb_agg(x),'[]'),array_agg(x->'data'->>'id') into candidates,candidate_ids from jsonb_array_elements(pool) x where
   v='topic:'||(x->>'topic_id') or v='sub:'||(x->>'subtopic_id') or
   (x->>'topic_id' is null and v='legacy:'||md5((x->>'subject')||chr(31)||(x->>'topic')));
  if jsonb_array_length(candidates)<n then raise exception 'Not enough verified questions; refresh availability';end if;
  if candidate_ids && used_ids then raise exception 'Parent topic and its subtopics overlap; select only one level';end if;
  used_ids:=used_ids||candidate_ids;
  select jsonb_agg(z.x->'data') into part from (select x from jsonb_array_elements(candidates) x order by random() limit n)z;picked:=picked||part;
 end loop;
 if (select count(distinct x->>'id') from jsonb_array_elements(picked) x)<>total_n then raise exception 'Duplicate question selection';end if;
 insert into jobmaster_private.sessions(user_id,track,started,deadline,snapshot) values(u,tr,ms,ms+mins::bigint*60000,picked) returning id into sid;
 return jsonb_build_object('id',sid,'count',total_n,'deadline',ms+mins::bigint*60000);
end $$;
revoke all on function public.jobmaster_custom_exam(jsonb) from public,anon;
grant execute on function public.jobmaster_custom_exam(jsonb) to authenticated;

commit;
select s.title subject,t.title topic,l.title subtopic,count(*) total,count(*) filter(where q.verified) approved from jobmaster_private.question_classification c join jobmaster_private.questions q on q.id=c.question_id join jobmaster_private.exam_subtopics l on l.id=c.subtopic_id join jobmaster_private.exam_topics t on t.id=l.topic_id join jobmaster_private.exam_subjects s on s.id=t.subject_id group by 1,2,3 order by 1,2,3;
