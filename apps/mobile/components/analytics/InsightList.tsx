import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/constants/theme';
import type { Insight } from '@/lib/analytics/types';

export function InsightList({ insights }: { insights: Insight[] }) {
  return (
    <View style={styles.wrap}>
      <Text style={styles.heading}>Insights</Text>
      {insights.map((insight) => (
        <View key={insight.id} style={styles.card}>
          <Text style={styles.message}>{insight.message}</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: 10,
  },
  heading: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderLeftColor: colors.accent,
    borderLeftWidth: 3,
    borderRadius: 12,
    borderWidth: 1,
    padding: 14,
  },
  message: {
    color: colors.text,
    fontSize: 14,
    lineHeight: 20,
  },
});
