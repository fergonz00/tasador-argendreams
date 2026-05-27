# Plantillas de WhatsApp — Tasador ArgenDreams (Fase 5)

Mensajes (templates / HSM) para las notificaciones automáticas. Se crean en
**WhatsApp Manager → Plantillas de mensajes** (en la cuenta de WhatsApp Business
de ArgenDreams) y se envían a aprobar a Meta.

## Reglas / decisiones
- **Categoría:** `UTILITY` (son avisos transaccionales de una operación, no marketing).
  Aprobación más fácil y costo menor.
- **Idioma:** `es_AR` (Español - Argentina). Si esa no está disponible, usar `es`.
- **Sin botones ni header por ahora** (cuerpo solo) → aprobación más simple. Cuando la
  app esté deployada en `tasador.argendreams.online` podemos sumar un botón URL "Abrir tasador".
- Las variables van como `{{1}}`, `{{2}}`, … en orden. Meta pide un **ejemplo** para cada una.
- El nombre del template va en `snake_case` (así se referencia desde la Edge Function).

---

## 1. `nueva_tasacion` → al ADMIN
Cuando un vendedor carga una tasación nueva.

**Cuerpo:**
```
Hola {{1}}, {{2}} cargó una nueva tasación para revisar: {{3}} ({{4}} km). Ingresá al tasador para moderarla.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | nombre del admin | Agustín |
| {{2}} | vendedor | Juan Pérez |
| {{3}} | vehículo | Volkswagen T-Cross 2021 |
| {{4}} | kilómetros | 45.000 |

---

## 2. `tasacion_rebotada` → al VENDEDOR
Cuando el admin rebota la tasación para que la corrija.

**Cuerpo:**
```
Hola {{1}}, el admin revisó la tasación de {{2}} y pidió correcciones: {{3}}. Ingresá al tasador para corregir y reenviar.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | vendedor | Juan |
| {{2}} | vehículo | VW T-Cross 2021 |
| {{3}} | campos/nota a corregir | Año, Fotos |

---

## 3. `nueva_unidad_reventa` → a CADA REVENTA
Cuando el admin envía la tasación a reventas.

**Cuerpo:**
```
Hola {{1}}, hay una unidad nueva para tasar: {{2}}, {{3}} km, {{4}}. Ingresá al tasador y cargá tu precio de toma.
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

**Cuerpo:**
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

**Cuerpo:**
```
Hola {{1}}, ya tenés el precio de toma para la tasación de {{2}}: {{3}}. Ingresá al tasador para verlo y confirmá con el cliente.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | vendedor | Juan |
| {{2}} | cliente / vehículo | María (VW T-Cross 2021) |
| {{3}} | precio de toma | $ 15.800.000 |

---

## 6. `reventa_seleccionada` → a la REVENTA ganadora
Cuando el admin elige su oferta como la mejor (envía precio al vendedor).

**Cuerpo:**
```
Hola {{1}}, tu oferta por {{2}} fue seleccionada como la mejor. Te avisamos en cuanto el cliente confirme la toma.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |

---

## 7. `usado_tomado` → a la REVENTA ganadora
Cuando el cliente acepta y el usado se toma como parte de pago.

**Cuerpo:**
```
Hola {{1}}, ¡operación confirmada! El usado {{2}} se toma a tu precio de {{3}}. Coordiná la recepción con el admin.
```
| Var | Contenido | Ejemplo |
|---|---|---|
| {{1}} | reventa | Carlos |
| {{2}} | vehículo | VW T-Cross 2021 |
| {{3}} | precio | $ 15.800.000 |

---

## Eventos → template → destinatario (resumen para la Edge Function)

| Evento (en la app) | Template | Destinatario |
|---|---|---|
| Vendedor envía tasación | `nueva_tasacion` | admin(s) |
| Admin rebota | `tasacion_rebotada` | vendedor de la tasación |
| Admin envía a reventas | `nueva_unidad_reventa` | todas las reventas activas |
| Admin pide mejora | `pedido_mejora` | reventas seleccionadas |
| Admin envía precio al vendedor | `precio_de_toma` | vendedor de la tasación |
| (mismo evento anterior) | `reventa_seleccionada` | reventa ganadora |
| Cliente acepta (usado tomado) | `usado_tomado` | reventa ganadora |

> Nota: el "quién recibe" dinámico (vendedor de la tasación, reventa ganadora) lo
> resuelve la Edge Function con los datos de la tasación. Los admins fijos se
> configuran en `notificaciones_config`.
