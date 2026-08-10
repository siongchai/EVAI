import { useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';

import {
  ErrorText,
  Field,
  PrimaryButton,
  SwitchField,
} from '@/components/ui';
import { colors } from '@/constants/theme';
import { parseOptionalNumber } from '@/lib/cars';
import { pickImageFromLibrary } from '@/lib/imagePicker';
import type { Car } from '@/types/database';

export type CarFormValues = {
  car_name: string;
  make: string;
  model_name: string;
  variant: string;
  battery_size_kwh: number;
  initial_odometer_km: number;
  initial_soc_percent: number;
  collection_date: string | null;
  license_plate: string;
  purchase_price_sgd: number;
  is_primary: boolean;
  imageUri: string | null;
};

type CarFormProps = {
  initial?: Partial<Car>;
  initialImageUrl?: string | null;
  submitLabel: string;
  onSubmit: (values: CarFormValues) => Promise<void>;
};

export function CarForm({
  initial,
  initialImageUrl,
  submitLabel,
  onSubmit,
}: CarFormProps) {
  const [carName, setCarName] = useState(initial?.car_name ?? '');
  const [make, setMake] = useState(initial?.make ?? '');
  const [modelName, setModelName] = useState(initial?.model_name ?? '');
  const [variant, setVariant] = useState(initial?.variant ?? '');
  const [battery, setBattery] = useState(
    initial?.battery_size_kwh ? String(initial.battery_size_kwh) : '',
  );
  const [odometer, setOdometer] = useState(
    initial?.initial_odometer_km ? String(initial.initial_odometer_km) : '',
  );
  const [soc, setSoc] = useState(
    initial?.initial_soc_percent ? String(initial.initial_soc_percent) : '',
  );
  const [collectionDate, setCollectionDate] = useState(
    initial?.collection_date ?? '',
  );
  const [licensePlate, setLicensePlate] = useState(initial?.license_plate ?? '');
  const [purchasePrice, setPurchasePrice] = useState(
    initial?.purchase_price_sgd ? String(initial.purchase_price_sgd) : '',
  );
  const [isPrimary, setIsPrimary] = useState(initial?.is_primary ?? false);
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const preview = imageUri ?? initialImageUrl ?? null;

  async function handlePickImage() {
    const uri = await pickImageFromLibrary();
    if (uri) setImageUri(uri);
  }

  async function handleSubmit() {
    setError(null);

    if (!make.trim() || !modelName.trim()) {
      setError('Make and model are required.');
      return;
    }

    setSaving(true);
    try {
      await onSubmit({
        car_name: carName.trim(),
        make: make.trim(),
        model_name: modelName.trim(),
        variant: variant.trim(),
        battery_size_kwh: parseOptionalNumber(battery),
        initial_odometer_km: parseOptionalNumber(odometer),
        initial_soc_percent: parseOptionalNumber(soc),
        collection_date: collectionDate.trim() || null,
        license_plate: licensePlate.trim(),
        purchase_price_sgd: parseOptionalNumber(purchasePrice),
        is_primary: isPrimary,
        imageUri,
      });
    } catch (err) {
      const message =
        err && typeof err === 'object' && 'message' in err
          ? String((err as { message: unknown }).message)
          : err instanceof Error
            ? err.message
            : 'Could not save car.';
      setError(message || 'Could not save car.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <View style={styles.form}>
      <Pressable onPress={handlePickImage} style={styles.imagePicker}>
        {preview ? (
          <Image source={{ uri: preview }} style={styles.image} />
        ) : (
          <Text style={styles.imagePlaceholder}>Add photo</Text>
        )}
      </Pressable>

      <Field label="Nickname" value={carName} onChangeText={setCarName} />
      <Field label="Make *" value={make} onChangeText={setMake} />
      <Field label="Model *" value={modelName} onChangeText={setModelName} />
      <Field label="Variant" value={variant} onChangeText={setVariant} />
      <Field
        label="Battery size (kWh)"
        keyboardType="decimal-pad"
        value={battery}
        onChangeText={setBattery}
      />
      <Field
        label="Initial odometer (km)"
        keyboardType="decimal-pad"
        value={odometer}
        onChangeText={setOdometer}
      />
      <Field
        label="Initial SOC (%)"
        keyboardType="decimal-pad"
        value={soc}
        onChangeText={setSoc}
      />
      <Field
        label="Collection date (YYYY-MM-DD)"
        autoCapitalize="none"
        value={collectionDate}
        onChangeText={setCollectionDate}
        placeholder="2024-01-15"
      />
      <Field
        label="License plate"
        autoCapitalize="characters"
        value={licensePlate}
        onChangeText={setLicensePlate}
      />
      <Field
        label="Purchase price (SGD)"
        keyboardType="decimal-pad"
        value={purchasePrice}
        onChangeText={setPurchasePrice}
      />
      <SwitchField
        label="Primary vehicle"
        value={isPrimary}
        onValueChange={setIsPrimary}
      />

      <ErrorText message={error} />
      <PrimaryButton label={submitLabel} loading={saving} onPress={handleSubmit} />
    </View>
  );
}

const styles = StyleSheet.create({
  form: {
    gap: 14,
  },
  imagePicker: {
    alignItems: 'center',
    alignSelf: 'center',
    backgroundColor: colors.surfaceElevated,
    borderColor: colors.border,
    borderRadius: 64,
    borderWidth: 1,
    height: 120,
    justifyContent: 'center',
    marginBottom: 8,
    overflow: 'hidden',
    width: 120,
  },
  image: {
    height: '100%',
    width: '100%',
  },
  imagePlaceholder: {
    color: colors.textMuted,
    fontWeight: '600',
  },
});
