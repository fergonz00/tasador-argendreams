# Tasador ArgenDreams — Contexto del proyecto

## Qué es

App web de tasación de autos usados para **ArgenDreams**, concesionaria nueva que vende **BYD 0km**. Permite que vendedores carguen tasaciones, que un admin (Agustín, jefe de ventas) las modere, y que 7-8 reventas pongan precios "tipo remate" para que el admin elija el mejor.

**No confundir con tasador-tga**: TGA es Tito Gonzalez (VW). ArgenDreams es otra empresa, otra marca. Comparten conceptos técnicos pero son apps separadas.

## Stack técnico (heredado de tasador-tga)

- HTML único (`index.html`) sin build, sin framework, sin bundler
- CSS y JS vanilla, todo inline
- **Supabase** (REST API directa con fetch). **Mismo proyecto que tasador-tga**, tablas con prefijo `argendreams_*` para no chocar
- Hosting: GitHub Pages con dominio propio vía CNAME (a definir, posible `tasador.argendreams.com.ar`)
- Análisis IA de fotos: reusa la Edge Function `analyze-photos` de tga (Claude Opus). Anthropic API key vive como secret en Supabase
- Notificaciones WhatsApp: nueva línea + nuevas plantillas Meta a configurar por Fer. Edge function se deja preparada pero sin disparar hasta que la línea esté lista

## Roles

| Rol | Quién | Qué puede hacer |
|---|---|---|
| `vendedor` | Cada vendedor de ArgenDreams (con usuario propio) | Crear tasaciones · ver "Mis tasaciones" · corregir las que rebota el admin · marcar TOMADO/NO TOMADO al final |
| `admin` | Agustín (jefe de ventas) | Todo lo del vendedor + moderar tasaciones (rebotar o enviar a reventas) + ver precios de reventas en ranking + cerrar precio final · Único que ve CCA / Fórmula FMG / IA / diferencia $/% interna |
| `reventa` | 7-8 reventas externos (con usuario propio) | Ver lista de tasaciones a tasar · cargar precio de toma para cada una · NO ve CCA, FMG, IA ni datos internos |
| `superadmin` | `fngonzalez` (Fer) hardcoded | Igual que admin + gestión de usuarios |

## Flujo de una tasación (estados)

```
PENDIENTE_ADMIN ────────────────────────────────────────────┐
   ↑    │ Admin rebota con notas                            │
   │    ▼                                                   │
REBOTADA → Vendedor corrige → vuelve a PENDIENTE_ADMIN ──┘
        │
        │ Admin "enviar a reventas"
        ▼
EN_REVENTA → Cada reventa carga su precio (independiente)
        │
        │ (al menos 1 precio cargado)
        ▼
PRECIOS_RECIBIDOS → Admin ve ranking con descuento configurable (7/9/12%)
        │           │
        │           ├─→ Admin "reenviar a reventas para mejorar"
        │           │   → guarda ronda actual en histórico, vuelve a EN_REVENTA
        │           │
        │           └─→ Admin "enviar precio al vendedor" (con validación)
        ▼
PRECIO_AL_VENDEDOR → Vendedor (o Admin) marca TOMADO / NO_TOMADO
        ▼
CERRADA (resultado: tomada | no_tomada)
```

## Wizard del vendedor (12 pasos)

| # | Paso | Notas |
|---|---|---|
| 1 | Nombre y apellido del cliente | Texto libre |
| 2 | Marca del usado | Igual fuente que TGA (CSV CCA) |
| 3 | Año | Lista 1990 - año actual |
| 4 | Modelo | Misma fuente que TGA |
| 5 | Versión | Misma fuente que TGA |
| 6 | 0km equivalente del usado | Opcional. Igual que TGA: cascada marca → modelo → versión. Solo info referencial, sin precios visibles al vendedor |
| 7 | Kilómetros | Number |
| 8 | Color | Texto libre o lista. **Necesario para que el reventa lo vea** |
| 9 | Provincia de radicación | Lista de provincias argentinas (sin patente) |
| 10 | 0km BYD que consulta el cliente | Cascada modelo → versión desde la **sheet nueva de BYD ArgenDreams** (a crear). Precios de lista de referencia |
| 11 | Precio ofrecido al cliente | Para que Agustín vea qué descuento real está ofreciendo el vendedor |
| 12 | ¿Se ofreció unidad de stock con entrega rápida? | Sí/No |
| 13 | Fotos + análisis IA | Igual que TGA. IA solo la ve el admin |

**Diferencias respecto al wizard de TGA:**
- Agregado paso de datos cliente
- Eliminado origen del usado (concesionaria nueva, casi nadie tiene un usado de ArgenDreams)
- Eliminada patente (solo provincia)
- Eliminada referencia de precio Kavak
- Cambiado VW 0km por BYD 0km como objeto de la compra
- Agregada pregunta de stock con entrega rápida

## Vista de Reventa (lo que SÍ y NO ve)

**SÍ ve:**
- Marca, modelo, año, km, versión, **color**, provincia
- Fotos
- Comentarios del admin (si los agrega)

**NO ve:**
- Datos del cliente (nombre y apellido)
- Análisis IA
- Precio ofrecido al cliente por el vendedor
- 0km BYD que consulta el cliente
- Precios de otros reventas
- CCA / Fórmula FMG / cualquier referencia interna

Carga un único campo: **precio de toma** (en ARS).

## Vista de Admin (Agustín)

**Pestañas:** Pendientes / En reventa / Precios recibidos / Cerradas / Todas

**Para cada tasación ve:**
- Todos los datos del usado + datos del cliente
- Fotos + análisis IA (descuento sugerido)
- 3 métodos de precio referencia: **CCA, Fórmula FMG, precio del 0km equivalente**
- Precio ofrecido al cliente + 0km BYD que pretende
- **Ranking de precios de reventas** (de mayor a menor) cuando ya hay
- Selector de descuento: 7% / 9% / 12% (default 9%). Recalcula automático el precio de toma sugerido para cada reventa
- Diferencia $ y % que se le gana en cada precio (solo Agustín la ve)
- Botones: REBOTAR / ENVIAR A REVENTAS / REENVIAR PARA MEJORAR / ENVIAR PRECIO AL VENDEDOR

**Validación al "Enviar precio al vendedor":**
- Si el precio que pone es menor al mejor reventa × (1 - 7%) → muestra warning:
  *"Estás pasando un precio inferior al mínimo recomendable según la tasación más alta. ¿Querés mandarlo igual?"*

**Mensaje al confirmar:**
- *"Se obtiene una diferencia de [X]% o [$Y] de tomarse el usado"* — solo Agustín lo ve

## Sheet de BYD 0km vigentes (a crear)

URL pública (gviz CSV) a definir. Columnas planificadas:
- Modelo
- Versión
- Precio (ARS)
- Stock disponible (opcional)
- Actualizado

Fer va a crear esta sheet manualmente con los precios de lista de referencia. La idea es poder actualizarla sin tocar código.

**No reutilizar la sheet "Tito"** del scraper-byd-precios — esa es para Argendreams pero scrapeada de elcerokm.com. La de ArgenDreams tasador es manual con precios de lista oficiales.

## Schema Supabase

### `argendreams_usuarios`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| usuario | text UNIQUE | login |
| clave | text | texto plano (deuda técnica heredada de TGA) |
| nombre | text | |
| rol | text | `vendedor` \| `admin` \| `reventa` |
| activo | boolean | default true |
| debe_cambiar_clave | boolean | default true |
| telefono_wa | text | formato 549... sin + ni espacios (para WhatsApp) |
| notificaciones_wa | boolean | opt-out, default true |
| created_at | timestamptz | default now() |

### `argendreams_tasaciones`
| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| vendedor_id | uuid FK → usuarios | |
| cliente_nombre | text | |
| usado_marca | text | |
| usado_modelo | text | |
| usado_version | text | |
| usado_anio | int | |
| usado_km | int | |
| usado_color | text | |
| usado_provincia | text | |
| equiv_0km_marca | text | opcional |
| equiv_0km_modelo | text | opcional |
| equiv_0km_version | text | opcional |
| equiv_0km_precio | numeric | opcional |
| equiv_0km_moneda | text | ARS \| USD |
| byd_modelo | text | el 0km que pretende el cliente |
| byd_version | text | |
| byd_precio_lista | numeric | snapshot al momento de la carga |
| precio_ofrecido_cliente | numeric | en ARS |
| stock_entrega_rapida | boolean | |
| fotos | text[] | URLs Supabase Storage |
| estado | text | `pendiente_admin` \| `rebotada` \| `en_reventa` \| `precios_recibidos` \| `precio_al_vendedor` \| `cerrada` |
| resultado | text | NULL hasta cerrarla, después `tomada` \| `no_tomada` |
| descuento_pct_admin | numeric | 7 \| 9 \| 12, default 9 |
| precio_final_admin | numeric | el que Agustín envía al vendedor |
| analisis_ia_resumen | text | |
| analisis_ia_detalle | jsonb | |
| analisis_ia_descuento | numeric | |
| analisis_ia_estado | text | `pendiente` \| `ok` \| `error` |
| created_at | timestamptz | |
| updated_at | timestamptz | |

### `argendreams_reventas_precios`
Histórico completo (cada reenvío genera ronda nueva).

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| tasacion_id | uuid FK → tasaciones | |
| reventa_id | uuid FK → usuarios | |
| ronda | int | 1, 2, 3... incrementa cuando admin reenvía para mejorar |
| precio | numeric | |
| comentario | text | opcional |
| created_at | timestamptz | |

UNIQUE (tasacion_id, reventa_id, ronda)

### `argendreams_comentarios_admin`
Notas del admin cuando rebota una tasación, para que el vendedor sepa qué corregir.

| Campo | Tipo | Notas |
|---|---|---|
| id | uuid PK | |
| tasacion_id | uuid FK | |
| admin_id | uuid FK → usuarios | |
| comentario | text | |
| campos_a_corregir | text[] | nombres de campos del wizard a revisar |
| created_at | timestamptz | |

## Notificaciones WhatsApp (preparado, sin disparar)

Eventos planificados:
1. `tasacion_pendiente_carga` — vendedor envía → admin
2. `tasacion_rebotada` — admin rebota → vendedor
3. `enviada_a_reventas` — admin envía → todos los reventas activos
4. `reenviada_a_reventas` — admin pide mejorar precio → reventas
5. `precio_al_vendedor` — admin cierra precio → vendedor
6. `tasacion_cerrada` — vendedor o admin marca resultado → admin + vendedor

Cada evento se dispara con `notifyWA(tasacion_id, evento)` desde el frontend, fire-and-forget. La edge function `argendreams-notify-whatsapp` (a crear cuando Fer tenga la nueva línea WA) lee config + tasacion + usuarios y manda.

## Pendientes para próximas sesiones

1. ✅ Crear schema Supabase y SQL listo
2. ⏳ Adaptar `index.html` de TGA — branding ArgenDreams + BYD, sacar campos que no aplican
3. ⏳ Implementar wizard del vendedor (12 pasos)
4. ⏳ Implementar vista admin con ranking + descuento configurable
5. ⏳ Implementar vista reventa (mínima, sin info interna)
6. ⏳ Sistema de rebotes con `argendreams_comentarios_admin`
7. ⏳ Reutilizar gestión de usuarios de TGA
8. ⏳ Sheet BYD precios (Fer crea, código lee)
9. ⏳ Dominio + GitHub Pages + CNAME
10. ⏳ WhatsApp (cuando Fer tenga la nueva línea)
11. Lista inicial de usuarios reales: vendedores + Agustín + 7-8 reventas

## Decisiones de la primera sesión (26-may-2026)

- Supabase: reusar el proyecto de TGA con prefijo `argendreams_*` (más simple, evita configurar nueva Edge Function de IA fotos)
- Sheet BYD: nueva, manual, con precios de lista oficiales (distinta a la del scraper que ya existe)
- Color del usado: lo carga el vendedor (lo necesita el reventa)
- Usuarios reales: se cargan después de tener la plataforma funcional con usuarios de prueba
- Dominio: a definir, probablemente `tasador.argendreams.com.ar`
- WA: dejar preparado el código pero sin disparar hasta nueva línea Meta
