# Plantillas de WhatsApp — Tasador ArgenDreams (Fase 5)

Mensajes (templates / HSM) para las notificaciones automáticas. Se crean en
**WhatsApp Manager → Plantillas de mensajes** (cuenta de WhatsApp Business de
ArgenDreams) y se envían a aprobar a Meta.

## Reglas / decisiones
- **Categoría:** `UTILITY` (avisos transaccionales, no marketing). Aprobación más fácil.
- **Idioma:** `es_AR` (Español - Argentina). Si no está, usar `es`.
- **Sin botones ni header por ahora** (cuerpo solo). Cuando la app esté deployada en
  `tasador.argendreams.online` se puede sumar un botón URL "Abrir tasador".
- Variables `{{1}}`, `{{2}}`, … en orden. Meta pide un ejemplo por variable.
- Nombre del template en `snake_case` (así lo referencia la Edge Function).

---

## 1. `nueva_tasacion` → al ADMIN
Cuando un vendedor carga una tasación nueva.
```
Hola {{1}}, {{2}} cargó una nueva tasación para revisar: {{3}} ({{4}} km). Ingresá al tasador para avanzarla.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | admin | Agustín |
| {{2}} | vendedor | Juan Pérez |
| {{3}} | vehículo | Volkswagen T-Cross 2021 |
| {{4}} | kilómetros | 45.000 |

---

## 2. `tasacion_rebotada` → al VENDEDOR
Cuando el admin rebota la tasación para que la corrija.
```
Hola {{1}}, el admin revisó la tasación de {{2}} y pidió correcciones: {{3}}. Ingresá al tasador para corregir y reenviar.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | vendedor | Juan |
| {{2}} | vehículo | VW T-Cross 2021 |
| {{3}} | campos/nota | Año, Fotos |

---

## 3. `nueva_unidad_reventa` → a CADA REVENTA
Cuando el admin envía la tasación a reventas.
```
Hola {{1}}, hay una unidad nueva para tasar: {{2}}, {{3}} km, {{4}}. Ingresá a la plataforma para ver todos los detalles y cargar un precio de toma.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |
| {{3}} | kilómetros | 45.000 |
| {{4}} | color y provincia | Gris · Buenos Aires |

---

## 4. `pedido_mejora` → a la REVENTA seleccionada para mejorar
Cuando el admin le pide a una reventa que mejore su precio.
```
Hola {{1}}, el admin te pide que mejores tu precio para {{2}}. Ingresá al tasador y actualizá tu oferta.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |

---

## 5. `precio_de_toma` → al VENDEDOR
Cuando el admin define y envía el precio de toma.
```
Hola {{1}}, ya tenés el precio de toma para la tasación de {{2}}: {{3}}. Ingresá al tasador para verlo en detalle y confirmá con el cliente.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | vendedor | Juan |
| {{2}} | cliente / vehículo | María (VW T-Cross 2021) |
| {{3}} | precio de toma | $ 15.800.000 |

---

## 6. `resumen_reventas` → al ADMIN (1 hora después de "enviar a reventas")
Aviso de cuántas reventas ya cargaron precio. Se dispara **1 h después** de que el
admin envió la unidad a reventas (necesita un job programado — ver notas).
```
Hola {{1}}, ya {{2}} reventas le pusieron precio a {{3}}. Ingresá a la plataforma para ver los precios y quiénes todavía no cargaron.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | admin | Agustín |
| {{2}} | cantidad que cargó | 4 |
| {{3}} | vehículo | VW T-Cross 2021 |

---

## 7. `recordatorio_precio` → a la REVENTA que NO cargó precio
Lo dispara el admin con un botón ("pinchar a las que faltan").
```
Hola {{1}}, todavía no cargaste tu precio de toma para {{2}}. Ingresá a la plataforma para cargarlo.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |

---

## 8. `usado_tomado` → a la REVENTA final (confirmada por el admin)
Se manda **solo cuando el admin confirma** que el usado efectivamente se toma (después
de que el cliente entrega la unidad). Es la única vez que la reventa se entera de que
se queda con el auto.
```
Hola {{1}}, ¡operación confirmada! El usado {{2}} se toma a tu precio de {{3}}. Coordiná la recepción con el admin.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |
| {{3}} | precio | $ 15.800.000 |

---

## 9. `peritaje_agregado` → a CADA REVENTA  ✅ creado y activo en Meta (2026-06-02)
Cuando el admin (Agustín) carga el **peritaje físico** de una unidad que ya estaba en
reventas con precios cargados. Bumpea la ronda → las reventas re-cotizan con el peritaje a
la vista. **No reusa `pedido_mejora`** a propósito: el peritaje puede hacer que el precio
**baje** (no es "mejorá"), es "reveé según el estado real".
```
Hola {{1}}, se cargó el peritaje físico de {{2}}. El estado real del vehículo puede cambiar tu precio de toma: ingresá a la plataforma y revisá tu oferta.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |

---

## Eventos → template → destinatario

| Evento (en la app) | Template | Destinatario | Disparo |
|---|---|---|---|
| Vendedor envía tasación | `nueva_tasacion` | admin(s) | inmediato |
| Admin rebota | `tasacion_rebotada` | vendedor de la tasación | inmediato |
| Admin envía a reventas | `nueva_unidad_reventa` | reventas activas | inmediato |
| 1 h después de enviar a reventas | `resumen_reventas` | admin(s) | **programado (+1 h)** |
| Admin "pinchar a las que faltan" | `recordatorio_precio` | reventas sin precio | botón (admin) |
| Admin pide mejora | `pedido_mejora` | reventas seleccionadas | botón (admin) |
| Admin envía precio al vendedor | `precio_de_toma` | vendedor de la tasación | inmediato |
| Admin **confirma** que se toma el usado | `usado_tomado` | reventa final | inmediato |
| Admin carga **peritaje físico** con precios ya cargados | `peritaje_agregado` | reventas activas | inmediato (bump de ronda) |

---

## Lógica de negocio importante (afecta el flujo en la app)

- **La reventa NO se entera de que "ganó"** cuando el admin pasa el precio al vendedor.
  Esa selección es **referencia interna**: define el precio de toma al cliente (fijo) y
  queda guardada (qué precio/reventa se usó). El precio al cliente NO cambia después.
- **La reventa que se lleva el usado puede cambiar:** si el admin consigue otra reventa
  que pague más, se la pasa a esa. El monto de toma al cliente queda igual; la diferencia
  (lo que paga la reventa final − precio de toma al cliente) es **margen para ArgenDreams**,
  que puede crecer. Por eso solo se notifica (`usado_tomado`) a la **reventa final**,
  cuando el admin confirma la toma.

## Notas de implementación (para la Edge Function + app)
- `resumen_reventas` (+1 h) necesita un **job programado**: `pg_cron` en Supabase que cada
  X minutos busque tasaciones enviadas a reventas hace ≥1 h sin "resumen enviado" y dispare
  el aviso (con flag para no repetir). Alternativa: Edge Function programada.
- **Panel admin "quiénes cargaron / quiénes faltan"**: en el detalle de la tasación en
  reventa, listar reventas activas con ✅/⏳ y un botón "Recordar" (manda `recordatorio_precio`)
  por las que faltan.
- El "quién recibe" dinámico (vendedor de la tasación, reventa final) lo resuelve la Edge
  Function con los datos de la tasación; los admins fijos van en `notificaciones_config`.
