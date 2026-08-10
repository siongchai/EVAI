import { getSupabase } from '@/lib/supabase';
import { deleteStoragePath, uploadUserImage } from '@/lib/storage';
import type { Car, CarInsert, CarUpdate } from '@/types/database';

export function carDisplayName(car: Pick<Car, 'car_name' | 'make' | 'model_name' | 'variant'>) {
  const named = car.car_name.trim();
  if (named) return named;
  return [car.make, car.model_name, car.variant].filter(Boolean).join(' ').trim() || 'Untitled car';
}

export async function listCars(userId: string): Promise<Car[]> {
  const { data, error } = await getSupabase()
    .from('cars')
    .select('*')
    .eq('user_id', userId)
    .order('is_primary', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function getCar(carId: string): Promise<Car | null> {
  const { data, error } = await getSupabase()
    .from('cars')
    .select('*')
    .eq('id', carId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function createCar(
  input: Omit<CarInsert, 'id' | 'created_at' | 'updated_at'>,
): Promise<Car> {
  const { data, error } = await getSupabase()
    .from('cars')
    .insert(input)
    .select('*')
    .single();

  if (error) throw error;
  return data;
}

export async function updateCar(carId: string, input: CarUpdate): Promise<Car> {
  const { data, error } = await getSupabase()
    .from('cars')
    .update(input)
    .eq('id', carId)
    .select('*')
    .single();

  if (error) throw error;
  return data;
}

export async function deleteCar(car: Car): Promise<void> {
  const { error } = await getSupabase().from('cars').delete().eq('id', car.id);
  if (error) throw error;
  await deleteStoragePath('cars', car.image_path).catch(() => undefined);
}

export async function updateCarImage(
  car: Car,
  imageUri: string,
): Promise<Car> {
  const path = await uploadUserImage({
    bucket: 'cars',
    userId: car.user_id,
    fileName: car.id,
    uri: imageUri,
  });

  const updated = await updateCar(car.id, { image_path: path });

  if (car.image_path && car.image_path !== path) {
    await deleteStoragePath('cars', car.image_path).catch(() => undefined);
  }

  return updated;
}

export function parseOptionalNumber(value: string): number {
  const trimmed = value.trim();
  if (!trimmed) return 0;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : 0;
}
