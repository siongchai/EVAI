import { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { colors } from '@/constants/theme';

type AuthFormProps = {
  mode: 'sign-in' | 'sign-up';
  submitLabel: string;
  onSubmit: (values: {
    email: string;
    password: string;
    fullName: string;
  }) => Promise<void>;
};

export function AuthForm({ mode, submitLabel, onSubmit }: AuthFormProps) {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit() {
    setError(null);
    setInfo(null);

    if (!email.trim() || !password) {
      setError('Email and password are required.');
      return;
    }

    if (mode === 'sign-up' && !fullName.trim()) {
      setError('Full name is required.');
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }

    setSubmitting(true);
    try {
      await onSubmit({ email, password, fullName });
      if (mode === 'sign-up') {
        setInfo(
          'Account created. If email confirmation is enabled in Supabase, check your inbox before signing in.',
        );
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <View style={styles.form}>
      {mode === 'sign-up' ? (
        <TextInput
          autoCapitalize="words"
          placeholder="Full name"
          placeholderTextColor={colors.textMuted}
          style={styles.input}
          value={fullName}
          onChangeText={setFullName}
        />
      ) : null}

      <TextInput
        autoCapitalize="none"
        autoComplete="email"
        keyboardType="email-address"
        placeholder="Email"
        placeholderTextColor={colors.textMuted}
        style={styles.input}
        value={email}
        onChangeText={setEmail}
      />

      <TextInput
        autoCapitalize="none"
        autoComplete={mode === 'sign-up' ? 'new-password' : 'password'}
        placeholder="Password"
        placeholderTextColor={colors.textMuted}
        secureTextEntry
        style={styles.input}
        value={password}
        onChangeText={setPassword}
      />

      {error ? <Text style={styles.error}>{error}</Text> : null}
      {info ? <Text style={styles.info}>{info}</Text> : null}

      <Pressable
        disabled={submitting}
        onPress={handleSubmit}
        style={({ pressed }) => [
          styles.button,
          (pressed || submitting) && styles.buttonPressed,
        ]}
      >
        {submitting ? (
          <ActivityIndicator color={colors.text} />
        ) : (
          <Text style={styles.buttonText}>{submitLabel}</Text>
        )}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  form: {
    gap: 12,
    width: '100%',
  },
  input: {
    backgroundColor: colors.inputBackground,
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    color: colors.text,
    fontSize: 16,
    paddingHorizontal: 14,
    paddingVertical: 14,
  },
  button: {
    alignItems: 'center',
    backgroundColor: colors.accent,
    borderRadius: 12,
    marginTop: 8,
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
  error: {
    color: colors.danger,
    fontSize: 14,
  },
  info: {
    color: colors.success,
    fontSize: 14,
  },
});
