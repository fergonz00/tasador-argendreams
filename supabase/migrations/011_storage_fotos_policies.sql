-- Migration 011 — Políticas de Storage para el bucket argendreams-fotos
--
-- Problema: el bucket es público para LEER, pero no tenía ninguna política que
-- permitiera SUBIR objetos con la publishable/anon key. Toda subida de fotos
-- (wizard del vendedor y fotos del peritaje del admin) fallaba con:
--   403 Unauthorized — "new row violates row-level security policy"
--
-- Fix: políticas permisivas de insert/select/update sobre storage.objects
-- acotadas al bucket. Mismo modelo de seguridad que el resto de la app
-- (RLS OFF en tablas, control client-side). NO se agrega DELETE a propósito
-- (la app no borra de storage; las fotos viejas quedan).
--
-- Corrida en Supabase (proyecto xcijbomhvwwlzgmazvep) el 2026-06-04.

drop policy if exists "argendreams_fotos_insert" on storage.objects;
create policy "argendreams_fotos_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'argendreams-fotos');

drop policy if exists "argendreams_fotos_select" on storage.objects;
create policy "argendreams_fotos_select"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'argendreams-fotos');

drop policy if exists "argendreams_fotos_update" on storage.objects;
create policy "argendreams_fotos_update"
  on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'argendreams-fotos')
  with check (bucket_id = 'argendreams-fotos');
