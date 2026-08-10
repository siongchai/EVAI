-- Fix: table existed but API roles lacked privileges (42501 permission denied)

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on table public.cars to authenticated;
grant select on table public.cars to anon;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select on table public.profiles to anon;
