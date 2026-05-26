# Sheet de precios BYD 0km — ArgenDreams

## Qué es

Sheet pública de Google con los **precios de lista oficiales** de los modelos BYD que vende ArgenDreams. La app la lee como CSV vía `gviz/tq?tqx=out:csv` para mostrar al vendedor los modelos vigentes en el paso 10 del wizard.

**Distinta a la sheet del scraper-byd-precios** que vive en la sheet "Tito" — esa scrapea elcerokm.com diariamente y es para Argendreams (revisar memoria `project_scraper_byd`). La que se necesita acá es **manual**, con los precios de lista oficial de ArgenDreams.

## Estructura propuesta de la sheet

Hoja única (puede llamarse "PRECIOS" o "BYD"). Columnas:

| Columna | Tipo | Ejemplo | Notas |
|---|---|---|---|
| Modelo | text | DOLPHIN | Mayúsculas, sin tildes |
| Versión | text | GS | Versión exacta como la promocionan |
| Precio | number | 28500000 | Precio de lista en ARS (sin formato, sin separadores) |
| Moneda | text | ARS | ARS o USD (todos en ARS preferentemente) |
| Stock disponible | text | Sí / No / Limitado | Opcional |
| Actualizado | date | 2026-05-26 | Para auditoría |

Primera fila = headers exactos como arriba.

## Cómo publicar

1. Crear el Sheet en la cuenta de Google de Fer/ArgenDreams
2. Archivo → Compartir → Publicar en la web
3. Elegir hoja PRECIOS, formato CSV, "Publicar"
4. Copiar la URL que tiene formato:
   ```
   https://docs.google.com/spreadsheets/d/e/{ID}/pub?gid={GID}&single=true&output=csv
   ```
5. Pasar la URL a Claude para hardcodearla en `index.html` como `BYD_PRECIOS_CSV_URL`

## Modelos BYD que suele vender ArgenDreams (referencia, a confirmar con Fer)

- **DOLPHIN** (compacto eléctrico) — versiones GS, GL
- **SEAL** (sedán eléctrico) — Design, Excellence AWD
- **YUAN PLUS / ATTO 3** (SUV eléctrico)
- **HAN** (sedán premium)
- **SONG PLUS** (SUV híbrido)
- **SHARK** (pickup eléctrica)

Fer va a definir la lista completa cuando arme la sheet.
