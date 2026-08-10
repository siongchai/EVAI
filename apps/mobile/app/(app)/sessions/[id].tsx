import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
} from 'react-native';
import { Stack, useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';

import { SessionForm } from '@/components/SessionForm';
import { ErrorText, PrimaryButton } from '@/components/ui';
import { colors } from '@/constants/theme';
import { listCars } from '@/lib/cars';
import {
  costPerKWh,
  deleteSession,
  formatDuration,
  formatSessionWhen,
  getSession,
  updateSession,
} from '@/lib/sessions';
import type { Car, ChargingSession } from '@/types/database';

export default function EditSessionScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [session, setSession] = useState<ChargingSession | null>(null);
  const [cars, setCars] = useState<Car[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await getSession(id);
      if (!data) {
        setError('Session not found.');
        setSession(null);
        return;
      }
      setSession(data);
      const carList = await listCars(data.user_id);
      setCars(carList);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load session.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  async function handleDelete() {
    if (!session) return;

    const confirmed =
      Platform.OS === 'web'
        ? window.confirm('Delete this charging session permanently?')
        : await new Promise<boolean>((resolve) => {
            Alert.alert(
              'Delete session',
              'Delete this charging session permanently?',
              [
                { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
                {
                  text: 'Delete',
                  style: 'destructive',
                  onPress: () => resolve(true),
                },
              ],
            );
          });

    if (!confirmed) return;

    setDeleting(true);
    setError(null);
    try {
      await deleteSession(session.id);
      router.replace('/(app)/sessions');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete session.');
      setDeleting(false);
    }
  }

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Session' }} />

      {loading ? (
        <ActivityIndicator color={colors.accent} />
      ) : session ? (
        <>
          <Text style={styles.summary}>
            {formatSessionWhen(session.start_date)} ·{' '}
            {formatDuration(session.session_duration_seconds)}
            {session.energy_kwh > 0 ? ` · ${session.energy_kwh} kWh` : ''}
            {session.amount_sgd > 0
              ? ` · $${session.amount_sgd.toFixed(2)}`
              : ''}
            {session.energy_kwh > 0
              ? ` · $${costPerKWh(session).toFixed(2)}/kWh`
              : ''}
          </Text>

          <SessionForm
            key={session.id + session.updated_at}
            initial={session}
            cars={cars}
            submitLabel="Save changes"
            onSubmit={async (values) => {
              const updated = await updateSession(session.id, values);
              setSession(updated);
              router.back();
            }}
          />
          <PrimaryButton
            label="Delete session"
            tone="danger"
            loading={deleting}
            onPress={handleDelete}
          />
        </>
      ) : (
        <Text style={styles.missing}>Session not found.</Text>
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
  summary: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  missing: {
    color: colors.textMuted,
    fontSize: 16,
  },
});
