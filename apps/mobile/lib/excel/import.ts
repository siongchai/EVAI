import * as XLSX from 'xlsx';

import { normalizeChargerType } from '@/lib/chargerType';
import {
  combinedExcelDateTime,
  durationSecondsFromExcel,
  truncateToWholeMinutes,
} from '@/lib/excel/dates';
import { isExcelHeaderRow, EXCEL_COLUMNS as Col } from '@/lib/excel/layout';
import {
  encodeImportMetadata,
  excelRowFromSession,
  importReferenceFromSession,
} from '@/lib/excel/metadata';
import type { ChargingSession, ChargingSessionInsert } from '@/types/database';

export type ExcelImportRow = {
  rowIndex: number;
  startDate: Date;
  endDate: Date;
  sessionDurationSeconds: number;
  startSOCPercent: number;
  endSOCPercent: number;
  odometerKM: number;
  chargingLocation: string;
  chargerId: string;
  chargingNetwork: string;
  chargerType: string;
  chargerPowerKW: number;
  amountSGD: number;
  energyKWh: number;
  reference: string | null;
};

export type ExcelImportPlan = {
  importedCount: number;
  updatedCount: number;
  skippedInvalid: number;
  toInsert: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>[];
  toUpdate: { id: string; patch: Partial<ChargingSessionInsert> }[];
  warnings: string[];
};

export class ExcelImportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ExcelImportError';
  }
}

type WorksheetRow = {
  rowIndex: number;
  cells: Record<string, string>;
};

export function importSessionsFromWorkbook(
  workbookData: ArrayBuffer,
  options: {
    userId: string;
    carModel: string;
    carId?: string | null;
    existingSessions: ChargingSession[];
  },
): ExcelImportPlan {
  const rows = readWorksheetRows(workbookData);
  const header = rows.find((row) => row.rowIndex === 1);
  if (!header || !isExcelHeaderRow(header.cells)) {
    throw new ExcelImportError(
      'The Excel file does not contain recognizable charging session data.',
    );
  }

  const lookup = new ExistingSessionLookup(options.existingSessions);
  const toInsert: ExcelImportPlan['toInsert'] = [];
  const toUpdate: ExcelImportPlan['toUpdate'] = [];
  const warnings: string[] = [];
  let skippedInvalid = 0;
  const carModel = options.carModel.trim() || 'Unknown Car';

  for (const row of rows) {
    if (row.rowIndex <= 1) continue;
    const parsed = parseRow(row);
    if (!parsed.ok) {
      skippedInvalid += 1;
      warnings.push(`Row ${row.rowIndex}: ${parsed.message}`);
      continue;
    }

    const existing = lookup.match(parsed.row);
    if (existing) {
      const patch = sessionPatchFromRow(parsed.row, carModel, options.carId);
      toUpdate.push({ id: existing.id, patch });
      lookup.register(
        { ...existing, ...patch, id: existing.id } as ChargingSession,
        parsed.row,
      );
      continue;
    }

    const insert = sessionInsertFromRow(
      parsed.row,
      options.userId,
      carModel,
      options.carId,
    );
    toInsert.push(insert);
    lookup.registerSynthetic(insert, parsed.row);
  }

  if (toInsert.length === 0 && toUpdate.length === 0 && skippedInvalid === 0) {
    throw new ExcelImportError(
      'The Excel file does not contain recognizable charging session data.',
    );
  }

  return {
    importedCount: toInsert.length,
    updatedCount: toUpdate.length,
    skippedInvalid,
    toInsert,
    toUpdate,
    warnings,
  };
}

function readWorksheetRows(workbookData: ArrayBuffer): WorksheetRow[] {
  const workbook = XLSX.read(workbookData, {
    type: 'array',
    cellDates: false,
    raw: true,
  });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) {
    throw new ExcelImportError('Unable to read the selected Excel file.');
  }

  const sheet = workbook.Sheets[sheetName];
  const ref = sheet['!ref'];
  if (!ref) {
    throw new ExcelImportError('Unable to read the selected Excel file.');
  }

  const range = XLSX.utils.decode_range(ref);
  const rows: WorksheetRow[] = [];

  for (let r = range.s.r; r <= range.e.r; r += 1) {
    const cells: Record<string, string> = {};
    for (let c = range.s.c; c <= range.e.c; c += 1) {
      const address = XLSX.utils.encode_cell({ r, c });
      const cell = sheet[address];
      if (!cell) continue;
      const col = XLSX.utils.encode_col(c);
      cells[col] = cellToString(cell);
    }
    if (Object.keys(cells).length === 0) continue;
    rows.push({ rowIndex: r + 1, cells });
  }

  return rows;
}

function cellToString(cell: XLSX.CellObject): string {
  if (cell.w != null && String(cell.w).trim() !== '') {
    // Prefer formatted text for duration-like strings, but serial dates need raw numbers.
    if (typeof cell.v === 'number' && cell.t === 'n') {
      return String(cell.v);
    }
    return String(cell.w);
  }
  if (cell.v == null) return '';
  return String(cell.v);
}

function parseRow(
  row: WorksheetRow,
): { ok: true; row: ExcelImportRow } | { ok: false; message: string } {
  const cells = row.cells;
  const location = (cells[Col.location] ?? '').trim();
  if (!location) {
    return { ok: false, message: 'Missing charging station.' };
  }

  const startDate = combinedExcelDateTime(
    cells[Col.startDate] ?? '',
    cells[Col.startTime] ?? cells[Col.startDate] ?? '',
  );
  if (!startDate) {
    return { ok: false, message: 'Missing or invalid start date/time.' };
  }

  let endDate = combinedExcelDateTime(
    cells[Col.endDate] ?? '',
    cells[Col.endTime] ?? cells[Col.endDate] ?? '',
  );
  const durationSeconds = durationSecondsFromExcel(cells[Col.duration] ?? '');
  const hasExplicitEndDateTime =
    Boolean((cells[Col.endDate] ?? '').trim()) &&
    Boolean((cells[Col.endTime] ?? '').trim());

  if (!endDate && durationSeconds && durationSeconds > 0) {
    endDate = new Date(startDate.getTime() + durationSeconds * 1000);
  }

  if (!endDate) {
    return { ok: false, message: 'Missing or invalid end date/time.' };
  }

  let resolvedEnd = endDate;
  if (!hasExplicitEndDateTime && resolvedEnd < startDate) {
    resolvedEnd = new Date(resolvedEnd.getTime() + 86_400_000);
  }

  const computedDuration = truncateToWholeMinutes(
    Math.max(0, Math.floor((resolvedEnd.getTime() - startDate.getTime()) / 1000)),
  );
  const sessionDurationSeconds = durationSeconds ?? computedDuration;

  const energy = Number(cells[Col.energy] ?? '') || 0;
  const cost = Number(cells[Col.cost] ?? '') || 0;
  const startSOC = Number(cells[Col.startSOC] ?? '') || 0;
  const endSOC = Number(cells[Col.endSOC] ?? '') || 0;

  if (
    sessionDurationSeconds === 0 &&
    energy === 0 &&
    cost === 0 &&
    startSOC === 0
  ) {
    return { ok: false, message: 'Incomplete session row.' };
  }

  const network = (cells[Col.network] ?? '').trim();
  const chargerType = normalizeChargerType(cells[Col.chargerType] ?? '');
  const chargerPowerKW = Number(cells[Col.powerKW] ?? '') || 0;
  const chargerId = (cells[Col.chargerId] ?? '').trim();
  const reference = (cells[Col.reference] ?? '').trim() || null;

  return {
    ok: true,
    row: {
      rowIndex: row.rowIndex,
      startDate,
      endDate: resolvedEnd,
      sessionDurationSeconds,
      startSOCPercent: startSOC,
      endSOCPercent: endSOC,
      odometerKM: Number(cells[Col.odometer] ?? '') || 0,
      chargingLocation: location,
      chargerId,
      chargingNetwork: resolvedNetwork(network, location),
      chargerType,
      chargerPowerKW,
      amountSGD: cost,
      energyKWh: energy,
      reference,
    },
  };
}

function resolvedNetwork(network: string, location: string): string {
  if (network) return network;
  const lower = location.toLowerCase();
  if (lower.includes('orto')) return 'ORTO';
  if (lower.includes('shell')) return 'Shell Recharge';
  if (lower.includes('charge+') || lower.includes('charge plus')) return 'Charge+';
  if (lower.includes('sp group') || lower.startsWith('sp ')) return 'SP Group';
  if (lower.includes('tesla')) return 'Tesla';
  if (lower.includes('hdb')) return 'HDB';
  return 'Imported';
}

function normalizedChargerId(value: string): string {
  return value.trim() ? value.trim() : 'UNKNOWN';
}

function sessionInsertFromRow(
  row: ExcelImportRow,
  userId: string,
  carModel: string,
  carId?: string | null,
): Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'> {
  return {
    user_id: userId,
    car_id: carId ?? null,
    charging_location: row.chargingLocation,
    charger_id: normalizedChargerId(row.chargerId),
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
    idle_duration_seconds: 0,
    car_model: carModel,
    extraction_confidence: 1,
    raw_ai_response: encodeImportMetadata(row.reference, row.rowIndex),
    source_image_ids: '',
  };
}

function sessionPatchFromRow(
  row: ExcelImportRow,
  carModel: string,
  carId?: string | null,
): Partial<ChargingSessionInsert> {
  return {
    charging_location: row.chargingLocation,
    charger_id: normalizedChargerId(row.chargerId),
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
    idle_duration_seconds: 0,
    car_model: carModel,
    extraction_confidence: 1,
    raw_ai_response: encodeImportMetadata(row.reference, row.rowIndex),
    ...(carId !== undefined ? { car_id: carId } : {}),
  };
}

function sessionFingerprint(input: {
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
  private byReference = new Map<string, ChargingSession>();
  private byExcelRow = new Map<number, ChargingSession>();
  private byFingerprint = new Map<string, ChargingSession>();

  constructor(sessions: ChargingSession[]) {
    for (const session of sessions) {
      const reference = importReferenceFromSession(session)?.trim();
      if (reference) this.byReference.set(reference, session);
      const excelRow = excelRowFromSession(session);
      if (excelRow != null) this.byExcelRow.set(excelRow, session);
      this.byFingerprint.set(
        sessionFingerprint({
          startDate: session.start_date,
          chargingLocation: session.charging_location,
          energyKWh: session.energy_kwh,
          amountSGD: session.amount_sgd,
        }),
        session,
      );
    }
  }

  match(row: ExcelImportRow): ChargingSession | null {
    if (row.reference?.trim()) {
      const byRef = this.byReference.get(row.reference.trim());
      if (byRef) return byRef;
    }
    const byRow = this.byExcelRow.get(row.rowIndex);
    if (byRow) return byRow;
    return (
      this.byFingerprint.get(
        sessionFingerprint({
          startDate: row.startDate,
          chargingLocation: row.chargingLocation,
          energyKWh: row.energyKWh,
          amountSGD: row.amountSGD,
        }),
      ) ?? null
    );
  }

  register(session: ChargingSession, row: ExcelImportRow) {
    if (row.reference?.trim()) {
      this.byReference.set(row.reference.trim(), session);
    }
    this.byExcelRow.set(row.rowIndex, session);
    this.byFingerprint.set(
      sessionFingerprint({
        startDate: row.startDate,
        chargingLocation: row.chargingLocation,
        energyKWh: row.energyKWh,
        amountSGD: row.amountSGD,
      }),
      session,
    );
  }

  registerSynthetic(
    insert: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>,
    row: ExcelImportRow,
  ) {
    const synthetic = {
      id: `pending-${row.rowIndex}`,
      ...insert,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    } as ChargingSession;
    this.register(synthetic, row);
  }
}
