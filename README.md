# EVAi

AI-powered EV charging analytics.

## Apps

| Path | Status |
|------|--------|
| `apps/mobile` | Expo client (web + iOS + Android) — active development |
| `EVAi2` | Legacy SwiftUI iOS app — product reference |
| `supabase/` | Database migrations |

## Quick start

1. Phase 0 setup: [docs/PHASE0.md](docs/PHASE0.md) (Supabase Auth + profiles)
2. Phase 1 setup: [docs/PHASE1.md](docs/PHASE1.md) (account + cars)

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
