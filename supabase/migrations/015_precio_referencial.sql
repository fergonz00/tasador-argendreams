-- 015 — Precio referencial (lo pone el admin sin pasar por reventas)
-- Para cuando la foto se ve medio mal y el admin no quiere molestar a todas las
-- reventas: pone un precio ORIENTATIVO (no final) + un comentario que ve el vendedor.
-- La tasación NO cambia de estado (sigue en pendiente_admin), así el admin puede
-- después enviarla a reventas normalmente SIN que el vendedor tenga que recargar nada.

alter table public.tasaciones
  add column if not exists precio_referencial numeric;
alter table public.tasaciones
  add column if not exists precio_referencial_comentario text;
alter table public.tasaciones
  add column if not exists precio_referencial_at timestamptz;
