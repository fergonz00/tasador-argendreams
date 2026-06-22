-- 013_version_manual.sql
-- Permite que el vendedor cargue una versión a mano cuando no está en la lista CCA.
-- El flag queda visible para que el admin (Agustín) la revise y dé el OK o la rebote.

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS usado_version_manual boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN tasaciones.usado_version_manual IS
  'true = la versión la escribió el vendedor a mano (no estaba en CCA). El admin la revisa: OK (enviar a reventas) o rebota.';
