# VRAM → BRAM — diseño APARCADO (análisis 2026-07-11)

> **Estado: APARCADO por decisión de producto.** El análisis está completo y es
> válido; no se ejecuta ahora porque metería la BRAM del chip al 92-97% y
> **congelaría** las features BRAM-hambrientas del roadmap (OPL4/V9990/frontend).
> v1.1 se cierra con el turbo de 4.40 MHz (honesto y estable). Este documento
> conserva el análisis para no repetirlo cuando se retome.

## Por qué se planteó

El turbo se queda en **4.40 MHz** (medido) en vez de los 5.369 nominales. Causa
raíz **medida** (`tools/sdr16_tb`, tests T9b/T10):

- La SDRAM sirve **6.75 MHz sostenido** (periodo 148 ns) → el ancho de banda no
  es el techo.
- CPU y VDP **comparten** la SDRAM por división de tiempo 50/50 (la impone el
  propio VDP con `video_dlclk`/`dhclk`). La CPU recibe **un slot por ventana de
  vídeo** = 6.75 MHz de cadencia de acceso.
- Las rejillas de slot (6.75 MHz) y de T-state turbo (5.369 MHz) son
  **inconmensurables** → el 25% de las lecturas caen justo pasado el borde del
  T-state y pierden un T entero. `5.369 / 1.25 ≈ 4.30`, que cuadra con el 4.40.

Se agotaron los retoques baratos del handshake: iter.2b=4.33, iter.3-A=4.40;
iter.2c/2d **corrompieron** lecturas. **4.40 es el techo práctico** de la
arquitectura de SDRAM compartida.

Sacar la VRAM del VDP a memoria propia resolvería **dos** cosas de una:
- **(a) Turbo real**: la CPU se queda con todos los slots → cadencia 6.75→13.5
  MHz → holgura de sobra sobre 5.369.
- **(b) Screen 3 curado de raíz**: `vram_write` deja de competir por el slot
  físico de la SDRAM → el refresh corre incondicional → la inanición (el cuelgue
  de multicolor en modo normal) **no puede ocurrir**. Los guards MG2 y
  anti-inanición (`rfsh_skip_cnt`) pasan a ser código muerto que se borra.

## El presupuesto de BRAM es el bloqueo

- GW5AT-60: **118 bloques BSRAM × 18 Kbit = 2124 Kbit**. La build _71b usa
  **51/118 (44%)** → 67 bloques libres.
- VRAM = **128 KB FIJOS** (`VdpAdr[16:0]`; el bit 16 es selector de lane, no
  dirección — el core no direcciona 192 KB sin reescribir el núcleo VDP).
- 128 KB en BRAM = 64 bloques (modo 16 Kbit → **97% total**) o ~57 (modo 9-bit
  → **92%**). **Entra, pero deja la BSRAM al 92-97% = margen casi nulo.**
- Ese techo **congela** OPL4 (F2), V9990 (F3) y el frontend gráfico (F4). En
  este chip, VRAM→BRAM y esas features son **casi excluyentes** salvo que se
  libere BRAM en otro sitio primero.

## DDR3 — descartado para VRAM

`fpga/src/memory_ddr3.v` está **al 0%** (esqueleto: IP sin generar, instancia
comentada). El DDR3 (Hynix 512 MB ×16) tiene latencia **alta y variable** +
refresh + calibración → choca con el **contrato del puerto VRAM del VDP**
(latencia **fija de 1 ciclo `clk_27m`, sin ACK**). Reintroduciría justo la
latencia que queremos quitar. El DDR3 queda para CPU/mapper/framebuffer futuro,
no para VRAM.

## Contrato del puerto VRAM (para cuando se retome)

4 señales, hoy servidas por `memory.v` (`mem1` en `top.v`):

| Señal | Dir | Ancho | Notas |
|---|---|---|---|
| `vram_addr` (`VdpAdr`) | in | `[16:0]` | `[15:0]`=palabra (64K); `[16]`=lane (par/impar) |
| `vram_din` (`VrmDbo`) | in | `[7:0]` | byte de escritura |
| `vram_write` (`~WeVdp_n`) | in | nivel | **no** es pulso; se cualifica a strobe 1T por dot |
| `vram_dout` (`→VrmDbi`) | out | `[15:0]` | palabra completa; el VDP elige lane |

Reloj `clk_27m`, **latencia de lectura fija de 1 ciclo** → una BRAM síncrona es
drop-in. **Crítico**: implementar los DOS lanes de verdad (byte-write-enable por
`[16]`). El stub `ram64k` del repo devuelve `{dbi,dbi}` y **rompería
GRAPHIC6/7** (2 fetches/dot con lanes independientes).

## Plan incremental (8 builds, TB-first) — cuando se retome

0. Golden TB `vram_bram_tb.v` (marco de `sdr16_tb`; patrón G6/7 de 2 fetches/dot
   que exige lanes reales).
1. `vram_bram.v` (64K×16 dual-lane, byte-write-enable por `[16]`). TB verde.
2. Conmutar la fuente de `VrmDbi2` al módulo BRAM por define (SDRAM aún
   cableada). 5 puertas + BSRAM ≤115/118 en el `.rpt` + Screen 3 no cuelga.
3. Fijar el modo BSRAM real (16 Kbit=64 vs 9-bit=57) según el reporte P&R.
4. Borrar el datapath VDP muerto de `memory.v` (estados `SdrSta` 110/111;
   generación fila/banco/col VDP; lane; `SdrDat`; latch `vram_dout`) **y** los
   guards MG2/`rfsh_skip_cnt`.
5. **Refresh AUTÓNOMO** (7.8 µs/fila del W9825) desacoplado del slot VDP —
   **antes** de repurposar slots, o la SDRAM se descarga.
6. Árbitro CPU-only: **no es una línea** — los muxes de fila/col/DQM/dato leen
   `video_dlclk` EN VIVO, no el `SdrSta[1]` latcheado; hay que forzarlos a la
   rama CPU. z80bench → hacia 5.37+.
7. Validación HW de la meta doble + limpieza de señales muertas (`sdram_read`,
   `sdram_dout`, `enable_sdram`, `SdrSize`, `FreeCounter2`, `wire VrmDbi`, el
   oddity `reg VrmDbi2`).

## Cuándo retomarlo

Cuando se sepa el mix real de features de vídeo/audio. Si V9990 acaba siendo el
camino, quizá su propia VRAM y este trabajo se fusionen. Si antes se libera BRAM
(mover buffers/ROM de CPU a DDR3/SSRAM), el 92% deja de ser bloqueante.

*(Análisis completo del workflow de 6 agentes en la memoria de Claude y en
`scratchpad/vram_plan.json` de la sesión.)*
