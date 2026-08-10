import { getSupabase } from '@/lib/supabase';
import { deleteStoragePath, uploadUserImage } from '@/lib/storage';
import type { Profile } from '@/types/database';

export async function fetchProfile(userId: string): Promise<Profile | null> {
  const { data, error } = await getSupabase()
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function updateProfileName(
  userId: string,
  fullName: string,
): Promise<Profile> {
  const { data, error } = await getSupabase()
    .from('profiles')
    .update({ full_name: fullName.trim() })
    .eq('id', userId)
    .select('*')
    .single();

  if (error) throw error;
  return data;
}

export async function updateProfileAvatar(
  userId: string,
  imageUri: string,
  previousPath?: string | null,
): Promise<Profile> {
  const path = await uploadUserImage({
    bucket: 'avatars',
    userId,
    fileName: 'avatar',
    uri: imageUri,
  });

  const { data, error } = await getSupabase()
    .from('profiles')
    .update({ avatar_path: path })
    .eq('id', userId)
    .select('*')
    .single();

  if (error) throw error;

  if (previousPath && previousPath !== path) {
    await deleteStoragePath('avatars', previousPath).catch(() => undefined);
  }

  return data;
}

export async function changePassword(newPassword: string): Promise<void> {
  const { error } = await getSupabase().auth.updateUser({
    password: newPassword,
  });
  if (error) throw error;
}

export async function deleteOwnAccount(): Promise<void> {
  const { error } = await getSupabase().rpc('delete_own_account');
  if (error) throw error;
}
