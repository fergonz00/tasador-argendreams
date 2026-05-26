-- Migración 002 — Agrega moneda al precio ofrecido al cliente
-- BYD se cotiza siempre en USD. Dejamos el campo por flexibilidad futura.
-- Correr en Dashboard → SQL Editor.

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS precio_ofrecido_moneda TEXT NOT NULL DEFAULT 'USD'
  CHECK (precio_ofrecido_moneda IN ('USD', 'ARS'));

-- Para las tasaciones existentes (si hay), las marca como USD por default (queda en el DEFAULT)
