# EVAi

AI-powered EV charging analytics.

## Apps

| Path | Status |
|------|--------|
| `apps/mobile` | Expo client (web + iOS + Android) — active development |
| `EVAi2` | Legacy SwiftUI iOS app — product reference |
| `supabase/` | Database migrations |

## Quick start

1. Phase 0: [docs/PHASE0.md](docs/PHASE0.md) — Auth + profiles  
2. Phase 1: [docs/PHASE1.md](docs/PHASE1.md) — Account + cars  
3. Phase 2: [docs/PHASE2.md](docs/PHASE2.md) — Sessions + Excel  
4. Phase 3: [docs/PHASE3.md](docs/PHASE3.md) — Capture / AI extraction
3. Phase 2 setup: [docs/PHASE2.md](docs/PHASE2.md) (charging sessions + Excel)

```bash
cd apps/mobile
cp .env.example .env   # add Supabase URL + anon key
npm install
npm run web
```

## Stack

- **Client:** Expo + Expo Router
- **Auth / DB / Storage:** Supabase
- **Web host:** Vercel
- **Native builds:** EAS
