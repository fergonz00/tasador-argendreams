-- ═══════════════════════════════════════════════════════════════════
-- Migration 004 — Reventa ganadora
-- Guarda qué reventa fue seleccionada (mejor precio) cuando el admin
-- envía el precio al vendedor. Sirve para avisarle a esa reventa que su
-- oferta fue elegida y, al cerrarse como TOMADA, que el usado se toma a
-- su precio como parte de pago.
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS reventa_ganadora_id UUID REFERENCES usuarios(id);
