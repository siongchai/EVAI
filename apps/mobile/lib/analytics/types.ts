export type MonthlyMetrics = {
  year: number;
  month: number; // 1-12
  totalCost: number;
  totalEnergy: number;
  sessionCount: number;
  averageCostPerKWh: number;
};

export type DailyCostPoint = {
  day: number;
  date: Date;
  cost: number;
};

export type MonthlyTrendPoint = {
  year: number;
  month: number;
  label: string;
  totalCost: number;
  totalEnergy: number;
  sessionCount: number;
};

export type NetworkBreakdownItem = {
  network: string;
  sessionCount: number;
  totalCost: number;
  totalEnergy: number;
  averageCostPerKWh: number;
};

export type MonthForecast = {
  projectedCost: number;
  projectedEnergy: number;
  projectedCount: number;
  direction: 'up' | 'down' | 'stable';
  previousMonthCost: number;
};

export type Insight = {
  id: string;
  message: string;
};
