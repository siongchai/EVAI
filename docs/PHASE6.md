# Phase 6 — Polish: AI settings, migrate, widgets, notifications

Optional follow-up after Phase 5 ship readiness.

## Delivered

### 6.1 AI Settings
Screen: `Account → AI Settings` (`/(app)/account/ai-settings`)

- Preferred provider: **OpenAI** or **Claude**
- Optional on-device keys via Secure Store (native) / AsyncStorage (web)
- Capture shows the active engine and links back to AI Settings
- Edge Function + local extract proxy accept `preferredProvider` when both server keys exist

### 6.2 Migrate from legacy EVAi
Screen: `Account → Migrate from EVAi (legacy)` (`/(app)/account/migrate`)

Import Excel (`.xlsx`) or Swift JSON (`ExportService.exportJSON`) into Supabase.
Sample: `apps/mobile/lib/migrate/swiftJson.test-data.json`

### 6.3 iOS home-screen widgets
Uses `expo-widgets` (dev/EAS builds — not Expo Go):

| Widget | Kind | Shows |
|--------|------|--------|
| Monthly Summary | `MonthlySummaryWidget` | Month label, cost (SGD), energy |
| Last Session | `LastSessionWidget` | Location, cost, energy, date |

- App Group: `group.sg.tsc.EVAi2` (same as legacy Swift widgets)
- Synced from Home load and after session create/update/delete/import
- Web/Android use no-op stubs so `ship:check` still passes

### 6.4 Notifications
Screen: `Account → Notifications`

- Local **monthly summary** reminder (1st of month, 09:00) on iOS/Android
- Optional Expo push token stored on `profiles.expo_push_token` when EAS `projectId` is real
- Migration: `supabase/migrations/20260811000000_profile_push_tokens.sql`

## Prerequisites

- Phases 0–5 on `main`
- Apply the push-token migration in Supabase SQL editor / CLI
- For widgets + push on device: `eas init` (real projectId) + preview/dev build

## Phase 6 done when

- [ ] AI Settings saves preferred provider + keys
- [ ] Capture status reflects Edge / proxy / OpenAI / Claude
- [ ] Excel + Swift JSON migrate work
- [ ] Widgets appear in iOS gallery after a new native build
- [ ] Home/session edits refresh widget snapshots
- [ ] Notifications toggle schedules/cancels monthly local reminder
- [ ] Push-token migration applied (optional until you want remote push)

## Still deferred

- Apple Intelligence Expo Module (iOS 26+, OCR-fusion dependent)
- Server-driven remote push campaigns (token storage is ready; Edge sender not required yet)
