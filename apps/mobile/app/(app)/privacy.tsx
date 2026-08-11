import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { Stack } from 'expo-router';

import { colors } from '@/constants/theme';

const SECTIONS = [
  {
    title: 'What EVAi stores',
    body: 'Your account email and profile details, vehicles, charging sessions, uploaded avatars/car photos, and optional receipt screenshots used for AI extraction. Session analytics are computed from your own charging data.',
  },
  {
    title: 'Where data lives',
    body: 'Account and session data are stored in Supabase (Postgres + Storage) for your signed-in user only, protected with row-level security. Auth sessions are kept on device with secure storage on native apps and browser storage on web.',
  },
  {
    title: 'AI extraction',
    body: 'When you use Capture, selected images are sent to an AI provider (OpenAI or Anthropic) through a server-side proxy/Edge Function so API keys are not required in the browser for production. Raw model responses may be saved on the session for review. Do not upload images that contain unrelated personal information you do not want processed.',
  },
  {
    title: 'Permissions',
    body: 'EVAi may request photo library or camera access to capture receipts and profile/car images, and file access to import or export Excel charging logs. These permissions are optional for basic account use.',
  },
  {
    title: 'Sharing & third parties',
    body: 'EVAi does not sell your charging history. Data is shared with infrastructure providers needed to run the app (Supabase for auth/database/storage, and the AI provider you configure for extraction).',
  },
  {
    title: 'Your controls',
    body: 'You can edit profile details, delete cars or sessions, export Excel logs, and delete your account from Account. Account deletion removes your auth user and cascaded app data subject to provider retention policies.',
  },
  {
    title: 'Contact',
    body: 'For privacy questions about this EVAi deployment, contact the project owner who operates your Supabase/Vercel project.',
  },
] as const;

export default function PrivacyScreen() {
  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
    >
      <Stack.Screen options={{ title: 'Privacy' }} />
      <Text style={styles.title}>Privacy</Text>
      <Text style={styles.subtitle}>
        How EVAi handles account, charging, and capture data.
      </Text>
      {SECTIONS.map((section) => (
        <View key={section.title} style={styles.card}>
          <Text style={styles.cardTitle}>{section.title}</Text>
          <Text style={styles.cardBody}>{section.body}</Text>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 14,
    padding: 24,
    paddingBottom: 48,
  },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 4,
  },
  card: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    gap: 8,
    padding: 16,
  },
  cardTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
  },
  cardBody: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 21,
  },
});
