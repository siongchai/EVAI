import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Stack, useRouter } from 'expo-router';

import { SessionForm } from '@/components/SessionForm';
import { ErrorText, PrimaryButton, SuccessText } from '@/components/ui';
import { colors } from '@/constants/theme';
import { listCars } from '@/lib/cars';
import { extractSessionFromImageUris, isExtractionConfigured } from '@/lib/extraction/extract';
import {
  formatConfidence,
  mapExtractionToSessionDraft,
} from '@/lib/extraction/mapToSession';
import { pickReceiptImages } from '@/lib/imagePicker';
import { createSession } from '@/lib/sessions';
import { uploadSessionPhotos } from '@/lib/storage';
import { useAuth } from '@/providers/AuthProvider';
import type { Car, ChargingSession } from '@/types/database';

type Phase = 'pick' | 'extracting' | 'review';

function makeCaptureId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

export default function CaptureSessionScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const [cars, setCars] = useState<Car[]>([]);
  const [phase, setPhase] = useState<Phase>('pick');
  const [imageUris, setImageUris] = useState<string[]>([]);
  const [draft, setDraft] = useState<Partial<ChargingSession> | null>(null);
  const [rawAi, setRawAi] = useState('');
  const [confidence, setConfidence] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const loadCars = useCallback(async () => {
    if (!user) return;
    try {
      setCars(await listCars(user.id));
    } catch {
      // non-fatal on capture screen
    }
  }, [user]);

  useEffect(() => {
    void loadCars();
  }, [loadCars]);

  async function handlePick() {
    setError(null);
    setInfo(null);
    const uris = await pickReceiptImages(5);
    if (uris.length === 0) return;
    setImageUris(uris);
    setDraft(null);
    setPhase('pick');
  }

  async function handleExtract() {
    if (!user) return;
    if (imageUris.length === 0) {
      setError('Pick at least one dashboard or receipt photo.');
      return;
    }
    if (!isExtractionConfigured()) {
      setError(
        'AI not configured. Add EXPO_PUBLIC_OPENAI_API_KEY and run `npm run extract-proxy`, or deploy the extract-session Edge Function.',
      );
      return;
    }

    setPhase('extracting');
    setError(null);
    setInfo(null);
    try {
      const result = await extractSessionFromImageUris(imageUris);
      const mapped = mapExtractionToSessionDraft(result.parsed);
      const primary = cars.find((car) => car.is_primary) ?? cars[0] ?? null;
      if (primary && !mapped.car_model) {
        mapped.car_model = [primary.make, primary.model_name, primary.variant]
          .filter(Boolean)
          .join(' ');
        mapped.car_id = primary.id;
      } else if (primary) {
        mapped.car_id = primary.id;
      }
      setDraft(mapped);
      setRawAi(result.raw);
      setConfidence(result.parsed.extraction_confidence);
      setPhase('review');
      setInfo(
        `Extracted with ${formatConfidence(result.parsed.extraction_confidence)} confidence. Review before saving.`,
      );
    } catch (err) {
      setPhase('pick');
      setError(
        err && typeof err === 'object' && 'message' in err
          ? String((err as { message: unknown }).message)
          : err instanceof Error
            ? err.message
            : 'Extraction failed.',
      );
    }
  }

  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Stack.Screen options={{ title: 'Capture' }} />

      <Text style={styles.title}>Capture charging session</Text>
      <Text style={styles.body}>
        Upload 1–5 photos (dashboard before/after + charging app/receipt). AI
        fills the form for review.
      </Text>

      <View style={styles.actions}>
        <PrimaryButton label="Choose photos" onPress={handlePick} />
        <PrimaryButton
          label={
            phase === 'extracting' ? 'Extracting…' : 'Extract with AI'
          }
          loading={phase === 'extracting'}
          disabled={imageUris.length === 0 || phase === 'extracting'}
          onPress={handleExtract}
        />
      </View>

      {imageUris.length > 0 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={styles.thumbs}>
            {imageUris.map((uri) => (
              <Image key={uri} source={{ uri }} style={styles.thumb} />
            ))}
          </View>
        </ScrollView>
      ) : (
        <Pressable onPress={handlePick} style={styles.emptyPick}>
          <Text style={styles.emptyPickText}>Tap to select photos</Text>
        </Pressable>
      )}

      <ErrorText message={error} />
      <SuccessText message={info} />

      {phase === 'extracting' ? (
        <View style={styles.loadingBox}>
          <ActivityIndicator color={colors.accent} size="large" />
          <Text style={styles.loadingText}>
            Reading screenshots with AI…
          </Text>
        </View>
      ) : null}

      {phase === 'review' && draft ? (
        <>
          <Text style={styles.section}>
            Review draft · confidence {formatConfidence(confidence)}
          </Text>
          <SessionForm
            key={`draft-${draft.start_date}-${draft.energy_kwh}`}
            initial={draft}
            cars={cars}
            submitLabel="Save session"
            onSubmit={async (values) => {
              if (!user) throw new Error('Not signed in.');

              let sourceImageIds = '';
              try {
                const paths = await uploadSessionPhotos({
                  userId: user.id,
                  captureId: makeCaptureId(),
                  uris: imageUris,
                });
                sourceImageIds = paths.join(',');
              } catch (uploadError) {
                // Still allow save if storage bucket isn't migrated yet
                console.warn('Session photo upload failed', uploadError);
              }

              await createSession({
                user_id: user.id,
                ...values,
                extraction_confidence: confidence ?? 0,
                raw_ai_response: rawAi,
                source_image_ids: sourceImageIds,
              });

              router.replace('/(app)/sessions');
            }}
          />
        </>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    backgroundColor: colors.background,
    flex: 1,
  },
  content: {
    gap: 16,
    padding: 24,
    paddingBottom: 48,
  },
  title: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '700',
  },
  body: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  actions: {
    gap: 10,
  },
  thumbs: {
    flexDirection: 'row',
    gap: 10,
  },
  thumb: {
    borderRadius: 12,
    height: 96,
    width: 96,
  },
  emptyPick: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderStyle: 'dashed',
    borderWidth: 1,
    justifyContent: 'center',
    minHeight: 120,
    padding: 20,
  },
  emptyPickText: {
    color: colors.textMuted,
    fontWeight: '600',
  },
  loadingBox: {
    alignItems: 'center',
    gap: 12,
    paddingVertical: 24,
  },
  loadingText: {
    color: colors.textMuted,
  },
  section: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
    marginTop: 8,
  },
});
