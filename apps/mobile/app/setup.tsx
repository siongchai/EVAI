import { StyleSheet, Text, View } from 'react-native';

import { colors } from '@/constants/theme';

export default function SetupScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.title}>Connect Supabase to continue</Text>
      <Text style={styles.body}>
        Copy `apps/mobile/.env.example` to `apps/mobile/.env` and set:
      </Text>
      <View style={styles.codeBlock}>
        <Text style={styles.code}>EXPO_PUBLIC_SUPABASE_URL=...</Text>
        <Text style={styles.code}>EXPO_PUBLIC_SUPABASE_ANON_KEY=...</Text>
      </View>
      <Text style={styles.body}>
        Then run the SQL in `supabase/migrations/` and restart the Expo app.
        Full steps are in `docs/PHASE0.md`.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
    gap: 16,
    justifyContent: 'center',
    padding: 24,
  },
  brand: {
    color: colors.accent,
    fontSize: 40,
    fontWeight: '800',
    letterSpacing: 1,
  },
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
  },
  body: {
    color: colors.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  codeBlock: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    gap: 8,
    padding: 16,
  },
  code: {
    color: colors.text,
    fontFamily: 'Courier',
    fontSize: 13,
  },
});
