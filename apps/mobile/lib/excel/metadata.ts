import type { ChargingSession } from '@/types/database';

export type SessionImportPayload = {
  importReference?: string | null;
  source: string;
  importedAt: string;
  excelRow?: number | null;
};

export function encodeImportMetadata(
  reference: string | null | undefined,
  excelRow: number,
): string {
  const payload: SessionImportPayload = {
    importReference: reference?.trim() || null,
    source: 'excel',
    importedAt: new Date().toISOString(),
    excelRow,
  };
  return JSON.stringify(payload);
}

export function parseImportMetadata(
  raw: string,
): SessionImportPayload | null {
  if (!raw || raw.startsWith('enc:v1:')) return null;
  try {
    const parsed = JSON.parse(raw) as SessionImportPayload;
    if (!parsed || typeof parsed !== 'object') return null;
    if (parsed.source !== 'excel') return null;
    return parsed;
  } catch {
    return null;
  }
}

export function importReferenceFromSession(
  session: Pick<ChargingSession, 'raw_ai_response'>,
): string | null {
  return parseImportMetadata(session.raw_ai_response)?.importReference ?? null;
}

export function excelRowFromSession(
  session: Pick<ChargingSession, 'raw_ai_response'>,
): number | null {
  return parseImportMetadata(session.raw_ai_response)?.excelRow ?? null;
}
