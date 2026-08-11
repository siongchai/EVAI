import { useCallback, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Link, Stack, useFocusEffect } from 'expo-router';

import { BarChart } from '@/components/analytics/BarChart';
import { InsightList } from '@/components/analytics/InsightList';
import { MetricGrid } from '@/components/analytics/MetricGrid';
import { MonthPicker } from '@/components/analytics/MonthPicker';
import { ErrorText } from '@/components/ui';
import { colors } from '@/constants/theme';
import { buildInsights } from '@/lib/analytics/insights';
import {
  currentYearMonth,
  dailyCostPoints,
  monthlyMetrics,
  recentSessionsInMonth,
} from '@/lib/analytics/metrics';
import { formatSgd } from '@/lib/analytics/format';
import { fetchProfile } from '@/lib/profile';
import {
  formatDuration,
  formatSessionWhen,
  listSessions,
} from '@/lib/sessions';
import { useAuth } from '@/providers/AuthProvider';
import type { ChargingSession } from '@/types/database';

export default function HomeScreen() {
  const { user } = useAuth();
  const initial = currentYearMonth();
  const [year, setYear] = useState(initial.year);
  const [month, setMonth] = useState(initial.month);
  const [sessions, setSessions] = useState<ChargingSession[]>([]);
  const [greetingName, setGreetingName] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      const [profile, nextSessions] = await Promise.all([
        fetchProfile(user.id),
        listSessions(user.id),
      ]);
      setGreetingName(profile?.full_name?.trim() || 'there');
      setSessions(nextSessions);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard.');
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
  const daily = useMemo(
    () => dailyCostPoints(sessions, year, month),
    [sessions, year, month],
  );
  const insights = useMemo(
    () => buildInsights(sessions, year, month, 2),
    [sessions, year, month],
  );
  const recent = useMemo(
    () => recentSessionsInMonth(sessions, year, month, 3),
    [sessions, year, month],
  );

  // Sparkline: sample every few days so the chart stays readable
  const sparkItems = useMemo(() => {
    const step = daily.length > 16 ? 2 : 1;
    return daily
      .filter((_, index) => index % step === 0 || index === daily.length - 1)
      .map((point) => ({
        key: String(point.day),
        label: String(point.day),
        value: point.cost,
      }));
  }, [daily]);

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Home' }} />

      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.greeting}>Hi {greetingName}</Text>
      <Text style={styles.subtitle}>Your charging overview</Text>

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

          <BarChart
            title="Daily cost"
            items={sparkItems}
            emptyLabel="No charging cost this month yet."
            valueFormatter={(value) => (value > 0 ? value.toFixed(0) : '')}
          />

          <InsightList insights={insights} />

          <View style={styles.section}>
            <View style={styles.sectionHeader}>
              <Text style={styles.sectionTitle}>Recent sessions</Text>
              <Link href="/(app)/sessions" asChild>
                <Pressable>
                  <Text style={styles.link}>See all</Text>
                </Pressable>
              </Link>
            </View>
            {recent.length === 0 ? (
              <Text style={styles.empty}>No sessions in this month.</Text>
            ) : (
              recent.map((session) => (
                <Link
                  key={session.id}
                  href={`/(app)/sessions/${session.id}`}
                  asChild
                >
                  <Pressable style={styles.sessionCard}>
                    <Text style={styles.sessionTitle}>
                      {session.charging_location || 'Untitled session'}
                    </Text>
                    <Text style={styles.sessionMeta}>
                      {formatSessionWhen(session.start_date)} ·{' '}
                      {formatSgd(session.amount_sgd)} ·{' '}
                      {formatDuration(session.session_duration_seconds)}
                    </Text>
                  </Pressable>
                </Link>
              ))
            )}
          </View>

          <View style={styles.navRow}>
            <Link href="/(app)/analytics" asChild>
              <Pressable style={styles.navChip}>
                <Text style={styles.navChipText}>Analytics</Text>
              </Pressable>
            </Link>
            <Link href="/(app)/sessions/capture" asChild>
              <Pressable style={styles.navChip}>
                <Text style={styles.navChipText}>Capture</Text>
              </Pressable>
            </Link>
            <Link href="/(app)/sessions" asChild>
              <Pressable style={styles.navChip}>
                <Text style={styles.navChipText}>Sessions</Text>
              </Pressable>
            </Link>
            <Link href="/(app)/cars" asChild>
              <Pressable style={styles.navChip}>
                <Text style={styles.navChipText}>Cars</Text>
              </Pressable>
            </Link>
            <Link href="/(app)/account" asChild>
              <Pressable style={styles.navChip}>
                <Text style={styles.navChipText}>Account</Text>
              </Pressable>
            </Link>
          </View>
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
  brand: {
    color: colors.accent,
    fontSize: 32,
    fontWeight: '800',
  },
  greeting: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 15,
    marginBottom: 4,
  },
  loader: {
    marginTop: 24,
  },
  section: {
    gap: 10,
  },
  sectionHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
  link: {
    color: colors.accent,
    fontWeight: '700',
  },
  empty: {
    color: colors.textMuted,
  },
  sessionCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    gap: 4,
    padding: 14,
  },
  sessionTitle: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
  },
  sessionMeta: {
    color: colors.textMuted,
    fontSize: 13,
  },
  navRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  navChip: {
    backgroundColor: colors.surfaceElevated,
    borderColor: colors.border,
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  navChipText: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '600',
  },
});
