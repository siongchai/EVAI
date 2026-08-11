import { getSupabase } from '@/lib/supabase';

export type StorageBucket = 'avatars' | 'cars' | 'session-photos';

export function publicStorageUrl(
  bucket: StorageBucket,
  path: string | null | undefined,
): string | null {
  if (!path) return null;
  const { data } = getSupabase().storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}

export async function uploadUserImage(options: {
  bucket: StorageBucket;
  userId: string;
  fileName: string;
  uri: string;
}): Promise<string> {
  const response = await fetch(options.uri);
  const blob = await response.blob();
  const contentType = blob.type || 'image/jpeg';
  const extension = contentType.includes('png')
    ? 'png'
    : contentType.includes('webp')
      ? 'webp'
      : 'jpg';
  const path = `${options.userId}/${options.fileName}.${extension}`;

  const { error } = await getSupabase().storage
    .from(options.bucket)
    .upload(path, blob, {
      upsert: true,
      contentType,
      cacheControl: '3600',
    });

  if (error) throw error;
  return path;
}

export async function uploadSessionPhotos(options: {
  userId: string;
  captureId: string;
  uris: string[];
}): Promise<string[]> {
  const paths: string[] = [];
  for (let i = 0; i < options.uris.length; i += 1) {
    const uri = options.uris[i]!;
    const path = await uploadUserImage({
      bucket: 'session-photos',
      userId: options.userId,
      fileName: `captures/${options.captureId}/${String(i + 1).padStart(2, '0')}`,
      uri,
    });
    paths.push(path);
  }
  return paths;
}

export async function deleteStoragePath(
  bucket: StorageBucket,
  path: string | null | undefined,
): Promise<void> {
  if (!path) return;
  const { error } = await getSupabase().storage.from(bucket).remove([path]);
  if (error) throw error;
}
