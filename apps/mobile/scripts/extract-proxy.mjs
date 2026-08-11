/**
 * Local AI extraction proxy for Expo web.
 * Supports OpenAI (sk-...) and Anthropic Claude (sk-ant-...).
 *
 * Usage: npm run extract-proxy
 * Keys from apps/mobile/.env:
 *   OPENAI_API_KEY / EXPO_PUBLIC_OPENAI_API_KEY
 *   ANTHROPIC_API_KEY / EXPO_PUBLIC_ANTHROPIC_API_KEY / EXPO_PUBLIC_OPENAI_API_KEY (if sk-ant-)
 */
import { createServer } from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const PORT = Number(process.env.EXTRACT_PROXY_PORT || 8787);

function loadEnvFile() {
  const envPath = join(root, '.env');
  if (!existsSync(envPath)) return;
  const text = readFileSync(envPath, 'utf8');
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile();

const EXTRACTION_PROMPT = `You are an EV charging data extraction assistant.
Analyze ALL provided images in any order.

STEP 1 — IDENTIFY IMAGE TYPES:
Classify each image as one of:
- Dashboard before charging
- Dashboard after charging
- Charging app summary (or receipt)

Upload order is not authoritative — infer types from visual content only.

STEP 2 — EXTRACT FROM DASHBOARDS:
Find the battery State of Charge (SOC) on each dashboard photo:
- Must have a "%" symbol linked to a battery level gauge (F/E scale, battery icon, SOC/Battery label)
- ONLY accept numbers displayed as battery charge percentage with "%"
- Ignore numbers WITHOUT "%": cruise/set speed, ADAS, speed limit, temperature, driving range (km), odometer, clock time, drive mode
- CRITICAL: the large central number on many dashboards (e.g. "30" with a speedometer icon, NO "%") is cruise/set speed — NEVER use it as SOC

STEP 3 — ASSIGN BEGIN/END SOC:
- start_soc_percent = lower SOC % across dashboard photos
- end_soc_percent = higher SOC % across dashboard photos
- Return numeric 0–100 only

STEP 4 — EXTRACT FROM CHARGING APP / RECEIPT:
- charging_location, charger_id, charging_network, charger_type, charger_power_kw
- start_date / start_time, end_date / end_time
- energy_kwh, amount_sgd, session_duration, idle_duration, odometer_km, car_model

STEP 5 — OUTPUT:
Do your reasoning silently. Your entire reply must be a single JSON object and
nothing else — no markdown, no headings, no code fences, no commentary.
Use null for unknown fields. Keys:
charging_location, charger_id, charging_network, charger_type, charger_power_kw,
start_date, start_time, end_date, end_time, start_soc_percent, end_soc_percent,
odometer_km, energy_kwh, amount_sgd, session_duration, idle_duration, car_model,
extraction_confidence`;

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  });
  res.end(body);
}

function resolveCredentials(preferred) {
  const openai =
    process.env.OPENAI_API_KEY ||
    (process.env.EXPO_PUBLIC_OPENAI_API_KEY &&
    !process.env.EXPO_PUBLIC_OPENAI_API_KEY.startsWith('sk-ant-')
      ? process.env.EXPO_PUBLIC_OPENAI_API_KEY
      : '') ||
    '';
  const anthropic =
    process.env.ANTHROPIC_API_KEY ||
    process.env.EXPO_PUBLIC_ANTHROPIC_API_KEY ||
    (process.env.EXPO_PUBLIC_OPENAI_API_KEY?.startsWith('sk-ant-')
      ? process.env.EXPO_PUBLIC_OPENAI_API_KEY
      : '') ||
    '';

  if (preferred === 'claude' && anthropic) {
    return { key: anthropic, provider: 'claude' };
  }
  if (preferred === 'openai' && openai) {
    return { key: openai, provider: 'openai' };
  }
  if (anthropic) return { key: anthropic, provider: 'claude' };
  if (openai) return { key: openai, provider: 'openai' };
  return { key: '', provider: 'none' };
}

function isAnthropicKey(key) {
  return key.startsWith('sk-ant-');
}

function toDataUrl(base64) {
  return String(base64).startsWith('data:')
    ? String(base64)
    : `data:image/jpeg;base64,${base64}`;
}

function stripDataUrl(base64) {
  const value = String(base64);
  const match = value.match(/^data:([^;]+);base64,(.+)$/);
  if (match) {
    return { mediaType: match[1], data: match[2] };
  }
  return { mediaType: 'image/jpeg', data: value };
}

async function extractWithOpenAI(apiKey, images) {
  const content = [{ type: 'text', text: EXTRACTION_PROMPT }];
  images.forEach((base64, index) => {
    content.push({ type: 'text', text: `Image ${index + 1}:` });
    content.push({
      type: 'image_url',
      image_url: { url: toDataUrl(base64), detail: 'high' },
    });
  });

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
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

  const json = await response.json();
  if (!response.ok) {
    throw new Error(
      json?.error?.message ?? `OpenAI error (${response.status})`,
    );
  }

  const raw = json?.choices?.[0]?.message?.content;
  if (typeof raw !== 'string' || !raw.trim()) {
    throw new Error('OpenAI returned an empty response');
  }
  return raw;
}

function extractJsonObject(raw) {
  let text = String(raw ?? '').trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) text = fenced[1].trim();
  if (text.startsWith('{') && text.endsWith('}')) return text;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start >= 0 && end > start) return text.slice(start, end + 1).trim();
  return text;
}

async function extractWithClaude(apiKey, images) {
  const content = [
    { type: 'text', text: EXTRACTION_PROMPT },
    {
      type: 'text',
      text: 'After analyzing the images, reply with ONLY the JSON object. No markdown.',
    },
  ];
  images.forEach((base64, index) => {
    const { mediaType, data } = stripDataUrl(base64);
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
    const response = await fetch('https://api.anthropic.com/v1/messages', {
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
          'You extract structured EV charging session data from screenshots. Your entire response must be a single valid JSON object matching the requested schema. Never use markdown headings or explanations. Use null for unavailable fields. Do not guess.',
        messages: [{ role: 'user', content }],
      }),
    });

    const json = await response.json();
    if (response.ok) {
      const raw = (json?.content ?? [])
        .filter((block) => block.type === 'text' && block.text)
        .map((block) => block.text)
        .join('\n')
        .trim();
      if (!raw) throw new Error('Claude returned an empty response');
      const extracted = extractJsonObject(raw);
      // Validate early so we can surface a clear error
      JSON.parse(extracted);
      return extracted;
    }

    lastError = json?.error?.message ?? `Claude error (${response.status})`;
    // Try next model on not_found / invalid model
    if (!/model|not[_ ]found|invalid/i.test(lastError)) {
      throw new Error(lastError);
    }
  }

  throw new Error(lastError);
}

const server = createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    const { key, provider } = resolveCredentials();
    sendJson(res, 200, {
      ok: true,
      provider: key ? provider : 'none',
    });
    return;
  }

  if (req.method !== 'POST' || req.url !== '/extract') {
    sendJson(res, 404, { error: 'Not found' });
    return;
  }

  try {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
    const images = (body.imagesBase64 ?? []).filter(Boolean).slice(0, 5);
    if (images.length === 0) {
      sendJson(res, 400, { error: 'At least one image is required' });
      return;
    }

    const preferred =
      body.preferredProvider === 'claude' || body.preferredProvider === 'openai'
        ? body.preferredProvider
        : undefined;
    const { key: apiKey, provider } = resolveCredentials(preferred);
    if (!apiKey || provider === 'none') {
      sendJson(res, 500, {
        error:
          'Missing API key in apps/mobile/.env. Set EXPO_PUBLIC_OPENAI_API_KEY (OpenAI sk-...) or EXPO_PUBLIC_ANTHROPIC_API_KEY / sk-ant-... key.',
      });
      return;
    }

    const useClaude = provider === 'claude' || isAnthropicKey(apiKey);
    const raw = useClaude
      ? await extractWithClaude(apiKey, images)
      : await extractWithOpenAI(apiKey, images);

    sendJson(res, 200, {
      raw,
      provider: useClaude ? 'claude' : 'openai',
    });
  } catch (error) {
    sendJson(res, 500, {
      error: error instanceof Error ? error.message : 'Proxy extraction failed',
    });
  }
});

server.listen(PORT, () => {
  const { key, provider } = resolveCredentials();
  console.log(`EVAi extract proxy listening on http://localhost:${PORT}`);
  console.log(`Provider: ${key ? provider : 'none'}`);
  console.log(`POST http://localhost:${PORT}/extract`);
});
