# JobMaster Unified V5 — প্রথমে এটি পড়ুন

## এই release-এর সিদ্ধান্ত
পুরোনো পরীক্ষা দেওয়ার interface, `/api/workspace` answer/submit/result, PDF, grading ও historical attempts retained। V4-এর আলাদা student Live panel আর render হয় না। একই Live Exam page-এ published paper date/course tabs দিয়ে দেখায়। Routine আছে কিন্তু question paper প্রকাশ হয়নি—এমন row শুধু Study Routine-তে থাকে, Live exam হিসেবে নয়।

Admin-এর প্রধান কাজের ধারা:
**Course → প্রশ্ন যোগ/Import → Review → Routine → Publish exam**।

Admin → Course Studio → course বাছুন → **Routine / Live / Import / AI**:
- **Routine & Live Exams**: manual add/edit, SQL preview/import/export, publish/unpublish routine, remove/restore, paper publication, future exam time/duration edit, cancellation/unlink।
- **SQL / CSV mapped import**: একই course question bank-এ প্রশ্ন input; duplicate bank নয়।
- **Optional Gemini / AI**: prompt/paste helper, optional server API।
- Category / course nesting এবং deleted question archive retained।

আগের বিশেষ daywise source-review tools রাখা আছে, কিন্তু পুরোনো duplicate schedule tab প্রধান navigation থেকে সরানো হয়েছে। আগে daywise questions link থাকলে সেই source/topic-review gate দিয়েই paper publish হয়; নতুন system তা bypass করে না।

## আগে কী backup করবেন
1. Existing GitHub repository/branch backup।
2. Supabase database backup/export।
3. Existing Vercel environment configuration নিজের কাছে রাখুন—keys chat/GitHub-এ প্রকাশ করবেন না।

এই ZIP conversation-এর existing workspace project-এর full upgrade। আপনার GitHub-এ এর বাইরে অন্য changes থাকলে merge করুন; অন্ধভাবে overwrite নয়। কোনো hosted account/data এখানে download বা bundle করা হয়নি।

---
## ১. Supabase-এ পরিবর্তন — আগে এই ধাপ
আপনার site-এ V3 migration আগেই successful হয়েছিল। V4 function missing থাকলেও নিচের combined installer সেটি অন্তর্ভুক্ত করে।

1. Vercel-এর `NEXT_PUBLIC_SUPABASE_URL` যে project-এর, ঠিক সেই Supabase project খুলুন।
2. SQL Editor → New query।
3. ZIP-এর root **`UPDATE-SUPABASE.sql`**-এর সম্পূর্ণ content paste → Run।
   - এতে Platform V4 prerequisite + Unified V5 + schema cache reload আছে।
   - আগে আলাদা V4 বা V5 চালিয়ে থাকলেও rerun-safe হিসেবে পরীক্ষা হয়েছে।
   - V3 না থাকলে installer স্পষ্ট prerequisite error দেবে। তখন error না দেখে পরের ধাপ করবেন না।
   - পুরোনো STEP-5/seed/BCS routine setup আবার চালাবেন না।
4. যাচাই করতে শুধু এটি চালাতে পারেন:

```sql
select
 to_regprocedure('public.jobmaster_courses(jsonb)') as courses,
 to_regprocedure('public.jobmaster_upgrade(jsonb)') as upgrade,
 to_regprocedure('public.jobmaster_schedule(jsonb)') as schedule;
```
তিনটি value-ই non-null হওয়া চাই।

5. API function এখনও schema-cache error দিলে:
```sql
NOTIFY pgrst, 'reload schema';
```
তারপর কয়েক সেকেন্ড পরে Admin page reload করুন। ভুল project-এ migration চললে cache reload তা ঠিক করবে না—project URL মিলান।

### Migration কী করে / কী করে না
- বিদ্যমান `bcs_month_plan` routine table এবং `exams` table reuse করে। আলাদা দ্বিতীয় exam engine তৈরি করে না।
- Course, routine visibility ও soft-remove fields যোগ করে; ৫০ নম্বর বাধ্যতামূলক legacy check শিথিল করে ১–১০০ marks support করে।
- আগের compatible published exams একই routine editor-এ adopt করে; একই exam দ্বিতীয়বার card হয় না।
- Questions, results, previous attempts, bookmarks বা accounts delete/reset করে না।
- Existing ৫০ নম্বরের historical routine/exam নিজে থেকে ১০০ করে না—তাহলে প্রশ্নসংখ্যা ও ইতিহাস ভুল হতো। নতুন form-এর default ১০০; unpublished future routine edit করে ১০০ দিন।
- Removed/unpublished routine automatic legacy publication থেকে বাদ পড়ে।
- Hosted DB-তে agent এই SQL চালায়নি।

---
## ২. GitHub-এ পরিবর্তন
1. **`JobMaster-Unified-V5.zip` extract করুন**।
2. Existing repo `rayhan393in/jobmaster-bd`-এর root-এ extracted source merge/upload করুন। **`package.json` repo root-এ থাকতে হবে**—দ্বিতীয় nesting folder নয়।
3. পুরো source ZIP দেওয়া হয়েছে: `src/`, `public/`, `deployment/`, `scripts/`, tests ও root config files। প্রয়োজনীয় changed files-এর তালিকা `V5-CHANGED-FILES.json`।
4. Commit দিন, যেমন `Merge unified routine and live exam workflow`।
5. শুধু `.zip` ফাইলটি repo-তে upload করলে website code বদলাবে না।
6. আপনার actual `.env.local`, API keys, SQLite db, node_modules বা `.next` commit করবেন না। ZIP-এ এগুলো নেই। `.env.example` শুধু blank placeholders।

Agent কোনো GitHub push করেনি। Full ZIP-টাই GitHub upload/merge-এর deliverable।

---
## ৩. Vercel-এ পরিবর্তন
Project → Settings → Environment Variables-এ যাচাই করুন:

| Variable | Value / প্রয়োজন |
|---|---|
| `JOBMASTER_BACKEND` | **`supabase`** — Production-এ অত্যন্ত জরুরি |
| `NEXT_PUBLIC_SUPABASE_URL` | আপনার একই hosted Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | সেই project-এর publishable key; existing anon-key alternative supported |
| `NEXT_PUBLIC_SITE_URL` | `https://jobmaster-bd.vercel.app` |
| `GEMINI_API_KEY`, `GEMINI_MODEL` | ঐচ্ছিক; basic routine/live exam-এর জন্য প্রয়োজন নেই |

- Vercel-এ local SQLite ব্যবহার করবেন না। `JOBMASTER_BACKEND` বাদ গেলে local adapter বেছে নিতে পারে, Vercel writable persistent DB নয়—runtime error হতে পারে।
- Existing variables সঠিক থাকলে নতুন mandatory environment variable নেই।
- Framework Next.js; build `npm run build`; Root Directory যেখানে package.json। Output default Next.js configuration রাখুন।
- Commit-এর auto-deploy complete/Ready হওয়া পর্যন্ত অপেক্ষা করুন। Env বদলালে নতুন Redeploy দিন।
- Deployment complete হলে `/admin` hard refresh → **ADMIN WORKSPACE · V5** দেখুন।
- Supabase Auth Site URL/allowed callback আপনার production domain-এর সঙ্গে মিলতে হবে; existing `/auth/callback` retained। এই release password-recovery UI implementation নয়।

Agent Vercel production deployment করেনি। Local production build/browser tests hosted network/Auth test-এর সমান নয়।

---
## ৪. Admin থেকে প্রতিদিন কী করবেন — আর GitHub পরিবর্তন নয়

### A. প্রশ্ন input
1. Course নির্বাচন করুন; Subject → Topic → Subtopic তৈরি করুন।
2. **প্রশ্ন যোগ** দিয়ে manually লিখুন অথবা mapped SQL/CSV import করুন।
3. প্রশ্ন, answer, explanation ও source review করে Approve করুন। বর্তমান compatible workflow-এ Approve=verify+publish; draft=unpublished।
4. AI/pasted generation সবসময় pending draft; নিজে review ছাড়া publish নয়।

### B. Routine add বা SQL import
1. **Routine / Live / Import / AI → Routine & Live Exams**।
2. নাম, বিষয়–টপিক, Daily/Weekly, date/time, marks, duration দিন।
3. Default ১০০ marks, Daily ১৮:০০–২২:০০ Asia/Dhaka। Marks=question count, সঠিক +১, ভুল −০.৫; supported ১–১০০।
4. `Routine শিক্ষার্থীদের জন্য প্রকাশ করুন` tick → Save routine।
5. SQL চাইলে একই panel-এ **SQL file দিয়ে routine import/export** খুলুন। Template download → edit → file upload/paste → Preview → Import routines। ১–১০০ rows / ১ MB, selected course mapping, atomic rollback।
6. routine published=true হলেও question paper নিজে থেকে publish হয় না। এটি ইচ্ছাকৃত নিরাপত্তা ধাপ।

### C. একই routine থেকে Live exam publish
1. Question scope-এ valid subtopic দিন, অথবা selected course-এর mixed approved pool রাখুন।
2. Saved routine card-এ **Publish exam**।
3. ১০০ marks চাইলে সেই pool-এ ১০০টি **approved, unreserved** প্রশ্ন লাগবে। কম থাকলে সঠিক error আসবে—অন্য course থেকে filler নয়।
4. Legacy daywise-linked paper হলে আগের source/topic review complete করতে হবে।
5. পরীক্ষা date/course tab-এ একই student Live Exam page-এ দেখা যাবে। নির্ধারিত সময়েই অংশ নেওয়া যায়।

### D. Live exam-এর সময় manual change
1. ওই routine card → **Edit / Change exam time**।
2. Start, End এবং Duration দিন → Save routine।
3. Database-এর আসল exam schedule ও routine দুইটিই update হয়। **GitHub/Vercel redeploy লাগে না**।
4. এটি শুধু future, unattempted paper-এর জন্য। শুরু হয়েছে বা কেউ attempt করেছে—তাহলে time edit/cancel blocked, যাতে existing timer/result না নষ্ট হয়।
5. Published paper-এর marks বদলাতে আগে **Cancel / unlink exam** → routine marks edit → approved bank থেকে republish।
6. Cancel exam history/snapshot delete করে না। Routine remove-ও soft archive; Restore আছে।

### E. SQL দুই ধরনের—গুলিয়ে ফেলবেন না
- **Admin safe SQL uploader:** `INSERT INTO jobmaster_routine_import (data) VALUES ('JSON'::jsonb);` template। Parser validated data নেয়; arbitrary SQL execute করে না। Question uploader-এর template table নাম আলাদা `jobmaster_import`।
- **Supabase SQL Editor:** privileged owner সরাসরি routine/time SQL করতে চাইলে `deployment/updates/Routine-Direct-SQL-Example.sql` এবং `Exam-Time-Direct-SQL-Example.sql` দেখুন। এগুলো commented, placeholder templates—unchanged run করার জন্য নয়। এগুলো main installer নয়।

---
## ৫. Student flow
- একটিই **Live Exam** পেজ; পাশাপাশি কেবল ওই তারিখের actual published exam/course tabs। কোনো অন্য exam না থাকলে খালি course tab নয়।
- Date বেছে Daily/Weekly filter; একই পুরোনো exam interface → answer save → resume → submit।
- End/publish time-এর আগে answer/review/result গোপন। পরে বাস্তব score, explanation, PDF ও Top5।
- Routine-only rows **Study Routine** পাতায়; Live exam হিসেবে দেখানো হয় না।
- BCS/EEE/PetroBangla এবং arbitrary course bank আলাদা থাকে। Published custom course নতুন deployment ছাড়াই catalog-এ যুক্ত হয়।
- Old routine, custom-topic builder, PDF ও source-review tools retained। Smart Routine PDF বর্তমানে existing BCS routine path ব্যবহার করে; generic course calendar PDF নতুন করে বানানো হয়নি।

## ৬. পরীক্ষা ও সীমা—আসল ফলাফল
নতুন release-এর logs:
- `unified-v5-install-results.txt`: ৬ installer checks, exact combined installer twice after V3, existing data preserve, required RPCs present।
- `unified-v5-sql-results.txt`: ৪৪ PostgreSQL checks PASS।
- `unified-v5-browser-results.txt`: ৩০ browser/API checks PASS; manual question input/review, routine SQL/manual, linked time edit, single live UI, real start/answer/submit/result, PDF, 390px mobile।
- `unified-v5-100marks-results.txt`: ৯ end-to-end checks PASS—১০০ approved unique questions, OLD exam interface-এ ১০০ questions, ১০০ answers persisted, grading সত্যি ১০০/১০০, ১০০ explanations। Disposable fixtures; production question bank বানিয়ে ভরা হয়নি।
- Existing regression suites rerun: V4 SQL ৫৪; V3 SQL ৪৮; cloud baseline ৩২; taxonomy SQL ২৫; V3 browser ২৪; taxonomy browser ১৪; integration ৪৩—PASS।
- Build ও TypeScript PASS।

**Test হয়নি / দাবি করছি না:** hosted Supabase Auth/network execution, actual Vercel production deployment, live Gemini provider response/key, real multi-user load। SQL PostgreSQL emulator-এ ও UI local production server-এ পরীক্ষা হয়েছে। Migration + deployment করে owner-এর একটি real account দিয়ে live smoke test করতেই হবে।

V4 standalone browser script পুরোনো duplicate UI-কে লক্ষ্য করত; V5-এর জন্য নতুন unified browser test ব্যবহার করুন। পুরোনো log দেখিয়ে current hosted deployment successful বলা হচ্ছে না।

## ৭. Hosted smoke test—সবচেয়ে জরুরি
1. `/admin` → V5 দেখা যাচ্ছে, কোনো missing RPC error নেই।
2. একটি ছোট ১–২ marks-এর future test routine ও approved source-checked questions দিয়ে exam publish করুন।
3. সময় শুরু হলে student account দিয়ে exam দিন; উত্তর save/resume/submit দেখুন।
4. End-এর পরে result, review, PDF ও leaderboard দেখুন।
5. এটি pass হলে ১০০ marks-এর real daily/weekly publish করুন।

শুধু UI card দেখা মানে পরীক্ষা production-এ tested নয়। Error হলে exact error দিন—account, প্রশ্ন বা database delete/reset করবেন না।
