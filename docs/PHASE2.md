# Phase 2 — Charging sessions

List, create, edit, and delete charging sessions on Supabase, plus Excel import/export matching the legacy EV charging log layout.

## Prerequisites

- Phase 1 complete ([PHASE1.md](PHASE1.md))
- At least one signed-in user (cars optional but recommended for import car label)

## 1. Run the Phase 2 migration

1. Open Supabase → **SQL** → **SQL Editor** → New query.
2. Paste and run these in order:
   - `supabase/migrations/20260810200000_charging_sessions.sql`
   - `supabase/migrations/20260810210000_charging_sessions_grants.sql`
3. Click **Run** (safe to re-run; policies are dropped/recreated).
4. Confirm **Table Editor** → `charging_sessions` exists.

If saving a session fails with `permission denied for table charging_sessions`, run the grants migration.

## 2. Restart the app

```bash
cd apps/mobile
npm install
npm run web
```

Stop/restart Expo if it was already running so new routes load.

## 3. Verify

Signed in as your test user:

1. **Home** → shows session count; link to **Sessions**.
2. **Sessions**
   - Add session (location + start/end required)
   - Edit fields (network, SOC, energy, cost, charger type, linked car)
   - Delete a session
3. **Import Excel**
   - Use a log like `EV Charging logs 4 2.xlsx` (columns A–P)
   - Confirm rows appear; re-import updates matching rows (reference / row / fingerprint)
4. **Export Excel** → downloads/shares an `.xlsx` in the same layout
5. In Supabase, confirm rows in `charging_sessions`

## What’s included

| Area | Details |
|------|---------|
| Sessions CRUD | Fields aligned with legacy Swift `ChargingSession` |
| Car link | Optional `car_id` + `car_model` label |
| Excel import | Legacy charging-log columns; Singapore wall-clock serials |
| Excel export | Same header layout for round-trip |
| RLS | Users only access their own sessions |

## Phase 2 done when

- [ ] Migration applied
- [ ] Session create/edit/delete works on web
- [ ] Excel import creates/updates sessions
- [ ] Excel export downloads a usable workbook
- [ ] Same flows work on iOS or Android (optional for Phase 2)

## Next: Phase 3

Receipt/capture extraction (photo → session draft).
