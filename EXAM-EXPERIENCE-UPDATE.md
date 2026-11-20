# JobMaster — Dashboard & Full Question Paper Update

## কী পরিবর্তন হয়েছে

1. এক প্রশ্ন করে navigation বাদ: পুরো পরীক্ষার সব প্রশ্ন একই scrollable পাতায়। প্রতিটি প্রশ্নের ৪টি বিকল্প ও নম্বর থাকবে। বড় পর্দায় দু-কলামের options, mobile-এ এক কলাম।
2. Timer sticky header-এ; প্রশ্ন নম্বরের palette দিয়ে jump, অনুত্তরিত/review filter, autosave status ও submit confirmation।
3. উত্তর সার্ভারে সফলভাবে save হওয়ার পর selected দেখায়। Save চলার সময় submit বন্ধ; reload/resume-এ সংরক্ষিত উত্তর ফেরত আসে। Review markers শুধু বর্তমান view-এর জন্য; bookmark নয়, reload-এ থাকে না।
4. Dashboard-এর উপরে Exam Desk: চলমান attempt-এ ফেরত যাওয়া, live পরীক্ষার সরাসরি button, পরবর্তী প্রকাশিত পরীক্ষা/রুটিন এবং custom exam। Calendar response-এর server time offset ব্যবহার; অংশগ্রহণের সময় backend আবার যাচাই করে।
5. বড় marketing hero এবং স্থায়ী placeholder upcoming-exam card সরানো হয়েছে।
6. Result summary: score, correct, wrong, unanswered এবং attempted-answer accuracy। Scoring: correct × 1 − wrong × 0.5; unanswered zero। পুরোনো backend scoring অপরিবর্তিত।
7. প্রতিটি attempt-এর question paper PDF; submit এবং scheduled result publication-এর পরে answer/explanation/result PDF। Ownership, authentication, PDF rate limit এবং result embargo প্রযোজ্য। আগের routine ও result-report PDF-ও রাখা হয়েছে।
8. Custom exam builder: প্রতি topic-এর available count, search, নিজস্ব count (মোট 1–100; 1–30 topics) এবং সময় (1–180 মিনিট)। অপর্যাপ্ত প্রশ্নে silently কম প্রশ্ন দেয় না।
9. Admin-এর আলাদা “সম্পূর্ণ রুটিন” tab: 30 Daily + 4 Weekly, বিষয়/টপিক, সময়, marks এবং status। Admin view-এ দীর্ঘ topics খোলা থাকে। Daywise import/review panel-এর link আছে।

## Backend ও ডেটার সীমা

- নতুন route `/api/custom-exam` এবং `/api/exam-pdf` সত্যিকারের backend; mock result নয়।
- Cloud custom exam-এর জন্য `deployment/updates/Custom-Topic-Exams.sql` প্রয়োজন। এটি additive; existing question/session rows delete বা overwrite করে না।
- ওই migration-এর prerequisites: STEP-5-SUPABASE.sql, BCS-Auto-Routine-Setup.sql, BCS-Daywise-Import.sql।
- Cloud-এ stored source metadata থেকে topic পাওয়া যায়। Metadata না থাকলে স্পষ্টভাবে “বিষয়ভিত্তিক — টপিক অনির্ধারিত” লেখা হয়; syllabus-এর সঙ্গে ভুয়া mapping নেই।
- Local SQLite preview-তে daywise topic metadata storage নেই; তাই local custom builder শুধু প্রকৃত subject অনুযায়ী grouping দেয়। Cloud named-topic selection আলাদাভাবে PostgreSQL-এ পরীক্ষা হয়েছে।
- Custom exams কেবল verified প্রশ্ন নেয়। ভবিষ্যৎ/অসমাপ্ত calendar বা scheduled paper-এ reserved প্রশ্ন এই custom pool-এ আসে না। বিদ্যমান generic mixed-practice mode-এর selection policy এই update-এ বদলানো হয়নি; সেটিতে unverified imported/original প্রশ্ন থাকতে পারে।
- কোনো available verified প্রশ্ন না থাকলে builder ফাঁকা অবস্থা ও কারণ দেখায়। প্রশ্ন তৈরি/verification স্বয়ংক্রিয় নয়।
- Cloud-এ Chromium ও Bangla font tracing `/api/exam-pdf` route-এর জন্য config-এ যুক্ত হয়েছে। PDF-গুলো local production build-এ বাস্তবে generate হয়েছে; Vercel runtime-এ এখনও পরীক্ষা হয়নি।
- সম্পূর্ণ মাসিক routine PDF, topic note PDF ও formula sheet এই update-এ যোগ হয়নি।
- Hosted Supabase Auth/network, deployed migration ও live Vercel behaviour যাচাই হয়নি। কোনো deployment করা হয়নি।

## পরীক্ষার ফল

- TypeScript: `npx tsc --noEmit` সফল।
- Production build: `npm run build` সফল।
- `tests/exam-experience-browser.mjs`: 15 PASS — desktop/mobile, full paper, custom count/time, saved-answer restore, real PDFs, score, 34 admin slots, no JS error।
- `tests/custom-exam-sql.mjs`: 17 PASS — additive/idempotent migration, anonymous denial, actual availability, no answer key in catalog, insufficient/duplicate count rejection, exact count/time, existing scoring/ownership, future reservation exclusion, stored named-topic selection।
- `tests/custom-exam-api.mjs`: 10 PASS — authentication, cross-origin rejection, shortage/duplicates/invalid-track rejection, exact count, foreign/anonymous PDF denial, scheduled answer-PDF embargo।
- Existing integration: 43 PASS।
- Existing cloud PostgreSQL regression: 32 PASS।
- মোট 117 checks PASS, plus TypeScript and production build। সব test local; cloud tests disposable PGlite PostgreSQL-compatible database-এ।

## এখন deployment-এর প্রথম ধাপ — শুধু এটিই করুন

আগের তিনটি prerequisite migration ইনস্টল থাকলে Supabase SQL Editor-এর একটি নতুন query-তে **Custom-Topic-Exams.sql সম্পূর্ণ ফাইল Run করুন**। না থাকলে আগে জানান কোন migration পর্যন্ত ইনস্টল হয়েছে। সফল হওয়ার পরে source files GitHub-এ update ও Vercel redeploy-এর পরবর্তী ধাপ দেওয়া যাবে।

নতুন migration ছাড়া custom cloud feature কাজ করবে না; শুধু এই SQL চালালেও website UI আপডেট হবে না—source redeploy আলাদা ধাপ।

## Source package

ZIP-এ সম্পূর্ণ project source/config/deployment/tests আছে। node_modules, .next, .env secrets, SQLite database ও authentication data বাদ দেওয়া হয়েছে। Extract করা source দিয়ে পুরোনো project-এর files update করুন; নিজের Vercel environment variables অপরিবর্তিত রাখুন। কোনো student data ফাইল দিয়ে প্রতিস্থাপন করবেন না।
