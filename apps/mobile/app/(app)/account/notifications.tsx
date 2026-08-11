import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack, useFocusEffect } from 'expo-router';

import {
  ErrorText,
  PrimaryButton,
  SuccessText,
  SwitchField,
} from '@/components/ui';
import { colors } from '@/constants/theme';
import {
  loadNotificationPrefs,
  notificationsSupported,
  setMonthlySummaryEnabled,
  type NotificationPrefs,
} from '@/lib/notifications';
import { useAuth } from '@/providers/AuthProvider';

export default function NotificationsScreen() {
  const { user } = useAuth();
  const [prefs, setPrefs] = useState<NotificationPrefs | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setPrefs(await loadNotificationPrefs());
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Could not load notification prefs.',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      void refresh();
    }, [refresh]),
  );

  async function handleToggle(enabled: boolean) {
    if (!user) return;
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      const next = await setMonthlySummaryEnabled(user.id, enabled);
      setPrefs(next);
      setSuccess(
        enabled
          ? 'Monthly summary reminder enabled (1st of each month, 9:00).'
          : 'Monthly summary reminder disabled.',
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update notifications.');
      setPrefs(await loadNotificationPrefs());
    } finally {
      setBusy(false);
    }
  }

  const supported = notificationsSupported();

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
    >
      <Stack.Screen options={{ title: 'Notifications' }} />

      <Text style={styles.body}>
        Local monthly reminders work on iOS/Android builds. Expo push tokens are
        saved to your profile when a real EAS projectId is configured (needed for
        remote pushes later).
      </Text>

      {loading || !prefs ? (
        <ActivityIndicator color={colors.accent} />
      ) : (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Reminders</Text>
          {!supported ? (
            <Text style={styles.hint}>
              Notifications are not available on {Platform.OS}. Use an iOS or
              Android build to enable reminders.
            </Text>
          ) : (
            <>
              <SwitchField
                label="Monthly charging summary"
                value={prefs.monthlySummaryEnabled}
                onValueChange={(value) => {
                  void handleToggle(value);
                }}
              />
              <Text style={styles.hint}>
                Sends a local notification on the 1st of each month at 9:00 to
                open EVAi and review costs.
              </Text>
              {busy ? <ActivityIndicator color={colors.accent} /> : null}
            </>
          )}
        </View>
      )}

      <ErrorText message={error} />
      <SuccessText message={success} />

      {supported && prefs?.monthlySummaryEnabled ? (
        <PrimaryButton
          label="Refresh permission / token"
          tone="muted"
          loading={busy}
          onPress={() => handleToggle(true)}
        />
      ) : null}
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
  body: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  section: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 12,
    padding: 16,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
  hint: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
});
