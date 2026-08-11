import { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Image,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Link, Stack, useFocusEffect } from 'expo-router';

import {
  ErrorText,
  Field,
  PrimaryButton,
  SuccessText,
} from '@/components/ui';
import { colors } from '@/constants/theme';
import {
  changePassword,
  deleteOwnAccount,
  fetchProfile,
  updateProfileAvatar,
  updateProfileName,
} from '@/lib/profile';
import { pickImageFromLibrary } from '@/lib/imagePicker';
import { publicStorageUrl } from '@/lib/storage';
import { useAuth } from '@/providers/AuthProvider';
import type { Profile } from '@/types/database';

export default function AccountScreen() {
  const { user, signOut } = useAuth();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(true);
  const [savingName, setSavingName] = useState(false);
  const [savingAvatar, setSavingAvatar] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchProfile(user.id);
      setProfile(data);
      setFullName(data?.full_name ?? '');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load profile.');
    } finally {
      setLoading(false);
    }
  }, [user]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  const avatarUrl = publicStorageUrl('avatars', profile?.avatar_path);

  async function handleSaveName() {
    if (!user) return;
    setSavingName(true);
    setError(null);
    setSuccess(null);
    try {
      const updated = await updateProfileName(user.id, fullName);
      setProfile(updated);
      setSuccess('Profile name updated.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update name.');
    } finally {
      setSavingName(false);
    }
  }

  async function handleAvatar() {
    if (!user || !profile) return;
    const uri = await pickImageFromLibrary();
    if (!uri) return;

    setSavingAvatar(true);
    setError(null);
    setSuccess(null);
    try {
      const updated = await updateProfileAvatar(
        user.id,
        uri,
        profile.avatar_path,
      );
      setProfile(updated);
      setSuccess('Avatar updated.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not upload avatar.');
    } finally {
      setSavingAvatar(false);
    }
  }

  async function handlePassword() {
    setError(null);
    setSuccess(null);

    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    setSavingPassword(true);
    try {
      await changePassword(password);
      setPassword('');
      setConfirmPassword('');
      setSuccess('Password updated.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not change password.');
    } finally {
      setSavingPassword(false);
    }
  }

  async function confirmDelete() {
    const confirmed =
      Platform.OS === 'web'
        ? window.confirm(
            'Delete your account permanently? This removes your profile, cars, and uploaded images.',
          )
        : await new Promise<boolean>((resolve) => {
            Alert.alert(
              'Delete account',
              'This permanently deletes your account, cars, and uploaded images.',
              [
                { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
                {
                  text: 'Delete',
                  style: 'destructive',
                  onPress: () => resolve(true),
                },
              ],
            );
          });

    if (confirmed) {
      await handleDelete();
    }
  }

  async function handleDelete() {
    setDeleting(true);
    setError(null);
    try {
      await deleteOwnAccount();
      await signOut();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete account.');
      setDeleting(false);
    }
  }

  async function handleSignOut() {
    setError(null);
    try {
      await signOut();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign out failed.');
    }
  }

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Account' }} />

      {loading ? (
        <ActivityIndicator color={colors.accent} />
      ) : (
        <>
          <View style={styles.header}>
            <Pressable onPress={handleAvatar} style={styles.avatarButton}>
              {savingAvatar ? (
                <ActivityIndicator color={colors.accent} />
              ) : avatarUrl ? (
                <Image source={{ uri: avatarUrl }} style={styles.avatar} />
              ) : (
                <Text style={styles.avatarPlaceholder}>Add photo</Text>
              )}
            </Pressable>
            <View style={styles.headerText}>
              <Text style={styles.name}>{profile?.full_name || 'Unnamed'}</Text>
              <Text style={styles.email}>{user?.email}</Text>
            </View>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Profile</Text>
            <Field label="Full name" value={fullName} onChangeText={setFullName} />
            <PrimaryButton
              label="Save name"
              loading={savingName}
              onPress={handleSaveName}
            />
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Vehicles</Text>
            <Link href="/(app)/cars" asChild>
              <Pressable style={styles.linkCard}>
                <Text style={styles.linkTitle}>Manage cars</Text>
                <Text style={styles.linkBody}>
                  Add, edit, or remove vehicles on your account.
                </Text>
              </Pressable>
            </Link>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Legal</Text>
            <Link href="/(app)/privacy" asChild>
              <Pressable style={styles.linkCard}>
                <Text style={styles.linkTitle}>Privacy</Text>
                <Text style={styles.linkBody}>
                  How EVAi stores account, charging, and capture data.
                </Text>
              </Pressable>
            </Link>
          </View>

          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Security</Text>
            <Field
              label="New password"
              secureTextEntry
              value={password}
              onChangeText={setPassword}
            />
            <Field
              label="Confirm password"
              secureTextEntry
              value={confirmPassword}
              onChangeText={setConfirmPassword}
            />
            <PrimaryButton
              label="Update password"
              loading={savingPassword}
              onPress={handlePassword}
            />
          </View>

          <ErrorText message={error} />
          <SuccessText message={success} />

          <PrimaryButton label="Sign out" tone="muted" onPress={handleSignOut} />
          <PrimaryButton
            label="Delete account"
            tone="danger"
            loading={deleting}
            onPress={confirmDelete}
          />
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 20,
    padding: 24,
    paddingBottom: 48,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 16,
  },
  avatarButton: {
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    borderColor: colors.border,
    borderRadius: 40,
    borderWidth: 1,
    height: 80,
    justifyContent: 'center',
    overflow: 'hidden',
    width: 80,
  },
  avatar: {
    height: '100%',
    width: '100%',
  },
  avatarPlaceholder: {
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  headerText: {
    flex: 1,
    gap: 4,
  },
  name: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
  },
  email: {
    color: colors.textMuted,
    fontSize: 15,
  },
  section: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    gap: 12,
    padding: 16,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
  linkCard: {
    gap: 4,
  },
  linkTitle: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
  },
  linkBody: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
});
