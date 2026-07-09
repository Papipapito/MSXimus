# Plan "base mínima" — Console 60K (2026-07-09)

Cambio de estrategia acordado: aparcar SCC, conseguir que el HDMI arranque
SIEMPRE, montar una base mínima estable y re-añadir subsistemas de uno en uno.
Basado en el estudio de los tres proyectos que funcionan en esta placa:
nestang/snestang, C64Nano (MiSTle) y z8086 (arrancó a la primera).

## Lo que hacen los proyectos que funcionan (y nosotros no hacíamos)

| Patrón | nestang | C64Nano | z8086 | MSX_up (antes de v3.0) |
|---|---|---|---|---|
| PLLA con wrapper PLL_INIT (trim MDRP + lock filtrado) | sí | sí | sí | sí (ya lo teníamos) |
| mdclk de la PLLA = reloj de pad (50M), nunca otra PLL | sí | sí | sí | sí |
| CLKDIV en reset hasta lock filtrado (+contador) | sí (255 ciclos) | sí (RESETN=lock) | no usa CLKDIV | **NO: RESETN=1 fijo** |
| OSER10 RESET=0 constante (nunca reset de fabric) | sí | (vreset síncrono de video_analyzer) | sí | **NO: reset de s1 soltado ~1 ciclo tras cargar** |
| Dominios core/video | async + BRAM dual-clock (framebuffer/ring 32 líneas) | mono-dominio (pixel==core) | async + DPB dual-clock (VRAM texto) | 54M core / 27M CLKDIV fase arbitraria |

## Diagnóstico HDMI "1 de cada 5 arranques"

PLL_INIT tarda ~1 ms trimando el charge-pump (y REINTENTA si el lock no
engancha). Durante ese tiempo la PLLA saca basura. Nuestro CLKDIV dividía esa
basura desde el ciclo 0 (RESETN=1) y el RESET de los OSER10 se soltaba ~1
ciclo tras cargar el bitstream, con los relojes aún sucios → el alineamiento
1:5 del gearbox interno del OSER10 quedaba a la lotería → cuando sale mal,
HDMI muerto hasta el power-cycle. Encaja con la observación de Albert: "si el
HDMI funciona, el LED de lock se ilumina fijo".

Reinterpretación del _28: la PLLA-directa (pclk del ODIV2) quizá NO era el
problema — z8086 alimenta los OSER10 directamente con dos ODIVs de una PLLA
(74.25/371.25) y funciona. Lo que _28 conservaba era esta disciplina de reset
rota. Se re-probará como experimento de Fase 4.

## Fase 1 — HDMI siempre arranca (build _34)

- `top.v`: CLKDIV `div5_video` en reset hasta `clock_locked` (lock FILTRADO
  por PLL_INIT, sincronizado 2FF a 135M) + 255 ciclos de 135M. Si el lock cae
  (reintento de PLL_INIT), vuelve a reset y rearranca limpio.
- `serializer.sv`: OSER10 `RESET(1'b0)` fijo (patrón nestang/z8086).
- SDC: fuera la false_path a `gwSer*/RESET` (ya no existe); false_path al
  sincronizador `lock_s135`.
- **Criterio de éxito: 15-20 power-cycles seguidos con imagen. Antes: ~1/5 fallaba.**

## Fase 2 — base mínima

Con la Fase 1 validada, build "MSX pelado" con subsistemas COMPILADOS FUERA
(`` `ifdef `` por subsistema en top.v, no ramas git):

- Queda: T80 + SDRAM (memory.v) + VDP/HDMI + teclado (BL616/hub) + PSG + SD/Nextor.
- Fuera: SCC (aparcado), OPLL, sn76489/modos consola, turbo WSX/F11, WiFi-UART,
  megaram opcional en un segundo paso si hace falta aislar más.
- Menos lógica = menos presión de placement (adiós lotería de -1ns) y menos
  frentes abiertos a la vez. El menú es software del pack flash y no estorba;
  si se quiere arranque directo a BASIC, es un pack sin menú, no un cambio RTL.

## Fase 3 — re-añadir de uno en uno

Orden propuesto (un subsistema por build, validado en placa antes del
siguiente): megaram → OPLL → turbo → modos consola → SCC (con Fase 4 hecha).

## Fase 4 — experimento estructural: 27M alineado (re-_28 bien hecho)

Con la disciplina de reset de Fase 1: pclk=ODIV2 (27M) de la MISMA PLLA en
vez del CLKDIV. Los ODIVs de un mismo VCO salen alineados tras el lock
(z8086 lo demuestra usándolos como par PCLK/FCLK). Si funciona en placa,
clk_27m queda alineado con clk_54m POR CONSTRUCCIÓN (como el rPLL del TN20K)
y muere la clase entera de bugs de fase: SCC/PSG podrían volver a 27M, y el
árbitro DH/DL y el cuelgue de SCREEN 3 pierden su sospechoso principal.
Si no funciona, plan B estructural = cruce por BRAM dual-clock en el
linebuffer (patrón nestang/snestang).

## Aparcados (no tocar hasta tener base estable)

SCC mudo (2 intentos fallidos: chip@54M _32, glue@54M _33) · SCREEN 3 (carrera
sensible a placement) · F11/turbo (3 teorías muertas) · ESC→BASIC cuelgue
azul/rayas (puede ser el mismo fondo de fase; re-evaluar tras Fase 4).
