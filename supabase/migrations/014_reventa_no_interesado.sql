-- 014 — Reventa "no interesado en la compra"
-- Permite que una reventa marque que NO quiere tomar una unidad (con comentario)
-- en lugar de cargar un precio. Se registra como una fila de reventas_precios con
-- precio NULL + no_interesado=true (respeta el UNIQUE por tasacion/reventa/ronda,
-- así puede cambiar de idea y cargar precio, o viceversa).

alter table public.reventas_precios
  add column if not exists no_interesado boolean not null default false;

-- precio pasa a ser opcional: null cuando la reventa dice "no interesado".
alter table public.reventas_precios
  alter column precio drop not null;

-- Coherencia: o hay precio, o está marcado como no interesado.
alter table public.reventas_precios
  drop constraint if exists reventas_precios_precio_o_descarte;
alter table public.reventas_precios
  add constraint reventas_precios_precio_o_descarte
  check (no_interesado = true or precio is not null);
