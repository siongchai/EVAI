import * as XLSX from 'xlsx';

import { normalizeChargerType } from '@/lib/chargerType';
import {
  durationString,
  excelSerialFromDate,
} from '@/lib/excel/dates';
import {
  EXCEL_COLUMNS as Col,
  EXCEL_HEADER_COLUMNS,
  EXCEL_HEADER_TITLES,
} from '@/lib/excel/layout';
import { importReferenceFromSession } from '@/lib/excel/metadata';
import type { ChargingSession } from '@/types/database';

export function exportSessionsWorkbook(sessions: ChargingSession[]): ArrayBuffer {
  const sorted = [...sessions].sort((a, b) => {
    const startDiff =
      new Date(a.start_date).getTime() - new Date(b.start_date).getTime();
    if (startDiff !== 0) return startDiff;
    return new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
  });

  const aoa: (string | number | null)[][] = [
    EXCEL_HEADER_COLUMNS.map((column) => EXCEL_HEADER_TITLES[column] ?? ''),
  ];

  for (const session of sorted) {
    aoa.push(dataRow(session));
  }

  const sheet = XLSX.utils.aoa_to_sheet(aoa);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, sheet, 'Charging Log');
  return XLSX.write(workbook, { type: 'array', bookType: 'xlsx' }) as ArrayBuffer;
}

function dataRow(session: ChargingSession): (string | number | null)[] {
  const start = new Date(session.start_date);
  const totalEnd = totalSessionEndDate(session);
  const startSerial = excelSerialFromDate(start);
  const endSerial = excelSerialFromDate(totalEnd);
  const durationSeconds =
    session.session_duration_seconds > 0
      ? session.session_duration_seconds
      : Math.max(0, Math.floor((totalEnd.getTime() - start.getTime()) / 1000));

  const values: Record<string, string | number | null> = {
    [Col.startDate]: startSerial,
    [Col.startTime]: startSerial,
    [Col.endDate]: endSerial,
    [Col.endTime]: endSerial,
    [Col.duration]: durationString(durationSeconds),
    [Col.location]: session.charging_location,
    [Col.startSOC]: session.start_soc_percent > 0 ? session.start_soc_percent : null,
    [Col.endSOC]: session.end_soc_percent > 0 ? session.end_soc_percent : null,
    [Col.odometer]: session.odometer_km > 0 ? session.odometer_km : null,
    [Col.chargerId]: exportedChargerId(session.charger_id) || null,
    [Col.cost]: session.amount_sgd > 0 ? session.amount_sgd : null,
    [Col.energy]: session.energy_kwh > 0 ? session.energy_kwh : null,
    [Col.reference]: importReferenceFromSession(session) || null,
    [Col.network]:
      session.charging_network && session.charging_network !== 'Imported'
        ? session.charging_network
        : null,
    [Col.chargerType]:
      normalizeChargerType(session.charger_type) !== 'Others'
        ? session.charger_type
        : null,
    [Col.powerKW]: session.charger_power_kw > 0 ? session.charger_power_kw : null,
  };

  return EXCEL_HEADER_COLUMNS.map((column) => values[column] ?? null);
}

function totalSessionEndDate(session: ChargingSession): Date {
  const start = new Date(session.start_date);
  if (session.session_duration_seconds > 0) {
    return new Date(start.getTime() + session.session_duration_seconds * 1000);
  }
  const end = new Date(session.end_date);
  return new Date(
    end.getTime() + Math.max(0, session.idle_duration_seconds) * 1000,
  );
}

function exportedChargerId(value: string): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed.toUpperCase() === 'UNKNOWN') return '';
  return trimmed;
}
