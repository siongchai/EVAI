import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors } from '@/constants/theme';
import { monthLabel } from '@/lib/analytics/format';

type MonthPickerProps = {
  year: number;
  month: number;
  onChange: (year: number, month: number) => void;
};

export function MonthPicker({ year, month, onChange }: MonthPickerProps) {
  function shift(delta: number) {
    const next = new Date(year, month - 1 + delta, 1);
    onChange(next.getFullYear(), next.getMonth() + 1);
  }

  return (
    <View style={styles.row}>
      <Pressable onPress={() => shift(-1)} style={styles.button}>
        <Text style={styles.buttonText}>‹</Text>
      </Pressable>
      <Text style={styles.label}>{monthLabel(year, month)}</Text>
      <Pressable onPress={() => shift(1)} style={styles.button}>
        <Text style={styles.buttonText}>›</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  label: {
    color: colors.text,
    flex: 1,
    fontSize: 18,
    fontWeight: '700',
    textAlign: 'center',
  },
  button: {
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: 1,
    height: 36,
    justifyContent: 'center',
    width: 36,
  },
  buttonText: {
    color: colors.accent,
    fontSize: 22,
    fontWeight: '700',
    lineHeight: 24,
  },
});
