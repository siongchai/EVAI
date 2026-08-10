/** Excel serial date helpers — Singapore wall-clock (matches legacy Swift). */

const SG_OFFSET_MS = 8 * 60 * 60 * 1000;

/** Midnight 1899-12-30 in Asia/Singapore, as UTC ms. */
function excelEpochUtcMs(): number {
  return Date.UTC(1899, 11, 30) - SG_OFFSET_MS;
}

export function dateFromExcelSerial(serial: number): Date | null {
  if (!(serial > 0)) return null;

  const dayIndex = Math.floor(serial);
  const fraction = serial - dayIndex;
  const secondOfDay = Math.min(Math.max(0, Math.round(fraction * 86_400)), 86_399);
  return new Date(excelEpochUtcMs() + dayIndex * 86_400_000 + secondOfDay * 1000);
}

export function timeOfDayFraction(serial: number): number {
  if (serial > 0 && serial < 1) return serial;
  return serial - Math.floor(serial);
}

export function combinedExcelDateTime(
  dateSerial: string,
  timeSerial: string,
): Date | null {
  const trimmedDate = dateSerial.trim();
  const trimmedTime = timeSerial.trim();
  const dateValue = Number(trimmedDate);
  if (!(dateValue > 0)) return null;

  const calendarDayIndex = Math.floor(dateValue);
  const timeValue = Number(trimmedTime);
  if (!(timeValue > 0)) {
    return dateFromExcelSerial(dateValue);
  }

  const fraction = timeOfDayFraction(timeValue);
  const secondOfDay = Math.min(Math.max(0, Math.round(fraction * 86_400)), 86_399);
  return new Date(excelEpochUtcMs() + calendarDayIndex * 86_400_000 + secondOfDay * 1000);
}

export function excelSerialFromDate(date: Date): number {
  const ms = date.getTime() - excelEpochUtcMs();
  return ms / 86_400_000;
}

/** Parses EV charging log duration strings into seconds (hours + minutes). */
export function durationSecondsFromExcel(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) return null;

  const lower = trimmed.toLowerCase();
  if (
    !lower.includes('h') &&
    !lower.includes('m') &&
    !lower.includes('s') &&
    trimmed.includes('.')
  ) {
    const serial = Number(trimmed);
    if (serial > 0 && serial < 2) {
      return truncateToWholeMinutes(Math.round(serial * 86_400));
    }
  }

  let hours = 0;
  let minutes = 0;

  const hourMatch = lower.match(/(\d+)\s*h/);
  if (hourMatch) hours = Number(hourMatch[1]) || 0;

  const minMatch =
    lower.match(/(\d+)\s*m(?:in)?(?:\s|$)/) ?? lower.match(/(\d+)\s*m/);
  if (minMatch) minutes = Number(minMatch[1]) || 0;

  const total = hours * 3600 + minutes * 60;
  return total > 0 ? total : null;
}

export function truncateToWholeMinutes(seconds: number): number {
  if (seconds <= 0) return 0;
  return Math.floor(seconds / 60) * 60;
}

export function durationString(seconds: number): string {
  const total = Math.max(0, Math.trunc(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;
  return `${hours} h ${minutes} m ${secs} s`;
}
