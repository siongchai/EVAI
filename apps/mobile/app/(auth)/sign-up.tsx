import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { AuthForm } from '@/components/AuthForm';
import { colors } from '@/constants/theme';
import { useAuth } from '@/providers/AuthProvider';

export default function SignUpScreen() {
  const { signUp } = useAuth();

  return (
    <View style={styles.container}>
      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.subtitle}>Create your account</Text>
      <Text style={styles.title}>Sign up</Text>

      <AuthForm
        mode="sign-up"
        submitLabel="Create account"
        onSubmit={({ email, password, fullName }) =>
          signUp(email, password, fullName)
        }
      />

      <Text style={styles.footer}>
        Already have an account?{' '}
        <Link href="/(auth)/sign-in" style={styles.link}>
          Sign in
        </Link>
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.background,
    flex: 1,
    justifyContent: 'center',
    padding: 24,
  },
  brand: {
    color: colors.accent,
    fontSize: 42,
    fontWeight: '800',
    letterSpacing: 1,
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 15,
    marginBottom: 28,
    marginTop: 6,
  },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 20,
  },
  footer: {
    color: colors.textMuted,
    fontSize: 15,
    marginTop: 20,
    textAlign: 'center',
  },
  link: {
    color: colors.accent,
    fontWeight: '700',
  },
});
