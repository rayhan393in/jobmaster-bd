# JobMaster BD

Next.js / React / TypeScript preparation dashboard with **two backend modes**.

## Supabase + Vercel (new cloud adapter)

1. Run `deployment/STEP-5-SUPABASE.sql` in a new Supabase project's SQL Editor.
2. Run `supabase/migrations/003_expiry_cron.sql` to enable database expiry scheduling.
3. Set the environment variables in `.env.example`, using `JOBMASTER_BACKEND=supabase`.
4. Deploy on Vercel with Node 22.x (supported LTS), Next.js, build `npm run build`.
5. Configure Supabase Site URL and `/auth/callback` allowed redirect; register and verify email.
6. Explicitly promote your own verified UUID using `deployment/ADMIN-AFTER-SIGNUP.sql`.
7. Complete the live acceptance checks before opening registration to students.

**Detailed Bengali instructions:** `deployment/README-BN.md`.
**No service-role/secret/database password is needed by the app.** Only the public URL and
publishable key are configured. Never commit `.env`, SQLite databases or private setup codes.
Do not use the obsolete `supabase/schema.sql` draft for the cloud adapter.

### Implemented cloud path

- Supabase Auth registration, login/logout, PKCE email-verification callback and
  server-side HttpOnly session cookies with refresh handling.
- Cloud profiles with server-managed roles, private tables with RLS, and an
  authenticated SECURITY DEFINER RPC with explicit ownership/admin checks.
- Dashboard, task planner, bookmarks, topic progress, 30-question BCS/EEE practice,
  autosave/resume, wrong-question practice and actual-result analytics.
- Database-authoritative deadlines, row-locked answer/submission writes,
  idempotent scoring, scheduled exam uniqueness and result/key embargo.
- Admin add/edit/verification, validated CSV preview/import, scheduling and basic audit rows.
- Actual per-exam leaderboard, downloadable routine/result PDF, serverless Chromium bundle.
- Database cron finalizer (requires running migration 003); requests also catch up overdue attempts.

### Tests actually run

- `npm run test:cloud`: **32 PostgreSQL-engine checks passed** using PGlite.
- `JOBMASTER_BACKEND=supabase npm run build`: **PASS**.
- Historical local adapter: 43 integration checks + student/admin browser suites;
  rerun when changing local features. See `TEST-RESULTS.md` for current execution records.

**Not yet verified:** the user's hosted Supabase Auth/email/network settings, pg_cron job
execution, real Vercel deployment and production PDF execution. These require project
configuration and live smoke tests. No cloud deployment has been claimed complete.

### Content / feature limits

Sixty AI-assisted practice questions (30 per track), explicitly editorial-review-pending;
not verified past papers. The study explorer is an editorial outline, not a complete
official BPSC syllabus. Full source-verified coverage, adaptive multi-week planning,
spaced repetition, seven additional PDF types, period leaderboards, XLSX import,
email recovery/MFA UI, advanced admin audit UI and independent security/load audits
remain incomplete. Do not present this as a production-complete examination service.
Cloud CSV requests are capped at 3 MB to fit serverless request constraints.

## Local preview

```sh
npm ci
npx playwright install --with-deps chromium
# JOBMASTER_BACKEND defaults to local when unset
npm run build
npm start -- --hostname 0.0.0.0
```

Local SQLite is for a persistent Node host, not Vercel's ephemeral disk. Local users,
passwords and owner setup codes do not migrate automatically into Supabase.
For the older local architecture/setup instructions see `LOCAL-README.md` (cloud
support was added after that document; old statements about absent cloud code are historical).

## Structure

- `src/app/api/*` — runtime backend routing
- `src/lib/cloud/` — Supabase Auth/RPC/PDF implementation (no SQLite imports)
- `src/lib/local/` — original local API implementation
- `src/lib/store.ts` — local SQLite schema and scoring
- `supabase/migrations/001_cloud_backend.sql` — cloud schema/RLS/RPC
- `supabase/migrations/002_practice_seed.sql` — 60 labeled fixtures and topic IDs
- `supabase/migrations/003_expiry_cron.sql` — durable DB scheduler
- `deployment/STEP-5-SUPABASE.sql` — combined schema + seed for one copy/paste
- `tests/cloud-sql.mjs` — PostgreSQL permission/flow checks, no hosted credentials

`npm run seed:sql` regenerates the combined SQL from the maintained content fixtures.
No fake accounts, results, passwords or administrator credentials are included.
