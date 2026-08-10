/** Excel charging-log column layout (matches legacy Swift ExcelChargingLogLayout). */

export const EXCEL_COLUMNS = {
  startDate: 'A',
  startTime: 'B',
  endDate: 'C',
  endTime: 'D',
  duration: 'E',
  startSOC: 'F',
  endSOC: 'G',
  odometer: 'H',
  location: 'I',
  chargerId: 'J',
  cost: 'K',
  energy: 'L',
  reference: 'M',
  network: 'N',
  chargerType: 'O',
  powerKW: 'P',
} as const;

export const EXCEL_HEADER_TITLES: Record<string, string> = {
  A: 'Start Date',
  B: 'Start Time',
  C: 'End Date',
  D: 'End Time',
  E: 'Duration',
  F: 'Start SOC',
  G: 'End SOC',
  H: 'Odometer',
  I: 'Charging Station',
  J: 'Charging Station ID',
  K: 'Cost',
  L: 'Total Energy Consumption',
  M: 'Reference',
  N: 'Network',
  O: 'Charger Type',
  P: 'Power kW',
};

export const EXCEL_HEADER_COLUMNS = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
] as const;

export function isExcelHeaderRow(cells: Record<string, string>): boolean {
  return (
    cells.I === EXCEL_HEADER_TITLES.I &&
    cells.A === EXCEL_HEADER_TITLES.A &&
    cells.B === EXCEL_HEADER_TITLES.B &&
    cells.C === EXCEL_HEADER_TITLES.C &&
    cells.D === EXCEL_HEADER_TITLES.D &&
    (cells.N == null || cells.N === '' || cells.N === EXCEL_HEADER_TITLES.N) &&
    (cells.O == null || cells.O === '' || cells.O === EXCEL_HEADER_TITLES.O) &&
    (cells.P == null || cells.P === '' || cells.P === EXCEL_HEADER_TITLES.P)
  );
}
