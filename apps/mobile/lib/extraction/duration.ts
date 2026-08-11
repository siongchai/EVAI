/** Simplified port of DurationParsingService → whole minutes. */
export function parseDurationToMinutes(value: string | number | null | undefined): number {
  if (value == null) return 0;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.round(value));
  }

  const trimmed = String(value).trim();
  if (!trimmed) return 0;

  const lower = trimmed.toLowerCase();

  const minSec = lower.match(
    /(\d+)\s*(?:min|mins|minute|minutes|m)\s*(\d+)\s*(?:sec|secs|second|seconds|s)?/,
  );
  if (minSec) {
    const minutes = Number(minSec[1]);
    const seconds = Number(minSec[2]);
    return minutes + (seconds >= 30 ? 1 : 0);
  }

  if (lower.includes('h')) {
    const sides = lower.split('h');
    const hours = Number((sides[0] ?? '').replace(/[^\d]/g, '')) || 0;
    const mins = Number((sides[1] ?? '').replace(/[^\d]/g, '')) || 0;
    const total = hours * 60 + mins;
    return total > 0 ? total : 0;
  }

  if (lower.includes(':')) {
    const [h, m] = lower.split(':');
    const hours = Number(h);
    const mins = Number(m);
    if (Number.isFinite(hours) && Number.isFinite(mins)) {
      return hours * 60 + mins;
    }
  }

  const digits = lower.replace(/[^\d.]/g, '');
  const numeric = Number(digits);
  if (!Number.isFinite(numeric) || numeric <= 0) return 0;

  // Avoid MMSS concatenation trap: 3753 → 37m 53s ≈ 38 minutes
  if (numeric >= 1000 && numeric <= 5959 && Number.isInteger(numeric)) {
    const asInt = Math.trunc(numeric);
    const mm = Math.floor(asInt / 100);
    const ss = asInt % 100;
    if (ss < 60) return mm + (ss >= 30 ? 1 : 0);
  }

  return Math.min(720, Math.round(numeric));
}
