# Phase 4 — Home + Analytics

Client-side monthly metrics, cost trends, network breakdown, forecast, and rule-based insights from `charging_sessions`.

## Prerequisites

- Phase 2+ with sessions data ([PHASE2.md](PHASE2.md) / [PHASE3.md](PHASE3.md))
- No new Supabase migration required

## 1. Run the app

```bash
cd apps/mobile
npm install
npm run web
```

## 2. Verify

1. **Home**
   - Month picker (‹ ›)
   - Four metrics: total cost, energy, sessions, avg $/kWh
   - Daily cost bars for the month
   - 1–2 insights
   - Recent sessions (up to 3) + chips to Analytics / Capture / Sessions / Cars / Account
2. **Analytics**
   - Same month picker + metrics
   - Month-end forecast card
   - Last 6 months cost bars
   - Network breakdown for the month
   - Up to 4 insights
3. Change month and confirm numbers update
4. Capture/import a session, return to Home — metrics refresh

## What’s included

| Area | Details |
|------|---------|
| Metrics | Port of Swift `monthlyMetrics` |
| Daily / monthly charts | View-based bar charts (no native chart dep) |
| Networks | Cost/energy/session breakdown |
| Forecast | Linear day-of-month scale vs prior month |
| Insights | MoM spend, late-night savings, cheapest network, forecast |

## Deferred

Hourly heatmap, SOC/battery charts, quarterly trends, full InsightEngine suite, analytics cache.

## Phase 4 done when

- [ ] Home shows month metrics + daily cost + recent sessions
- [ ] Analytics shows forecast, 6-month trend, networks
- [ ] Insights appear when enough session data exists

## Next: Phase 5

Ship — Vercel web deploy, EAS iOS/Android builds, store/privacy polish.
