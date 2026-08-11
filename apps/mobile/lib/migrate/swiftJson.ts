import { normalizeChargerType } from '@/lib/chargerType';
import type { ChargingSession, ChargingSessionInsert } from '@/types/database';

export type SwiftJsonSession = {
  id?: string;
  chargingLocation?: string;
  chargerId?: string;
  chargingNetwork?: string;
  chargerType?: string;
  chargerPowerKW?: number;
  startDate?: string;
  endDate?: string;
  startSOCPercent?: number;
  endSOCPercent?: number;
  odometerKM?: number;
  energyKWh?: number;
  amountSGD?: number;
  sessionDuration?: number;
  idleDuration?: number;
  carModel?: string;
  extractionConfidence?: number;
  createdAt?: string;
  updatedAt?: string;
};

export type SwiftJsonExport = {
  app?: string;
  exportedAt?: string;
  sessionCount?: number;
  sessions?: SwiftJsonSession[];
};

export type SwiftJsonImportPlan = {
  importedCount: number;
  updatedCount: number;
  skippedInvalid: number;
  skippedDuplicate: number;
  toInsert: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>[];
  toUpdate: { id: string; patch: Partial<ChargingSessionInsert> }[];
  warnings: string[];
};

export class SwiftJsonImportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SwiftJsonImportError';
  }
}

export function parseSwiftJsonExport(raw: string | unknown): SwiftJsonExport {
  const data =
    typeof raw === 'string'
      ? (JSON.parse(raw) as unknown)
      : (raw as unknown);

  if (!data || typeof data !== 'object') {
    throw new SwiftJsonImportError('JSON file is empty or invalid.');
  }

  const record = data as Record<string, unknown>;

  // Accept either { sessions: [...] } or a bare array of sessions
  if (Array.isArray(data)) {
    return { sessions: data as SwiftJsonSession[] };
  }

  if (Array.isArray(record.sessions)) {
    return record as SwiftJsonExport;
  }

  throw new SwiftJsonImportError(
    'Unrecognized export. Expected an EVAi JSON export with a "sessions" array.',
  );
}

export function importSessionsFromSwiftJson(
  payload: SwiftJsonExport | string,
  options: {
    userId: string;
    carModel: string;
    carId?: string | null;
    existingSessions: ChargingSession[];
  },
): SwiftJsonImportPlan {
  const exportData =
    typeof payload === 'string' ? parseSwiftJsonExport(payload) : payload;
  const sessions = exportData.sessions ?? [];
  if (sessions.length === 0) {
    throw new SwiftJsonImportError('No sessions found in the JSON export.');
  }

  const lookup = new ExistingSessionLookup(options.existingSessions);
  const toInsert: SwiftJsonImportPlan['toInsert'] = [];
  const toUpdate: SwiftJsonImportPlan['toUpdate'] = [];
  const warnings: string[] = [];
  let skippedInvalid = 0;
  let skippedDuplicate = 0;
  const fallbackCarModel = options.carModel.trim() || 'Unknown Car';

  sessions.forEach((session, index) => {
    const parsed = normalizeSession(session, index);
    if (!parsed.ok) {
      skippedInvalid += 1;
      warnings.push(parsed.message);
      return;
    }

    const existing = lookup.match(parsed.row);
    const carModel = parsed.row.carModel || fallbackCarModel;

    if (existing) {
      // Prefer leaving cloud data if fingerprint already matches closely
      const same =
        nearlyEqual(existing.energy_kwh, parsed.row.energyKWh) &&
        nearlyEqual(existing.amount_sgd, parsed.row.amountSGD) &&
        existing.charging_location === parsed.row.chargingLocation;
      if (same) {
        skippedDuplicate += 1;
        return;
      }

      const patch = toPatch(parsed.row, carModel, options.carId);
      toUpdate.push({ id: existing.id, patch });
      lookup.register({ ...existing, ...patch, id: existing.id } as ChargingSession);
      return;
    }

    const insert = toInsertRow(
      parsed.row,
      options.userId,
      carModel,
      options.carId,
    );
    toInsert.push(insert);
    lookup.registerSynthetic(insert);
  });

  if (toInsert.length === 0 && toUpdate.length === 0 && skippedInvalid === 0) {
    if (skippedDuplicate > 0) {
      throw new SwiftJsonImportError(
        `All ${skippedDuplicate} sessions already exist in the cloud.`,
      );
    }
    throw new SwiftJsonImportError('No valid sessions could be imported.');
  }

  return {
    importedCount: toInsert.length,
    updatedCount: toUpdate.length,
    skippedInvalid,
    skippedDuplicate,
    toInsert,
    toUpdate,
    warnings,
  };
}

type NormalizedRow = {
  chargingLocation: string;
  chargerId: string;
  chargingNetwork: string;
  chargerType: string;
  chargerPowerKW: number;
  startDate: Date;
  endDate: Date;
  startSOCPercent: number;
  endSOCPercent: number;
  odometerKM: number;
  energyKWh: number;
  amountSGD: number;
  sessionDurationSeconds: number;
  idleDurationSeconds: number;
  carModel: string;
  extractionConfidence: number;
  legacyId: string | null;
};

function normalizeSession(
  session: SwiftJsonSession,
  index: number,
): { ok: true; row: NormalizedRow } | { ok: false; message: string } {
  const location = String(session.chargingLocation ?? '').trim();
  const startDate = parseDate(session.startDate);
  const endDate = parseDate(session.endDate);

  if (!location) {
    return { ok: false, message: `Session ${index + 1}: missing location.` };
  }
  if (!startDate || !endDate) {
    return {
      ok: false,
      message: `Session ${index + 1}: missing or invalid start/end dates.`,
    };
  }

  const sessionDurationSeconds = Math.max(
    0,
    Math.floor(Number(session.sessionDuration) || 0),
  );
  const idleDurationSeconds = Math.max(
    0,
    Math.floor(Number(session.idleDuration) || 0),
  );
  const energyKWh = Number(session.energyKWh) || 0;
  const amountSGD = Number(session.amountSGD) || 0;

  if (
    sessionDurationSeconds === 0 &&
    energyKWh === 0 &&
    amountSGD === 0 &&
    !(Number(session.startSOCPercent) > 0)
  ) {
    return { ok: false, message: `Session ${index + 1}: incomplete data.` };
  }

  return {
    ok: true,
    row: {
      chargingLocation: location,
      chargerId: String(session.chargerId ?? '').trim() || 'UNKNOWN',
      chargingNetwork:
        String(session.chargingNetwork ?? '').trim() ||
        inferredNetwork(location),
      chargerType: normalizeChargerType(String(session.chargerType ?? '')),
      chargerPowerKW: Number(session.chargerPowerKW) || 0,
      startDate,
      endDate,
      startSOCPercent: Number(session.startSOCPercent) || 0,
      endSOCPercent: Number(session.endSOCPercent) || 0,
      odometerKM: Number(session.odometerKM) || 0,
      energyKWh,
      amountSGD,
      sessionDurationSeconds:
        sessionDurationSeconds ||
        Math.max(
          0,
          Math.floor((endDate.getTime() - startDate.getTime()) / 1000),
        ),
      idleDurationSeconds,
      carModel: String(session.carModel ?? '').trim(),
      extractionConfidence: clamp01(Number(session.extractionConfidence) || 1),
      legacyId: typeof session.id === 'string' ? session.id : null,
    },
  };
}

function toInsertRow(
  row: NormalizedRow,
  userId: string,
  carModel: string,
  carId?: string | null,
): Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'> {
  return {
    user_id: userId,
    car_id: carId ?? null,
    charging_location: row.chargingLocation,
    charger_id: row.chargerId,
    charging_network: row.chargingNetwork,
    charger_type: row.chargerType,
    charger_power_kw: row.chargerPowerKW,
    start_date: row.startDate.toISOString(),
    end_date: row.endDate.toISOString(),
    start_soc_percent: row.startSOCPercent,
    end_soc_percent: row.endSOCPercent,
    odometer_km: row.odometerKM,
    energy_kwh: row.energyKWh,
    amount_sgd: row.amountSGD,
    session_duration_seconds: row.sessionDurationSeconds,
    idle_duration_seconds: row.idleDurationSeconds,
    car_model: carModel,
    extraction_confidence: row.extractionConfidence,
    raw_ai_response: row.legacyId
      ? JSON.stringify({ source: 'swift-json', legacyId: row.legacyId })
      : JSON.stringify({ source: 'swift-json' }),
    source_image_ids: '',
  };
}

function toPatch(
  row: NormalizedRow,
  carModel: string,
  carId?: string | null,
): Partial<ChargingSessionInsert> {
  return {
    charging_location: row.chargingLocation,
    charger_id: row.chargerId,
    charging_network: row.chargingNetwork,
    charger_type: row.chargerType,
    charger_power_kw: row.chargerPowerKW,
    start_date: row.startDate.toISOString(),
    end_date: row.endDate.toISOString(),
    start_soc_percent: row.startSOCPercent,
    end_soc_percent: row.endSOCPercent,
    odometer_km: row.odometerKM,
    energy_kwh: row.energyKWh,
    amount_sgd: row.amountSGD,
    session_duration_seconds: row.sessionDurationSeconds,
    idle_duration_seconds: row.idleDurationSeconds,
    car_model: carModel,
    extraction_confidence: row.extractionConfidence,
    ...(carId !== undefined ? { car_id: carId } : {}),
  };
}

function parseDate(value: unknown): Date | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 1;
  return Math.min(1, Math.max(0, value));
}

function nearlyEqual(a: number, b: number): boolean {
  return Math.abs(a - b) < 0.0001;
}

function inferredNetwork(location: string): string {
  const lower = location.toLowerCase();
  if (lower.includes('orto')) return 'ORTO';
  if (lower.includes('shell')) return 'Shell Recharge';
  if (lower.includes('charge+') || lower.includes('charge plus')) return 'Charge+';
  if (lower.includes('sp group') || lower.startsWith('sp ')) return 'SP Group';
  if (lower.includes('tesla')) return 'Tesla';
  if (lower.includes('hdb')) return 'HDB';
  return 'Imported';
}

function fingerprint(input: {
  startDate: Date | string;
  chargingLocation: string;
  energyKWh: number;
  amountSGD: number;
}): string {
  const start =
    typeof input.startDate === 'string'
      ? new Date(input.startDate)
      : input.startDate;
  const epoch = Math.floor(start.getTime() / 1000);
  return `${epoch}|${input.chargingLocation.toLowerCase()}|${input.energyKWh}|${input.amountSGD}`;
}

class ExistingSessionLookup {
  private byFingerprint = new Map<string, ChargingSession>();
  private byLegacyId = new Map<string, ChargingSession>();

  constructor(sessions: ChargingSession[]) {
    for (const session of sessions) {
      this.byFingerprint.set(
        fingerprint({
          startDate: session.start_date,
          chargingLocation: session.charging_location,
          energyKWh: session.energy_kwh,
          amountSGD: session.amount_sgd,
        }),
        session,
      );
      const legacy = legacyIdFromRaw(session.raw_ai_response);
      if (legacy) this.byLegacyId.set(legacy, session);
    }
  }

  match(row: NormalizedRow): ChargingSession | null {
    if (row.legacyId) {
      const byId = this.byLegacyId.get(row.legacyId);
      if (byId) return byId;
    }
    return (
      this.byFingerprint.get(
        fingerprint({
          startDate: row.startDate,
          chargingLocation: row.chargingLocation,
          energyKWh: row.energyKWh,
          amountSGD: row.amountSGD,
        }),
      ) ?? null
    );
  }

  register(session: ChargingSession) {
    this.byFingerprint.set(
      fingerprint({
        startDate: session.start_date,
        chargingLocation: session.charging_location,
        energyKWh: session.energy_kwh,
        amountSGD: session.amount_sgd,
      }),
      session,
    );
    const legacy = legacyIdFromRaw(session.raw_ai_response);
    if (legacy) this.byLegacyId.set(legacy, session);
  }

  registerSynthetic(
    insert: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>,
  ) {
    this.byFingerprint.set(
      fingerprint({
        startDate: insert.start_date,
        chargingLocation: insert.charging_location ?? '',
        energyKWh: insert.energy_kwh ?? 0,
        amountSGD: insert.amount_sgd ?? 0,
      }),
      {
        id: `pending-${this.byFingerprint.size}`,
        user_id: insert.user_id,
        car_id: insert.car_id ?? null,
        charging_location: insert.charging_location ?? '',
        charger_id: insert.charger_id ?? 'UNKNOWN',
        charging_network: insert.charging_network ?? '',
        charger_type: insert.charger_type ?? 'Others',
        charger_power_kw: insert.charger_power_kw ?? 0,
        start_date: insert.start_date,
        end_date: insert.end_date,
        start_soc_percent: insert.start_soc_percent ?? 0,
        end_soc_percent: insert.end_soc_percent ?? 0,
        odometer_km: insert.odometer_km ?? 0,
        energy_kwh: insert.energy_kwh ?? 0,
        amount_sgd: insert.amount_sgd ?? 0,
        session_duration_seconds: insert.session_duration_seconds ?? 0,
        idle_duration_seconds: insert.idle_duration_seconds ?? 0,
        car_model: insert.car_model ?? '',
        extraction_confidence: insert.extraction_confidence ?? 1,
        raw_ai_response: insert.raw_ai_response ?? '',
        source_image_ids: insert.source_image_ids ?? '',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
    );
  }
}

function legacyIdFromRaw(raw: string | null | undefined): string | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { legacyId?: unknown; source?: unknown };
    if (
      parsed?.source === 'swift-json' &&
      typeof parsed.legacyId === 'string'
    ) {
      return parsed.legacyId;
    }
  } catch {
    // not JSON metadata
  }
  return null;
}
