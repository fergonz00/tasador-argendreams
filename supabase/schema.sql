-- ═══════════════════════════════════════════════════════════════════
-- Tasador ArgenDreams — Schema inicial Supabase
-- Correr en el mismo proyecto Supabase de TGA (Dashboard → SQL Editor)
-- Prefijo argendreams_ para no chocar con las tablas de tga
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- USUARIOS
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_usuarios (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario             TEXT UNIQUE NOT NULL,
  clave               TEXT NOT NULL,              -- texto plano (deuda técnica heredada)
  nombre              TEXT NOT NULL,
  rol                 TEXT NOT NULL CHECK (rol IN ('vendedor', 'admin', 'reventa')),
  activo              BOOLEAN NOT NULL DEFAULT true,
  debe_cambiar_clave  BOOLEAN NOT NULL DEFAULT true,
  telefono_wa         TEXT,                       -- formato 549... sin + ni espacios
  notificaciones_wa   BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_argendreams_usuarios_usuario ON argendreams_usuarios(usuario);
CREATE INDEX IF NOT EXISTS idx_argendreams_usuarios_rol_activo ON argendreams_usuarios(rol, activo);

-- Superadmin inicial (Fer). Cambiar la clave en el primer login.
INSERT INTO argendreams_usuarios (usuario, clave, nombre, rol, debe_cambiar_clave)
VALUES ('fngonzalez', 'CambiarMe2026', 'Fer González', 'admin', true)
ON CONFLICT (usuario) DO NOTHING;

-- Admin Agustín (jefe de ventas). Pendiente: agregar teléfono cuando esté.
INSERT INTO argendreams_usuarios (usuario, clave, nombre, rol, debe_cambiar_clave)
VALUES ('agustin', 'CambiarMe2026', 'Agustín (Jefe Ventas)', 'admin', true)
ON CONFLICT (usuario) DO NOTHING;

-- Usuarios de prueba para arrancar
INSERT INTO argendreams_usuarios (usuario, clave, nombre, rol, debe_cambiar_clave) VALUES
  ('vendedor_test',  'CambiarMe2026', 'Vendedor de prueba',  'vendedor', true),
  ('reventa_test_1', 'CambiarMe2026', 'Reventa de prueba 1', 'reventa',  true),
  ('reventa_test_2', 'CambiarMe2026', 'Reventa de prueba 2', 'reventa',  true)
ON CONFLICT (usuario) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────
-- TASACIONES
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_tasaciones (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendedor_id             UUID NOT NULL REFERENCES argendreams_usuarios(id),

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

  -- 0km BYD que pretende comprar el cliente
  byd_modelo              TEXT,
  byd_version             TEXT,
  byd_precio_lista        NUMERIC,                -- snapshot al momento de la carga

  -- Oferta del vendedor al cliente
  precio_ofrecido_cliente NUMERIC NOT NULL,
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

  -- Análisis IA (reusa edge function de TGA)
  analisis_ia_resumen     TEXT,
  analisis_ia_detalle     JSONB,
  analisis_ia_descuento   NUMERIC,
  analisis_ia_estado      TEXT CHECK (analisis_ia_estado IN ('pendiente', 'ok', 'error')),

  -- Auditoría
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_argendreams_tasaciones_vendedor ON argendreams_tasaciones(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_argendreams_tasaciones_estado   ON argendreams_tasaciones(estado);
CREATE INDEX IF NOT EXISTS idx_argendreams_tasaciones_created  ON argendreams_tasaciones(created_at DESC);

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION argendreams_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_argendreams_tasaciones_updated ON argendreams_tasaciones;
CREATE TRIGGER trg_argendreams_tasaciones_updated
  BEFORE UPDATE ON argendreams_tasaciones
  FOR EACH ROW EXECUTE FUNCTION argendreams_set_updated_at();


-- ─────────────────────────────────────────────────────────────────
-- PRECIOS DE REVENTAS (histórico completo, una fila por reventa × ronda)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_reventas_precios (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id  UUID NOT NULL REFERENCES argendreams_tasaciones(id) ON DELETE CASCADE,
  reventa_id   UUID NOT NULL REFERENCES argendreams_usuarios(id),
  ronda        INT  NOT NULL DEFAULT 1,
  precio       NUMERIC NOT NULL,
  comentario   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tasacion_id, reventa_id, ronda)
);

CREATE INDEX IF NOT EXISTS idx_argendreams_reventas_tasacion ON argendreams_reventas_precios(tasacion_id);
CREATE INDEX IF NOT EXISTS idx_argendreams_reventas_reventa  ON argendreams_reventas_precios(reventa_id);


-- ─────────────────────────────────────────────────────────────────
-- COMENTARIOS DEL ADMIN (rebotes)
-- Cuando el admin rebota una tasación, deja notas + campos a corregir
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_comentarios_admin (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id         UUID NOT NULL REFERENCES argendreams_tasaciones(id) ON DELETE CASCADE,
  admin_id            UUID NOT NULL REFERENCES argendreams_usuarios(id),
  comentario          TEXT,
  campos_a_corregir   TEXT[],                    -- ej: ['usado_km', 'usado_color', 'fotos']
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_argendreams_comentarios_tasacion ON argendreams_comentarios_admin(tasacion_id);


-- ─────────────────────────────────────────────────────────────────
-- COMENTARIOS DEL ADMIN PARA REVENTAS
-- Mensajes que aparecen junto a la tasación cuando los reventas la ven
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_comentarios_reventa (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id  UUID NOT NULL REFERENCES argendreams_tasaciones(id) ON DELETE CASCADE,
  admin_id     UUID NOT NULL REFERENCES argendreams_usuarios(id),
  comentario   TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_argendreams_coment_reventa_tasacion ON argendreams_comentarios_reventa(tasacion_id);


-- ─────────────────────────────────────────────────────────────────
-- NOTIFICACIONES WHATSAPP (preparado para más adelante)
-- Mismo esquema que tasador-tga, prefijado
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS argendreams_notificaciones_config (
  evento                       TEXT PRIMARY KEY,
  usuarios_ids                 UUID[] NOT NULL DEFAULT '{}',
  incluir_vendedor_referencia  BOOLEAN NOT NULL DEFAULT false,
  updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by                   UUID REFERENCES argendreams_usuarios(id)
);

CREATE TABLE IF NOT EXISTS argendreams_notificaciones_log (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tasacion_id              UUID REFERENCES argendreams_tasaciones(id),
  destinatario_id          UUID REFERENCES argendreams_usuarios(id),
  destinatario_telefono    TEXT,
  template                 TEXT,
  evento                   TEXT,
  estado                   TEXT,            -- 'ok' | 'error'
  meta_message_id          TEXT,
  error_detalle            TEXT,
  payload                  JSONB,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_argendreams_notif_log_tasacion ON argendreams_notificaciones_log(tasacion_id);

-- Inicializar config de los 6 eventos con superadmin como destinatario fijo
INSERT INTO argendreams_notificaciones_config (evento, usuarios_ids, incluir_vendedor_referencia)
SELECT e.evento, ARRAY[u.id]::UUID[], e.incl
FROM (VALUES
  ('tasacion_pendiente_carga',  false),
  ('tasacion_rebotada',         true),    -- al vendedor
  ('enviada_a_reventas',        false),   -- a todos los reventas activos (lógica en edge fn)
  ('reenviada_a_reventas',      false),
  ('precio_al_vendedor',        true),    -- al vendedor de la tasación
  ('tasacion_cerrada',          true)
) AS e(evento, incl)
CROSS JOIN (SELECT id FROM argendreams_usuarios WHERE usuario='fngonzalez') AS u
ON CONFLICT (evento) DO NOTHING;


-- ─────────────────────────────────────────────────────────────────
-- STORAGE BUCKET para fotos
-- (correr aparte en Storage si no existe — desde el Dashboard:
--  Storage → New bucket → name=argendreams-fotos, public=true)
-- ─────────────────────────────────────────────────────────────────


-- ═══════════════════════════════════════════════════════════════════
-- FIN
-- ═══════════════════════════════════════════════════════════════════
