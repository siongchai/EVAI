import { useCallback, useState } from 'react';
import { ScrollView, StyleSheet } from 'react-native';
import { Stack, useFocusEffect, useRouter } from 'expo-router';

import { SessionForm } from '@/components/SessionForm';
import { colors } from '@/constants/theme';
import { listCars } from '@/lib/cars';
import { createSession } from '@/lib/sessions';
import { useAuth } from '@/providers/AuthProvider';
import type { Car } from '@/types/database';

export default function NewSessionScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const [cars, setCars] = useState<Car[]>([]);

  useFocusEffect(
    useCallback(() => {
      if (!user) return;
      void listCars(user.id).then(setCars).catch(() => setCars([]));
    }, [user]),
  );

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Add session' }} />
      <SessionForm
        cars={cars}
        submitLabel="Create session"
        onSubmit={async (values) => {
          if (!user) throw new Error('Not signed in.');

          const session = await createSession({
            user_id: user.id,
            ...values,
            extraction_confidence: 1,
            raw_ai_response: '',
            source_image_ids: '',
          });

          router.replace(`/(app)/sessions/${session.id}`);
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
