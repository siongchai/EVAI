import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
} from 'react-native';
import { Stack, useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';

import { CarForm } from '@/components/CarForm';
import { ErrorText, PrimaryButton } from '@/components/ui';
import { colors } from '@/constants/theme';
import {
  deleteCar,
  getCar,
  updateCar,
  updateCarImage,
} from '@/lib/cars';
import { publicStorageUrl } from '@/lib/storage';
import type { Car } from '@/types/database';

export default function EditCarScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [car, setCar] = useState<Car | null>(null);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await getCar(id);
      if (!data) {
        setError('Car not found.');
        setCar(null);
        return;
      }
      setCar(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load car.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  async function handleDelete() {
    if (!car) return;

    const confirmed =
      Platform.OS === 'web'
        ? window.confirm('Delete this car permanently?')
        : await new Promise<boolean>((resolve) => {
            Alert.alert('Delete car', 'Delete this car permanently?', [
              { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
              {
                text: 'Delete',
                style: 'destructive',
                onPress: () => resolve(true),
              },
            ]);
          });

    if (!confirmed) return;

    setDeleting(true);
    setError(null);
    try {
      await deleteCar(car);
      router.replace('/(app)/cars');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete car.');
      setDeleting(false);
    }
  }

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Edit car' }} />

      {loading ? (
        <ActivityIndicator color={colors.accent} />
      ) : car ? (
        <>
          <CarForm
            key={car.id + car.updated_at}
            initial={car}
            initialImageUrl={publicStorageUrl('cars', car.image_path)}
            submitLabel="Save changes"
            onSubmit={async (values) => {
              const updated = await updateCar(car.id, {
                car_name: values.car_name,
                make: values.make,
                model_name: values.model_name,
                variant: values.variant,
                battery_size_kwh: values.battery_size_kwh,
                initial_odometer_km: values.initial_odometer_km,
                initial_soc_percent: values.initial_soc_percent,
                collection_date: values.collection_date,
                license_plate: values.license_plate,
                purchase_price_sgd: values.purchase_price_sgd,
                is_primary: values.is_primary,
              });

              const withImage = values.imageUri
                ? await updateCarImage(updated, values.imageUri)
                : updated;

              setCar(withImage);
              router.back();
            }}
          />
          <PrimaryButton
            label="Delete car"
            tone="danger"
            loading={deleting}
            onPress={handleDelete}
          />
        </>
      ) : (
        <Text style={styles.missing}>Car not found.</Text>
      )}

      <ErrorText message={error} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 16,
    padding: 24,
    paddingBottom: 48,
  },
  missing: {
    color: colors.textMuted,
    fontSize: 16,
  },
});
