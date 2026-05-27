-- ═══════════════════════════════════════════════════════════════════
-- Migration 005 — Pedido de mejora dirigido por reventa
-- El admin elige a QUÉ reventas pedirles que mejoren su precio (no a todas).
-- mejora_solicitada=true en la fila de esa reventa → la reventa ve el aviso
-- "mejorá tu precio". Al actualizar su precio, vuelve a false.
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE reventas_precios
  ADD COLUMN IF NOT EXISTS mejora_solicitada BOOLEAN NOT NULL DEFAULT false;
