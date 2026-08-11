import { getSupabase } from '@/lib/supabase';
import { syncHomeScreenWidgets } from '@/lib/widgets/sync';
import type {
  ChargingSession,
  ChargingSessionInsert,
  ChargingSessionUpdate,
} from '@/types/database';

async function refreshWidgetsForUser(userId: string): Promise<void> {
  try {
    const sessions = await listSessions(userId);
    syncHomeScreenWidgets(sessions);
  } catch (error) {
    console.warn('Widget refresh failed', error);
  }
}

export async function listSessions(userId: string): Promise<ChargingSession[]> {
  const { data, error } = await getSupabase()
    .from('charging_sessions')
    .select('*')
    .eq('user_id', userId)
    .order('start_date', { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function getSession(
  sessionId: string,
): Promise<ChargingSession | null> {
  const { data, error } = await getSupabase()
    .from('charging_sessions')
    .select('*')
    .eq('id', sessionId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function createSession(
  input: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>,
): Promise<ChargingSession> {
  const { data, error } = await getSupabase()
    .from('charging_sessions')
    .insert(input)
    .select('*')
    .single();

  if (error) throw error;
  await refreshWidgetsForUser(input.user_id);
  return data;
}

export async function createSessions(
  inputs: Omit<ChargingSessionInsert, 'id' | 'created_at' | 'updated_at'>[],
): Promise<ChargingSession[]> {
  if (inputs.length === 0) return [];

  const { data, error } = await getSupabase()
    .from('charging_sessions')
    .insert(inputs)
    .select('*');

  if (error) throw error;
  const userId = inputs[0]?.user_id;
  if (userId) await refreshWidgetsForUser(userId);
  return data ?? [];
}

export async function updateSession(
  sessionId: string,
  input: ChargingSessionUpdate,
): Promise<ChargingSession> {
  const { data, error } = await getSupabase()
    .from('charging_sessions')
    .update(input)
    .eq('id', sessionId)
    .select('*')
    .single();

  if (error) throw error;
  if (data?.user_id) await refreshWidgetsForUser(data.user_id);
  return data;
}

export async function deleteSession(sessionId: string): Promise<void> {
  const existing = await getSession(sessionId);
  const { error } = await getSupabase()
    .from('charging_sessions')
    .delete()
    .eq('id', sessionId);

  if (error) throw error;
  if (existing?.user_id) await refreshWidgetsForUser(existing.user_id);
}

export function parseOptionalNumber(value: string): number {
  const trimmed = value.trim();
  if (!trimmed) return 0;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function parseOptionalInt(value: string): number {
  return Math.max(0, Math.trunc(parseOptionalNumber(value)));
}

export function costPerKWh(session: Pick<ChargingSession, 'amount_sgd' | 'energy_kwh'>) {
  if (session.energy_kwh <= 0) return 0;
  return session.amount_sgd / session.energy_kwh;
}

export function formatSessionWhen(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatDuration(seconds: number): string {
  const total = Math.max(0, Math.trunc(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (hours <= 0) return `${minutes}m`;
  return `${hours}h ${minutes}m`;
}

/** Convert ISO timestamptz → local datetime-local value (YYYY-MM-DDTHH:mm). */
export function isoToDateTimeLocal(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** Convert datetime-local value → ISO timestamptz. */
export function dateTimeLocalToIso(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const date = new Date(trimmed);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

export function computeDurationSeconds(startIso: string, endIso: string): number {
  const start = new Date(startIso).getTime();
  const end = new Date(endIso).getTime();
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) return 0;
  return Math.floor((end - start) / 1000 / 60) * 60;
}
