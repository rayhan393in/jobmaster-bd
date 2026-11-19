# JobMaster BD

Functional multi-user **local deployment**, built with Next.js, TypeScript, React,
Tailwind, Lucide, Recharts, SQLite, Playwright PDF and Zod.

## Quick start

```sh
npm ci
npx playwright install --with-deps chromium
npm run build
npm start -- --hostname 0.0.0.0
```

Create your account in the UI. Passwords require at least ten characters.
To explicitly provision your registered account as administrator:

```sh
node scripts/admin.mjs your-email@example.com
```

Refresh, open the profile icon / Settings, then Admin Center. There is **no shared
admin password** and regular registration does not grant administration unless
a server operator has explicitly configured `JOBMASTER_ADMIN_EMAIL`.

## Implemented and tested

- Registration / login / logout; scrypt-salted passwords; random HttpOnly
  SameSite session cookie; only token digests stored; expiry and revocation.
- Authenticated user-scoped tasks, attempts, answer storage, bookmarks and topic progress.
- BCS / EEE isolation; thirty distinct AI-assisted practice questions per track.
  These are labeled **editorial review pending**, not verified previous papers.
- Editorial study explorer: 10 BCS subjects, 15 EEE subjects, chapters, topics,
  theory notes, selected formulas and persistent self-reported completion.
  **Not claimed to be a complete official syllabus.**
- Practice, incorrect-question revision, bookmark revision, reload/resume,
  answer autosave, server-authoritative deadlines, transactional scoring,
  negative marks, idempotent submission and post-submit write locks.
- Server expiry worker runs every second while the Node server is alive;
  requests and process startup also finalize overdue sessions. Answers after
  the deadline are rejected regardless of browser timer state.
- Protected admin: student list, add question, inspect answers/explanations,
  verification toggle, CSV preview, schema validation, normalized fingerprint
  duplicate checks, validation-report download, transactional import.
- Schedule an exam from verified questions with start, end, duration and result
  publication times (admin input is Bangladesh time, UTC+06:00). One attempt per
  student per scheduled exam. Keys, score and leaderboard embargo until publish.
- Per-exam leaderboard from actual published attempts only. Tie order currently
  uses score descending then start time ascending; there are no synthetic ranks.
- Daily routine generation prioritizes subjects with observed mistakes;
  completion, actual-result analytics, weakness detection and real study streak.
- A4 downloadable routine and result PDFs rendered by Chromium, embedded local
  Bengali font, tables, page numbers and escaped user text; no external PDF assets.
- Mobile layout, mobile track switch, dark/light theme; no exposed secret keys.
- Indexed storage capacity tested with 10,000 temporary rows and full rollback.

## Still incomplete / not production-ready

1. **Supabase authentication/data adapter and Vercel deployment**. The running
   app uses SQLite and custom sessions, NOT Supabase. The PostgreSQL/RLS draft
   in `supabase/schema.sql` is not deployed, integrated or audited. Environment
   variables alone do not switch the adapter. Vercel ephemeral disk is not
   suitable for this database. Use a persistent Node host for the current build.
2. Official BPSC document/version archive and fully validated syllabus coverage.
   An attempt to retrieve the official legacy PDF failed; no third-party copy
   was silently promoted to authoritative status. Supply current official PDFs
   and verify applicability before publishing an official syllabus.
3. Expert review of questions/notes, verified recruitment papers, full EEE
   organization-specific bank, diagrams and comprehensive numericals.
4. Topic/subtopic-linked question analytics, spaced repetition, weekly off-day,
   exam-goal planner, weekly/monthly adaptive routines and missed-task rescheduling.
5. XLSX import (CSV UTF-8 is implemented), admin edit/delete/audit log, announcements,
   exam question-selection preview and customizable marking rules. Current
   marking is +1 / −0.5; scheduled question selection uses verified pool order.
6. Daily/weekly/monthly aggregate competitive leaderboards. Practice is deliberately
   excluded from competition rankings.
7. Seven additional PDF types (weekly/monthly plans, notes/formula sheets,
   question papers and detailed performance/revision reports).
8. Email verification, password reset, MFA, distributed rate limiter, independent
   security audit, concurrency/load test and real-device testing.
9. Serverless/distributed durable scheduler. The current expiry worker requires
   the Node process to remain alive; restart catch-up is implemented.

## Tests

Run against the production server:

```sh
node tests/integration.mjs
node tests/capacity.mjs
node tests/browser.mjs
```

Integration tests create test-only accounts and clean up their rows. Browser
tests cover registration, routine, autosave/reload/resume, submission/review,
track isolation and a 390px viewport. Capacity fixtures are rolled back and
never presented as learning content. See TEST-RESULTS.md.

## Structure

- `src/app/page.tsx` — dashboard / practice / reports shell
- `src/components/` — auth gate, syllabus explorer, admin and exam center
- `src/app/api/` — authenticated backend routes
- `src/lib/auth.ts` — password/session/origin/rate-limit helpers
- `src/lib/store.ts` — indexed local relational schema + scoring
- `src/lib/catalog.ts` — 60 labeled AI-assisted practice fixtures
- `src/lib/syllabus.ts` — non-official editorial study outline
- `src/instrumentation.ts` — server expiry finalizer
- `supabase/schema.sql` — future PostgreSQL/RLS migration draft
- `public/fonts/` — embedded Bengali font and OFL license

No user registration or imported content is sent to an external AI service.
Keep the database private and back it up on persistent hosting. Do not commit
SQLite files or server credentials to source control.

## Website-owner access (updated)

Open **Admin লগইন / Website management** on the login form, or visit `/admin`.
For first-time setup, a server operator runs `node scripts/admin-setup.mjs` and privately
provides the generated code to the owner. The code expires after 24 hours and is single-use.
Open `/admin/setup`, enter the code, name, email and your own password. For an existing
account, enter that account's correct password. Setup creates/promotes the account and signs
it in; later logins use `/admin` with the normal email/password, not the setup code.
The admin panel now supports question editing; every edit resets verification.
Layout/theme/code editing still requires source changes; no visual page-builder is included.
