-- ═══════════════════════════════════════════════════════════════════
-- Migration 018 — Ivan Calustro, vendedor nuevo del local Obelisco
--
-- Pedido de Fer (2026-09-24): sumar a Ivan Calustro como vendedor de
-- Obelisco, bajo Martin Peralta (`martinp`, rol supervisor, alta en la
-- migration 017). Con esto Obelisco pasa de 6 a 7 vendedores y Martin
-- recibe los avisos sup_* de las tasaciones de Ivan.
--
-- Telefono: +54 9 11 8024-5327 -> 5491180245327 (formato de la tabla:
-- solo digitos, con 549 adelante, sin + ni espacios).
--
-- Ojo: NO confundir con `ivanm` (Ivan Malovrh), el ex jefe de Obelisco
-- que quedo inactivo el 26-jun-26. Son personas distintas; por eso el
-- usuario nuevo es `ivanc`.
--
-- Sale con la clave generica de la casa y debe_cambiar_clave = true,
-- igual que las altas de la 017.
--
-- YA CORRIDA el 24-sep-26 via Management API. Este archivo queda como
-- registro: el <CLAVE_GENERICA> de abajo va reemplazado a mano por la
-- clave generica de la casa si alguna vez hay que rehacer el alta
-- (este repo es publico, no va en texto plano).
--
-- Correr en: Dashboard -> SQL Editor -> New query -> Run
--            (o Management API, que es como se corrio)
-- ═══════════════════════════════════════════════════════════════════

INSERT INTO usuarios (
  usuario, clave, nombre, rol, activo, debe_cambiar_clave,
  telefono_wa, notificaciones_wa, notif_admin_bulk, supervisor_id
) VALUES (
  'ivanc', '<CLAVE_GENERICA>', 'Ivan Calustro', 'vendedor', true, true,
  '5491180245327', true, true,
  (SELECT id FROM usuarios WHERE usuario = 'martinp')
)
ON CONFLICT (usuario) DO NOTHING;
