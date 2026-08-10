# EVAi

AI-powered EV charging analytics.

## Apps

| Path | Status |
|------|--------|
| `apps/mobile` | Expo client (web + iOS + Android) — active development |
| `EVAi2` | Legacy SwiftUI iOS app — product reference |
| `supabase/` | Database migrations |

## Quick start (Phase 0)

See [docs/PHASE0.md](docs/PHASE0.md).

```bash
cd apps/mobile
cp .env.example .env   # add Supabase URL + anon key
npm install
npm run web
```

## Stack

- **Client:** Expo + Expo Router
- **Auth / DB:** Supabase
- **Web host:** Vercel
- **Native builds:** EAS
