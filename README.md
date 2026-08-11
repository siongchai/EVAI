# EVAi

AI-powered EV charging analytics for **web, iOS, and Android**.

## Apps

| Path | Status |
|------|--------|
| `apps/mobile` | Expo client (web + iOS + Android) — active product |
| `EVAi2` | Legacy SwiftUI iOS app — product reference |
| `supabase/` | Database migrations + Edge Functions |

## Docs by phase

1. [Phase 0](docs/PHASE0.md) — Auth + profiles  
2. [Phase 1](docs/PHASE1.md) — Account + cars  
3. [Phase 2](docs/PHASE2.md) — Sessions + Excel  
4. [Phase 3](docs/PHASE3.md) — Capture / AI extraction  
5. [Phase 4](docs/PHASE4.md) — Home + Analytics  
6. [Phase 5](docs/PHASE5.md) — Ship (Vercel + EAS)

## Local quick start

```bash
cd apps/mobile
cp .env.example .env   # add Supabase URL + anon key (+ AI key for capture)
npm install
npm run web
```

For local Capture on web, also run:

```bash
npm run extract-proxy
```

## Production

See [docs/PHASE5.md](docs/PHASE5.md):

- Web → Vercel (`apps/mobile`)
- Native → EAS Build / Submit
- AI → Supabase Edge Function `extract-session`

## Stack

- **Client:** Expo + Expo Router
- **Auth / DB / Storage:** Supabase
- **Web host:** Vercel
- **Native builds:** EAS
