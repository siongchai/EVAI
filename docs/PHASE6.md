# Phase 6 — AI settings + legacy migrate

Optional follow-up after Phase 5 ship readiness. This slice covers the highest-value cross-platform items:

1. **In-app AI provider settings**
2. **Swift → cloud migrate helper** (Excel + JSON)

Deferred for later slices: home-screen widgets, push notifications, Apple Intelligence native bridge.

## Prerequisites

- Phases 0–4 verified locally
- Phase 5 shipping config recommended (Edge Function for production Capture)

## 1. AI Settings

Screen: `Account → AI Settings` (`/(app)/account/ai-settings`)

- Preferred provider: **OpenAI** or **Claude**
- Optional on-device keys via Secure Store (native) / AsyncStorage (web)
- Capture shows the active engine and links back to AI Settings
- Edge Function + local extract proxy accept `preferredProvider` when both server keys exist

### Client resolution order

1. Edge Function when `EXPO_PUBLIC_USE_EDGE_EXTRACTION=1`
2. Web → local extract proxy (`npm run extract-proxy`)
3. Native → preferred stored/env key, then the other provider, then proxy

Do **not** ship browser AI keys in production — use the Edge Function.

## 2. Migrate from legacy EVAi

Screen: `Account → Migrate from EVAi (legacy)` (`/(app)/account/migrate`)

From the original Swift app, export:

- **Excel** (same workbook format as Sessions → Import), or
- **JSON** (`ExportService.exportJSON` → `{ sessions: [...] }` camelCase)

Then in the Expo app:

1. Open Migrate
2. Choose the file
3. Preview insert/update/skip counts
4. Import into Supabase (linked to your primary car when present)

Not migrated: local photos, Keychain AI keys, widgets, SwiftData profile UUID.

Sample JSON for smoke tests: `apps/mobile/lib/migrate/swiftJson.test-data.json`

## Phase 6 done when

- [ ] AI Settings saves preferred provider + keys
- [ ] Capture status reflects Edge / proxy / OpenAI / Claude
- [ ] Preferred provider is honored by proxy/Edge when both secrets exist
- [ ] Excel migrate preview + import works
- [ ] Swift JSON migrate preview + import works (duplicates skipped)

## Later (Phase 6+)

- iOS widgets (`expo-widgets`) mirroring Monthly Summary / Last Session
- Push tokens + monthly summary notifications
- Apple Intelligence Expo Module (iOS 26+, OCR-fusion dependent)
