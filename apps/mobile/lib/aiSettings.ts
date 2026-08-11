import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

import { env } from '@/lib/env';

export type CloudProvider = 'openai' | 'claude';

export type AiSettings = {
  preferredProvider: CloudProvider;
};

const PREFS_KEY = 'evai.ai_settings';
const OPENAI_KEY = 'evai.openai_api_key';
const ANTHROPIC_KEY = 'evai.anthropic_api_key';

const DEFAULT_SETTINGS: AiSettings = {
  preferredProvider: 'openai',
};

async function storageGet(key: string): Promise<string | null> {
  if (Platform.OS === 'web') {
    return AsyncStorage.getItem(key);
  }
  return SecureStore.getItemAsync(key);
}

async function storageSet(key: string, value: string): Promise<void> {
  if (Platform.OS === 'web') {
    await AsyncStorage.setItem(key, value);
    return;
  }
  await SecureStore.setItemAsync(key, value);
}

async function storageRemove(key: string): Promise<void> {
  if (Platform.OS === 'web') {
    await AsyncStorage.removeItem(key);
    return;
  }
  await SecureStore.deleteItemAsync(key);
}

export async function loadAiSettings(): Promise<AiSettings> {
  try {
    const raw = await AsyncStorage.getItem(PREFS_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    const parsed = JSON.parse(raw) as Partial<AiSettings>;
    return {
      preferredProvider:
        parsed.preferredProvider === 'claude' ? 'claude' : 'openai',
    };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

export async function saveAiSettings(settings: AiSettings): Promise<void> {
  await AsyncStorage.setItem(PREFS_KEY, JSON.stringify(settings));
}

export async function hasStoredOpenAiKey(): Promise<boolean> {
  return Boolean(await storageGet(OPENAI_KEY));
}

export async function hasStoredAnthropicKey(): Promise<boolean> {
  return Boolean(await storageGet(ANTHROPIC_KEY));
}

export async function getStoredOpenAiKey(): Promise<string | null> {
  return storageGet(OPENAI_KEY);
}

export async function getStoredAnthropicKey(): Promise<string | null> {
  return storageGet(ANTHROPIC_KEY);
}

export async function saveOpenAiKey(key: string): Promise<void> {
  const trimmed = key.trim();
  if (!trimmed) throw new Error('Enter an OpenAI API key.');
  if (trimmed.startsWith('sk-ant-')) {
    throw new Error('That looks like an Anthropic key. Save it under Claude.');
  }
  await storageSet(OPENAI_KEY, trimmed);
}

export async function saveAnthropicKey(key: string): Promise<void> {
  const trimmed = key.trim();
  if (!trimmed) throw new Error('Enter an Anthropic API key.');
  if (!trimmed.startsWith('sk-ant-')) {
    throw new Error('Claude keys usually start with sk-ant-.');
  }
  await storageSet(ANTHROPIC_KEY, trimmed);
}

export async function clearOpenAiKey(): Promise<void> {
  await storageRemove(OPENAI_KEY);
}

export async function clearAnthropicKey(): Promise<void> {
  await storageRemove(ANTHROPIC_KEY);
}

export type ExtractionEngine =
  | 'edge'
  | 'proxy'
  | 'openai'
  | 'claude'
  | 'none';

export type ExtractionRuntime = {
  configured: boolean;
  engine: ExtractionEngine;
  preferredProvider: CloudProvider;
  label: string;
  detail: string;
};

function envOpenAiKey(): string {
  const key = env.openaiApiKey.trim();
  if (!key || key.startsWith('sk-ant-')) return '';
  return key;
}

function envAnthropicKey(): string {
  const dedicated = env.anthropicApiKey.trim();
  if (dedicated) return dedicated;
  const maybe = env.openaiApiKey.trim();
  if (maybe.startsWith('sk-ant-')) return maybe;
  return '';
}

/** Resolve which engine Capture will use given current settings + env. */
export async function resolveExtractionRuntime(): Promise<ExtractionRuntime> {
  const settings = await loadAiSettings();
  const preferred = settings.preferredProvider;
  const storedOpenAi = (await getStoredOpenAiKey())?.trim() ?? '';
  const storedAnthropic = (await getStoredAnthropicKey())?.trim() ?? '';
  const openAi = storedOpenAi || envOpenAiKey();
  const anthropic = storedAnthropic || envAnthropicKey();

  if (env.useEdgeExtraction) {
    return {
      configured: true,
      engine: 'edge',
      preferredProvider: preferred,
      label: 'Supabase Edge Function',
      detail: `Preferred provider: ${preferred === 'claude' ? 'Claude' : 'OpenAI'} (server secrets).`,
    };
  }

  if (Platform.OS === 'web') {
    return {
      configured: Boolean(env.extractProxyUrl),
      engine: env.extractProxyUrl ? 'proxy' : 'none',
      preferredProvider: preferred,
      label: 'Local extract proxy',
      detail: `Run \`npm run extract-proxy\`. Preferred: ${
        preferred === 'claude' ? 'Claude' : 'OpenAI'
      }.`,
    };
  }

  if (preferred === 'claude' && anthropic) {
    return {
      configured: true,
      engine: 'claude',
      preferredProvider: preferred,
      label: 'Claude (direct)',
      detail: storedAnthropic
        ? 'Using key saved in AI Settings.'
        : 'Using EXPO_PUBLIC_ANTHROPIC_API_KEY / env.',
    };
  }

  if (preferred === 'openai' && openAi) {
    return {
      configured: true,
      engine: 'openai',
      preferredProvider: preferred,
      label: 'OpenAI (direct)',
      detail: storedOpenAi
        ? 'Using key saved in AI Settings.'
        : 'Using EXPO_PUBLIC_OPENAI_API_KEY.',
    };
  }

  if (anthropic) {
    return {
      configured: true,
      engine: 'claude',
      preferredProvider: preferred,
      label: 'Claude (direct)',
      detail: 'Preferred key unavailable; using Claude.',
    };
  }

  if (openAi) {
    return {
      configured: true,
      engine: 'openai',
      preferredProvider: preferred,
      label: 'OpenAI (direct)',
      detail: 'Preferred key unavailable; using OpenAI.',
    };
  }

  if (env.extractProxyUrl) {
    return {
      configured: true,
      engine: 'proxy',
      preferredProvider: preferred,
      label: 'Local extract proxy',
      detail: 'No device keys — falling back to extract proxy.',
    };
  }

  return {
    configured: false,
    engine: 'none',
    preferredProvider: preferred,
    label: 'Not configured',
    detail:
      'Save an API key in AI Settings, set env keys, run the extract proxy, or enable Edge extraction.',
  };
}
