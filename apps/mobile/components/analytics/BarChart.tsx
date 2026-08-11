import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/constants/theme';

type BarItem = {
  key: string;
  label: string;
  value: number;
};

type BarChartProps = {
  title: string;
  items: BarItem[];
  emptyLabel?: string;
  valueFormatter?: (value: number) => string;
};

export function BarChart({
  title,
  items,
  emptyLabel = 'No data yet',
  valueFormatter = (value) => value.toFixed(0),
}: BarChartProps) {
  const max = Math.max(...items.map((item) => item.value), 0);
  const hasData = items.some((item) => item.value > 0);

  return (
    <View style={styles.card}>
      <Text style={styles.title}>{title}</Text>
      {!hasData ? (
        <Text style={styles.empty}>{emptyLabel}</Text>
      ) : (
        <View style={styles.chart}>
          {items.map((item) => {
            const height = max > 0 ? Math.max(4, (item.value / max) * 100) : 4;
            return (
              <View key={item.key} style={styles.column}>
                <Text style={styles.value}>{valueFormatter(item.value)}</Text>
                <View style={styles.barTrack}>
                  <View style={[styles.barFill, { height }]} />
                </View>
                <Text style={styles.label} numberOfLines={1}>
                  {item.label}
                </Text>
              </View>
            );
          })}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 12,
    padding: 16,
  },
  title: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
  empty: {
    color: colors.textMuted,
    fontSize: 14,
  },
  chart: {
    alignItems: 'flex-end',
    flexDirection: 'row',
    gap: 6,
    minHeight: 140,
  },
  column: {
    alignItems: 'center',
    flex: 1,
    gap: 4,
  },
  value: {
    color: colors.textMuted,
    fontSize: 9,
  },
  barTrack: {
    backgroundColor: colors.inputBackground,
    borderRadius: 6,
    height: 100,
    justifyContent: 'flex-end',
    overflow: 'hidden',
    width: '70%',
  },
  barFill: {
    backgroundColor: colors.accent,
    borderRadius: 6,
    width: '100%',
  },
  label: {
    color: colors.textMuted,
    fontSize: 10,
    textAlign: 'center',
    width: '100%',
  },
});
