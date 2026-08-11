import type { ExtractedSessionData } from '@/lib/extraction/types';

function asNullableString(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function asNullableNumber(value: unknown): number | null {
  if (value == null || value === '') return null;
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const cleaned = String(value).replace(/[^\d.-]/g, '');
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

/** Pull a JSON object out of model output that may include markdown / prose. */
export function sanitizeExtractionJson(raw: string): string {
  let text = raw.trim();

  // Fenced code block
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    text = fenced[1].trim();
  }

  // Already looks like JSON
  if (text.startsWith('{') && text.endsWith('}')) {
    return text;
  }

  // Extract outermost JSON object
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return text.slice(start, end + 1).trim();
  }

  return text;
}

export function parseExtractedSessionData(raw: string): ExtractedSessionData {
  const sanitized = sanitizeExtractionJson(raw);
  let json: Record<string, unknown>;
  try {
    json = JSON.parse(sanitized) as Record<string, unknown>;
  } catch (error) {
    const preview = sanitized.slice(0, 120).replace(/\s+/g, ' ');
    throw new Error(
      `AI returned non-JSON output (${preview}…). Try extracting again.`,
    );
  }

  return {
    charging_location: asNullableString(json.charging_location),
    charger_id: asNullableString(json.charger_id),
    charging_network: asNullableString(json.charging_network),
    charger_type: asNullableString(json.charger_type),
    charger_power_kw: asNullableNumber(json.charger_power_kw),
    start_date: asNullableString(json.start_date),
    start_time: asNullableString(json.start_time),
    end_date: asNullableString(json.end_date),
    end_time: asNullableString(json.end_time),
    start_soc_percent: asNullableNumber(json.start_soc_percent),
    end_soc_percent: asNullableNumber(json.end_soc_percent),
    odometer_km: asNullableNumber(json.odometer_km),
    energy_kwh: asNullableNumber(json.energy_kwh),
    amount_sgd: asNullableNumber(json.amount_sgd),
    session_duration:
      json.session_duration == null
        ? null
        : (json.session_duration as string | number),
    idle_duration:
      json.idle_duration == null
        ? null
        : (json.idle_duration as string | number),
    car_model: asNullableString(json.car_model),
    extraction_confidence: asNullableNumber(json.extraction_confidence),
  };
}
