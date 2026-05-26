-- ═══════════════════════════════════════════════════════════════════
-- Tasador ArgenDreams — Schema inicial Supabase
-- Proyecto: xcijbomhvwwlzgmazvep (org ArgenDreams Free)
-- Correr en: Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- USUARIOS
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario             TEXT UNIQUE NOT NULL,
  clave               TEXT NOT NULL,              -- texto plano (deuda técnica heredada de TGA)
  nombre              TEXT NOT NULL,
  rol                 TEXT NOT NULL CHECK (rol IN ('vendedor', 'admin', 'reventa')),
  activo              BOOLEAN NOT NULL DEFAULT true,
  debe_cambiar_clave  BOOLEAN NOT NULL DEFAULT true,
  telefono_wa         TEXT,                       -- formato 549... sin + ni espacios
  notificaciones_wa   BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_usuario    ON usuarios(usuario);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol_activo ON usuarios(rol, activo);

-- Superadmin inicial (Fer). Cambiar la clave en el primer login.
INSERT INTO usuarios (usuario, clave, nombre, rol, debe_cambiar_clave)
VALUES ('fngonzalez', 'CambiarMe2026', 'Fer González', 'admin', true)
ON CONFLICT (usuario) DO NOTHING;

-- Admin Agustín (jefe de ventas). Pendiente: agregar teléfono cuando esté.
INSERT INTO usuarios (usuario, clave, nombre, rol, debe_cambiar_clave)
VALUES ('agustin', 'CambiarMe2026', 'Agustín (Jefe Ventas)', 'admin', true)
ON CONFLICT (usuario) DO NOTHING;

-- Usuarios de prueba para arrancar
INSERT INTO usuarios (usuario, clave, nombre, rol, debe_cambiar_clave) VALUES
  ('vendedor_test',  'CambiarMe2026', 'Vendedor de prueba',  'vendedor', true),
  ('reventa_test_1', 'CambiarMe2026', 'Reventa de prueba 1', 'reventa',  true),
  ('reventa_test_2', 'CambiarMe2026', 'Reventa de prueba 2', 'reventa',  true)
ON CONFLICT (usuario) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────
-- TASACIONES
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasaciones (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendedor_id             UUID NOT NULL REFERENCES usuarios(id),

  -- Cliente
  cliente_nombre          TEXT NOT NULL,

  -- Usado
  usado_marca             TEXT NOT NULL,
  usado_modelo            TEXT NOT NULL,
  usado_version           TEXT,
  usado_anio              INT  NOT NULL,
  usado_km                INT  NOT NULL,
  usado_color             TEXT NOT NULL,         -- el reventa lo ve, por eso obligatorio
  usado_provincia         TEXT NOT NULL,

  -- 0km equivalente del usado (opcional, info referencial)
  equiv_0km_marca         TEXT,
  equiv_0km_modelo        TEXT,
  equiv_0km_version       TEXT,
  equiv_0km_precio        NUMERIC,
  equiv_0km_moneda        TEXT CHECK (equiv_0km_moneda IN ('ARS', 'USD')),
  equiv_0km_comentario    TEXT,                -- si el vendedor corrigió la sugerencia, qué no coincidía

  -- 0km BYD que pretende comprar el cliente
  byd_modelo              TEXT,
  byd_version             TEXT,
  byd_precio_lista        NUMERIC,                -- snapshot al momento de la carga

  -- Oferta del vendedor al cliente (sin FyF — flete y formulario)
  precio_ofrecido_cliente NUMERIC NOT NULL,
  precio_ofrecido_moneda  TEXT NOT NULL DEFAULT 'USD' CHECK (precio_ofrecido_moneda IN ('USD', 'ARS')),
  stock_entrega_rapida    BOOLEAN NOT NULL DEFAULT false,

  -- Fotos
  fotos                   TEXT[],

  -- Estado del flujo
  estado                  TEXT NOT NULL DEFAULT 'pendiente_admin'
    CHECK (estado IN ('pendiente_admin', 'rebotada', 'en_reventa',
                      'precios_recibidos', 'precio_al_vendedor', 'cerrada')),
  resultado               TEXT CHECK (resultado IN ('tomada', 'no_tomada')),

  -- Configuración admin
  descuento_pct_admin     NUMERIC NOT NULL DEFAULT 9,    -- 7 | 9 | 12
  precio_final_admin      NUMERIC,                       -- el precio que Agustín envía al vendedor
  ronda_actual            INT NOT NULL DEFAULT 1,        -- incrementa al "reenviar para mejorar"

  -- Análisis IA (Edge Function analyze-photos a deployar después)
  analisis_ia_resumen     TEXT,
  analisis_ia_detalle     JSONB,
  analisis_ia_descuento   NUMERIC,
  analisis_ia_estado      TEXT CHECK (analisis_ia_estado IN ('pendiente', 'ok', 'error')),

  -- Auditoría
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tasaciones_vendedor ON tasaciones(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_tasaciones_estado   ON tasaciones(estado);
CREATE INDEX IF NOT EXISTS idx_tasaciones_created  ON tasaciones(created_at DESC);

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_tasaciones_updated') THEN
    CREATE TRIGGER trg_tasaciones_updated
      BEFORE UPDATE ON tasaciones
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────
-- PRECIOS DE REVENTAS (histórico completo, una fila por reventa × ronda)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reventas_precios (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id  UUID NOT NULL REFERENCES tasaciones(id) ON DELETE CASCADE,
  reventa_id   UUID NOT NULL REFERENCES usuarios(id),
  ronda        INT  NOT NULL DEFAULT 1,
  precio       NUMERIC NOT NULL,
  comentario   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tasacion_id, reventa_id, ronda)
);

CREATE INDEX IF NOT EXISTS idx_reventas_precios_tasacion ON reventas_precios(tasacion_id);
CREATE INDEX IF NOT EXISTS idx_reventas_precios_reventa  ON reventas_precios(reventa_id);


-- ─────────────────────────────────────────────────────────────────
-- COMENTARIOS DEL ADMIN (rebotes)
-- Cuando el admin rebota una tasación, deja notas + campos a corregir
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comentarios_admin (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id         UUID NOT NULL REFERENCES tasaciones(id) ON DELETE CASCADE,
  admin_id            UUID NOT NULL REFERENCES usuarios(id),
  comentario          TEXT,
  campos_a_corregir   TEXT[],                    -- ej: ['usado_km', 'usado_color', 'fotos']
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comentarios_admin_tasacion ON comentarios_admin(tasacion_id);


-- ─────────────────────────────────────────────────────────────────
-- COMENTARIOS PARA REVENTAS
-- Mensajes que aparecen junto a la tasación cuando los reventas la ven
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comentarios_reventa (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id  UUID NOT NULL REFERENCES tasaciones(id) ON DELETE CASCADE,
  admin_id     UUID NOT NULL REFERENCES usuarios(id),
  comentario   TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comentarios_reventa_tasacion ON comentarios_reventa(tasacion_id);


-- ─────────────────────────────────────────────────────────────────
-- NOTIFICACIONES WHATSAPP (preparado para más adelante)
-- Mismo esquema que tasador-tga
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notificaciones_config (
  evento                       TEXT PRIMARY KEY,
  usuarios_ids                 UUID[] NOT NULL DEFAULT '{}',
  incluir_vendedor_referencia  BOOLEAN NOT NULL DEFAULT false,
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by                   UUID REFERENCES usuarios(id)
);

CREATE TABLE IF NOT EXISTS notificaciones_log (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id              UUID REFERENCES tasaciones(id),
  destinatario_id          UUID REFERENCES usuarios(id),
  destinatario_telefono    TEXT,
  template                 TEXT,
  evento                   TEXT,
  estado                   TEXT,            -- 'ok' | 'error'
  meta_message_id          TEXT,
  error_detalle            TEXT,
  payload                  JSONB,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_log_tasacion ON notificaciones_log(tasacion_id);

-- Inicializar config de los 6 eventos con superadmin como destinatario fijo
INSERT INTO notificaciones_config (evento, usuarios_ids, incluir_vendedor_referencia)
SELECT e.evento, ARRAY[u.id]::UUID[], e.incl
FROM (VALUES
  ('tasacion_pendiente_carga',  false),
  ('tasacion_rebotada',         true),    -- al vendedor
  ('enviada_a_reventas',        false),   -- a todos los reventas activos (lógica en edge fn)
  ('reenviada_a_reventas',      false),
  ('precio_al_vendedor',        true),    -- al vendedor de la tasación
  ('tasacion_cerrada',          true)
) AS e(evento, incl)
CROSS JOIN (SELECT id FROM usuarios WHERE usuario='fngonzalez') AS u
ON CONFLICT (evento) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════
-- FIN — Recordá crear el Storage bucket "argendreams-fotos" (public)
-- desde el Dashboard: Storage → New bucket
-- ═══════════════════════════════════════════════════════════════════
