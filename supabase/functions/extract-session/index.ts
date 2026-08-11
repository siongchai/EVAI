// Supabase Edge Function: extract charging session fields from receipt images.
// Secrets (set one):
//   OPENAI_API_KEY=sk-...
//   ANTHROPIC_API_KEY=sk-ant-...
// Deploy: supabase functions deploy extract-session

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4';

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
- Must have a "%" symbol linked to a battery level gauge
- ONLY accept numbers displayed as battery charge percentage with "%"
- Ignore cruise/set speed and other non-% numbers

STEP 3 — ASSIGN BEGIN/END SOC:
- start_soc_percent = lower SOC %, end_soc_percent = higher SOC %
- Return numeric 0–100 only

STEP 4 — EXTRACT FROM CHARGING APP / RECEIPT:
charging_location, charger_id, charging_network, charger_type, charger_power_kw,
start_date, start_time, end_date, end_time, energy_kwh, amount_sgd,
session_duration, idle_duration, odometer_km, car_model

STEP 5 — OUTPUT:
Do reasoning silently. Reply with ONLY one JSON object — no markdown/headings.
Use null for unknown fields. Include extraction_confidence from 0 to 1.`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type ExtractRequest = {
  imagesBase64: string[];
};

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function isAnthropicKey(key: string) {
  return key.startsWith('sk-ant-');
}

function resolveApiKey() {
  return (
    Deno.env.get('ANTHROPIC_API_KEY') ||
    Deno.env.get('OPENAI_API_KEY') ||
    ''
  );
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

function stripDataUrl(base64: string) {
  const match = String(base64).match(/^data:([^;]+);base64,(.+)$/);
  if (match) return { mediaType: match[1], data: match[2] };
  return { mediaType: 'image/jpeg', data: String(base64) };
}

async function extractWithOpenAI(apiKey: string, images: string[]) {
  const content: Array<Record<string, unknown>> = [
    { type: 'text', text: EXTRACTION_PROMPT },
  ];
  images.forEach((base64, index) => {
    content.push({ type: 'text', text: `Image ${index + 1}:` });
    content.push({
      type: 'image_url',
      image_url: {
        url: String(base64).startsWith('data:')
          ? base64
          : `data:image/jpeg;base64,${base64}`,
        detail: 'high',
      },
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

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      payload?.error?.message ?? `OpenAI error (${response.status})`,
    );
  }
  const raw = payload?.choices?.[0]?.message?.content;
  if (typeof raw !== 'string' || !raw.trim()) {
    throw new Error('OpenAI returned an empty response');
  }
  return extractJsonObject(raw);
}

async function extractWithClaude(apiKey: string, images: string[]) {
  const content: Array<Record<string, unknown>> = [
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
          'You extract structured EV charging session data from screenshots. Your entire response must be a single valid JSON object. Never use markdown headings. Use null for unavailable fields.',
        messages: [{ role: 'user', content }],
      }),
    });

    const payload = await response.json();
    if (response.ok) {
      const raw = (payload?.content ?? [])
        .filter((block: { type: string; text?: string }) =>
          block.type === 'text' && block.text
        )
        .map((block: { text: string }) => block.text)
        .join('\n')
        .trim();
      if (!raw) throw new Error('Claude returned an empty response');
      const extracted = extractJsonObject(raw);
      JSON.parse(extracted);
      return extracted;
    }

    lastError = payload?.error?.message ?? `Claude error (${response.status})`;
    if (!/model|not[_ ]found|invalid/i.test(lastError)) {
      throw new Error(lastError);
    }
  }

  throw new Error(lastError);
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return json({ error: 'Unauthorized' }, 401);
    }

    const apiKey = resolveApiKey();
    if (!apiKey) {
      return json(
        {
          error:
            'Set OPENAI_API_KEY or ANTHROPIC_API_KEY as a Supabase function secret',
        },
        500,
      );
    }

    const body = (await req.json()) as ExtractRequest;
    const images = (body.imagesBase64 ?? []).filter(Boolean).slice(0, 5);
    if (images.length === 0) {
      return json({ error: 'At least one image is required' }, 400);
    }

    const raw = isAnthropicKey(apiKey)
      ? await extractWithClaude(apiKey, images)
      : await extractWithOpenAI(apiKey, images);

    return json({
      raw,
      user_id: user.id,
      provider: isAnthropicKey(apiKey) ? 'claude' : 'openai',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Extraction failed';
    return json({ error: message }, 500);
  }
});
