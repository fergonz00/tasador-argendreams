-- ═══════════════════════════════════════════════════════════════════
-- Migration 008 — flag para excluir admins de las notificaciones masivas
--
-- Caso de uso: Diego Kusnetzoff es admin "viewer" — ve todo lo que ve Agustín
-- y puede moderar, pero no quiere recibir WhatsApps por cada tasación nueva
-- ni por el resumen +1h. Sí quiere recibir los avisos cuando él mismo carga
-- una tasación como vendedor (rebote, precio_de_toma) — esos buscan por
-- vendedor_id, no por rol, así que siguen funcionando independiente del flag.
--
-- Columna nueva:
--   notif_admin_bulk = true  → recibe nueva_tasacion / resumen_reventas (default)
--   notif_admin_bulk = false → NO recibe esos avisos (Diego)
--
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS notif_admin_bulk BOOLEAN NOT NULL DEFAULT true;

-- Re-crear fn_resumen_reventas_pendientes incluyendo el nuevo filtro
-- (única función afectada del lado servidor; el cliente filtra en _waAdmins())
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
    SELECT COUNT(*) INTO cnt
    FROM reventas_precios rp
    WHERE rp.tasacion_id = r.id AND rp.ronda = r.ronda_actual;

    vehiculo := COALESCE(
      TRIM(BOTH ' ' FROM (COALESCE(r.usado_marca, '') || ' ' || COALESCE(r.usado_modelo, '') || ' ' || COALESCE(r.usado_anio::TEXT, ''))),
      '—'
    );

    FOR admin_rec IN
      SELECT id, nombre, usuario, telefono_wa
      FROM usuarios
      WHERE rol = 'admin'
        AND activo
        AND notificaciones_wa
        AND notif_admin_bulk           -- NUEVO: respetar el flag
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

    UPDATE tasaciones SET resumen_reventas_enviado_at = now() WHERE id = r.id;
  END LOOP;
END;
$$;

-- Crear Diego Kusnetzoff como admin viewer
-- - rol admin → ve y modera todo
-- - notif_admin_bulk false → NO recibe nueva_tasacion ni resumen_reventas
-- - notificaciones_wa true → si carga una tasación como vendedor sí recibe los
--   eventos personales (tasacion_rebotada, precio_de_toma)
-- - telefono_wa: NULL por ahora; cargarlo cuando Diego confirme su número
INSERT INTO usuarios (
  usuario, clave, nombre, rol, activo, debe_cambiar_clave,
  notificaciones_wa, notif_admin_bulk, telefono_wa
)
VALUES (
  'diegok', 'Argen2026', 'Diego Kusnetzoff', 'admin', true, true,
  true, false, NULL
)
ON CONFLICT (usuario) DO NOTHING;
