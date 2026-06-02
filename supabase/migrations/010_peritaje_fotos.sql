-- 010_peritaje_fotos.sql — Fotos cargadas por el admin durante el peritaje
-- Son ADICIONALES a `fotos` (las iniciales del vendedor). Las ve la reventa como parte
-- del peritaje (su SELECT las incluye). Se suben al mismo bucket `argendreams-fotos`.

ALTER TABLE tasaciones ADD COLUMN IF NOT EXISTS peritaje_fotos TEXT[];

COMMENT ON COLUMN tasaciones.peritaje_fotos IS 'Fotos cargadas por el admin en el peritaje (adicionales a fotos del vendedor). Visibles para la reventa.';
