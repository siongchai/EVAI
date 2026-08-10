-- Fix: ensure API roles have privileges on charging_sessions

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on table public.charging_sessions to authenticated;
grant select on table public.charging_sessions to anon;
