import { Link } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { AuthForm } from '@/components/AuthForm';
import { colors } from '@/constants/theme';
import { useAuth } from '@/providers/AuthProvider';

export default function SignInScreen() {
  const { signIn } = useAuth();

  return (
    <View style={styles.container}>
      <Text style={styles.brand}>EVAi</Text>
      <Text style={styles.subtitle}>AI-powered EV charging analytics</Text>
      <Text style={styles.title}>Sign in</Text>

      <AuthForm
        mode="sign-in"
        submitLabel="Sign in"
        onSubmit={({ email, password }) => signIn(email, password)}
      />

      <Text style={styles.footer}>
        No account yet?{' '}
        <Link href="/(auth)/sign-up" style={styles.link}>
          Create one
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
