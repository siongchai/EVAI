import {
  averageCostPerKwhForHourPredicate,
  monthForecast,
  monthlyMetrics,
  networkBreakdown,
  shiftYearMonth,
} from '@/lib/analytics/metrics';
import { formatCostPerKwh, formatSgd } from '@/lib/analytics/format';
import type { Insight } from '@/lib/analytics/types';
import type { ChargingSession } from '@/types/database';

export function buildInsights(
  sessions: ChargingSession[],
  year: number,
  month: number,
  limit = 4,
): Insight[] {
  const insights: Insight[] = [];
  const current = monthlyMetrics(sessions, year, month);
  const previousKey = shiftYearMonth(year, month, -1);
  const previous = monthlyMetrics(
    sessions,
    previousKey.year,
    previousKey.month,
  );

  if (previous.totalCost > 0 && current.sessionCount > 0) {
    const delta =
      ((current.totalCost - previous.totalCost) / previous.totalCost) * 100;
    if (Math.abs(delta) < 3) {
      insights.push({
        id: 'mom-stable',
        message: `Spending is roughly flat vs last month (${formatSgd(current.totalCost)} so far).`,
      });
    } else if (delta > 0) {
      insights.push({
        id: 'mom-up',
        message: `Spending is up ${delta.toFixed(0)}% vs last month.`,
      });
    } else {
      insights.push({
        id: 'mom-down',
        message: `Spending is down ${Math.abs(delta).toFixed(0)}% vs last month.`,
      });
    }
  }

  const lateAvg = averageCostPerKwhForHourPredicate(
    sessions,
    year,
    month,
    (hour) => hour >= 22,
  );
  const regularAvg = averageCostPerKwhForHourPredicate(
    sessions,
    year,
    month,
    (hour) => hour < 22,
  );
  if (lateAvg > 0 && regularAvg > lateAvg) {
    const savings = ((regularAvg - lateAvg) / regularAvg) * 100;
    if (savings >= 5) {
      insights.push({
        id: 'late-night',
        message: `Late-night charging averages ${formatCostPerKwh(lateAvg)} — about ${savings.toFixed(0)}% cheaper than earlier sessions.`,
      });
    }
  }

  const networks = networkBreakdown(sessions, year, month).filter(
    (item) => item.sessionCount >= 2 && item.averageCostPerKWh > 0,
  );
  if (networks.length > 0) {
    const cheapest = [...networks].sort(
      (a, b) => a.averageCostPerKWh - b.averageCostPerKWh,
    )[0]!;
    insights.push({
      id: 'cheapest-network',
      message: `${cheapest.network} is your cheapest network this month at ${formatCostPerKwh(cheapest.averageCostPerKWh)}.`,
    });
  }

  const forecast = monthForecast(sessions, year, month);
  if (current.sessionCount > 0) {
    const trend =
      forecast.direction === 'up'
        ? 'higher'
        : forecast.direction === 'down'
          ? 'lower'
          : 'similar';
    insights.push({
      id: 'forecast',
      message: `On pace for about ${formatSgd(forecast.projectedCost)} this month (${trend} than last month).`,
    });
  }

  if (insights.length === 0 && current.averageCostPerKWh > 0) {
    insights.push({
      id: 'avg-rate',
      message: `Your average rate this month is ${formatCostPerKwh(current.averageCostPerKWh)} across ${current.sessionCount} sessions.`,
    });
  }

  if (insights.length === 0) {
    insights.push({
      id: 'empty',
      message: 'Add or capture charging sessions to unlock insights.',
    });
  }

  return insights.slice(0, limit);
}
