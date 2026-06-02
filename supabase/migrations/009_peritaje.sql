-- 009_peritaje.sql — Peritaje físico de la unidad (lo carga el admin/Agustín)
-- ArgenDreams: Agustín es admin + perito a la vez (no hay rol/turno aparte como Fazzini en TGA).
--
-- Se separa en DOS columnas a propósito:
--   * analisis_fisico  → parte CUALITATIVA del peritaje (daños sin monto, estados de
--                        mecánica/interior, equipamiento, neumáticos, documentación,
--                        N° motor/chasis, estado general, pintura, observaciones).
--                        ESTA la ven las reventas (la incluyen en su SELECT) para re-cotizar.
--   * peritaje_costos  → los MONTOS de arreglo (por ítem + por daño + total). SOLO admin.
--                        Las reventas NO la incluyen en su SELECT (mismo criterio que el
--                        precio ofrecido / IA / CCA: se ocultan omitiendo la columna).
--
-- Flujo:
--   - Físico directo  → admin carga peritaje en pendiente_admin, después "Enviar a reventas".
--   - Virtual directo → nunca se carga peritaje.
--   - Virtual→físico  → admin carga peritaje cuando ya está en reventas. Si ya había precios
--                       (precios_recibidos), se bumpea ronda_actual+1 y se avisa a las reventas
--                       (evento peritaje_agregado) para que re-coticen con el peritaje a la vista.

ALTER TABLE tasaciones ADD COLUMN IF NOT EXISTS analisis_fisico   JSONB;
ALTER TABLE tasaciones ADD COLUMN IF NOT EXISTS peritaje_costos    JSONB;
ALTER TABLE tasaciones ADD COLUMN IF NOT EXISTS peritaje_cargado_at TIMESTAMPTZ;

COMMENT ON COLUMN tasaciones.analisis_fisico    IS 'Peritaje físico cualitativo (sin montos). Visible para reventas.';
COMMENT ON COLUMN tasaciones.peritaje_costos     IS 'Montos de arreglo del peritaje (por ítem/daño + total). Solo admin.';
COMMENT ON COLUMN tasaciones.peritaje_cargado_at IS 'Cuándo se cargó/actualizó por última vez el peritaje físico.';
