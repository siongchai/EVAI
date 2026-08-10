-- Phase 2: charging sessions table + RLS

create table if not exists public.charging_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  car_id uuid references public.cars (id) on delete set null,
  charging_location text not null default '',
  charger_id text not null default '',
  charging_network text not null default '',
  charger_type text not null default 'Others',
  charger_power_kw double precision not null default 0,
  start_date timestamptz not null,
  end_date timestamptz not null,
  start_soc_percent double precision not null default 0,
  end_soc_percent double precision not null default 0,
  odometer_km double precision not null default 0,
  energy_kwh double precision not null default 0,
  amount_sgd double precision not null default 0,
  session_duration_seconds integer not null default 0,
  idle_duration_seconds integer not null default 0,
  car_model text not null default '',
  extraction_confidence double precision not null default 0,
  raw_ai_response text not null default '',
  source_image_ids text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint charging_sessions_end_after_start check (end_date >= start_date)
);

create index if not exists charging_sessions_user_id_idx
  on public.charging_sessions (user_id);

create index if not exists charging_sessions_user_start_idx
  on public.charging_sessions (user_id, start_date desc);

create index if not exists charging_sessions_car_id_idx
  on public.charging_sessions (car_id);

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table public.charging_sessions to authenticated;
grant select on table public.charging_sessions to anon;

alter table public.charging_sessions enable row level security;

drop policy if exists "Users can view own charging sessions" on public.charging_sessions;
create policy "Users can view own charging sessions"
  on public.charging_sessions
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own charging sessions" on public.charging_sessions;
create policy "Users can insert own charging sessions"
  on public.charging_sessions
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own charging sessions" on public.charging_sessions;
create policy "Users can update own charging sessions"
  on public.charging_sessions
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own charging sessions" on public.charging_sessions;
create policy "Users can delete own charging sessions"
  on public.charging_sessions
  for delete
  using (auth.uid() = user_id);

drop trigger if exists charging_sessions_set_updated_at on public.charging_sessions;

create trigger charging_sessions_set_updated_at
  before update on public.charging_sessions
  for each row
  execute function public.set_updated_at();
