import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/constants/theme';
import {
  formatCostPerKwh,
  formatKwh,
  formatSgd,
} from '@/lib/analytics/format';
import type { MonthlyMetrics } from '@/lib/analytics/types';

export function MetricGrid({ metrics }: { metrics: MonthlyMetrics }) {
  const items = [
    { label: 'Total cost', value: formatSgd(metrics.totalCost) },
    { label: 'Energy', value: formatKwh(metrics.totalEnergy) },
    { label: 'Sessions', value: String(metrics.sessionCount) },
    {
      label: 'Avg rate',
      value: formatCostPerKwh(metrics.averageCostPerKWh),
    },
  ];

  return (
    <View style={styles.grid}>
      {items.map((item) => (
        <View key={item.label} style={styles.card}>
          <Text style={styles.label}>{item.label}</Text>
          <Text style={styles.value}>{item.value}</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    gap: 6,
    padding: 14,
    width: '48%',
    flexGrow: 1,
  },
  label: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  value: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
  },
});
