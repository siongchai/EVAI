import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack } from 'expo-router';

import { colors } from '@/constants/theme';
import { getSupabase } from '@/lib/supabase';
import { useAuth } from '@/providers/AuthProvider';
import type { Profile } from '@/types/database';

export default function HomeScreen() {
  const { user, signOut } = useAuth();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    if (!user) return;

    let cancelled = false;

    (async () => {
      const { data, error: profileError } = await getSupabase()
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();

      if (cancelled) return;

      if (profileError) {
        setError(profileError.message);
        return;
      }

      setProfile(data);
    })();

    return () => {
      cancelled = true;
    };
  }, [user]);

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

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Home' }} />
      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.title}>Phase 0 shell</Text>
      <Text style={styles.body}>
        Web, iOS, and Android share this Expo app. Auth and profile loading are
        wired to Supabase.
      </Text>

      <View style={styles.card}>
        <Text style={styles.label}>Signed in as</Text>
        <Text style={styles.value}>{user?.email ?? '—'}</Text>
        <Text style={[styles.label, styles.spacer]}>Profile name</Text>
        {profile ? (
          <Text style={styles.value}>{profile.full_name || 'Unnamed'}</Text>
        ) : error ? (
          <Text style={styles.error}>{error}</Text>
        ) : (
          <ActivityIndicator color={colors.accent} />
        )}
      </View>

      <Pressable
        disabled={signingOut}
        onPress={handleSignOut}
        style={({ pressed }) => [
          styles.button,
          (pressed || signingOut) && styles.buttonPressed,
        ]}
      >
        {signingOut ? (
          <ActivityIndicator color={colors.text} />
        ) : (
          <Text style={styles.buttonText}>Sign out</Text>
        )}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
    gap: 16,
    padding: 24,
    paddingTop: 64,
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
    gap: 8,
    marginTop: 8,
    padding: 20,
  },
  label: {
    color: colors.textMuted,
    fontSize: 13,
    textTransform: 'uppercase',
  },
  value: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '600',
  },
  spacer: {
    marginTop: 12,
  },
  error: {
    color: colors.danger,
  },
  button: {
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    marginTop: 'auto',
    paddingVertical: 14,
  },
  buttonPressed: {
    opacity: 0.85,
  },
  buttonText: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
});
