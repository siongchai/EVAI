import { getSupabase } from '@/lib/supabase';

export function publicStorageUrl(
  bucket: 'avatars' | 'cars',
  path: string | null | undefined,
): string | null {
  if (!path) return null;
  const { data } = getSupabase().storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}

export async function uploadUserImage(options: {
  bucket: 'avatars' | 'cars';
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

export async function deleteStoragePath(
  bucket: 'avatars' | 'cars',
  path: string | null | undefined,
): Promise<void> {
  if (!path) return;
  const { error } = await getSupabase().storage.from(bucket).remove([path]);
  if (error) throw error;
}
