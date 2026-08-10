import { useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { ErrorText, Field, PrimaryButton, SelectField } from '@/components/ui';
import { colors } from '@/constants/theme';
import { CHARGER_TYPE_OPTIONS, normalizeChargerType } from '@/lib/chargerType';
import { carDisplayName } from '@/lib/cars';
import {
  computeDurationSeconds,
  dateTimeLocalToIso,
  isoToDateTimeLocal,
  parseOptionalInt,
  parseOptionalNumber,
} from '@/lib/sessions';
import type { Car, ChargingSession } from '@/types/database';

export type SessionFormValues = {
  charging_location: string;
  charger_id: string;
  charging_network: string;
  charger_type: string;
  charger_power_kw: number;
  start_date: string;
  end_date: string;
  start_soc_percent: number;
  end_soc_percent: number;
  odometer_km: number;
  energy_kwh: number;
  amount_sgd: number;
  session_duration_seconds: number;
  idle_duration_seconds: number;
  car_model: string;
  car_id: string | null;
};

type SessionFormProps = {
  initial?: Partial<ChargingSession>;
  cars: Car[];
  submitLabel: string;
  onSubmit: (values: SessionFormValues) => Promise<void>;
};

function defaultDateTimeLocal(): string {
  return isoToDateTimeLocal(new Date().toISOString());
}

export function SessionForm({
  initial,
  cars,
  submitLabel,
  onSubmit,
}: SessionFormProps) {
  const [location, setLocation] = useState(initial?.charging_location ?? '');
  const [chargerId, setChargerId] = useState(initial?.charger_id ?? '');
  const [network, setNetwork] = useState(initial?.charging_network ?? '');
  const [chargerType, setChargerType] = useState(
    normalizeChargerType(initial?.charger_type ?? 'Others'),
  );
  const [power, setPower] = useState(
    initial?.charger_power_kw ? String(initial.charger_power_kw) : '',
  );
  const [startLocal, setStartLocal] = useState(
    initial?.start_date
      ? isoToDateTimeLocal(initial.start_date)
      : defaultDateTimeLocal(),
  );
  const [endLocal, setEndLocal] = useState(
    initial?.end_date
      ? isoToDateTimeLocal(initial.end_date)
      : defaultDateTimeLocal(),
  );
  const [startSoc, setStartSoc] = useState(
    initial?.start_soc_percent ? String(initial.start_soc_percent) : '',
  );
  const [endSoc, setEndSoc] = useState(
    initial?.end_soc_percent ? String(initial.end_soc_percent) : '',
  );
  const [odometer, setOdometer] = useState(
    initial?.odometer_km ? String(initial.odometer_km) : '',
  );
  const [energy, setEnergy] = useState(
    initial?.energy_kwh ? String(initial.energy_kwh) : '',
  );
  const [amount, setAmount] = useState(
    initial?.amount_sgd ? String(initial.amount_sgd) : '',
  );
  const [durationMinutes, setDurationMinutes] = useState(
    initial?.session_duration_seconds
      ? String(Math.round(initial.session_duration_seconds / 60))
      : '',
  );
  const [idleMinutes, setIdleMinutes] = useState(
    initial?.idle_duration_seconds
      ? String(Math.round(initial.idle_duration_seconds / 60))
      : '',
  );
  const [carModel, setCarModel] = useState(initial?.car_model ?? '');
  const [carId, setCarId] = useState<string | null>(initial?.car_id ?? null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const carOptions = useMemo(
    () => [
      { label: 'None', value: '' },
      ...cars.map((car) => ({
        label: carDisplayName(car),
        value: car.id,
      })),
    ],
    [cars],
  );

  function handleCarChange(nextId: string) {
    setCarId(nextId || null);
    if (!nextId) return;
    const car = cars.find((item) => item.id === nextId);
    if (!car) return;
    if (!carModel.trim()) {
      setCarModel(carDisplayName(car));
    }
  }

  async function handleSubmit() {
    setError(null);

    if (!location.trim()) {
      setError('Charging location is required.');
      return;
    }

    const startIso = dateTimeLocalToIso(startLocal);
    const endIso = dateTimeLocalToIso(endLocal);
    if (!startIso || !endIso) {
      setError('Start and end date/time are required (YYYY-MM-DDTHH:mm).');
      return;
    }
    if (new Date(endIso).getTime() < new Date(startIso).getTime()) {
      setError('End must be at or after start.');
      return;
    }

    const parsedDurationMinutes = durationMinutes.trim()
      ? parseOptionalInt(durationMinutes)
      : Math.round(computeDurationSeconds(startIso, endIso) / 60);

    setSaving(true);
    try {
      await onSubmit({
        charging_location: location.trim(),
        charger_id: chargerId.trim() || 'UNKNOWN',
        charging_network: network.trim(),
        charger_type: normalizeChargerType(chargerType),
        charger_power_kw: parseOptionalNumber(power),
        start_date: startIso,
        end_date: endIso,
        start_soc_percent: parseOptionalNumber(startSoc),
        end_soc_percent: parseOptionalNumber(endSoc),
        odometer_km: parseOptionalNumber(odometer),
        energy_kwh: parseOptionalNumber(energy),
        amount_sgd: parseOptionalNumber(amount),
        session_duration_seconds: parsedDurationMinutes * 60,
        idle_duration_seconds: parseOptionalInt(idleMinutes) * 60,
        car_model: carModel.trim() || 'Unknown Car',
        car_id: carId,
      });
    } catch (err) {
      const message =
        err && typeof err === 'object' && 'message' in err
          ? String((err as { message: unknown }).message)
          : err instanceof Error
            ? err.message
            : 'Could not save session.';
      setError(message || 'Could not save session.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <View style={styles.form}>
      <Text style={styles.section}>Station</Text>
      <Field
        label="Charging location *"
        value={location}
        onChangeText={setLocation}
      />
      <Field label="Network" value={network} onChangeText={setNetwork} />
      <Field
        label="Charger ID"
        value={chargerId}
        onChangeText={setChargerId}
        autoCapitalize="characters"
      />
      <SelectField
        label="Charger type"
        value={chargerType}
        options={CHARGER_TYPE_OPTIONS.map((option) => ({
          label: option,
          value: option,
        }))}
        onChange={(value) => setChargerType(normalizeChargerType(value))}
      />
      <Field
        label="Power (kW)"
        keyboardType="decimal-pad"
        value={power}
        onChangeText={setPower}
      />

      <Text style={styles.section}>Timing</Text>
      <Field
        label="Start (YYYY-MM-DDTHH:mm) *"
        autoCapitalize="none"
        value={startLocal}
        onChangeText={setStartLocal}
        placeholder="2024-06-15T21:30"
      />
      <Field
        label="End (YYYY-MM-DDTHH:mm) *"
        autoCapitalize="none"
        value={endLocal}
        onChangeText={setEndLocal}
        placeholder="2024-06-15T23:10"
      />
      <Field
        label="Duration (minutes)"
        keyboardType="number-pad"
        value={durationMinutes}
        onChangeText={setDurationMinutes}
        placeholder="Auto from start/end if blank"
      />
      <Field
        label="Idle (minutes)"
        keyboardType="number-pad"
        value={idleMinutes}
        onChangeText={setIdleMinutes}
      />

      <Text style={styles.section}>Energy & cost</Text>
      <Field
        label="Start SOC (%)"
        keyboardType="decimal-pad"
        value={startSoc}
        onChangeText={setStartSoc}
      />
      <Field
        label="End SOC (%)"
        keyboardType="decimal-pad"
        value={endSoc}
        onChangeText={setEndSoc}
      />
      <Field
        label="Energy (kWh)"
        keyboardType="decimal-pad"
        value={energy}
        onChangeText={setEnergy}
      />
      <Field
        label="Cost (SGD)"
        keyboardType="decimal-pad"
        value={amount}
        onChangeText={setAmount}
      />
      <Field
        label="Odometer (km)"
        keyboardType="decimal-pad"
        value={odometer}
        onChangeText={setOdometer}
      />

      <Text style={styles.section}>Vehicle</Text>
      <SelectField
        label="Linked car"
        value={carId ?? ''}
        options={carOptions}
        onChange={handleCarChange}
      />
      <Field label="Car model label" value={carModel} onChangeText={setCarModel} />

      <ErrorText message={error} />
      <PrimaryButton label={submitLabel} loading={saving} onPress={handleSubmit} />
    </View>
  );
}

const styles = StyleSheet.create({
  form: {
    gap: 14,
  },
  section: {
    color: colors.accent,
    fontSize: 15,
    fontWeight: '700',
    marginTop: 8,
  },
});
