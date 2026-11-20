# V5.1 — সত্যিকার single Admin + Live navigation fix

এই guide আগের V5 menu নির্দেশনার পরিবর্তে ব্যবহার করুন।

## কী সরানো / merge হয়েছে
- AdminCenter-এর পুরোনো/new toggle, outer Course Studio menu, duplicate question editor/list/CSV/schedule UI বাদ। Backend/data/delete করা হয়নি।
- একটি Admin Control Center, একটি `Admin tools` navigation।
- প্রশ্ন যাচাই, প্রশ্ন যোগ, taxonomy, Routine & Live Exams, CSV/SQL Import, papers, AI helper, category, archive, students একই course workspace-এ।
- BCS-এর পূর্বের daywise source/provenance review একই menu-তে `দিনভিত্তিক উৎস review` হিসেবে retained; EEE/custom bank-এ BCS source tools ঢোকানো হয়নি।
- আগে ব্যবহৃত classification আলাদা পুরোনো editor নয়: একই question editor থেকে valid Subtopic path assign করুন। Existing IDs/approval-reset protection retained।
- Course change করলে একই tool-এ থাকা যায়; আর পুরোনো আর নতুন দুটি panel নেই।

## Live exam fix
- নির্বাচিত দিনে কোনো published exam না থাকলেও Previous/Next প্রকৃত published dates-এ যেতে পারে। পুরোনো idx=-1 হলে দুই navigation button বন্ধ হয়ে যেত—সেটি ঠিক হয়েছে।
- `প্রকাশিত পরীক্ষার তারিখ` dropdown, manual Refresh exams, focus refresh এবং 30-second polling।
- Empty state স্পষ্ট করে: routine-only নাকি অন্য তারিখে paper আছে। অন্য তারিখের paper আজকের নামে দেখানো হয় না।
- Admin-এর published routine card-এ **Student exam দেখুন** link; সঠিক exam/course/date-এ Live পেজ খুলবে।
- পরীক্ষার সময়/marks/availability আগের server-authoritative V5 backend থেকেই। No auto-approval, no filler questions, no unscheduled free entry।
- Approved count/insufficient-pool warning Admin routine editor-এ দেখা যায়। এটি course-এর approved মোট; এর কিছু future exam-এ reserved থাকতে পারে।

## কী upload করবেন
Full source: `JobMaster-Single-Admin-V5.1.zip`। Extract করে existing repo root-এ merge করুন; ZIP নিজে upload নয়।

V5 থেকে মূল app changes মাত্র এই 8 files:
1. src/components/AdminCenter.tsx
2. src/components/CourseWorkbench.tsx
3. src/components/PlatformTools.tsx
4. src/components/RoutineManager.tsx
5. src/components/LiveExamCenter.tsx
6. src/app/page.tsx
7. src/app/admin/page.tsx
8. src/app/globals.css

অন্য source ও dependencies full ZIP-এ completeness-এর জন্য আছে। আগের build error এড়াতে নিশ্চিত করুন `src/lib/schedule-validation.ts` এবং `src/lib/local/schedule.ts` repo-তে এখনও আছে।

Commit → Vercel নতুন commit deploy → Ready হলে hard refresh। `/admin`-এ **ADMIN WORKSPACE · V5.1** এবং কেবল একটি navigation থাকবে। `Course Studio` outer tab বা পুরোনো tools toggle থাকবে না। সেগুলো থাকলে পুরোনো source/deployment চলছে।

## Supabase / Vercel
- **V5 UPDATE-SUPABASE.sql আগেই সফল থাকলে নতুন SQL/env change লাগবে না।** এই update UI/navigation fixes; schema পরিবর্তন নয়।
- V5 RPC missing হলে full ZIP-এর `UPDATE-SUPABASE.sql` একই hosted project-এ backup নিয়ে চালান; আগের `START-HERE-V5-BN.md`-এর database/environment নির্দেশনা প্রযোজ্য। পুরোনো seed পুনরায় নয়।
- Vercel backend `supabase` রাখুন। No hosted push/deploy/migration performed by the agent।

## এক জায়গা থেকে live publish করার কাজ
1. Course বাছুন → প্রশ্ন যোগ অথবা CSV/SQL Import।
2. প্রশ্ন source/answer/explanation যাচাই ও valid subtopic assign → Approve।
3. **Routine & Live Exams** → title/topics/date/start/end/minutes/marks → Save routine।
4. Question scope বাছুন → Saved routine card → **Publish exam**।
5. **Student exam দেখুন** দিয়ে সত্যিকারের paper আছে কি না ও সময় সঠিক কি না দেখুন। নির্ধারিত সময়ে student পরীক্ষা দিতে পারবে।
6. Marks 100 হলে scoped approved+unreserved pool-এ 100 questions প্রয়োজন। আপনার screenshot-এ BCS approved 3 ছিল, তাই UI fix করে অযাচাইকৃত 435 প্রশ্ন নিজে থেকে approve করা হয়নি। Owner প্রয়োজনে source-checked 1–3 marks ছোট test আগে চালাতে পারেন।
7. Future unattempted exam-এর time/duration edit, cancel/unlink, routine remove/restore আগের মতো একই card-এ। Started/attempted exam locked। Routine SQL import/export-ও একই tab-এ।

## পরীক্ষার ফল
- `single-admin-v5.1-browser-results.txt`: **36 PASS**: এক shell/menu, no nested second tools nav, question entry/review, routine SQL/manual, empty-date navigation, exact exam deep link, old exam start/answer/submit/result/PDF, mobile।
- `single-admin-v5.1-100marks-results.txt`: **9 PASS**, full 100-question original exam UI এবং 100/100 grading।
- Courses browser 24, taxonomy browser 14, integration 43 PASS; latest build and TypeScript PASS।
- V5 backend schema unchanged; V5 PostgreSQL/installer tests ও guide full ZIP-এ আছে। Historical V5.0 browser script পুরোনো navigation লক্ষ্য করে; current test হলো `tests/unified-v5.1-browser.mjs`।
- নতুন focus-link implementation-এ প্রথম test draft row বেছে নেওয়ার সমস্যা ধরেছিল; fix করে current 36 checks পুনরায় PASS হয়েছে। Failed-run logs নয়, final rerun results অন্তর্ভুক্ত।

Tests local production build/disposable fixtures-এ; actual hosted deployment/Auth/network এখানে করা হয়নি। Owner-এর production smoke test এখনও প্রয়োজন। কোনো question bank/test fixture hosted data হিসেবে বানিয়ে দেওয়া হয়নি।

## নিরাপত্তা
Screenshot/URL-এ `#access_token=...` থাকলে শেয়ার করবেন না। Screenshot crop/blur করুন। Recovery দিয়ে session পেয়ে যাওয়া মানেই নতুন password save হয়েছে নয়; password recovery আলাদা বিষয়।
