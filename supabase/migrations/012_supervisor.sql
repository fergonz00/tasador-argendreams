-- 012 — Rol SUPERVISOR (vendedores de otra sucursal)
-- * usuarios.rol acepta 'supervisor'
-- * usuarios.supervisor_id: a que supervisor reporta un vendedor (NULL = sin supervisor, casa central)
-- * tasaciones.cargada_por_id: quien cargo realmente la tasacion (NULL = el vendedor mismo;
--   se setea cuando el supervisor carga en nombre de un vendedor suyo)

ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check
  CHECK (rol IN ('vendedor', 'admin', 'reventa', 'supervisor'));

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS supervisor_id UUID REFERENCES usuarios(id);
CREATE INDEX IF NOT EXISTS idx_usuarios_supervisor ON usuarios(supervisor_id);

ALTER TABLE tasaciones ADD COLUMN IF NOT EXISTS cargada_por_id UUID REFERENCES usuarios(id);
