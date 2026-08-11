import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack, useFocusEffect, useRouter } from 'expo-router';

import { ErrorText, PrimaryButton, SuccessText } from '@/components/ui';
import { colors } from '@/constants/theme';
import { carDisplayName, listCars } from '@/lib/cars';
import { pickMigratableFile } from '@/lib/excel/file';
import { ExcelImportError, importSessionsFromWorkbook } from '@/lib/excel/import';
import {
  importSessionsFromSwiftJson,
  parseSwiftJsonExport,
  SwiftJsonImportError,
  type SwiftJsonImportPlan,
} from '@/lib/migrate/swiftJson';
import {
  createSessions,
  listSessions,
  updateSession,
} from '@/lib/sessions';
import { useAuth } from '@/providers/AuthProvider';
import type { ExcelImportPlan } from '@/lib/excel/import';

type Preview =
  | {
      kind: 'excel';
      name: string;
      plan: ExcelImportPlan;
    }
  | {
      kind: 'json';
      name: string;
      plan: SwiftJsonImportPlan;
      sessionCount: number;
    };

export default function MigrateScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const [preview, setPreview] = useState<Preview | null>(null);
  const [loadingCars, setLoadingCars] = useState(true);
  const [carLabel, setCarLabel] = useState('Unknown Car');
  const [carId, setCarId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const loadCars = useCallback(async () => {
    if (!user) return;
    setLoadingCars(true);
    try {
      const cars = await listCars(user.id);
      const primary = cars.find((car) => car.is_primary) ?? cars[0] ?? null;
      setCarLabel(primary ? carDisplayName(primary) : 'Unknown Car');
      setCarId(primary?.id ?? null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load cars.');
    } finally {
      setLoadingCars(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void loadCars();
    }, [loadCars]),
  );

  async function handlePick() {
    if (!user) return;
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      const file = await pickMigratableFile();
      if (!file) {
        setBusy(false);
        return;
      }

      const existing = await listSessions(user.id);

      if (file.kind === 'excel') {
        const plan = importSessionsFromWorkbook(file.data, {
          userId: user.id,
          carModel: carLabel,
          carId,
          existingSessions: existing,
        });
        setPreview({ kind: 'excel', name: file.name, plan });
      } else {
        const exportData = parseSwiftJsonExport(file.text);
        const plan = importSessionsFromSwiftJson(exportData, {
          userId: user.id,
          carModel: carLabel,
          carId,
          existingSessions: existing,
        });
        setPreview({
          kind: 'json',
          name: file.name,
          plan,
          sessionCount: exportData.sessions?.length ?? 0,
        });
      }
    } catch (err) {
      setPreview(null);
      setError(
        err instanceof ExcelImportError ||
          err instanceof SwiftJsonImportError ||
          err instanceof Error
          ? err.message
          : 'Could not read export file.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function handleImport() {
    if (!user || !preview) return;
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const { plan } = preview;
      if (plan.toInsert.length > 0) {
        await createSessions(plan.toInsert);
      }
      for (const item of plan.toUpdate) {
        await updateSession(item.id, item.patch);
      }

      const duplicateNote =
        preview.kind === 'json' && preview.plan.skippedDuplicate > 0
          ? ` Skipped ${preview.plan.skippedDuplicate} duplicates.`
          : '';

      setMessage(
        `Imported ${plan.importedCount}, updated ${plan.updatedCount}, skipped invalid ${plan.skippedInvalid}.${duplicateNote}`,
      );
      if (plan.warnings.length > 0) {
        setError(plan.warnings.slice(0, 3).join(' '));
      }
      setPreview(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Import failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Migrate from EVAi' }} />

      <Text style={styles.title}>Import legacy history</Text>
      <Text style={styles.body}>
        Bring charging sessions from the original EVAi iOS app into your cloud
        account. Export Excel (.xlsx) or JSON from the Swift app, then import
        here. Photos and local AI keys are not migrated.
      </Text>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Target vehicle</Text>
        {loadingCars ? (
          <ActivityIndicator color={colors.accent} />
        ) : (
          <Text style={styles.meta}>
            New sessions will be linked to: {carLabel}
            {carId ? '' : ' (no car on account yet — model name only)'}
          </Text>
        )}
      </View>

      <PrimaryButton
        label="Choose Excel or JSON export"
        loading={busy && !preview}
        onPress={handlePick}
      />

      {preview ? (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Preview</Text>
          <Text style={styles.meta}>File: {preview.name}</Text>
          <Text style={styles.meta}>
            Format: {preview.kind === 'excel' ? 'Excel workbook' : 'Swift JSON'}
          </Text>
          {preview.kind === 'json' ? (
            <Text style={styles.meta}>
              Sessions in file: {preview.sessionCount}
            </Text>
          ) : null}
          <Text style={styles.stat}>
            Will import {preview.plan.importedCount} · update{' '}
            {preview.plan.updatedCount} · skip invalid{' '}
            {preview.plan.skippedInvalid}
            {preview.kind === 'json'
              ? ` · skip duplicates ${preview.plan.skippedDuplicate}`
              : ''}
          </Text>
          {preview.plan.warnings.length > 0 ? (
            <Text style={styles.warning}>
              {preview.plan.warnings.slice(0, 4).join('\n')}
            </Text>
          ) : null}
          <PrimaryButton
            label="Import into cloud"
            loading={busy}
            onPress={handleImport}
          />
          <PrimaryButton
            label="Cancel"
            tone="muted"
            disabled={busy}
            onPress={() => setPreview(null)}
          />
        </View>
      ) : null}

      <ErrorText message={error} />
      <SuccessText message={message} />

      {message ? (
        <PrimaryButton
          label="View sessions"
          tone="muted"
          onPress={() => router.push('/(app)/sessions')}
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
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
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
    gap: 10,
    padding: 16,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
  meta: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  stat: {
    color: colors.accent,
    fontSize: 15,
    fontWeight: '700',
    lineHeight: 22,
  },
  warning: {
    color: '#E8A317',
    fontSize: 13,
    lineHeight: 18,
  },
});
