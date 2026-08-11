// Supabase Edge Function: extract charging session fields from receipt images.
// Secrets: OPENAI_API_KEY
// Deploy: supabase functions deploy extract-session --no-verify-jwt=false

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
- Must have a "%" symbol linked to a battery level gauge (F/E scale, battery icon, SOC/Battery label)
- ONLY accept numbers displayed as battery charge percentage with "%"
- Ignore numbers WITHOUT "%": cruise/set speed, ADAS, speed limit, temperature, driving range (km), odometer, clock time, drive mode
- CRITICAL: the large central number on many dashboards (e.g. "30" with a speedometer icon, NO "%") is cruise/set speed — NEVER use it as SOC
- Example: dashboard photos show 17% and 100% with central "30" on both → use 17 and 100 only

STEP 3 — ASSIGN BEGIN/END SOC:
This is a charging session — battery level rises while charging:
- start_soc_percent = lower SOC % across dashboard photos (before charging)
- end_soc_percent = higher SOC % across dashboard photos (after charging)
- If dashboard clock times are visible: earlier time = start, later time = end (use with SOC to confirm)
- If only one dashboard SOC is found: set that value and null for the other
- Return numeric 0–100 only (strip "%" in JSON)

STEP 4 — EXTRACT FROM CHARGING APP / RECEIPT:
- charging_location: full site name and address if visible
- charger_id: charger / connector / station identifier
- charging_network: operator brand (SP, Charge+, Shell Recharge, Tesla, etc.)
- charger_type: AC Charger, DC Fast Charger, or Others if unclear
- charger_power_kw: rated power in kW — AC typically 7.4, 11, 22, or 43; DC typically 50–100 (Standard) or 120–350 (Ultra-Fast)
- start_date / start_time: session start date and time
- end_date / end_time: time when charging power dropped to zero on the graph (the moment active charging stopped — NOT the session close time which includes idle)
- energy_kwh: total energy delivered (number before "kWh")
- amount_sgd: grand total paid (Total / Amount Paid / Grand Total — not subtotals or unit price)
- session_duration: TOTAL session duration including idle (e.g. "1h 53m" or "113" minutes). Use "37m 53s" for 37 min 53 sec — NEVER concatenate as 3753.
- idle_duration: idle time only (e.g. "37m 53s" or "37 min 53 sec"). NEVER concatenate minutes+seconds digits (3753 means 37m 53s, not 3753 minutes).
- odometer_km: odometer if visible on a dashboard photo
- car_model: car make/model if visible

STEP 5 — OUTPUT:
- Return valid JSON only — no markdown, no explanations, no extra text
- Use null for unknown or unreadable fields; do not guess
- Dates as YYYY-MM-DD when possible; times as HH:MM or include AM/PM exactly as shown
- Numeric fields: plain numbers only — no "%", "$", "SGD", "kWh", or "km" suffixes in JSON
- extraction_confidence: overall confidence from 0 to 1

Return exactly:

{
"charging_location": null,
"charger_id": null,
"charging_network": null,
"charger_type": null,
"charger_power_kw": null,
"start_date": null,
"start_time": null,
"end_date": null,
"end_time": null,
"start_soc_percent": null,
"end_soc_percent": null,
"odometer_km": null,
"energy_kwh": null,
"amount_sgd": null,
"session_duration": null,
"idle_duration": null,
"car_model": null,
"extraction_confidence": null
}`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type ExtractRequest = {
  imagesBase64: string[];
};

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

    const openaiKey = Deno.env.get('OPENAI_API_KEY');
    if (!openaiKey) {
      return json({ error: 'OPENAI_API_KEY is not configured on the server' }, 500);
    }

    const body = (await req.json()) as ExtractRequest;
    const images = (body.imagesBase64 ?? []).filter(Boolean).slice(0, 5);
    if (images.length === 0) {
      return json({ error: 'At least one image is required' }, 400);
    }

    const content: Array<Record<string, unknown>> = [
      { type: 'text', text: EXTRACTION_PROMPT },
    ];
    images.forEach((base64, index) => {
      content.push({ type: 'text', text: `Image ${index + 1}:` });
      content.push({
        type: 'image_url',
        image_url: {
          url: base64.startsWith('data:')
            ? base64
            : `data:image/jpeg;base64,${base64}`,
          detail: 'high',
        },
      });
    });

    const openaiResponse = await fetch(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openaiKey}`,
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
      },
    );

    const openaiJson = await openaiResponse.json();
    if (!openaiResponse.ok) {
      const message =
        openaiJson?.error?.message ??
        `OpenAI error (${openaiResponse.status})`;
      return json({ error: message }, 502);
    }

    const raw = openaiJson?.choices?.[0]?.message?.content;
    if (typeof raw !== 'string' || !raw.trim()) {
      return json({ error: 'OpenAI returned an empty response' }, 502);
    }

    return json({ raw, user_id: user.id });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Extraction failed';
    return json({ error: message }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
