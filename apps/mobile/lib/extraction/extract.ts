import { Platform } from 'react-native';

import {
  getStoredAnthropicKey,
  getStoredOpenAiKey,
  loadAiSettings,
  resolveExtractionRuntime,
  type CloudProvider,
  type ExtractionEngine,
} from '@/lib/aiSettings';
import { EXTRACTION_PROMPT } from '@/lib/extraction/prompt';
import { parseExtractedSessionData } from '@/lib/extraction/parse';
import type { ExtractionResult } from '@/lib/extraction/types';
import { env } from '@/lib/env';
import { getSupabase } from '@/lib/supabase';

export type ExtractionOutcome = ExtractionResult & {
  engine: ExtractionEngine;
  provider: CloudProvider | 'unknown';
};

async function uriToDataUrl(uri: string): Promise<string> {
  const response = await fetch(uri);
  const blob = await response.blob();
  const contentType = blob.type || 'image/jpeg';

  if (typeof FileReader !== 'undefined') {
    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        if (typeof reader.result === 'string') resolve(reader.result);
        else reject(new Error('Could not read image data.'));
      };
      reader.onerror = () => reject(new Error('Could not read image data.'));
      reader.readAsDataURL(blob);
    });
    return dataUrl;
  }

  const buffer = await blob.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  const base64 = globalThis.btoa(binary);
  return `data:${contentType};base64,${base64}`;
}

function fetchErrorMessage(error: unknown, context: string): Error {
  const message =
    error instanceof Error ? error.message : 'Network request failed';
  if (/failed to fetch|network request failed/i.test(message)) {
    return new Error(
      `${context}: ${message}. On web, OpenAI/Anthropic block browser calls — start the local proxy with \`npm run extract-proxy\`, or deploy the Supabase Edge Function.`,
    );
  }
  return error instanceof Error ? error : new Error(message);
}

function isAnthropicKey(key: string) {
  return key.startsWith('sk-ant-');
}

function extractJsonObject(raw: string): string {
  let text = raw.trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) text = fenced[1].trim();
  if (text.startsWith('{') && text.endsWith('}')) return text;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start >= 0 && end > start) return text.slice(start, end + 1).trim();
  return text;
}

async function extractViaProxy(
  imagesBase64: string[],
  preferredProvider: CloudProvider,
): Promise<{ raw: string; provider: CloudProvider | 'unknown' }> {
  let response: Response;
  try {
    response = await fetch(`${env.extractProxyUrl}/extract`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ imagesBase64, preferredProvider }),
    });
  } catch (error) {
    throw fetchErrorMessage(
      error,
      `Could not reach extract proxy at ${env.extractProxyUrl}`,
    );
  }

  const json = await response.json();
  if (!response.ok) {
    throw new Error(json?.error ?? `Proxy error (${response.status})`);
  }
  if (typeof json?.raw !== 'string') {
    throw new Error('Proxy returned no extraction payload.');
  }
  const provider =
    json?.provider === 'claude' || json?.provider === 'openai'
      ? (json.provider as CloudProvider)
      : 'unknown';
  return { raw: json.raw, provider };
}

async function extractViaEdgeFunction(
  imagesBase64: string[],
  preferredProvider: CloudProvider,
): Promise<{ raw: string; provider: CloudProvider | 'unknown' }> {
  const { data, error } = await getSupabase().functions.invoke(
    'extract-session',
    { body: { imagesBase64, preferredProvider } },
  );

  if (error) {
    throw new Error(error.message || 'Edge function extraction failed.');
  }

  if (data?.error) {
    throw new Error(String(data.error));
  }

  if (typeof data?.raw !== 'string') {
    throw new Error('Edge function returned no extraction payload.');
  }

  const provider =
    data?.provider === 'claude' || data?.provider === 'openai'
      ? (data.provider as CloudProvider)
      : 'unknown';
  return { raw: data.raw, provider };
}

async function extractViaOpenAIDirect(
  imagesBase64: string[],
  apiKey: string,
): Promise<string> {
  const content: Array<Record<string, unknown>> = [
    { type: 'text', text: EXTRACTION_PROMPT },
  ];

  imagesBase64.forEach((dataUrl, index) => {
    content.push({ type: 'text', text: `Image ${index + 1}:` });
    content.push({
      type: 'image_url',
      image_url: {
        url: dataUrl,
        detail: 'high',
      },
    });
  });

  let response: Response;
  try {
    response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [{ role: 'user', content }],
        max_tokens: 1800,
        temperature: 0,
        top_p: 1,
        seed: 7,
        response_format: { type: 'json_object' },
      }),
    });
  } catch (error) {
    throw fetchErrorMessage(error, 'OpenAI request failed');
  }

  const json = await response.json();
  if (!response.ok) {
    throw new Error(
      json?.error?.message ?? `OpenAI error (${response.status})`,
    );
  }

  const raw = json?.choices?.[0]?.message?.content;
  if (typeof raw !== 'string' || !raw.trim()) {
    throw new Error('OpenAI returned an empty response.');
  }
  return raw;
}

async function extractViaClaudeDirect(
  imagesBase64: string[],
  apiKey: string,
): Promise<string> {
  const content: Array<Record<string, unknown>> = [
    { type: 'text', text: EXTRACTION_PROMPT },
    {
      type: 'text',
      text: 'After analyzing the images, reply with ONLY the JSON object. No markdown.',
    },
  ];

  imagesBase64.forEach((dataUrl, index) => {
    const match = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
    const mediaType = match?.[1] ?? 'image/jpeg';
    const data = match?.[2] ?? dataUrl;
    content.push({ type: 'text', text: `Image ${index + 1}:` });
    content.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: mediaType.includes('png')
          ? 'image/png'
          : mediaType.includes('webp')
            ? 'image/webp'
            : 'image/jpeg',
        data,
      },
    });
  });

  const models = [
    'claude-sonnet-4-6',
    'claude-sonnet-4-5-20250929',
    'claude-3-5-sonnet-20241022',
  ];

  let lastError = 'Claude request failed';
  for (const model of models) {
    let response: Response;
    try {
      response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          max_tokens: 2048,
          temperature: 0,
          system:
            'You extract structured EV charging session data from screenshots. Your entire response must be a single valid JSON object. Never use markdown headings. Use null for unavailable fields.',
          messages: [{ role: 'user', content }],
        }),
      });
    } catch (error) {
      throw fetchErrorMessage(error, 'Claude request failed');
    }

    const json = await response.json();
    if (response.ok) {
      const raw = (json?.content ?? [])
        .filter(
          (block: { type: string; text?: string }) =>
            block.type === 'text' && block.text,
        )
        .map((block: { text: string }) => block.text)
        .join('\n')
        .trim();
      if (!raw) throw new Error('Claude returned an empty response.');
      return extractJsonObject(raw);
    }

    lastError = json?.error?.message ?? `Claude error (${response.status})`;
    if (!/model|not[_ ]found|invalid/i.test(lastError)) {
      throw new Error(lastError);
    }
  }

  throw new Error(lastError);
}

async function resolveDirectKeys(preferred: CloudProvider): Promise<{
  openAi: string;
  anthropic: string;
}> {
  const storedOpenAi = (await getStoredOpenAiKey())?.trim() ?? '';
  const storedAnthropic = (await getStoredAnthropicKey())?.trim() ?? '';
  const envOpenAi = env.openaiApiKey.trim();
  const envAnthropic = env.anthropicApiKey.trim();

  const openAi =
    storedOpenAi ||
    (!isAnthropicKey(envOpenAi) ? envOpenAi : '') ||
    '';
  const anthropic =
    storedAnthropic ||
    envAnthropic ||
    (isAnthropicKey(envOpenAi) ? envOpenAi : '') ||
    '';

  // Touch preferred so callers can prefer ordering elsewhere
  void preferred;
  return { openAi, anthropic };
}

export async function isExtractionConfigured(): Promise<boolean> {
  const runtime = await resolveExtractionRuntime();
  return runtime.configured;
}

export async function extractSessionFromImageUris(
  imageUris: string[],
): Promise<ExtractionOutcome> {
  if (imageUris.length === 0) {
    throw new Error('Add at least one receipt or dashboard photo.');
  }

  const settings = await loadAiSettings();
  const preferred = settings.preferredProvider;
  const imagesBase64 = await Promise.all(imageUris.map(uriToDataUrl));

  if (env.useEdgeExtraction) {
    try {
      const result = await extractViaEdgeFunction(imagesBase64, preferred);
      return {
        raw: result.raw,
        parsed: parseExtractedSessionData(result.raw),
        engine: 'edge',
        provider: result.provider === 'unknown' ? preferred : result.provider,
      };
    } catch (edgeError) {
      console.warn('Edge extraction failed, trying fallback', edgeError);
    }
  }

  if (Platform.OS === 'web') {
    const result = await extractViaProxy(imagesBase64, preferred);
    return {
      raw: result.raw,
      parsed: parseExtractedSessionData(result.raw),
      engine: 'proxy',
      provider: result.provider === 'unknown' ? preferred : result.provider,
    };
  }

  const { openAi, anthropic } = await resolveDirectKeys(preferred);

  if (preferred === 'claude' && anthropic) {
    const raw = await extractViaClaudeDirect(imagesBase64, anthropic);
    return {
      raw,
      parsed: parseExtractedSessionData(raw),
      engine: 'claude',
      provider: 'claude',
    };
  }

  if (preferred === 'openai' && openAi) {
    const raw = await extractViaOpenAIDirect(imagesBase64, openAi);
    return {
      raw,
      parsed: parseExtractedSessionData(raw),
      engine: 'openai',
      provider: 'openai',
    };
  }

  if (anthropic) {
    const raw = await extractViaClaudeDirect(imagesBase64, anthropic);
    return {
      raw,
      parsed: parseExtractedSessionData(raw),
      engine: 'claude',
      provider: 'claude',
    };
  }

  if (openAi) {
    const raw = await extractViaOpenAIDirect(imagesBase64, openAi);
    return {
      raw,
      parsed: parseExtractedSessionData(raw),
      engine: 'openai',
      provider: 'openai',
    };
  }

  const result = await extractViaProxy(imagesBase64, preferred);
  return {
    raw: result.raw,
    parsed: parseExtractedSessionData(result.raw),
    engine: 'proxy',
    provider: result.provider === 'unknown' ? preferred : result.provider,
  };
}
