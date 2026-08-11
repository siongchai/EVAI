import {
  currentYearMonth,
  monthlyMetrics,
} from '@/lib/analytics/metrics';
import { formatKwh, formatSgd, monthLabel } from '@/lib/analytics/format';
import type { ChargingSession } from '@/types/database';
import LastSessionWidget from '@/widgets/LastSessionWidget';
import MonthlySummaryWidget from '@/widgets/MonthlySummaryWidget';

export type WidgetSnapshot = {
  monthLabel: string;
  costLabel: string;
  energyLabel: string;
  lastLocation: string;
  lastCostLabel: string;
  lastEnergyLabel: string;
  lastDateLabel: string;
};

export function buildWidgetSnapshot(
  sessions: ChargingSession[],
  now = new Date(),
): WidgetSnapshot {
  const { year, month } = currentYearMonth(now);
  const metrics = monthlyMetrics(sessions, year, month);
  const last = [...sessions].sort(
    (a, b) =>
      new Date(b.start_date).getTime() - new Date(a.start_date).getTime(),
  )[0];

  const lastDate = last ? new Date(last.start_date) : null;

  return {
    monthLabel: monthLabel(year, month),
    costLabel: formatSgd(metrics.totalCost),
    energyLabel: formatKwh(metrics.totalEnergy),
    lastLocation: last?.charging_location?.trim() || 'No sessions yet',
    lastCostLabel: formatSgd(last?.amount_sgd ?? 0),
    lastEnergyLabel: formatKwh(last?.energy_kwh ?? 0),
    lastDateLabel: lastDate
      ? lastDate.toLocaleDateString(undefined, {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
        })
      : '—',
  };
}

/** Push latest session analytics into iOS home-screen widgets (no-op elsewhere). */
export function syncHomeScreenWidgets(sessions: ChargingSession[]): void {
  try {
    const snapshot = buildWidgetSnapshot(sessions);
    MonthlySummaryWidget.updateSnapshot({
      monthLabel: snapshot.monthLabel,
      costLabel: snapshot.costLabel,
      energyLabel: snapshot.energyLabel,
    });
    LastSessionWidget.updateSnapshot({
      location: snapshot.lastLocation,
      costLabel: snapshot.lastCostLabel,
      energyLabel: snapshot.lastEnergyLabel,
      dateLabel: snapshot.lastDateLabel,
    });
  } catch (error) {
    console.warn('Widget sync skipped', error);
  }
}
