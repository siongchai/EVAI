-- Phase 1: cars table, storage buckets, account deletion helper

create table if not exists public.cars (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  car_name text not null default '',
  make text not null default '',
  model_name text not null default '',
  variant text not null default '',
  battery_size_kwh double precision not null default 0,
  initial_odometer_km double precision not null default 0,
  initial_soc_percent double precision not null default 0,
  collection_date date,
  license_plate text not null default '',
  purchase_price_sgd double precision not null default 0,
  is_primary boolean not null default false,
  image_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists cars_user_id_idx on public.cars (user_id);
create index if not exists cars_user_primary_idx on public.cars (user_id, is_primary);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table public.cars to authenticated;
grant select on table public.cars to anon;

alter table public.cars enable row level security;

drop policy if exists "Users can view own cars" on public.cars;
create policy "Users can view own cars"
  on public.cars
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own cars" on public.cars;
create policy "Users can insert own cars"
  on public.cars
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own cars" on public.cars;
create policy "Users can update own cars"
  on public.cars
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own cars" on public.cars;
create policy "Users can delete own cars"
  on public.cars
  for delete
  using (auth.uid() = user_id);

drop trigger if exists cars_set_updated_at on public.cars;

create trigger cars_set_updated_at
  before update on public.cars
  for each row
  execute function public.set_updated_at();

-- Keep at most one primary car per user
create or replace function public.ensure_single_primary_car()
returns trigger
language plpgsql
as $$
begin
  if new.is_primary then
    update public.cars
    set is_primary = false
    where user_id = new.user_id
      and id <> new.id
      and is_primary = true;
  end if;
  return new;
end;
$$;

drop trigger if exists cars_ensure_single_primary on public.cars;

create trigger cars_ensure_single_primary
  before insert or update of is_primary on public.cars
  for each row
  when (new.is_primary = true)
  execute function public.ensure_single_primary_car();

-- Storage buckets (public read; write scoped to own folder)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('cars', 'cars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
create policy "Avatar images are publicly readable"
  on storage.objects
  for select
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload own avatar" on storage.objects;
create policy "Users can upload own avatar"
  on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can update own avatar" on storage.objects;
create policy "Users can update own avatar"
  on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can delete own avatar" on storage.objects;
create policy "Users can delete own avatar"
  on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Car images are publicly readable" on storage.objects;
create policy "Car images are publicly readable"
  on storage.objects
  for select
  using (bucket_id = 'cars');

drop policy if exists "Users can upload own car images" on storage.objects;
create policy "Users can upload own car images"
  on storage.objects
  for insert
  with check (
    bucket_id = 'cars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can update own car images" on storage.objects;
create policy "Users can update own car images"
  on storage.objects
  for update
  using (
    bucket_id = 'cars'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'cars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can delete own car images" on storage.objects;
create policy "Users can delete own car images"
  on storage.objects
  for delete
  using (
    bucket_id = 'cars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Deletes the signed-in auth user (cascades profile/cars)
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from storage.objects
  where bucket_id in ('avatars', 'cars')
    and (storage.foldername(name))[1] = uid::text;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
