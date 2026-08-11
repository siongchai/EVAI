import { useCallback, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack, useFocusEffect } from 'expo-router';

import { BarChart } from '@/components/analytics/BarChart';
import { InsightList } from '@/components/analytics/InsightList';
import { MetricGrid } from '@/components/analytics/MetricGrid';
import { MonthPicker } from '@/components/analytics/MonthPicker';
import { ErrorText } from '@/components/ui';
import { colors } from '@/constants/theme';
import { buildInsights } from '@/lib/analytics/insights';
import {
  currentYearMonth,
  monthForecast,
  monthlyMetrics,
  monthlyTrendPoints,
  networkBreakdown,
} from '@/lib/analytics/metrics';
import {
  formatCostPerKwh,
  formatKwh,
  formatSgd,
} from '@/lib/analytics/format';
import { listSessions } from '@/lib/sessions';
import { useAuth } from '@/providers/AuthProvider';
import type { ChargingSession } from '@/types/database';

export default function AnalyticsScreen() {
  const { user } = useAuth();
  const initial = currentYearMonth();
  const [year, setYear] = useState(initial.year);
  const [month, setMonth] = useState(initial.month);
  const [sessions, setSessions] = useState<ChargingSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      setSessions(await listSessions(user.id));
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Failed to load analytics.',
      );
    } finally {
      setLoading(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  const metrics = useMemo(
    () => monthlyMetrics(sessions, year, month),
    [sessions, year, month],
  );
  const networks = useMemo(
    () => networkBreakdown(sessions, year, month),
    [sessions, year, month],
  );
  const trend = useMemo(
    () => monthlyTrendPoints(sessions, 6, { year, month }),
    [sessions, year, month],
  );
  const forecast = useMemo(
    () => monthForecast(sessions, year, month),
    [sessions, year, month],
  );
  const insights = useMemo(
    () => buildInsights(sessions, year, month, 4),
    [sessions, year, month],
  );

  const directionLabel =
    forecast.direction === 'up'
      ? 'Higher than last month'
      : forecast.direction === 'down'
        ? 'Lower than last month'
        : 'Similar to last month';

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Analytics' }} />

      <Text style={styles.title}>Analytics</Text>
      <Text style={styles.subtitle}>
        Networks, trends, and month-end forecast from your sessions.
      </Text>

      <MonthPicker
        year={year}
        month={month}
        onChange={(nextYear, nextMonth) => {
          setYear(nextYear);
          setMonth(nextMonth);
        }}
      />

      {loading ? (
        <ActivityIndicator color={colors.accent} style={styles.loader} />
      ) : (
        <>
          <MetricGrid metrics={metrics} />

          <View style={styles.card}>
            <Text style={styles.cardTitle}>Month-end forecast</Text>
            <Text style={styles.forecastValue}>
              {formatSgd(forecast.projectedCost)}
            </Text>
            <Text style={styles.cardMeta}>
              ~{formatKwh(forecast.projectedEnergy)} · ~{forecast.projectedCount}{' '}
              sessions
            </Text>
            <Text style={styles.cardMeta}>{directionLabel}</Text>
            {forecast.previousMonthCost > 0 ? (
              <Text style={styles.cardMeta}>
                Last month: {formatSgd(forecast.previousMonthCost)}
              </Text>
            ) : null}
          </View>

          <BarChart
            title="Cost — last 6 months"
            items={trend.map((point) => ({
              key: `${point.year}-${point.month}`,
              label: point.label,
              value: point.totalCost,
            }))}
            valueFormatter={(value) => (value > 0 ? value.toFixed(0) : '')}
          />

          <View style={styles.card}>
            <Text style={styles.cardTitle}>Networks this month</Text>
            {networks.length === 0 ? (
              <Text style={styles.cardMeta}>No network data yet.</Text>
            ) : (
              networks.map((item) => (
                <View key={item.network} style={styles.networkRow}>
                  <View style={styles.networkMeta}>
                    <Text style={styles.networkName}>{item.network}</Text>
                    <Text style={styles.cardMeta}>
                      {item.sessionCount} sessions · {formatKwh(item.totalEnergy)}
                    </Text>
                  </View>
                  <View style={styles.networkValues}>
                    <Text style={styles.networkCost}>
                      {formatSgd(item.totalCost)}
                    </Text>
                    <Text style={styles.cardMeta}>
                      {formatCostPerKwh(item.averageCostPerKWh)}
                    </Text>
                  </View>
                </View>
              ))
            )}
          </View>

          <InsightList insights={insights} />
        </>
      )}

      <ErrorText message={error} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 16,
    padding: 24,
    paddingBottom: 48,
  },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  loader: {
    marginTop: 24,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 8,
    padding: 16,
  },
  cardTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
  forecastValue: {
    color: colors.accent,
    fontSize: 32,
    fontWeight: '800',
  },
  cardMeta: {
    color: colors.textMuted,
    fontSize: 13,
  },
  networkRow: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'space-between',
    paddingTop: 10,
  },
  networkMeta: {
    flex: 1,
    gap: 2,
  },
  networkName: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
  },
  networkValues: {
    alignItems: 'flex-end',
    gap: 2,
  },
  networkCost: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
  },
});
