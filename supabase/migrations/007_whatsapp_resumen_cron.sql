-- ═══════════════════════════════════════════════════════════════════
-- Migration 007 — WhatsApp: cron del aviso "resumen_reventas" (+1h)
--
-- Agrega tracking en tasaciones + función que llama la Edge Function
-- notify-whatsapp para cada tasación que cumple:
--   - fue enviada a reventas hace ≥ 1 h
--   - todavía no se mandó el resumen
--   - está en en_reventa o precios_recibidos
-- + schedule pg_cron cada 10 min.
--
-- PRE-REQUISITOS (en Supabase Dashboard → Database → Extensions):
--   - Habilitar extensión `pg_cron`
--   - Habilitar extensión `pg_net` (para HTTP request a la Edge Function)
--
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- Tracking columns
-- ─────────────────────────────────────────────
ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS enviada_a_reventas_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resumen_reventas_enviado_at  TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tasaciones_resumen_pendiente
  ON tasaciones(enviada_a_reventas_at)
  WHERE resumen_reventas_enviado_at IS NULL;


-- ─────────────────────────────────────────────
-- Config: URL de la Edge Function + anon key
-- ─────────────────────────────────────────────
-- Hardcodeado en la función. Si rotan las keys o la URL cambia, actualizar acá.
-- (anon key es pública; no es secreto.)
--
-- Edge Function:  https://xcijbomhvwwlzgmazvep.supabase.co/functions/v1/notify-whatsapp
-- Publishable:    sb_publishable_NPO73kz-5gDAYeiZnmZmcA_gNe6Y31M


-- ─────────────────────────────────────────────
-- Función PL/pgSQL: recorre tasaciones pendientes de resumen y dispara avisos
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_resumen_reventas_pendientes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  r RECORD;
  admin_rec RECORD;
  cnt INT;
  vehiculo TEXT;
  edge_url TEXT := 'https://xcijbomhvwwlzgmazvep.supabase.co/functions/v1/notify-whatsapp';
  anon_key TEXT := 'sb_publishable_NPO73kz-5gDAYeiZnmZmcA_gNe6Y31M';
BEGIN
  FOR r IN
    SELECT t.id, t.usado_marca, t.usado_modelo, t.usado_anio, t.ronda_actual
    FROM tasaciones t
    WHERE t.enviada_a_reventas_at IS NOT NULL
      AND t.enviada_a_reventas_at <= now() - interval '1 hour'
      AND t.resumen_reventas_enviado_at IS NULL
      AND t.estado IN ('en_reventa', 'precios_recibidos')
  LOOP
    -- Contar cuántas reventas cargaron precio en la ronda actual
    SELECT COUNT(*) INTO cnt
    FROM reventas_precios rp
    WHERE rp.tasacion_id = r.id AND rp.ronda = r.ronda_actual;

    vehiculo := COALESCE(
      TRIM(BOTH ' ' FROM (COALESCE(r.usado_marca, '') || ' ' || COALESCE(r.usado_modelo, '') || ' ' || COALESCE(r.usado_anio::TEXT, ''))),
      '—'
    );

    -- Disparar 1 mensaje por cada admin activo con teléfono y notificaciones ON
    FOR admin_rec IN
      SELECT id, nombre, usuario, telefono_wa
      FROM usuarios
      WHERE rol = 'admin'
        AND activo
        AND notificaciones_wa
        AND telefono_wa IS NOT NULL
        AND telefono_wa <> ''
    LOOP
      PERFORM net.http_post(
        url := edge_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || anon_key
        ),
        body := jsonb_build_object(
          'template', 'resumen_reventas',
          'to', admin_rec.telefono_wa,
          'params', jsonb_build_array(
            COALESCE(admin_rec.nombre, admin_rec.usuario, 'Admin'),
            cnt::TEXT,
            vehiculo
          ),
          'evento', 'resumen_reventas',
          'tasacion_id', r.id,
          'destinatario_id', admin_rec.id
        )
      );
    END LOOP;

    -- Marcamos como enviado aunque cnt sea 0 (es info útil al admin igual)
    -- y aunque no haya ningún admin con telefono_wa (evita loop infinito)
    UPDATE tasaciones SET resumen_reventas_enviado_at = now() WHERE id = r.id;
  END LOOP;
END;
$$;


-- ─────────────────────────────────────────────
-- Cron: cada 10 min ejecuta la función
-- ─────────────────────────────────────────────
-- pg_cron usa el schema `cron`. La sintaxis es cron clásica (m h dom mon dow).
-- "*/10 * * * *" = cada 10 minutos.
--
-- Si ya existe un job con ese nombre lo borra primero (idempotente al re-correr la migration).

SELECT cron.unschedule('resumen-reventas-1h')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'resumen-reventas-1h');

SELECT cron.schedule(
  'resumen-reventas-1h',
  '*/10 * * * *',
  $$SELECT fn_resumen_reventas_pendientes();$$
);
