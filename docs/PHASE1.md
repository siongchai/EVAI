# Phase 1 — Accounts + cars

Profile management, avatar upload, password change, account delete, and cars CRUD on Supabase.

## Prerequisites

- Phase 0 complete ([PHASE0.md](PHASE0.md))
- App already signs in against your Supabase project

## 1. Run the Phase 1 migration

1. Open Supabase → **SQL** → **SQL Editor** → New query.
2. Paste and run these in order:
   - `supabase/migrations/20260810100000_cars_and_storage.sql`
   - `supabase/migrations/20260810110000_cars_grants.sql`
3. Click **Run** (safe to re-run; policies are dropped/recreated).
4. Confirm:
   - **Table Editor** → `cars` exists
   - **Storage** → buckets `avatars` and `cars` exist

If saving a car fails with `permission denied for table cars`, run the grants migration (`..._cars_grants.sql`) — the table can exist while API roles still lack privileges.

## 2. Restart the app

```bash
cd apps/mobile
npm install
npm run web
```

Stop/restart Expo if it was already running so new routes load.

## 3. Verify

Signed in as your test user:

1. **Home** → shows name/email and car count; links to Account and Cars.
2. **Account**
   - Edit full name → Save
   - Tap avatar → upload photo
   - Change password → sign out → sign in with new password
3. **Cars**
   - Add car (make + model required)
   - Optional photo, primary flag, battery/odometer fields
   - Edit and delete a car
4. In Supabase, confirm rows in `cars` and files under Storage folders named with your user id.

## What’s included

| Area | Details |
|------|---------|
| Profile | Name + avatar (`profiles` + `avatars` bucket) |
| Security | Password update, sign out, delete account RPC |
| Cars | Full CRUD matching legacy Swift `Car` fields |
| RLS | Users only access their own rows/files |

## Phase 1 done when

- [ ] Migration applied
- [ ] Profile name + avatar work
- [ ] Password change works
- [ ] Cars add/edit/delete work on web
- [ ] Same flows work on iOS or Android simulator/device (optional for Phase 1)

## Next: Phase 2

See [PHASE2.md](PHASE2.md) — charging sessions sync (list, detail, create/edit, Excel import/export).
