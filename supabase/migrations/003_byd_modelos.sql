-- ═══════════════════════════════════════════════════════════════════
-- Migration 003 — Tabla byd_modelos (modelos BYD + precio de lista USD)
-- Reemplaza la lista hardcodeada en index.html. Editable desde la app
-- por el superadmin (fngonzalez) en el panel "Gestionar modelos BYD".
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS byd_modelos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  modelo        TEXT    NOT NULL,                 -- ej: DOLPHIN MINI 5P 75CV 55KW
  version       TEXT    NOT NULL,                 -- ej: GL / GS
  precio_lista  NUMERIC NOT NULL,                 -- precio de lista en USD
  activo        BOOLEAN NOT NULL DEFAULT true,    -- inactivo = no aparece en el wizard
  orden         INT     NOT NULL DEFAULT 0,       -- para ordenar la lista
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (modelo, version)
);

CREATE INDEX IF NOT EXISTS idx_byd_modelos_activo ON byd_modelos(activo, orden);

-- Trigger updated_at (reusa set_updated_at() creada en el schema inicial)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_byd_modelos_updated') THEN
    CREATE TRIGGER trg_byd_modelos_updated
      BEFORE UPDATE ON byd_modelos
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- Seed con los 8 modelos vigentes (precios USD de la hoja "precios vigentes")
INSERT INTO byd_modelos (modelo, version, precio_lista, orden) VALUES
  ('DOLPHIN MINI 5P 75CV 55KW',      'GL', 23990, 10),
  ('DOLPHIN MINI 5P 75CV 55KW',      'GS', 24990, 11),
  ('SONG PRO 5P DMI PLUG-IN HYBRID', 'GL', 35490, 20),
  ('SONG PRO 5P DMI PLUG-IN HYBRID', 'GS', 37490, 21),
  ('YUAN PRO 5P 94CV 70KW',          'GL', 30900, 30),
  ('YUAN PRO 5P 174CV 130KW',        'GS', 31900, 40),
  ('ATTO 2 5P DMI PLUG-IN HYBRID',   'GS', 33990, 50),
  ('SHARK D/C 1.5T DMO PHEV',        'GS', 59900, 60)
ON CONFLICT (modelo, version) DO NOTHING;
