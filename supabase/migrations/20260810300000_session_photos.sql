-- Phase 3: receipt / capture photo storage

insert into storage.buckets (id, name, public)
values ('session-photos', 'session-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Session photos are publicly readable" on storage.objects;
create policy "Session photos are publicly readable"
  on storage.objects
  for select
  using (bucket_id = 'session-photos');

drop policy if exists "Users can upload own session photos" on storage.objects;
create policy "Users can upload own session photos"
  on storage.objects
  for insert
  with check (
    bucket_id = 'session-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can update own session photos" on storage.objects;
create policy "Users can update own session photos"
  on storage.objects
  for update
  using (
    bucket_id = 'session-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'session-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Users can delete own session photos" on storage.objects;
create policy "Users can delete own session photos"
  on storage.objects
  for delete
  using (
    bucket_id = 'session-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
