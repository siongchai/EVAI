export const CHARGER_TYPE_OPTIONS = [
  'AC Charger',
  'DC Fast Charger',
  'Others',
] as const;

export type ChargerTypeOption = (typeof CHARGER_TYPE_OPTIONS)[number];

export function normalizeChargerType(value: string): ChargerTypeOption {
  const normalized = value.trim().toLowerCase();
  if (!normalized) return 'Others';

  switch (normalized) {
    case 'others':
    case 'other':
    case 'unknown':
      return 'Others';
    case 'ac charger':
    case 'ac':
      return 'AC Charger';
    case 'dc fast charger':
    case 'dc fast':
    case 'dcfc':
    case 'dc':
      return 'DC Fast Charger';
    default:
      break;
  }

  if (normalized.includes('type 2') || normalized.includes('type2')) {
    return 'AC Charger';
  }
  if (normalized.includes('chademo') || normalized.includes('ccs')) {
    return 'DC Fast Charger';
  }
  if (normalized.includes('ac') && !normalized.includes('dc')) {
    return 'AC Charger';
  }
  if (normalized.includes('dc')) {
    return 'DC Fast Charger';
  }

  return 'Others';
}
