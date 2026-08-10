import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Link, Stack, useFocusEffect, useRouter } from 'expo-router';

import { ErrorText, PrimaryButton } from '@/components/ui';
import { colors } from '@/constants/theme';
import { carDisplayName, listCars } from '@/lib/cars';
import { publicStorageUrl } from '@/lib/storage';
import { useAuth } from '@/providers/AuthProvider';
import type { Car } from '@/types/database';

export default function CarsScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const [cars, setCars] = useState<Car[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      setCars(await listCars(user.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load cars.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  return (
    <View style={styles.container}>
      <Stack.Screen
        options={{
          title: 'Cars',
          headerRight: () => (
            <Link href="/(app)/cars/new" asChild>
              <Pressable>
                <Text style={styles.headerAction}>Add</Text>
              </Pressable>
            </Link>
          ),
        }}
      />

      {loading ? (
        <ActivityIndicator color={colors.accent} style={styles.loader} />
      ) : (
        <FlatList
          data={cars}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.list}
          ListHeaderComponent={
            <View style={styles.headerBlock}>
              <ErrorText message={error} />
              <PrimaryButton
                label="Add car"
                onPress={() => router.push('/(app)/cars/new')}
              />
            </View>
          }
          ListEmptyComponent={
            <Text style={styles.empty}>
              No cars yet. Add your first EV to get started.
            </Text>
          }
          renderItem={({ item }) => {
            const imageUrl = publicStorageUrl('cars', item.image_path);
            return (
              <Link href={`/(app)/cars/${item.id}`} asChild>
                <Pressable style={styles.card}>
                  {imageUrl ? (
                    <Image source={{ uri: imageUrl }} style={styles.thumb} />
                  ) : (
                    <View style={[styles.thumb, styles.thumbPlaceholder]}>
                      <Text style={styles.thumbText}>EV</Text>
                    </View>
                  )}
                  <View style={styles.cardBody}>
                    <Text style={styles.cardTitle}>{carDisplayName(item)}</Text>
                    <Text style={styles.cardMeta}>
                      {[item.make, item.model_name, item.variant]
                        .filter(Boolean)
                        .join(' ')}
                    </Text>
                    {item.is_primary ? (
                      <Text style={styles.badge}>Primary</Text>
                    ) : null}
                  </View>
                </Pressable>
              </Link>
            );
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
  },
  loader: {
    marginTop: 40,
  },
  list: {
    gap: 12,
    padding: 24,
    paddingBottom: 48,
  },
  headerBlock: {
    gap: 12,
    marginBottom: 8,
  },
  headerAction: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
    paddingHorizontal: 8,
  },
  empty: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: 12,
  },
  card: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 14,
    padding: 14,
  },
  thumb: {
    borderRadius: 12,
    height: 64,
    width: 64,
  },
  thumbPlaceholder: {
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    justifyContent: 'center',
  },
  thumbText: {
    color: colors.textMuted,
    fontWeight: '700',
  },
  cardBody: {
    flex: 1,
    gap: 4,
  },
  cardTitle: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '700',
  },
  cardMeta: {
    color: colors.textMuted,
    fontSize: 14,
  },
  badge: {
    alignSelf: 'flex-start',
    color: colors.accent,
    fontSize: 12,
    fontWeight: '700',
    marginTop: 4,
    textTransform: 'uppercase',
  },
});
