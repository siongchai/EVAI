import { normalizeChargerType } from '@/lib/chargerType';
import { parseDurationToMinutes } from '@/lib/extraction/duration';
import type { ExtractedSessionData } from '@/lib/extraction/types';
import { isoToDateTimeLocal } from '@/lib/sessions';
import type { ChargingSession } from '@/types/database';

function combineDateTime(
  dateValue: string | null,
  timeValue: string | null,
): string | null {
  if (!dateValue && !timeValue) return null;

  const datePart = (dateValue ?? '').trim();
  let timePart = (timeValue ?? '').trim();

  if (!datePart && timePart) {
    // Time only — use today
    const today = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const isoDate = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`;
    return combineDateTime(isoDate, timePart);
  }

  // Normalize AM/PM times
  const ampm = timePart.match(/^(\d{1,2}):(\d{2})\s*(am|pm)$/i);
  if (ampm) {
    let hours = Number(ampm[1]);
    const minutes = ampm[2];
    const meridiem = ampm[3].toLowerCase();
    if (meridiem === 'pm' && hours < 12) hours += 12;
    if (meridiem === 'am' && hours === 12) hours = 0;
    timePart = `${String(hours).padStart(2, '0')}:${minutes}`;
  }

  if (/^\d{1,2}:\d{2}$/.test(timePart)) {
    const [h, m] = timePart.split(':');
    timePart = `${h.padStart(2, '0')}:${m}`;
  }

  if (!timePart) timePart = '00:00';

  // datePart may already be ISO-ish
  const normalizedDate = datePart.includes('T')
    ? datePart.slice(0, 10)
    : datePart;

  const candidate = `${normalizedDate}T${timePart}`;
  const parsed = new Date(candidate);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
}

/** Map AI extraction → Partial<ChargingSession> for SessionForm initial values. */
export function mapExtractionToSessionDraft(
  extracted: ExtractedSessionData,
): Partial<ChargingSession> {
  let startIso = combineDateTime(extracted.start_date, extracted.start_time);
  let endIso = combineDateTime(
    extracted.end_date ?? extracted.start_date,
    extracted.end_time,
  );

  if (!startIso && !endIso) {
    const now = new Date().toISOString();
    startIso = now;
    endIso = now;
  } else if (startIso && !endIso) {
    endIso = startIso;
  } else if (!startIso && endIso) {
    startIso = endIso;
  }

  if (
    startIso &&
    endIso &&
    new Date(endIso).getTime() < new Date(startIso).getTime()
  ) {
    // Swap if model inverted times
    const tmp = startIso;
    startIso = endIso;
    endIso = tmp;
  }

  let startSoc = extracted.start_soc_percent ?? 0;
  let endSoc = extracted.end_soc_percent ?? 0;
  if (startSoc > 0 && endSoc > 0 && startSoc > endSoc) {
    const tmp = startSoc;
    startSoc = endSoc;
    endSoc = tmp;
  }

  const durationMinutes = parseDurationToMinutes(extracted.session_duration);
  const idleMinutes = parseDurationToMinutes(extracted.idle_duration);

  return {
    charging_location: extracted.charging_location ?? '',
    charger_id: extracted.charger_id ?? '',
    charging_network: extracted.charging_network ?? '',
    charger_type: normalizeChargerType(extracted.charger_type ?? 'Others'),
    charger_power_kw: extracted.charger_power_kw ?? 0,
    start_date: startIso ?? new Date().toISOString(),
    end_date: endIso ?? new Date().toISOString(),
    start_soc_percent: startSoc,
    end_soc_percent: endSoc,
    odometer_km: extracted.odometer_km ?? 0,
    energy_kwh: extracted.energy_kwh ?? 0,
    amount_sgd: extracted.amount_sgd ?? 0,
    session_duration_seconds: durationMinutes * 60,
    idle_duration_seconds: idleMinutes * 60,
    car_model: extracted.car_model ?? '',
    extraction_confidence: extracted.extraction_confidence ?? 0,
  };
}

export function formatConfidence(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '—';
  return `${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`;
}

export function draftDateHint(draft: Partial<ChargingSession>): string {
  if (!draft.start_date) return '';
  return isoToDateTimeLocal(draft.start_date);
}
