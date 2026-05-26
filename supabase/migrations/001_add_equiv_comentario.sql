-- Migración 001 — Campo para comentario sobre el 0km equivalente
-- Permite al vendedor explicar por qué la sugerencia automática no coincide.
-- Correr en Dashboard → SQL Editor.

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS equiv_0km_comentario TEXT;
