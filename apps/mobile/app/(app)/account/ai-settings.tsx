import { useCallback, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Stack, useFocusEffect } from 'expo-router';

import {
  ErrorText,
  Field,
  PrimaryButton,
  SelectField,
  SuccessText,
} from '@/components/ui';
import { colors } from '@/constants/theme';
import {
  clearAnthropicKey,
  clearOpenAiKey,
  hasStoredAnthropicKey,
  hasStoredOpenAiKey,
  loadAiSettings,
  resolveExtractionRuntime,
  saveAiSettings,
  saveAnthropicKey,
  saveOpenAiKey,
  type AiSettings,
  type CloudProvider,
  type ExtractionRuntime,
} from '@/lib/aiSettings';
import { env } from '@/lib/env';

export default function AiSettingsScreen() {
  const [settings, setSettings] = useState<AiSettings | null>(null);
  const [runtime, setRuntime] = useState<ExtractionRuntime | null>(null);
  const [hasOpenAi, setHasOpenAi] = useState(false);
  const [hasAnthropic, setHasAnthropic] = useState(false);
  const [openAiInput, setOpenAiInput] = useState('');
  const [anthropicInput, setAnthropicInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [nextSettings, nextRuntime, openAi, anthropic] = await Promise.all([
        loadAiSettings(),
        resolveExtractionRuntime(),
        hasStoredOpenAiKey(),
        hasStoredAnthropicKey(),
      ]);
      setSettings(nextSettings);
      setRuntime(nextRuntime);
      setHasOpenAi(openAi);
      setHasAnthropic(anthropic);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load AI settings.');
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      void refresh();
    }, [refresh]),
  );

  async function handlePreferred(value: string) {
    if (!settings) return;
    const preferredProvider = value as CloudProvider;
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      const next = { ...settings, preferredProvider };
      await saveAiSettings(next);
      setSettings(next);
      setRuntime(await resolveExtractionRuntime());
      setSuccess(
        `Preferred provider set to ${
          preferredProvider === 'claude' ? 'Claude' : 'OpenAI'
        }.`,
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save preference.');
    } finally {
      setBusy(false);
    }
  }

  async function handleSaveOpenAi() {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await saveOpenAiKey(openAiInput);
      setOpenAiInput('');
      setHasOpenAi(true);
      setRuntime(await resolveExtractionRuntime());
      setSuccess('OpenAI key saved on this device.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save OpenAI key.');
    } finally {
      setBusy(false);
    }
  }

  async function handleSaveAnthropic() {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await saveAnthropicKey(anthropicInput);
      setAnthropicInput('');
      setHasAnthropic(true);
      setRuntime(await resolveExtractionRuntime());
      setSuccess('Claude key saved on this device.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save Claude key.');
    } finally {
      setBusy(false);
    }
  }

  async function handleClearOpenAi() {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await clearOpenAiKey();
      setHasOpenAi(false);
      setRuntime(await resolveExtractionRuntime());
      setSuccess('OpenAI key removed.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not remove key.');
    } finally {
      setBusy(false);
    }
  }

  async function handleClearAnthropic() {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await clearAnthropicKey();
      setHasAnthropic(false);
      setRuntime(await resolveExtractionRuntime());
      setSuccess('Claude key removed.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not remove key.');
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
      <Stack.Screen options={{ title: 'AI Settings' }} />

      {loading || !settings ? (
        <ActivityIndicator color={colors.accent} />
      ) : (
        <>
          <Text style={styles.body}>
            Choose which cloud vision model Capture prefers. Keys saved here stay
            on this device (Secure Store on native, browser storage on web).
            Production web should use the Edge Function instead of shipping keys.
          </Text>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Active engine</Text>
            <Text style={styles.statusLabel}>{runtime?.label ?? '—'}</Text>
            <Text style={styles.statusDetail}>{runtime?.detail}</Text>
            {env.useEdgeExtraction ? (
              <Text style={styles.hint}>
                EXPO_PUBLIC_USE_EDGE_EXTRACTION=1 — Capture calls Supabase first.
              </Text>
            ) : null}
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Preferred provider</Text>
            <SelectField
              label="When both keys are available"
              value={settings.preferredProvider}
              options={[
                { label: 'OpenAI', value: 'openai' },
                { label: 'Claude', value: 'claude' },
              ]}
              onChange={handlePreferred}
            />
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>OpenAI API key</Text>
            <Text style={styles.hint}>
              {hasOpenAi
                ? 'A key is saved on this device.'
                : env.openaiApiKey && !env.openaiApiKey.startsWith('sk-ant-')
                  ? 'Using EXPO_PUBLIC_OPENAI_API_KEY from env (not device storage).'
                  : 'No OpenAI key saved.'}
            </Text>
            <Field
              label="OpenAI key"
              value={openAiInput}
              onChangeText={setOpenAiInput}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              placeholder="sk-..."
            />
            <PrimaryButton
              label="Save OpenAI key"
              loading={busy}
              disabled={!openAiInput.trim()}
              onPress={handleSaveOpenAi}
            />
            {hasOpenAi ? (
              <PrimaryButton
                label="Remove OpenAI key"
                tone="muted"
                loading={busy}
                onPress={handleClearOpenAi}
              />
            ) : null}
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Claude API key</Text>
            <Text style={styles.hint}>
              {hasAnthropic
                ? 'A key is saved on this device.'
                : env.anthropicApiKey || env.openaiApiKey.startsWith('sk-ant-')
                  ? 'Using Anthropic key from env (not device storage).'
                  : 'No Claude key saved.'}
            </Text>
            <Field
              label="Anthropic key"
              value={anthropicInput}
              onChangeText={setAnthropicInput}
              autoCapitalize="none"
              autoCorrect={false}
              secureTextEntry
              placeholder="sk-ant-..."
            />
            <PrimaryButton
              label="Save Claude key"
              loading={busy}
              disabled={!anthropicInput.trim()}
              onPress={handleSaveAnthropic}
            />
            {hasAnthropic ? (
              <PrimaryButton
                label="Remove Claude key"
                tone="muted"
                loading={busy}
                onPress={handleClearAnthropic}
              />
            ) : null}
          </View>

          <ErrorText message={error} />
          <SuccessText message={success} />
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 20,
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
  statusLabel: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
  },
  statusDetail: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  hint: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
});
