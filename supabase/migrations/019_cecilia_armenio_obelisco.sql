-- ═══════════════════════════════════════════════════════════════════
-- Migration 019 — Cecilia Armenio, vendedora nueva del local Obelisco
--
-- Pedido de Martin Peralta a Fer por WhatsApp (24-sep-26, 15:05): usuario
-- de la plataforma de usados para Cecilia Armenio, vendedora de Obelisco.
-- Queda bajo `martinp` igual que el resto del local. Obelisco pasa de 7
-- a 8 vendedores (Ivan Calustro entro el mismo dia, migration 018).
--
-- Telefono: 11 5929-1985 -> 5491159291985 (formato de la tabla: solo
-- digitos, con 549 adelante, sin + ni espacios).
--
-- Sale con la clave generica de la casa y debe_cambiar_clave = true,
-- igual que las altas de la 017 y la 018.
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
  'ceciliaa', '<CLAVE_GENERICA>', 'Cecilia Armenio', 'vendedor', true, true,
  '5491159291985', true, true,
  (SELECT id FROM usuarios WHERE usuario = 'martinp')
)
ON CONFLICT (usuario) DO NOTHING;
