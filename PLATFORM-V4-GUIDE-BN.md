# JobMaster Platform V4 — existing project upgrade

## কী করা হয়েছে
এই release বিদ্যমান Next/React UI, Supabase RPC + private-schema/RLS architecture এবং local SQLite adapter-এর উপর additive upgrade। নতুন করে project তৈরি করা হয়নি। পুরোনো routine, daywise import, legacy exam builder, login, PDF, leaderboard ও historical attempts রাখা হয়েছে।

### Admin: আগের Course Studio + নতুন V4 tools
- Arbitrary course create/edit/publish/archive; independent Subject → Topic → Subtopic tree।
- BCS, EEE, BCS+EEE/Both এবং সব-course admin scope। Both শুধু মূল BCS/EEE memberships; custom courses আলাদা নির্বাচন করুন।
- Exam category create/rename; course-কে category ও parent course-এ map করা যায়। Cycle/invalid parent reject হয়।
- `EEE-PETROBANGLA` আলাদা course/bank; parent EEE। EEE সাধারণ bank-এর প্রশ্ন স্বয়ংক্রিয় copy/share হয় না। Migration কোনো PetroBangla প্রশ্ন/অফিশিয়াল syllabus বানিয়ে দেয় না। Admin source-checked taxonomy/questions যোগ করবেন।
- Manual question edit, source/explanation, classification, approval; ব্যবহারযোগ্য subtopic না দিলে approve নয়।
- Subtopic navigation-এ total, verified, pending, published এবং progress। বর্তমান compatible workflow-এ **Approve = verify + publish**; আলাদা verified-but-unpublished state নয়। Draft = pending/unpublished।
- Soft-delete/archive ও ID দিয়ে restore; restore করলে draft। Shared question delete blocked; original owning course থেকে edit, global approval rules retained। Delete-এর আগে question ID রাখুন। Historical attempt/paper snapshots মুছে যায় না।
- Existing taxonomy rename stable IDs রাখে। ব্যবহৃত node move/delete নয়; নতুন node তৈরি করে প্রশ্ন reclassify করুন।

### Student
- Question bank ও custom exam-এ published-course browser; BCS, EEE/PetroBangla, Both, all courses। Sidebar-এর current BCS/EEE দিয়ে default scope হয়।
- Subject, Topic অথবা exact Subtopic বেছে practice; কোনো filter-এ question কম হলে অন্য course/topic থেকে fallback নয়।
- নতুন course published হলেই catalog-এ যুক্ত হয়; নতুন code deployment প্রতিটি course-এর জন্য লাগে না।
- Course Live & Mock Exams panel-এ exact course এবং daily/weekly/mock filter।
- Server-authoritative exam window, one-attempt/resume, saved answers, grading, results after end, real Top 5। Fake/demo leaderboard নেই। আগের PDF/answer sheet pipeline retained।
- Legacy track-specific dashboard/routine/custom-builder অক্ষত; arbitrary courses পুরোনো static syllabus/routine-তে জোর করে যোগ করা হয়নি। Dynamic course catalog ও V4 live panel দিয়ে ব্যবহার করুন।

## Daily / Weekly / Mock
Admin → course → **Live / SQL / Gemini / Categories** → **Daily / Weekly / Mock**।
- New daily default 18:00–22:00 Asia/Dhaka, 100 marks, 60-minute attempt।
- Weekly default 100 marks; dates/window/duration editable।
- Marks = question count, প্রতি সঠিক +1, প্রতি ভুল −0.5; supported marks 1–100। Independent fractional mark weights নেই।
- Duration 1–240 minutes, window-এর ভেতর হতে হবে।
- Daily occurrence +1 calendar day; Weekly +7 days; একসঙ্গে 1–31 occurrence; mock single occurrence। **Infinite auto-repeat/cron নয়**। Admin পরের dates publish করবেন।
- প্রতিটি occurrence approved, unreserved questions নেয়। একই future question reuse নয়; পর্যাপ্ত না থাকলে সম্পূর্ণ request rollback। Cloud-এ routine/daywise reservations-ও বাদ। Local legacy routine reservation parity আগে থেকে সীমিত—local preview-কে production Supabase-এর বিকল্প ভাববেন না।
- Schedule publication-এর সময় question snapshot freeze হয়; পরে bank edit করলেও exam snapshot বদলায় না।
- শুধু unattempted future schedule edit/cancel করা যায়। Cancel হলে reservation release হয়; audit/snapshot retained।
- Existing live exams/calendar বা routine dates স্বয়ংক্রিয় reschedule হয় না; পুরোনো published data preserve করা হয়েছে। V4 defaults নতুন schedules-এর জন্য।

## CSV / SQL mapped import
**CSV Import** পুরোনো tab retained। নতুন mapped import: V4 tools → **SQL / CSV mapped import**।
- সর্বোচ্চ 500 questions / 3 MB per batch।
- Course selection বাধ্যতামূলক। Row-এর `subtopic_id` বা fallback subtopic mapping দিন।
- Server valid leaf/course থেকে subject/topic resolve করে; optional course_id/subject_id/topic_id preview-এ mismatch হলে reject হয়।
- Preview-এ hierarchy paths, validation result; import success/error দেখা যায়। Database duplicate collision হলে পুরো batch rollback।
- সব imports draft; admin review/approve ছাড়া published practice/live pool-এ যায় না।
- CSV columns: `question,A,B,C,D,correct,explanation,kind,source,subtopic_id,difficulty,source_metadata`। Optional `course_id,subject_id,topic_id`। Correct A/B/C/D, source_metadata JSON।
- **SQL file import একটি safe data format, arbitrary SQL executor নয়।** UI-এর Download safe SQL template ব্যবহার করুন:

```sql
INSERT INTO jobmaster_import (data) VALUES
('{"q":"Original question text?","o":["One","Two","Three","Four"],"a":0,"e":"Detailed explanation goes here.","kind":"original","source":"Original practice","subtopic_id":"VALID_LEAF_ID"}'::jsonb);
```

- `jobmaster_import` প্রকৃত database table নয়; app শুধু JSON rows parse করে existing validated import API-তে পাঠায়। DROP/UPDATE/DDL/functions/multiple statements reject হয়।
- **Migration/পুরোনো direct SQL এই uploader-এ দেবেন না।** Privileged migration Supabase SQL Editor-এ চালাতে হবে। Existing V3 direct SQL course mapping triggers retained।

## Optional Gemini / API-free AI
V4 tools → **Optional Gemini / AI**।
- Topic/subtopic অনুযায়ী original MCQ generation prompt; explanation ও review helper tasks।
- Copy prompt/paste JSON-এ API key লাগে না।
- Direct optional Gemini-এর জন্য Vercel server environment-এ `GEMINI_API_KEY` এবং আপনার account-এ available generateContent model-এর `GEMINI_MODEL` দিন, তারপর redeploy। `.env.example` শুধু blank placeholders।
- Key কখনো client source/database-এ দেওয়া হয় না। Admin auth/origin/body validation; 10 AI authorizations/minute; 25-second provider timeout। Prompt external provider-এ যাওয়ার আগে UI confirmation আছে। Sensitive data পাঠাবেন না।
- Provider response শুধু suggestion; automatically save/verify/publish নয়। JSON validate করে Save pending drafts করলে provenance forced `ai_generated`, human_review_required=true। Admin edit/review/approve করবেন।
- Gemini key/model ছাড়া পুরো platform কাজ করে। Provider missing/failure-এ no question saved।
- এই release-এ live Gemini provider success test হয়নি: কোনো API credential configure করা হয়নি। Missing-key fallback ও manual/pasted generation workflow পরীক্ষা হয়েছে।

## Install: existing Supabase + Vercel
**Live website-এ এই release deploy করা হয়নি; GitHub push-ও করা হয়নি। ZIP Drive-এ থাকলেই site update হবে না।**

1. আগে current GitHub branch/source ও hosted database backup/export রাখুন। এই package conversation-এর existing workspace code-এর upgrade; আপনার repo-তে অন্য নতুন changes থাকলে overwrite না করে merge করুন।
2. আগে V2 + Admin-Courses-V3 migration installed থাকতে হবে। আপনার আগের screenshot-এ V3 successful ছিল—পুরোনো STEP-5 বা seed আবার চালাবেন না।
3. Supabase SQL Editor-এ **শুধু `deployment/updates/Platform-V4.sql`** চালান। Root-এ `Platform-V4.sql` একই ফাইল easy access-এর জন্য। Additive/rerunnable; বিদ্যমান questions/attempts delete বা blanket verify করে না। যদি error হয় transaction rollback হবে—error না দেখে skip করবেন না।
4. ZIP extract করুন। `package.json`, `src`, `public`, `deployment`, config files ইত্যাদি existing repo root-এ merge/upload করুন। ZIP ফাইলটিকে repo-তে শুধু upload করলে code update হয় না। Files commit করুন। `.env.local`/keys/db/node_modules/.next upload করবেন না।
5. Vercel deployment-এ আগের Supabase env রাখুন: `JOBMASTER_BACKEND=supabase`, `NEXT_PUBLIC_SUPABASE_URL`, publishable/anon key ও site URL। Local SQLite production-এ নয়। নতুন Gemini variables optional।
6. GitHub auto-deploy complete বা Vercel Redeploy দিন। `/admin`-এ hard refresh করে **ADMIN WORKSPACE · V4** দেখুন।
7. Admin → EEE-PetroBangla-তে নিজের subjects/topics/subtopics/questions যোগ করুন; source check করে approve/publish করুন। Publish একটি small test exam first, তারপর larger schedules। নতুন course খালি থাকা স্বাভাবিক; low-quality filler seeded নয়।

## Tests and actual limits
- `platform-v4-sql-results.txt`: **54 PostgreSQL checks PASS**; disposable PGlite PostgreSQL, not hosted DB। Additive migration rerun, preservation, permissions, isolation, schedules, rollback, snapshots, timing, grading/review, archive/restore, AI authorization rate limits।
- `platform-v4-browser-results.txt`: **34 browser/API checks PASS**; local production build, desktop/390px mobile, SQL preview/rejection/import, AI pending provenance, category/nesting, real live save/start/answer/publish flow।
- Existing regressions: V3 SQL 48; V3 browser/API 24; cloud baseline 32; taxonomy SQL 25; taxonomy browser 14; integration 43—all PASS in their logs।
- `npm run build` and `npx tsc --noEmit` PASS।
- A parallel regression attempt exceeded sandbox memory; its empty logs were replaced by successful sequential reruns. Do not run several PGlite suites concurrently in a 2 GB environment.
- Hosted Supabase network/Auth/RLS execution, actual Gemini response, real user load and Vercel production deployment are **not** tested here। Source/build compatibility tests do not equal a hosted deployment guarantee।
- No official PetroBangla/BPSC syllabus, past-paper claims or new question bank content invented. Question-bank 500 task remains separate.

## Re-run tests
```sh
npm ci
npm run build
node tests/platform-v4-sql.mjs
# Start local adapter, bind publicly for preview if needed:
PORT=3002 npm run start -- --hostname 0.0.0.0
# In another terminal:
node tests/platform-v4-browser.mjs
```
Run PostgreSQL suites sequentially. Test scripts use disposable test users/questions and clean their fixtures. Never point local browser tests at hosted production.
