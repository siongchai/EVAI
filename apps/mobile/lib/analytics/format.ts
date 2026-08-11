export function formatSgd(value: number, digits = 2): string {
  return `$${value.toFixed(digits)}`;
}

export function formatKwh(value: number): string {
  return `${value.toFixed(1)} kWh`;
}

export function formatCostPerKwh(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return '—';
  return `$${value.toFixed(3)}/kWh`;
}

export function monthLabel(year: number, month: number): string {
  return new Date(year, month - 1, 1).toLocaleString(undefined, {
    month: 'long',
    year: 'numeric',
  });
}

export function shortMonthLabel(year: number, month: number): string {
  return new Date(year, month - 1, 1).toLocaleString(undefined, {
    month: 'short',
    year: '2-digit',
  });
}
