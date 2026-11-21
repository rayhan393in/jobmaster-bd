# JobMaster BD — Cloud deployment steps

**এখনকার ধাপ:** Supabase SQL Editor-এ `STEP-5-SUPABASE.sql` চালানো।
এই ফাইলে schema + 60টি AI-assisted practice প্রশ্ন + topic IDs আছে।
কোনো user/password/secret নেই। আগের draft `supabase/schema.sql` ব্যবহার করবেন না।
এই version re-run করলে বিদ্যমান প্রশ্ন বা user data মুছে যায় না।

## পরে, একে একে

1. মূল SQL সফল হওয়ার পরে feature SQL-গুলো **এই ক্রমে** চালান (প্রতিটি ফাইল সম্পূর্ণ সফল হওয়ার পর পরেরটি):
   - `deployment/updates/BCS-Auto-Routine-Setup.sql`
   - `deployment/updates/BCS-Daywise-Import.sql`
   - `deployment/updates/Subject-Topic-Subtopic-V2.sql`
   - `deployment/updates/Admin-Courses-V3.sql`
   - `deployment/updates/Platform-V4.sql`
   - `deployment/updates/Cloud-Schedule-RPC.sql` — এই patch-এ যোগ করা নতুন RPC; routine/calendar API-এর জন্য প্রয়োজন।
   এই dependency order গুরুত্বপূর্ণ: Admin-Courses-V3 taxonomy ও Daywise tables-এর ওপর নির্ভরশীল; Platform-V4 Admin-Courses-V3-এর ওপর নির্ভরশীল।
2. `supabase/migrations/003_expiry_cron.sql` চালানোর আগে নিশ্চিত করুন আপনার project-এ নির্দেশিত `001` ও `002` migrations-ও প্রয়োগ করা আছে; তারপর প্রতি মিনিটে overdue exam finalize করার DB scheduler চালু করুন।
3. নিরাপদ source ZIP-এর contents private repository-র root-এ upload করুন। `.env`, SQLite, `.next`, `node_modules` বা আগের admin code upload করবেন না।
4. Vercel-এ repository import; framework Next.js; build `npm run build`; Node 22.x বা পরবর্তী supported LTS বেছে নিন।
5. Vercel Environment Variables:
   - `JOBMASTER_BACKEND=supabase`
   - `NEXT_PUBLIC_SUPABASE_URL` = নিজের Project URL
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` = নিজের public/publishable key
   - `NEXT_PUBLIC_SITE_URL` = পরে চূড়ান্ত HTTPS deployment URL
   - Secret/service_role/database password এই অ্যাপের জন্য লাগবে না।
6. Deploy হওয়ার পরে Supabase Authentication → URL Configuration-এ Site URL হিসেবে নিজের HTTPS domain দিন; Redirect URLs-এ `https://YOUR-DOMAIN/auth/callback` যুক্ত করুন। Vercel-এর Site URL variable একই রাখুন এবং redeploy করুন।
7. নিজের email/password দিয়ে সাইটে register করুন। Email verification ON রাখুন, link খুলুন, তারপর login করুন। Supabase email provider-এর sending limits থাকতে পারে; production-এ নিজের SMTP প্রয়োজন হতে পারে।
8. Authentication → Users থেকে নিজের verified user UUID কপি করুন। `ADMIN-AFTER-SIGNUP.sql`-এর দুই জায়গার placeholder নিজের UUID দিয়ে বদলে SQL Editor-এ চালান। অন্য কারও UUID দেবেন না।
9. `/admin`-এ login করুন। Cloud mode-এ পুরোনো local owner-setup code অকার্যকর।
10. Test account দিয়ে login, routine, 30-question exam, autosave/resume, result ও PDF পরীক্ষা করুন। Admin প্রশ্ন verify করে short scheduled exam দিন; ফলাফল প্রকাশের আগে কোনো উত্তর/স্কোর যেন না দেখা যায় যাচাই করুন।

## নিরাপত্তা ও সীমাবদ্ধতা

- সব study data `jobmaster_private` schema-তে; browser role-এর direct access নেই; সব table-এ RLS ON।
- `public.jobmaster_action(jsonb)` authenticated RPC নিজে user/admin ownership পরীক্ষা করে। কোনো service-role key ব্যবহার করে RLS bypass করা হয় না।
- Authentication Supabase server APIs ও HttpOnly cookies ব্যবহার করে; email verification callback আছে।
- Scheduled timing, answer locks, idempotency, scoring ও result embargo PostgreSQL-এ হয়।
- Serverless PDF-এ bundled Chromium ও local Bengali font আছে; বাস্তব Vercel deployment এখনও আলাদাভাবে পরীক্ষা করতে হবে।
- Local SQLite users/data cloud-এ আপনা থেকে migrate হবে না। Cloud-এ নতুন করে registration প্রয়োজন।
- Official syllabus/content verification এখনও অসম্পূর্ণ। Seed প্রশ্ন AI-assisted/editorial-review-pending হিসেবেই আছে।
- Hosted Supabase Auth, email delivery, network, actual RLS settings ও Vercel deployment credentials ছাড়া যাচাই করা হয়নি। Local PostgreSQL-engine tests আলাদা।
