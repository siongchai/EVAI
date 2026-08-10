import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Link, Stack, useFocusEffect } from 'expo-router';

import { ErrorText, PrimaryButton } from '@/components/ui';
import { colors } from '@/constants/theme';
import { listCars } from '@/lib/cars';
import { fetchProfile } from '@/lib/profile';
import { publicStorageUrl } from '@/lib/storage';
import { useAuth } from '@/providers/AuthProvider';
import type { Profile } from '@/types/database';

export default function HomeScreen() {
  const { user, signOut } = useAuth();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [carCount, setCarCount] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [signingOut, setSigningOut] = useState(false);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      const [nextProfile, cars] = await Promise.all([
        fetchProfile(user.id),
        listCars(user.id),
      ]);
      setProfile(nextProfile);
      setCarCount(cars.length);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load account.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  async function handleSignOut() {
    setSigningOut(true);
    setError(null);
    try {
      await signOut();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign out failed.');
      setSigningOut(false);
    }
  }

  const avatarUrl = publicStorageUrl('avatars', profile?.avatar_path);

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Home' }} />
      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.title}>Account ready</Text>
      <Text style={styles.body}>
        Manage your profile and vehicles. Sessions and capture come in the next
        phases.
      </Text>

      {loading ? (
        <ActivityIndicator color={colors.accent} />
      ) : (
        <View style={styles.card}>
          <View style={styles.row}>
            {avatarUrl ? (
              <Image source={{ uri: avatarUrl }} style={styles.avatar} />
            ) : (
              <View style={[styles.avatar, styles.avatarPlaceholder]}>
                <Text style={styles.avatarLetter}>
                  {(profile?.full_name || user?.email || '?')
                    .charAt(0)
                    .toUpperCase()}
                </Text>
              </View>
            )}
            <View style={styles.meta}>
              <Text style={styles.value}>{profile?.full_name || 'Unnamed'}</Text>
              <Text style={styles.label}>{user?.email}</Text>
              <Text style={styles.label}>
                {carCount} {carCount === 1 ? 'car' : 'cars'}
              </Text>
            </View>
          </View>
        </View>
      )}

      <Link href="/(app)/account" asChild>
        <Pressable style={styles.navCard}>
          <Text style={styles.navTitle}>Account</Text>
          <Text style={styles.navBody}>
            Edit name, avatar, password, or delete account.
          </Text>
        </Pressable>
      </Link>

      <Link href="/(app)/cars" asChild>
        <Pressable style={styles.navCard}>
          <Text style={styles.navTitle}>Cars</Text>
          <Text style={styles.navBody}>
            Add and manage the EVs on your account.
          </Text>
        </Pressable>
      </Link>

      <ErrorText message={error} />

      <PrimaryButton
        label="Sign out"
        tone="muted"
        loading={signingOut}
        onPress={handleSignOut}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
    gap: 16,
    padding: 24,
  },
  brand: {
    color: colors.accent,
    fontSize: 36,
    fontWeight: '800',
  },
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
  },
  body: {
    color: colors.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    padding: 16,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 14,
  },
  avatar: {
    borderRadius: 28,
    height: 56,
    width: 56,
  },
  avatarPlaceholder: {
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    justifyContent: 'center',
  },
  avatarLetter: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
  },
  meta: {
    flex: 1,
    gap: 4,
  },
  label: {
    color: colors.textMuted,
    fontSize: 14,
  },
  value: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
  navCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 6,
    padding: 16,
  },
  navTitle: {
    color: colors.accent,
    fontSize: 18,
    fontWeight: '700',
  },
  navBody: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
});
