import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Link, Stack, useFocusEffect, useRouter } from 'expo-router';

import { ErrorText, PrimaryButton, SuccessText } from '@/components/ui';
import { colors } from '@/constants/theme';
import { carDisplayName, listCars } from '@/lib/cars';
import { exportSessionsWorkbook } from '@/lib/excel/export';
import { pickExcelFile, saveExcelFile } from '@/lib/excel/file';
import { ExcelImportError, importSessionsFromWorkbook } from '@/lib/excel/import';
import {
  createSessions,
  formatDuration,
  formatSessionWhen,
  listSessions,
  updateSession,
} from '@/lib/sessions';
import { useAuth } from '@/providers/AuthProvider';
import type { ChargingSession } from '@/types/database';

export default function SessionsScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const [sessions, setSessions] = useState<ChargingSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      setSessions(await listSessions(user.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load sessions.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  async function handleImport() {
    if (!user) return;
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      const data = await pickExcelFile();
      if (!data) {
        setBusy(false);
        return;
      }

      const [existing, cars] = await Promise.all([
        listSessions(user.id),
        listCars(user.id),
      ]);
      const primary = cars.find((car) => car.is_primary) ?? cars[0] ?? null;
      const carModel = primary ? carDisplayName(primary) : 'Unknown Car';

      const plan = importSessionsFromWorkbook(data, {
        userId: user.id,
        carModel,
        carId: primary?.id ?? null,
        existingSessions: existing,
      });

      if (plan.toInsert.length > 0) {
        await createSessions(plan.toInsert);
      }
      for (const item of plan.toUpdate) {
        await updateSession(item.id, item.patch);
      }

      await load();
      setMessage(
        `Imported ${plan.importedCount}, updated ${plan.updatedCount}, skipped ${plan.skippedInvalid}.`,
      );
      if (plan.warnings.length > 0) {
        setError(plan.warnings.slice(0, 3).join(' '));
      }
    } catch (err) {
      const text =
        err instanceof ExcelImportError || err instanceof Error
          ? err.message
          : 'Import failed.';
      setError(text);
    } finally {
      setBusy(false);
    }
  }

  async function handleExport() {
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      const workbook = exportSessionsWorkbook(sessions);
      await saveExcelFile(workbook);
      setMessage(`Exported ${sessions.length} sessions.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Export failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          title: 'Sessions',
          headerRight: () => (
            <Link href="/(app)/sessions/new" asChild>
              <Pressable>
                <Text style={styles.headerAction}>Add</Text>
              </Pressable>
            </Link>
          ),
        }}
      />

      {loading ? (
        <ActivityIndicator color={colors.accent} style={styles.loader} />
      ) : (
        <FlatList
          data={sessions}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          ListHeaderComponent={
            <View style={styles.headerBlock}>
              <ErrorText message={error} />
              <SuccessText message={message} />
              <PrimaryButton
                label="Capture with AI"
                onPress={() => router.push('/(app)/sessions/capture')}
              />
              <PrimaryButton
                label="Add session manually"
                tone="muted"
                onPress={() => router.push('/(app)/sessions/new')}
              />
              <PrimaryButton
                label="Import Excel"
                tone="muted"
                loading={busy}
                onPress={handleImport}
              />
              <PrimaryButton
                label="Export Excel"
                tone="muted"
                loading={busy}
                disabled={sessions.length === 0}
                onPress={handleExport}
              />
            </View>
          }
          ListEmptyComponent={
            <Text style={styles.empty}>
              No charging sessions yet. Capture from photos, add manually, or
              import an Excel log.
            </Text>
          }
          renderItem={({ item }) => (
            <Link href={`/(app)/sessions/${item.id}`} asChild>
              <Pressable style={styles.card}>
                <View style={styles.cardBody}>
                  <Text style={styles.cardTitle}>
                    {item.charging_location || 'Untitled session'}
                  </Text>
                  <Text style={styles.cardMeta}>
                    {formatSessionWhen(item.start_date)}
                  </Text>
                  <Text style={styles.cardMeta}>
                    {[
                      item.charging_network,
                      item.energy_kwh > 0 ? `${item.energy_kwh} kWh` : null,
                      item.amount_sgd > 0 ? `$${item.amount_sgd.toFixed(2)}` : null,
                      formatDuration(item.session_duration_seconds),
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </Text>
                </View>
              </Pressable>
            </Link>
          )}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
  },
  loader: {
    marginTop: 40,
  },
  list: {
    gap: 12,
    padding: 24,
    paddingBottom: 48,
  },
  headerBlock: {
    gap: 12,
    marginBottom: 8,
  },
  headerAction: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
    paddingHorizontal: 8,
  },
  empty: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: 12,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 14,
  },
  cardBody: {
    gap: 4,
  },
  cardTitle: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '700',
  },
  cardMeta: {
    color: colors.textMuted,
    fontSize: 14,
  },
});
