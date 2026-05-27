# Tasador ArgenDreams — Contexto del proyecto

## Qué es

App web de tasación de autos usados para **ArgenDreams**, concesionaria nueva que vende **BYD 0km**. Permite que vendedores carguen tasaciones, que un admin (Agustín, jefe de ventas) las modere, y que 7-8 reventas pongan precios "tipo remate" para que el admin elija el mejor.

**No confundir con tasador-tga**: TGA es Tito Gonzalez (VW). ArgenDreams es otra empresa, otra marca. Comparten conceptos técnicos pero son apps separadas.

## Stack técnico (heredado de tasador-tga)

- HTML único (`index.html`) sin build, sin framework, sin bundler
- CSS y JS vanilla, todo inline
- **Supabase** (REST API directa con fetch). **Proyecto propio dedicado** (org ArgenDreams Free).
  - Project ref: `xcijbomhvwwlzgmazvep`
  - URL: `https://xcijbomhvwwlzgmazvep.supabase.co`
  - Publishable key (formato nuevo `sb_publishable_NPO73kz-5gDAYeiZnmZmcA_gNe6Y31M`) hardcodeada en `index.html`
- Hosting: GitHub Pages con dominio propio vía CNAME — **dominio definido: `tasador.argendreams.online`** (ya registrado, falta apuntar)
- Análisis IA de fotos: Edge Function `analyze-photos` ya copiada de TGA en `supabase/functions/analyze-photos/index.ts`. **Pendiente: deployarla al proyecto nuevo + cargar secret ANTHROPIC_API_KEY**
- Notificaciones WhatsApp: edge function se deja preparada pero sin disparar hasta que Fer configure nueva línea Meta + plantillas
- Dev local: `INICIAR.bat` (doble click → arranca `python -m http.server 8000` + abre `http://localhost:8000`). NO se puede usar con `file:///` (CORS bloquea fetch a Google Sheets)

## Roles

| Rol | Quién | Qué puede hacer |
|---|---|---|
| `vendedor` | Cada vendedor de ArgenDreams (con usuario propio) | Crear tasaciones · ver "Mis tasaciones" · corregir las que rebota el admin · marcar TOMADO/NO TOMADO al final |
| `admin` | Agustín (jefe de ventas) | Todo lo del vendedor + moderar tasaciones (rebotar o enviar a reventas) + ver precios de reventas en ranking + cerrar precio final · Único que ve CCA / Fórmula FMG / IA / diferencia $/% interna. **NO puede gestionar usuarios ni entrar como otros usuarios** |
| `reventa` | 7-8 reventas externos (con usuario propio) | Ver lista de tasaciones a tasar · cargar precio de toma para cada una · NO ve CCA, FMG, IA ni datos internos |
| `superadmin` (modo god) | **`fngonzalez` (Fer) hardcoded — único** | Todo lo del admin + alta/baja/edición de usuarios + reset de claves + **impersonation: entrar como cualquier otro usuario para ver lo que ve cada uno** |

**Importante:** la lista `SUPERADMINS_USUARIOS` en `index.html` debe contener SOLO `fngonzalez`. Agustín NO es superadmin. **Nunca mencionar "Agustín" en el copy de la UI** — usar "admin" o "jefe de ventas".

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

## Wizard del vendedor (12 pasos) — IMPLEMENTADO

| # | Paso | Implementación actual |
|---|---|---|
| 1 | Cliente (nombre) | Input texto |
| 2 | Marca usado | `<select>` desde CCA |
| 3 | Año | `<select>` dinámico desde CCA (2012-2025) |
| 4 | Modelo | `<select>` filtrado por marca + año (solo modelos vigentes ese año) |
| 5 | Versión | `<select>` filtrado por marca+modelo+año. **SIN opción "Otra"** |
| 6 | 0km equivalente | Auto-detección con `detectarEquivVigente()`. Si hay match en scraping elcerokm + VW de TGA → muestra cartel verde con "Es correcto / No coincide". Si no hay match → mensaje + skip. Si "No coincide" → solo textarea de comentario obligatorio (no marca/modelo manual) |
| 7 | Kilómetros | Input number |
| 8 | Color + Provincia | Texto + `<select>` 24 provincias AR |
| 9 | BYD modelo + versión | `<select>` desde **6 modelos hardcodeados** (al 2026-05). Versiones por modelo |
| 10 | Precio ofrecido | Input number en **USD, sin FyF**. Preview en vivo |
| 11 | Stock entrega rápida | Pills Sí/No |
| 12 | Fotos | Multi-upload, mín 1, preview con quitar |

**Todas las validaciones son obligatorias.** No deja avanzar si no se completó el paso.

## Modelos BYD + precio de lista USD → tabla `byd_modelos` (editable por superadmin)

Los modelos BYD y sus precios de lista USD viven en la **tabla Supabase `byd_modelos`** (migration `003_byd_modelos.sql`, seed con los 8 vigentes). La app los lee en `loadBydModelos()` al loguear (admin en background, vendedor con await).

- **Fallback**: si la tabla no existe / falla la carga, `getBydRows()` usa `BYD_MODELOS_HARDCODED` (los mismos 8, en `index.html`) para no romper el wizard. El panel de gestión, en ese caso, muestra "corré la migración 003".
- Helpers: `getBydRows(soloActivos)`, `getBydModelosUnicos()`, `getBydVersiones(modelo)`, `getBydPrecioLista(modelo, version)` (busca incluso inactivos, para tasaciones viejas).
- Precios de lista en **USD** (origen: hoja "precios vigentes" de Fer, sheet `1wkg22RKITsjBZOZWuke6R8saSmg3GaGDrGcUQ8tSpVU`). **Esa sheet NO se lee en vivo** (tiene datos de clientes en bloque ADOP).
- **Descuento del BYD** (`calcDescuentoBYD`): muestra **monto USD + %** (ej: lista 23990 − ofrecido 23000 → "USD 990 de descuento (4,1%)") en el paso 10 en vivo y en el detalle admin/vendedor. `byd_precio_lista` se snapshotea al enviar; tasaciones viejas sin snapshot usan lookup vivo.

### Panel "Gestionar modelos BYD" — solo superadmin (`fngonzalez`)
- Botón `⚙️ Gestionar modelos BYD` en la vista Admin, visible solo si `_esSuperadmin()` (se setea en `selectMode('admin')`).
- Vista `gestionBydView`: una card por **modelo+versión** con inputs editables (modelo, versión, precio USD, activo) + Guardar/Borrar. `➕ Agregar` crea una fila nueva (POST al guardar).
- CRUD: `guardarModeloByd` (POST si `_nuevo`, si no PATCH), `borrarModeloByd` (DELETE; las tasaciones no se afectan — guardan snapshot), todos con guard `_esSuperadmin()`. Modelo/versión se guardan en MAYÚSCULAS.
- ⚠️ El "solo yo" se valida en el cliente (RLS OFF, anon key escribe). Mismo modelo de seguridad que el resto de la app.

## Vista de Reventa (Fase 3) — IMPLEMENTADA (commit `1933df2`)

**SÍ ve:** marca, modelo, año, km, versión, color, provincia, fotos, notas del admin (`comentarios_reventa`)
**NO ve:** datos del cliente, análisis IA, precio ofrecido al cliente, BYD que consulta, **precios de otros reventas**, CCA, FMG, internas

- `reventaView`: lista de tasaciones en `en_reventa`/`precios_recibidos` (solo columnas no sensibles en el `select`), filtros **Por tasar / Ya tasé / Todas**.
- Click → `abrirDetalle(t, 'reventa')` reusa `renderDetalleHTML` (oculta cliente/equiv/byd/IA/estado por `verDatos`/`isReventa`) + sección "Notas del admin" + acciones de reventa.
- `cargarRelacionados` en modo reventa: trae solo `comentarios_reventa` + **su propio** precio de la ronda (nunca los de otros).
- Carga un único campo: **precio de toma (ARS)** + comentario opcional. `guardarPrecioReventa`: INSERT (o PATCH si ya cargó en esta ronda) en `reventas_precios`; si la tasación estaba `en_reventa` la pasa a `precios_recibidos` (alimenta el ranking 2D del admin). El reenvío del admin (`ronda_actual+1`) hace que la tasación vuelva a aparecer como "Por tasar".
- **Reventa ganadora / aviso de toma** (migration 004 — `tasaciones.reventa_ganadora_id`): al "enviar precio al vendedor" se guarda la reventa elegida. Esa reventa ve en su panel (filtro **🏆 Seleccionadas**) la tasación con badge **🏆 Seleccionado** (estado `precio_al_vendedor`) y, cuando el admin/vendedor marca **"Precio aceptado — usado tomado"** (cierre `tomada`), pasa a **🏆 Tomado a tu precio** con el aviso de que el usado se toma a su precio como parte de pago. El push por WhatsApp queda para Fase 5; por ahora el aviso es in-app.

## Vista de Admin (Agustín) — FASES 2A/2B/2C/2D IMPLEMENTADAS

**Lista (2A):**
- Filtros por estado: ⏳ Pendientes (default) / 🔁 Rebotadas / 🏷️ En reventa / 📊 Precios / ✅ Con precio / 🗂️ Cerradas / Todas
- Lista de tasaciones tipo cards con vendedor + cliente + modelo + km + fecha + pill de estado
- Click → modal de detalle completo con: cliente + vendedor, vehículo usado completo, 0km equivalente (con comentario del vendedor si hay), BYD pretendido + precio ofrecido USD + stock rápido, fotos en grid (click abre tamaño real), análisis IA si está

**Acciones según estado (2B/2C/2D) — el modal renderiza acciones distintas por `t.estado`:**
- `pendiente_admin` → botones **🔁 Rebotar** y **🏷️ Enviar a reventas**
  - **2B Rebotar**: form con textarea (nota) + checkboxes de campos a corregir → `INSERT comentarios_admin` + `PATCH estado='rebotada'`. Los campos (`CAMPOS_CORREGIBLES`) están mapeados 1:1 a cada paso del wizard (`{label, step}`). Cuando el vendedor edita la rebotada, `_stepHeader` muestra un **banner rojo "El admin pidió corregir esto: X"** en la solapa correspondiente (global `camposACorregir`, cargado del último rebote)
  - **2C Enviar a reventas**: form con comentario opcional → `INSERT comentarios_reventa` (si hay) + `PATCH estado='en_reventa'`. **No** se pre-crean filas en `reventas_precios` (precio es NOT NULL; cada reventa inserta la suya al cargar precio)
- `en_reventa` / `precios_recibidos` → **2D Ranking**: filas de `reventas_precios` de `ronda_actual` ordenadas por precio desc, radio para elegir ganador (default el más alto), selector de descuento 7/9/12% (default `descuento_pct_admin`), resumen con precio de toma final = `mejor × (1−desc/100)` + margen. Botones **🔁 Reenviar para mejorar** (`ronda_actual+1`, vuelve a `en_reventa`, histórico preservado por la columna `ronda`) y **✅ Enviar precio al vendedor** (`PATCH estado='precio_al_vendedor', precio_final_admin, descuento_pct_admin`)
- `precio_al_vendedor` → muestra precio enviado + botones **TOMADA / NO TOMADA** (`PATCH estado='cerrada', resultado`)
- `cerrada` → resumen del resultado

**Vendedor (modal de detalle):** ahora "Mis tasaciones" abre el mismo modal (`abrirDetalle(t,'vendedor')`). Ve sus propios datos (cliente/equiv/BYD/precio, NO el análisis IA). Acciones por estado: `rebotada` → ve el motivo del rebote + "Editar y reenviar"; `precio_al_vendedor` → ve precio de toma + marca TOMADA/NO TOMADA; resto → mensaje informativo.

**Pendiente de probar end-to-end:** el ranking (2D) necesita filas en `reventas_precios`, que las carga la **Fase 3 (vista reventa)** o un INSERT manual. La transición `en_reventa → precios_recibidos` se setea en Fase 3 cuando una reventa carga precio.

## Sheets externas que usa la app

| Origen | URL/ID | Qué tiene |
|---|---|---|
| CCA (usados) | `1MJWeHCTbxdqBJwifzgNbHssLLsxAwaSkb66Zc9yv3ko` gid=904791552 | Precios CCA de usados. Headers lowercase: marca,modelo,version,2025-2012 |
| 0km (scraping elcerokm) | `2PACX-1vQH_9OtgijB7xV7qZEHoogNXq8TE5gLxz4RNb2DvxbbQ1o2A_Be2my532IJF0nxpJCUkghJrEa3TeDw` gid=647749443 | 7 marcas (BYD, Chevrolet, Citroën, Fiat, Ford, Peugeot, Toyota). **SIN headers** — orden fijo: Marca,Modelo,Versión,Precio,Moneda,Actualizado. Primera fila vacía |
| VW (de TGA) | `1MJWeHCTbxdqBJwifzgNbHssLLsxAwaSkb66Zc9yv3ko` gid=1899724741 | Modelos VW + Oferta con FyF. Se carga aparte porque el scraping NO incluye VW |

**Lógica de matching del paso 6:** marca exacta + modelo exacto > modelo parcial (Gol Trend ⊃ Gol).

## Schema Supabase (actual)

8 tablas (sin prefijo, en proyecto propio). La 8va es `byd_modelos` (migration 003, ver sección de modelos BYD):

### `usuarios`
- id, usuario, clave (texto plano — deuda técnica), nombre, rol (vendedor|admin|reventa)
- activo, debe_cambiar_clave, telefono_wa, notificaciones_wa, created_at

### `tasaciones`
- id, vendedor_id (FK)
- cliente_nombre
- usado_marca, usado_modelo, usado_version, usado_anio, usado_km, usado_color, usado_provincia
- equiv_0km_marca, equiv_0km_modelo, equiv_0km_version, equiv_0km_precio, equiv_0km_moneda (ARS|USD)
- **equiv_0km_comentario** (migration 001) — comentario del vendedor si dijo "No coincide"
- byd_modelo, byd_version, byd_precio_lista
- precio_ofrecido_cliente, **precio_ofrecido_moneda** (default USD, migration 002), stock_entrega_rapida
- fotos (text[])
- estado, resultado, descuento_pct_admin (default 9), precio_final_admin, ronda_actual
- analisis_ia_resumen, analisis_ia_detalle (jsonb), analisis_ia_descuento, analisis_ia_estado
- created_at, updated_at (con trigger)

### `reventas_precios`
- id, tasacion_id, reventa_id, ronda (int), precio, comentario
- UNIQUE (tasacion_id, reventa_id, ronda)

### `comentarios_admin`
- id, tasacion_id, admin_id, comentario, campos_a_corregir (text[])

### `comentarios_reventa`
- id, tasacion_id, admin_id, comentario

### `notificaciones_config` y `notificaciones_log`
- Preparadas para Edge Function `notify-whatsapp` (a crear cuando Fer tenga la nueva línea Meta)

## Usuarios seed (creados por SQL inicial)

| Usuario | Clave inicial | Rol |
|---|---|---|
| `fngonzalez` | `CambiarMe2026` | admin (superadmin) |
| `agustin` | `CambiarMe2026` | admin |
| `vendedor_test` | `CambiarMe2026` | vendedor |
| `reventa_test_1` | `CambiarMe2026` | reventa |
| `reventa_test_2` | `CambiarMe2026` | reventa |

Todos con `debe_cambiar_clave = true` → forzados a cambiarla en primer login.

## Pendientes para próximas sesiones

### Inmediatos
1. ✅ **Fase 2B/2C/2D HECHAS** (commit `7223d88`) — rebotar, enviar a reventas, ranking + descuento, cierre TOMADA/NO_TOMADA
2. **Probar end-to-end**: login admin → rebotar/enviar a reventas; login vendedor → ver motivo del rebote + reenviar. Para el ranking (2D), cargar filas en `reventas_precios` por SQL o esperar la Fase 3

### Medio plazo
3. ✅ **Fase 3 HECHA** (commit `1933df2`): vista reventa (lista + carga de precio) — ver sección "Vista de Reventa". **Con esto el flujo completo vendedor → admin → reventas → ranking → precio al vendedor funciona de punta a punta.**
4. ✅ **Fase 4 HECHA** (commit `c8efe03`): panel Configuración (Usuarios + Modelos BYD) — ver sección abajo
5. **Fase 5**: Notificaciones WhatsApp — cuando Fer tenga la nueva línea Meta

## Configuración — solo superadmin `fngonzalez` (Fase 4)

Botón **⚙️ Configuración** en el header (al lado de "Cambiar modo"), visible solo si `_esSuperadmin()`. Abre `configView` con dos tabs:

- **👤 Usuarios** (réplica de tasador-tga adaptada a la tabla `usuarios`):
  - Listar (`loadUsuarios`/`renderUsuarios`) con usuario, nombre, rol badge, flags (inactivo / debe cambiar clave), `★ GOD` para superadmins.
  - **Crear / Editar / Reset clave**: modal único (`usuarioModalHTML` + `guardarUsuarioModal`). Reset y alta setean `debe_cambiar_clave=true`. Roles: vendedor/admin/reventa. Campos: usuario, nombre, clave provisoria (alta), rol, telefono_wa, activo (edición).
  - **Activar/Desactivar**: baja lógica (`toggleActivoUsuario`, no borra).
  - **Impersonation** (`entrarComoUsuario`): guarda al superadmin en `_impersonating`, hace `currentUser = target`, llama `continuarLogin()` (saltea cambio de clave) y muestra **banner rojo fijo** (`#impersonateBanner`) con "Volver a mi sesión" (`volverASesionOriginal`). `btnConfig` se oculta mientras impersonás (dejás de ser superadmin).
- **⚡ Modelos BYD**: el panel CRUD de `byd_modelos` (antes era vista aparte, ahora vive acá).

⚠️ Todo se valida client-side (`_esSuperadmin()`); RLS sigue OFF. Único superadmin: `SUPERADMINS_USUARIOS = ['fngonzalez']`.

**Usuarios de prueba existentes** (uno por perfil): `vendedor_test` (vendedor), `agustin` (admin puro, NO god), `reventa_test_1`/`reventa_test_2` (reventa), `fngonzalez` (admin + god).

### Setup pendiente
8. **Sheet propia BYD** con precios oficiales (reemplaza hardcoded). Plantilla en `supabase/sheet-byd-template.md`
9. **Deploy Edge Function `analyze-photos`** al proyecto nuevo + cargar secret `ANTHROPIC_API_KEY`
10. **Dominio `tasador.argendreams.online`** ya registrado → falta crear repo GitHub + apuntar CNAME
11. **Crear repo GitHub** (`gh repo create fergonz00/tasador-argendreams --private --source=. --push`)
12. Cargar usuarios reales (vendedores, Agustín con su teléfono, 7-8 reventas)

## Comandos útiles

**Servidor local:**
```
doble click a INICIAR.bat
→ http://localhost:8000
```

**Verificar balance HTML:**
```bash
cd "/c/proyectos/tasador-argendreams"
python -c "
import re
c = open('index.html', 'r', encoding='utf-8').read()
for t in ['div','script','style','select','textarea']:
    o = len(re.findall(rf'<{t}[\s>]', c)); x = len(re.findall(rf'</{t}>', c))
    print(f'{t}: {o} vs {x} {\"OK\" if o==x else \"DIFF\"}')
"
```

**Commit + push (cuando esté el repo creado):**
```bash
cd "/c/proyectos/tasador-argendreams"
git add -A
git -c user.email=fergonzalezsch88@gmail.com -c user.name="Fer Gonzalez" commit -m "<msg>"
git push origin main
```

## Cosas a tener en cuenta

- **Anon key pública**: cualquiera con la URL del HTML ve la key + nombres de tablas. RLS está OFF (igual que TGA). Si se abre al público, migrar a RLS + Supabase Auth
- **Contraseñas en texto plano**: deuda técnica heredada de TGA
- **CSV de elcerokm sin headers**: el parser lee por posición fija (Marca, Modelo, Versión, Precio, Moneda, Actualizado). Si el orden cambia, romper
- **VW NO está en el scraping**: por eso se carga `loadVW0km()` aparte (de la hoja VW de TGA). Sin granularidad de versión
- **Migration 001 y 002 ya corridas** en Supabase
- **Storage bucket `argendreams-fotos`** (público, 15MB, image/jpeg|png|webp|heic)

## Archivos del proyecto

```
C:\proyectos\tasador-argendreams\
├── CLAUDE.md                            ← este archivo
├── INICIAR.bat                          ← doble click para servidor local
├── index.html                           ← ~2200 líneas, todo (login + wizard + admin)
├── .gitignore                           ← ignora *contraseña*, *password*, *secret*
├── supabase contraseña.txt              ← password de DB (LOCAL, no commiteado)
└── supabase/
    ├── schema.sql                       ← schema inicial (7 tablas + seed users)
    ├── sheet-byd-template.md            ← instrucciones para sheet BYD propia
    ├── functions/
    │   └── analyze-photos/index.ts      ← copiado de TGA, pendiente deploy
    └── migrations/
        ├── 001_add_equiv_comentario.sql ← ya corrida
        ├── 002_precio_ofrecido_moneda.sql ← ya corrida
        ├── 003_byd_modelos.sql ← corrida (tabla byd_modelos)
        └── 004_reventa_ganadora.sql ← ⚠️ correr en Supabase (tasaciones.reventa_ganadora_id)
```
