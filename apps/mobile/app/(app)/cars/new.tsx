import { ScrollView, StyleSheet } from 'react-native';
import { Stack, useRouter } from 'expo-router';

import { CarForm } from '@/components/CarForm';
import { colors } from '@/constants/theme';
import { createCar, updateCarImage } from '@/lib/cars';
import { useAuth } from '@/providers/AuthProvider';

export default function NewCarScreen() {
  const { user } = useAuth();
  const router = useRouter();

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Add car' }} />
      <CarForm
        submitLabel="Create car"
        onSubmit={async (values) => {
          if (!user) throw new Error('Not signed in.');

          const car = await createCar({
            user_id: user.id,
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

          if (values.imageUri) {
            await updateCarImage(car, values.imageUri);
          }

          router.replace(`/(app)/cars/${car.id}`);
        }}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    padding: 24,
    paddingBottom: 48,
  },
});
