export type ExtractedSessionData = {
  charging_location: string | null;
  charger_id: string | null;
  charging_network: string | null;
  charger_type: string | null;
  charger_power_kw: number | null;
  start_date: string | null;
  start_time: string | null;
  end_date: string | null;
  end_time: string | null;
  start_soc_percent: number | null;
  end_soc_percent: number | null;
  odometer_km: number | null;
  energy_kwh: number | null;
  amount_sgd: number | null;
  session_duration: string | number | null;
  idle_duration: string | number | null;
  car_model: string | null;
  extraction_confidence: number | null;
};

export type ExtractionResult = {
  raw: string;
  parsed: ExtractedSessionData;
};
