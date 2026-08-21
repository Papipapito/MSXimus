# Pantalla de lanzamiento (ROM y DSK) — diseño de layout fijo

**Estado:** implementado en MSXnano (commits `a15480a` + pantalla DSK, 2026-07-16).
**Objetivo de este doc:** que el mismo diseño se pueda implementar en el **MSXimus**
(el menú es el MISMO `src/menu_main.asm` con el flag `IF MSXIMUS`; portar = llevar
estos cambios a la copia del menú del repo MSXimus, o recompilar con el flag).

## Por qué se rediseñó

La pantalla antigua apiñaba todo en las filas 1-8, imprimía los campos en
secuencia (el tamaño de 1-4 dígitos desplazaba la columna del mapper), al ciclar
el mapper con M solo limpiaba 4 espacios (los nombres van de 6 a 15 chars →
residuos en pantalla), la barra no escalaba (una ROM de 2MB la desbordaba y se
capaba al 25%; una de 16K apenas pintaba 2 bloques) y los nombres largos hacían
wrap descolocando el resto. La pantalla de DSK era otra distinta (3 líneas).

## Principios

1. **Layout FIJO**: cada elemento tiene fila/columna constantes. Nunca se
   recoloca nada en función del contenido.
2. **Campos de ancho fijo + limpieza previa**: todo campo dinámico se borra a su
   ancho completo (`clear_at`) antes de reimprimir. Imposible dejar residuos.
3. **Una sola pantalla para ROM y DSK**: esqueleto común (`.bls_skel`); solo
   cambian título, etiquetas de la fila de datos, textos de estado y pie.
4. **Barra siempre creíble**: marco fijo de 64 celdas; el relleno se escala al
   tamaño real (Bresenham) y SIEMPRE termina llena.

## Layout (SCREEN 0 / TEXT2, 80×24; POSIT: H=columna, L=fila, 1-based)

| Fila | Contenido | Posición / campo |
|---|---|---|
| 2  | Título centrado: `Lanzar ROM` / `Lanzar disco` | ROM col 36 (`#2402`), DSK col 35 (`#2302`) |
| 3  | Línea fina (char `#10`) | `draw_hline` con A=3 |
| 6  | Etiqueta `Fichero:` | col 3 (`#0306`) |
| 8  | Nombre del fichero | col 5, **máx 72**; si len>72 → 69 chars + `...` (`.bsr_name`) |
| 11 | Fila de datos | `Tamano:` col 5 + valor col 13 (campo 6, `"2048K"`) · `Mapper:`/`Tipo:` col 27 + valor col 35 (**campo 15**) · `SRAM:` col 57 + On/Off col 63 (solo ROM ASCII8/16; el grupo se borra entero si no aplica) |
| 15 | Barra de progreso | `[` col 8 · 64 celdas cols 9-72 · `]` col 73. Track vacío = char `#10`; relleno = `#DB` |
| 17 | Estado | col 26, **campo fijo 30** (cols 26-55). Spinner del análisis en col 44 (`#2C11`) |
| 21 | Línea fina | `draw_hline` con A=21 |
| 22 | Pie de teclas centrado | fila borrada entera (79 cols) y variante impresa en su columna de centrado |

### Textos de estado (caben en el campo de 30)

- ROM: `Analizando ROM...` (+spinner) → `Cargando ROM en megaram...` → `ROM cargada.`
- DSK: `DSK listo para montar.` → `Montando disco Nextor...`
- Errores DSK (vía `.bsd_err`): `DSK fragmentado: recopialo` / `Falta NEXTOR.EMU en la raiz` /
  `Error escribiendo en la SD` — el pie cambia a `Pulsa una tecla para volver...` (col 26).

### Pies (fila 22)

- ROM ASCII8/16 (54 ch, col 14): `RETURN = Lanzar   M = Mapper   S = SRAM   ESC = Volver`
- ROM resto (43 ch, col 19): `RETURN = Lanzar   M = Mapper   ESC = Volver`
- DSK (39 ch, col 21): `RETURN = Montar y lanzar   ESC = Volver`

## Rutinas (todas en `menu_main.asm`, locales del bloque del browser salvo indicado)

- **`.bls_skel`** — esqueleto común: `cls_browser` + `BROWSING=0` + líneas 3/21 +
  `Fichero:` + `.bsr_name` + marco de la barra. Cada pantalla pinta su título después.
- **`.bsr_name`** — nombre con strlen acotado (73): ≤72 entero; si no, 69+`...`.
- **`.bsr_status`** — HL=texto → `clear_at(#1A11, 30)` + print. Cada mensaje tapa
  el anterior (y el spinner).
- **`.bsr_mprint`** — mapper en campo 15 (`clear_at(#230B,15)` + nombre).
- **`.bsr_sprint` / `.bsr_sprcl`** — grupo SRAM (pinta / borra 9 cols desde col 57).
- **`.bsr_footer`** — borra fila 22 y pinta la variante ROM que toque.
- **`.bsd_err`** — HL=error → estado + pie "pulsa una tecla" + `browse_getkey` + volver.
- **`.bsd_fillbar`** — barra al 100% de golpe (montaje DSK: no hay carga larga).
- **`clear_at`** (global) — HL=pos (#ColFila), B=ancho: borra el campo y deja el
  cursor reposicionado al inicio → el llamador imprime encima.
- **`rom_kb`** (global) — HL=KB del fichero seleccionado (sirve para ROM y DSK;
  refactor de `print_rom_kb`). También escala la barra.

### Barra escalada (en `load_rom`)

- `BAR_TOT = max(1, ceil(KB/8))` = segmentos de 8K de la ROM (2MB → 256).
- Por cada segmento de 8K completado (`LOAD_OFF` envuelve a 0):
  `BAR_FRAC += 64`; mientras `BAR_FRAC >= BAR_TOT`: resta y pinta una celda `#DB`
  (Bresenham exacto: al acabar hay pintadas exactamente 64).
- `BAR_CNT` capa el total a 64 celdas (no pisa el `]`); al terminar la cadena de
  clusters se rellena hasta 64 (por si el size del directorio no cuadra).
- Variables: `BAR_FRAC #E83C` (2B), `BAR_TOT #E83E` (2B), `BAR_CNT #E85A` (1B) —
  huecos libres verificados del mapa de RAM. **En MSXimus verificar que esos
  huecos siguen libres** si su copia del menú divergió.

## Gotchas (¡leer antes de portar!)

1. **CHPUT ignora los códigos de control 0x00-0x1F** (no imprime NI avanza el
   cursor). El track de la barra (char `#10`) va por **FILVRM** directo a la name
   table: `HL=#0468` (fila física 14×80 + col física 8), `BC=64`, `A=#10`. Es el
   mismo motivo por el que `draw_hline` usa FILVRM.
2. **Apagar el marquee del browser**: `BROWSING=0` al entrar a la pantalla
   (lo hace `.bls_skel`). Si no, `browse_getkey` → `marquee_tick` repinta nombres
   >59 chars en scroll ENCIMA de la pantalla. `browse` lo re-asserta al volver.
3. **Rango de `jr`**: al meter las subrutinas nuevas, los saltos del bucle de
   teclas (`cp M/m/S/s`) quedaron fuera de rango → son `jp z`.
4. **Guard de tamaño**: la región pre-`#A000` lleva `ds #A000-$` (si desborda, el
   build FALLA — bien). Tras este rediseño quedan ~**100 bytes** de margen en el
   MSXnano. Si al portar no cabe, mover strings a la región post-`#A010`.
5. **POSIT: H=columna, L=fila** (1-based). OJO: el comentario de `print_on_off`
   dice lo contrario y está MAL (el código pasa HL directo a POSIT).
6. **Build limpio** (`rom:` ya depende de `clean`). Desde WSL las tools son .exe:
   `make rom BINASM="./bin/asmsx.exe -z -r" BINZX0="./bin/zx0.exe -f"
   BINZX7="./bin/zx7mini.exe" BINPLETTER="./bin/pletter.exe"`.
7. El resultado (`fm_logo_menu.bin`, 16K) se inyecta en el pack a **0x6C000**
   (`dd seek=442368 conv=notrunc`). Solo cambia el `.bin`; el `.fs` no se toca.

## Port a MSXimus — pasos

1. El menú del MSXimus es la variante `IF MSXIMUS` del MISMO fichero. Llevar el
   diff de `menu_main.asm` (pantallas ROM+DSK, helpers, strings, equs BAR_*) a la
   copia del repo MSXimus (`MSX_up`).
2. Verificar los 3 equs `BAR_*` contra el mapa de RAM de esa copia.
3. Recompilar con el guard y comprobar el margen; probar: ROM corta (16K), ROM
   2MB, nombre >72 chars, ciclar M varias veces, DSK OK y DSK fragmentado.
