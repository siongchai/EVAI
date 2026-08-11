# Phase 3 — Capture / AI extraction

Photo capture → OpenAI vision extraction → review form → save `charging_sessions`.

## Prerequisites

- Phase 2 complete ([PHASE2.md](PHASE2.md))
- OpenAI API key (GPT-4o vision)

## 1. Run the storage migration

1. Supabase → **SQL Editor**
2. Run `supabase/migrations/20260810300000_session_photos.sql`
3. Confirm **Storage** → bucket `session-photos`

## 2. Configure AI (pick one)

### Option A — Local web (recommended for testing)

Browsers cannot call OpenAI directly (CORS → “Failed to fetch”). Use the local proxy:

1. In `apps/mobile/.env`:

```bash
# OpenAI OR Anthropic (sk-ant-...) — proxy auto-detects by key prefix
EXPO_PUBLIC_OPENAI_API_KEY=sk-...
# or:
# EXPO_PUBLIC_ANTHROPIC_API_KEY=sk-ant-...
EXPO_PUBLIC_EXTRACT_PROXY_URL=http://localhost:8787
EXPO_PUBLIC_USE_EDGE_EXTRACTION=0
```

2. In one terminal:

```bash
cd apps/mobile
npm run extract-proxy
```

3. In another terminal: `npm run web`

The proxy reads your key from `.env` and calls OpenAI or Claude server-side
(`sk-ant-...` → Claude; otherwise OpenAI).

### Option B — Supabase Edge Function (recommended)

```bash
# from repo root, with Supabase CLI logged in
supabase functions deploy extract-session
supabase secrets set OPENAI_API_KEY=sk-...
```

Then in `apps/mobile/.env`:

```bash
EXPO_PUBLIC_USE_EDGE_EXTRACTION=1
# optional fallback:
# EXPO_PUBLIC_OPENAI_API_KEY=
```

Function source: `supabase/functions/extract-session/index.ts`.

## 3. Run the app

```bash
cd apps/mobile
npm install
npm run web
```

## 4. Verify

1. **Home → Capture** (or **Sessions → Capture with AI**)
2. Choose 1–5 photos (dashboard before/after + app/receipt recommended)
3. **Extract with AI** → review prefilled form + confidence
4. Edit if needed → **Save session**
5. Confirm row in Supabase `charging_sessions` (`raw_ai_response`, `source_image_ids`, `extraction_confidence`)
6. Photos appear under Storage → `session-photos` / `{user_id}/captures/...`

## What’s included

| Area | Details |
|------|---------|
| Capture UI | Multi-image picker, extract, review via `SessionForm` |
| Prompt / schema | Ported from legacy `SessionExtractionParser` |
| AI call | Edge Function **or** direct OpenAI (env key) |
| Save | Reuses Phase 2 `createSession` + photo upload |

## Deferred

OCR fusion, Apple Intelligence, PDF import, offline queue, Claude provider UI.

## Phase 3 done when

- [ ] `session-photos` bucket migrated
- [ ] AI key or Edge Function configured
- [ ] Capture → extract → review → save works on web
- [ ] Session stores confidence + raw AI JSON (+ image paths when upload succeeds)

## Next: Phase 4

Home dashboard + analytics charts/insights.
