-- ═══════════════════════════════════════════════════════════════════
-- Migration 017 — Martin Peralta (jefe Obelisco) + directores Diego K / Juan C
--
-- Incluye lo que la 008 nunca llego a correrse en la base (verificado
-- 2026-08-19: la columna notif_admin_bulk NO existia y el usuario diegok
-- tampoco). Efecto colateral de eso: _waAdmins() en index.html filtraba por
-- una columna inexistente -> PostgREST devolvia 400 -> NINGUN admin recibio
-- nunca el WhatsApp `nueva_tasacion` (0 registros en notificaciones_log).
-- Esta migration lo repara.
--
-- 1) notif_admin_bulk: admins con false NO reciben nueva_tasacion ni
--    resumen_reventas (avisos masivos). Si reciben los personales
--    (tasacion_rebotada, precio_de_toma) porque esos buscan por vendedor_id.
-- 2) martinp  -> supervisor del local Obelisco (los 6 vendedores que antes
--    reportaban a ivanm). Recibe los 3 avisos sup_* de Obelisco.
--    Su telefono es la linea corporativa del local, la misma que tenia
--    ivanm (confirmado por Fer) -> se la saco a ivanm para no duplicar.
-- 3) diegok + juanc -> directores generales, rol admin + superadmin
--    hardcodeado en index.html (SUPERADMINS_USUARIOS). notif_admin_bulk=false
--    porque pidieron NO recibir un WhatsApp por cada cosa que pasa.
--
-- Correr en: Dashboard -> SQL Editor -> New query -> Run
--            (o Management API, que es como se corrio)
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS notif_admin_bulk BOOLEAN NOT NULL DEFAULT true;

-- ── Usuarios nuevos ────────────────────────────────────────────────
INSERT INTO usuarios (
  usuario, clave, nombre, rol, activo, debe_cambiar_clave,
  telefono_wa, notificaciones_wa, notif_admin_bulk
) VALUES
  ('martinp', 'Argen2026', 'Martin Peralta',    'supervisor', true, true, '5491131371798', true, true),
  ('diegok',  'Argen2026', 'Diego Kusnetzoff',  'admin',      true, true, '5491140538787', true, false),
  ('juanc',   'Argen2026', 'Juan Contini',      'admin',      true, true, '5491141489793', true, false)
ON CONFLICT (usuario) DO NOTHING;

-- La linea 5491131371798 es del local Obelisco y ahora la usa Martin.
-- ivanm quedo inactivo el 26-jun (no se borra, conserva historial).
UPDATE usuarios SET telefono_wa = NULL WHERE usuario = 'ivanm';

-- ── Los 6 vendedores de Obelisco pasan a reportar a Martin ─────────
-- (eran los que tenian supervisor_id = ivanm antes de la baja de junio;
--  los supervisor_id NULL restantes = Nuñez / casa central, NO se tocan)
UPDATE usuarios
   SET supervisor_id = (SELECT id FROM usuarios WHERE usuario = 'martinp')
 WHERE usuario IN ('daniela', 'guillermod', 'jonatanr', 'michaela', 'pablor', 'santiagow');

-- ── Cron del resumen +1h: respetar notif_admin_bulk ────────────────
CREATE OR REPLACE FUNCTION fn_resumen_reventas_pendientes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
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
      '-'
    );

    FOR admin_rec IN
      SELECT id, nombre, usuario, telefono_wa
      FROM usuarios
      WHERE rol = 'admin'
        AND activo
        AND notificaciones_wa
        AND notif_admin_bulk
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
$fn$;
