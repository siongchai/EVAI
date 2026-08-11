import { Platform } from 'react-native';

import { EXTRACTION_PROMPT } from '@/lib/extraction/prompt';
import { parseExtractedSessionData } from '@/lib/extraction/parse';
import type { ExtractionResult } from '@/lib/extraction/types';
import { env } from '@/lib/env';
import { getSupabase } from '@/lib/supabase';

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
      `${context}: ${message}. On web, OpenAI blocks browser calls — start the local proxy with \`npm run extract-proxy\` (uses your .env key), or deploy the Supabase Edge Function.`,
    );
  }
  return error instanceof Error ? error : new Error(message);
}

async function extractViaProxy(imagesBase64: string[]): Promise<string> {
  let response: Response;
  try {
    response = await fetch(`${env.extractProxyUrl}/extract`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ imagesBase64 }),
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
  return json.raw;
}

async function extractViaEdgeFunction(
  imagesBase64: string[],
): Promise<string> {
  const { data, error } = await getSupabase().functions.invoke(
    'extract-session',
    { body: { imagesBase64 } },
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

  return data.raw;
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

export function isExtractionConfigured(): boolean {
  return (
    Boolean(env.openaiApiKey) ||
    env.useEdgeExtraction ||
    Boolean(env.extractProxyUrl)
  );
}

export async function extractSessionFromImageUris(
  imageUris: string[],
): Promise<ExtractionResult> {
  if (imageUris.length === 0) {
    throw new Error('Add at least one receipt or dashboard photo.');
  }

  const imagesBase64 = await Promise.all(imageUris.map(uriToDataUrl));

  let raw: string;

  // Prefer Edge Function when enabled
  if (env.useEdgeExtraction) {
    try {
      raw = await extractViaEdgeFunction(imagesBase64);
      return { raw, parsed: parseExtractedSessionData(raw) };
    } catch (edgeError) {
      // fall through to proxy / direct
      console.warn('Edge extraction failed, trying fallback', edgeError);
    }
  }

  // Web: always use local proxy (OpenAI CORS blocks browser)
  if (Platform.OS === 'web') {
    raw = await extractViaProxy(imagesBase64);
    return { raw, parsed: parseExtractedSessionData(raw) };
  }

  // Native can call OpenAI directly with the env key
  if (env.openaiApiKey) {
    raw = await extractViaOpenAIDirect(imagesBase64, env.openaiApiKey);
    return { raw, parsed: parseExtractedSessionData(raw) };
  }

  // Last resort: proxy (e.g. simulator pointing at host machine)
  raw = await extractViaProxy(imagesBase64);
  return { raw, parsed: parseExtractedSessionData(raw) };
}
