-- ═══════════════════════════════════════════════════════════════════
-- Migration 006 — Reventa final + aceptación del cliente
-- El precio al cliente (precio_final_admin) queda fijo. Al confirmar la toma,
-- el admin elige la reventa que efectivamente se lleva el usado (puede ser
-- otra que pague más). Margen = reventa_final_precio - precio_final_admin.
--   cliente_acepto       → el vendedor/admin marca que el cliente aceptó el precio
--   reventa_final_id     → reventa a la que se le asigna el usado (la notificada)
--   reventa_final_precio → lo que paga esa reventa (snapshot al confirmar)
-- (reventa_ganadora_id de la migration 004 queda como REFERENCIA del precio.)
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS cliente_acepto       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reventa_final_id     UUID REFERENCES usuarios(id),
  ADD COLUMN IF NOT EXISTS reventa_final_precio NUMERIC;
