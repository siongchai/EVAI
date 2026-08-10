# Phase 0 — Foundations

Expo app for web + iOS + Android, Supabase Auth, Vercel web deploy prep.

## What’s in the repo

| Path | Purpose |
|------|---------|
| `apps/mobile` | Expo (Router) client |
| `supabase/migrations` | SQL for `profiles` + RLS |
| `EVAi2` | Legacy Swift iOS app (reference) |

## 1. Create Supabase project

1. Go to [https://supabase.com](https://supabase.com) → New project.
2. Auth → Providers → enable **Email**.
3. For local/dev speed, Auth → Providers → Email → disable **Confirm email** (re-enable before production).
4. SQL Editor → paste and run `supabase/migrations/20260810000000_profiles.sql`
   (includes grants for `authenticated` / `anon`).
5. Project Settings → API → copy **Project URL** and **anon public** key.

## 2. Configure the Expo app

```bash
cd apps/mobile
cp .env.example .env
```

Fill in:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJ...
```

## 3. Run locally

```bash
cd apps/mobile
npm install
npm run web      # browser
npm run ios      # iOS simulator (macOS)
npm run android  # Android emulator
```

Without `.env`, the app opens the **Setup** screen instead of auth.

## 4. Verify auth

1. Open the app → Sign up with email/password + name.
2. Confirm a row appears in Supabase Table Editor → `profiles`.
3. Sign out, sign in again.
4. Home shell should show email + profile name.

## 5. Deploy web to Vercel

1. Import [siongchai/EVAI](https://github.com/siongchai/EVAI) in Vercel.
2. Set **Root Directory** to `apps/mobile`.
3. Framework: Other (uses `vercel.json`).
4. Add env vars:
   - `EXPO_PUBLIC_SUPABASE_URL`
   - `EXPO_PUBLIC_SUPABASE_ANON_KEY`
5. Deploy. Build runs `npm run export:web` → `dist`.

In Supabase Auth → URL configuration, add your Vercel URL to **Site URL** and **Redirect URLs**.

## 6. Native builds (optional in Phase 0)

```bash
npm i -g eas-cli
cd apps/mobile
eas login
eas init   # replaces projectId in app.json
eas build --platform ios --profile preview
eas build --platform android --profile preview
```

## Phase 0 done when

- [ ] Supabase project exists with Email auth + `profiles` migration
- [ ] Sign up / sign in works on web
- [ ] Same flow works on iOS or Android simulator/device
- [ ] Web deploy succeeds on Vercel (or local `npm run export:web` succeeds)

## Next: Phase 1

See [PHASE1.md](PHASE1.md) — account management, avatar upload, cars CRUD.
