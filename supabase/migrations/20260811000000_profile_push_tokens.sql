-- Phase 6: optional Expo push token + notification preference on profiles

alter table public.profiles
  add column if not exists expo_push_token text,
  add column if not exists notifications_enabled boolean not null default false;

comment on column public.profiles.expo_push_token is
  'Expo push token for native devices when monthly/remote notifications are enabled';
comment on column public.profiles.notifications_enabled is
  'User opted into push/local notification features on a native client';
