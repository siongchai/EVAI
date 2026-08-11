# Phase 5 — Ship (web + iOS + Android)

Production deploy checklist for Vercel (web), EAS (iOS/Android), Supabase Auth URLs, and privacy.

## Prerequisites

- Phases 0–4 complete and verified locally
- Supabase project with all migrations applied (profiles, cars, sessions, session-photos, grants)
- OpenAI or Anthropic key for production Edge Function

## 1. Production AI (required for Capture on web)

Do **not** ship `EXPO_PUBLIC_OPENAI_API_KEY` / Anthropic keys in the web bundle.

```bash
# Install Supabase CLI if needed, then from repo root:
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy extract-session
# OpenAI OR Anthropic (auto-detected by key prefix):
supabase secrets set OPENAI_API_KEY=sk-...
# or:
# supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

Set client env everywhere (Vercel + EAS):

```bash
EXPO_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=eyJ...
EXPO_PUBLIC_USE_EDGE_EXTRACTION=1
```

## 2. Supabase Auth URLs

In Supabase → **Authentication** → **URL configuration**:

- **Site URL:** your Vercel production URL (e.g. `https://evai.vercel.app`)
- **Redirect URLs:** add
  - `https://evai.vercel.app/**`
  - `evai://**` (native deep link scheme)
  - local `http://localhost:8081/**` for development

Re-enable **Confirm email** before public launch if you disabled it for Phase 0 testing.

## 3. Deploy web to Vercel

1. Import [siongchai/EVAI](https://github.com/siongchai/EVAI) in Vercel.
2. **Root Directory:** `apps/mobile`
3. Framework: Other (uses `apps/mobile/vercel.json`)
4. Add env vars from section 1.
5. Deploy.

Verify:

- Sign up / sign in
- Home + Analytics load
- Sessions CRUD / Excel
- Capture works via Edge Function (not local proxy)
- Privacy page at `/privacy`

Local production export check:

```bash
cd apps/mobile
npm run export:web
```

## 4. Native builds with EAS

```bash
npm i -g eas-cli
cd apps/mobile
eas login
eas init   # writes real projectId into app.json → extra.eas.projectId
```

Set secrets for builds:

```bash
eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_URL --value https://xxxx.supabase.co
eas secret:create --scope project --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value eyJ...
eas secret:create --scope project --name EXPO_PUBLIC_USE_EDGE_EXTRACTION --value 1
```

Preview builds (internal testing):

```bash
eas build --platform ios --profile preview
eas build --platform android --profile preview
```

Production:

```bash
eas build --platform all --profile production
eas submit --platform ios --profile production
eas submit --platform android --profile production
```

Update `eas.json` → `submit.production.ios.ascAppId` with your App Store Connect app id before iOS submit.

### Store listing notes

- **Bundle ID:** `sg.tsc.EVAi2` (iOS) / `sg.tsc.evai2` (Android)
- **Privacy policy URL:** host the in-app Privacy page publicly, e.g. `https://YOUR_VERCEL_URL/privacy`
- Permissions copy is in `app.json` (camera, photo library, documents)

## 5. Privacy & compliance

- In-app Privacy screen: `/(app)/privacy` (also linked from Account)
- iOS privacy manifests / usage strings configured in `app.json`
- Android media/camera permissions declared in `app.json`

Before App Store review, replace the contact line in `app/(app)/privacy.tsx` with a real support email if needed.

## Phase 5 done when

- [ ] Edge Function deployed + secrets set
- [ ] Vercel production web app live with Supabase Auth redirects
- [ ] Capture works on production web without browser AI keys
- [ ] EAS project initialized (`projectId` not a placeholder)
- [ ] iOS and/or Android preview build installed on a device
- [ ] Privacy page reachable from Account and as a public URL

## Next: Phase 6 (optional)

Widgets, Apple Intelligence path, Swift→cloud migrate helper, push notifications, richer in-app AI provider settings.
