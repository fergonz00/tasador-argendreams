-- Migration 016 — aviso al admin cuando una reventa cotiza MÁS ALTO que el mejor
-- precio ya avisado para esa tasación.
--
-- Regla (pedido de Fer, 2026-07-13): el admin recibe un WhatsApp (template
-- mejor_precio_admin) solo cuando entra un precio de reventa que supera el máximo
-- que ya se le había avisado. La primera cotización siempre avisa (supera a "nada");
-- después, solo las mejoras. Precios iguales o más bajos no molestan.
--
-- Es un "techo histórico" (cross-ronda): si en una ronda posterior alguien supera lo
-- mejor que se vio, se vuelve a avisar; si cotizan más barato, no.

ALTER TABLE tasaciones
  ADD COLUMN IF NOT EXISTS max_precio_avisado_admin numeric;

COMMENT ON COLUMN tasaciones.max_precio_avisado_admin IS
  'Mejor precio de reventa ya avisado al admin por WhatsApp (high-water-mark). Se avisa solo cuando un precio nuevo lo supera.';
