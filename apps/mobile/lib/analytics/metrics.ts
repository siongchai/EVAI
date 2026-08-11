import type {
  DailyCostPoint,
  MonthForecast,
  MonthlyMetrics,
  MonthlyTrendPoint,
  NetworkBreakdownItem,
} from '@/lib/analytics/types';
import { shortMonthLabel } from '@/lib/analytics/format';
import type { ChargingSession } from '@/types/database';

export function currentYearMonth(date = new Date()): { year: number; month: number } {
  return { year: date.getFullYear(), month: date.getMonth() + 1 };
}

export function shiftYearMonth(
  year: number,
  month: number,
  delta: number,
): { year: number; month: number } {
  const d = new Date(year, month - 1 + delta, 1);
  return { year: d.getFullYear(), month: d.getMonth() + 1 };
}

export function sessionsInMonth(
  sessions: ChargingSession[],
  year: number,
  month: number,
): ChargingSession[] {
  return sessions.filter((session) => {
    const date = new Date(session.start_date);
    return (
      !Number.isNaN(date.getTime()) &&
      date.getFullYear() === year &&
      date.getMonth() + 1 === month
    );
  });
}

export function monthlyMetrics(
  sessions: ChargingSession[],
  year: number,
  month: number,
): MonthlyMetrics {
  const inMonth = sessionsInMonth(sessions, year, month);
  const totalCost = inMonth.reduce((sum, s) => sum + (s.amount_sgd || 0), 0);
  const totalEnergy = inMonth.reduce((sum, s) => sum + (s.energy_kwh || 0), 0);
  return {
    year,
    month,
    totalCost,
    totalEnergy,
    sessionCount: inMonth.length,
    averageCostPerKWh: totalEnergy > 0 ? totalCost / totalEnergy : 0,
  };
}

export function dailyCostPoints(
  sessions: ChargingSession[],
  year: number,
  month: number,
): DailyCostPoint[] {
  const daysInMonth = new Date(year, month, 0).getDate();
  const totals = new Array<number>(daysInMonth).fill(0);

  for (const session of sessionsInMonth(sessions, year, month)) {
    const date = new Date(session.start_date);
    const day = date.getDate();
    if (day >= 1 && day <= daysInMonth) {
      totals[day - 1]! += session.amount_sgd || 0;
    }
  }

  return totals.map((cost, index) => ({
    day: index + 1,
    date: new Date(year, month - 1, index + 1),
    cost,
  }));
}

export function monthlyTrendPoints(
  sessions: ChargingSession[],
  monthsBack = 6,
  end: { year: number; month: number } = currentYearMonth(),
): MonthlyTrendPoint[] {
  const points: MonthlyTrendPoint[] = [];
  for (let i = monthsBack - 1; i >= 0; i -= 1) {
    const { year, month } = shiftYearMonth(end.year, end.month, -i);
    const metrics = monthlyMetrics(sessions, year, month);
    points.push({
      year,
      month,
      label: shortMonthLabel(year, month),
      totalCost: metrics.totalCost,
      totalEnergy: metrics.totalEnergy,
      sessionCount: metrics.sessionCount,
    });
  }
  return points;
}

export function networkBreakdown(
  sessions: ChargingSession[],
  year: number,
  month: number,
): NetworkBreakdownItem[] {
  const map = new Map<string, NetworkBreakdownItem>();

  for (const session of sessionsInMonth(sessions, year, month)) {
    const network = session.charging_network.trim() || 'Unknown';
    const existing = map.get(network) ?? {
      network,
      sessionCount: 0,
      totalCost: 0,
      totalEnergy: 0,
      averageCostPerKWh: 0,
    };
    existing.sessionCount += 1;
    existing.totalCost += session.amount_sgd || 0;
    existing.totalEnergy += session.energy_kwh || 0;
    map.set(network, existing);
  }

  return [...map.values()]
    .map((item) => ({
      ...item,
      averageCostPerKWh:
        item.totalEnergy > 0 ? item.totalCost / item.totalEnergy : 0,
    }))
    .sort((a, b) => b.totalCost - a.totalCost);
}

export function monthForecast(
  sessions: ChargingSession[],
  year: number,
  month: number,
  now = new Date(),
): MonthForecast {
  const current = monthlyMetrics(sessions, year, month);
  const previous = shiftYearMonth(year, month, -1);
  const previousMetrics = monthlyMetrics(
    sessions,
    previous.year,
    previous.month,
  );

  const isCurrentMonth =
    now.getFullYear() === year && now.getMonth() + 1 === month;
  const dayOfMonth = isCurrentMonth ? Math.max(1, now.getDate()) : new Date(year, month, 0).getDate();
  const daysInMonth = new Date(year, month, 0).getDate();
  const scale = daysInMonth / dayOfMonth;

  const projectedCost = current.totalCost * scale;
  const previousCost = previousMetrics.totalCost;
  let direction: MonthForecast['direction'] = 'stable';
  if (previousCost > 0) {
    if (projectedCost > previousCost * 1.05) direction = 'up';
    else if (projectedCost < previousCost * 0.95) direction = 'down';
  }

  return {
    projectedCost,
    projectedEnergy: current.totalEnergy * scale,
    projectedCount: Math.round(current.sessionCount * scale),
    direction,
    previousMonthCost: previousCost,
  };
}

export function recentSessionsInMonth(
  sessions: ChargingSession[],
  year: number,
  month: number,
  limit = 3,
): ChargingSession[] {
  return [...sessionsInMonth(sessions, year, month)]
    .sort(
      (a, b) =>
        new Date(b.start_date).getTime() - new Date(a.start_date).getTime(),
    )
    .slice(0, limit);
}

export function averageCostPerKwhForHourPredicate(
  sessions: ChargingSession[],
  year: number,
  month: number,
  predicate: (hour: number) => boolean,
): number {
  let cost = 0;
  let energy = 0;
  for (const session of sessionsInMonth(sessions, year, month)) {
    const hour = new Date(session.start_date).getHours();
    if (!predicate(hour)) continue;
    cost += session.amount_sgd || 0;
    energy += session.energy_kwh || 0;
  }
  return energy > 0 ? cost / energy : 0;
}
