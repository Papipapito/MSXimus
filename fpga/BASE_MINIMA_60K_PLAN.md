# Plan "base mínima" — Console 60K (v2, 2026-07-09)

Estrategia acordada: aparcar SCC, HDMI arrancando SIEMPRE, base mínima estable,
re-añadir de uno en uno. v1 se basaba en nestang/C64Nano/z8086; esta v2 integra
el **barrido completo de los 36 repos de nand2mario** (workflow 2026-07-09,
13 agentes + crítico; smstang/mdtang/gbatang/tangcore/486tang/pctang/
usb_hid_host/ddr3_framebuffer/blog…). Clones de referencia en el scratchpad
de la sesión (`n2m/`).

## A. Premisas INVERTIDAS o zanjadas por el barrido

1. **Los 2 USB-A de la Console 60K van DIRECTOS al fabric del GW5A**, no al
   BL616: `usb1_dp=H13, usb1_dn=G13, usb2_dp=M15, usb2_dn=M16` (LVCMOS33,
   tangcore `console.cst:54-62`; ⚠️ el esquemático de Sipeed está MAL, la
   verdad es el .cst). TangCore les cuelga 2× `usb_hid_host` (soft-host
   low-speed 1.5Mbps, <300 LUT + 1 BRAM por puerto, reloj 12MHz de una
   `pll_12`). **Teclado USB-A sin hub = viable YA** (límite: teclados
   full-speed no enumeran; probar el teclado concreto).
2. **DDR3 como RAM general del Z80: DESCARTADA con evidencia definitiva.**
   Ni gbatang (GBA, el core más hambriento) ni 486tang la usan de RAM: cita
   del autor en el blog de 486tang: *"So SDRAM became the main memory"*
   (multiplexar la DDR3 entre RAM y framebuffer "would have been
   complicated"; latencia lectura ~300ns y ni determinista). Nuestro plan
   (SDRAM slot = RAM MSX, DDR3 = framebuffer frontend) es EXACTAMENTE el suyo.
3. **El OSER10 NO exige CLKDIV**: los 4 cores console60k alimentan PCLK/FCLK
   con DOS ODIVs de la misma PLLA a ratio 5 (smstang `pll_74.v` ODIV0=20/
   ODIV1=4; ídem monitorcore/mdtang/tangcore). Nuestro fallo del `_28` tuvo
   otra causa (probablemente la disciplina de reset que arregló la `_34`).
   → re-test = **la cura de raíz del problema de fase 27↔54** (fase F3.2).
4. **PLL_INIT no es obligatorio** (los cores era-TangCore usan PLLA cruda,
   MDCLK=gnd, y funcionan) pero 486tang —lo más reciente— lo RE-ADOPTA y el
   trim depende de MULTI_FAC (umbrales >16/>34; el nuestro es 27).
   **Conservamos nuestro wrapper.** Matiz nestang: su CLKDIV se suelta por
   contador libre de 255 (el lock NI SE CONECTA); nuestra `_34` (lock
   filtrado + 255) es más estricta. Bien así.

## B. La arquitectura consenso de los cores que funcionan

- **Mono-dominio de core + clock-enables para TODO** (`(* direct_enable *)`).
  smstang: rueda de 30 estados a 53.7MHz → ce_cpu 3.58 / ce_vdp 10.74 /
  ce_pix 5.37 (`smstang_top.sv:104-135`). mdtang igual con 2 CPUs y 2 chips
  de audio. El blog de SNESTang lo formula: fuera ripple clocks, "phase-based
  design", relojes emparentados del mismo PLL.
- **Nunca un bus en reloj lento.** La única excepción (T80 de mdtang a
  MCLK/2 por Fmax — ¡el MISMO T80 nuestro!) lleva disciplina de 5 piezas:
  ODIV propio (no CLKDIV) + `create_generated_clock` + multicycle 4/3 + CEN
  alineado muestreando el reloj lento COMO DATO (`system.sv:211-244`) + ack
  solo en el enable del consumidor (`system.sv:1259`). 486tang idéntico para
  SDRAM 2×: `always @(negedge clk_2x) phase <= ~clk_sys;`
  (`sdram_x2_wrapper.sv:68-96`).
- **VRAM en BRAM dual-port, CPU y render en puertos FÍSICOS separados** —
  smstang `vdp.v:131-137`, mdtang `system.sv:397-450`. Sin árbitro: la clase
  de carrera fetch-vs-CPU (nuestro SCREEN 3) es estructuralmente imposible.
  Los "access slots" TMS de mdtang existen solo por fidelidad, no por
  arbitraje.
- **Audio a reloj completo**: strobe edge-detect a full clock
  (`jt89.v:88-96`), síntesis bajo cen dividido (`jt89.v:70`), y **latch de
  bus con el chip siempre habilitado** — el VM2413 (¡el MISMO OPLL YM2413 de
  MSX-Music!) recibe fm_a/fm_d latcheados a clk_sys con cs_n=0/we_n=0 fijos
  (`system.v:344-352`). Los chips nunca ven el bus del Z80 directamente.
- **Z80 sin waits**: smstang deja WAIT_n=1'b1 SIEMPRE (`system.v:250`) —
  WRAM/VRAM en BRAM (1 ciclo) y ROM en SDRAM con latencia FIJA 4-5 ciclos ≪
  los 15 del periodo del enable. Sin FSM de waits adaptativos.
- **SDRAM síncrona al core** (1× smstang/mdtang, 2× 486tang, 3-4×
  nestang/gbatang): peticiones por FLANCO latcheadas en slot de fase conocida
  (`sdram_nes.v:124-126,246`), refresh estructural (slot propio) u
  oportunista en idle, y **fase del reloj de pad por PE_COARSE/FINE de la
  PLLA** (225-315° según diseño) en vez de inversión binaria como nuestro
  `SDCLK_INVERT`.
- **Turbo**: smstang = swap combinacional de enables de la MISMA rueda
  (3.58→5.37, ¡nuestro caso exacto!, `system.v:404`); mdtang latchea el
  divisor SOLO al expirar la cuenta (`system.sv:260-266`); **pctang al subir
  4.77→12.5 RECONFIGURA los waits del chipset a la vez**
  (`pctang_top.sv:191-216`) — el único precedente de que la FSM de esperas
  debe cambiar con la velocidad. Nuestro F11 encaja: la FSM de waits
  adaptativos asume el tren 3.58.
- **Video→HDMI**: framebuffer BRAM dual-clock de frame completo sin sync
  (smstang, tolera tear) o ring de 32 líneas + pausa de frame con el core
  +0.28% rápido y el AUDIO NUNCA pausado (mdtang `framebuffer_sync.sv`).
- **SDC**: multicycle 2 -start sobre TODOS los pines del T80 (smstang.sdc:5-6,
  su commit "resolve timing closure… allow 2 cycles for z80"); grupos
  -asynchronous exhaustivos (486tang ao486.sdc); create_clock sobre pines
  internos de IPs.
- **Placement/GW5A**: resets de alto fan-out replicados A MANO
  (`rst <= {16{reset}}`, 486tang `system.sv:106-109` — Gowin no replica ni
  con Replicate Resources; fue "la mayor ganancia" según su blog); Place
  Option 2 + Route Option 1; registros IOB en pines SDRAM; INS_LOC del DLL/
  PLLA para reproducibilidad (ddr3_framebuffer `console60k.cst:196-198`).

## C. Respuestas del barrido a nuestros bugs abiertos

- **SCC mudo** — no hay SCC en ningún repo; la receta transferible es la del
  VM2413+jt89 (checklist): (1) ¿el write-strobe del SCC se edge-detecta a
  54M a reloj completo?; (2) ¿su cen lleva `(* direct_enable *)`?; (3) ¿la
  wave RAM tiene algún puerto que quedó a 27M?; (4) latch de bus en dominio
  core con chip siempre seleccionado.
- **SCREEN 3** — nadie implementa multicolor M3 (smstang manda todo modo
  no-M4 a su camino Graphics II). Fix estructural: VRAM BRAM dual-port.
  Pista NUEVA del crítico sobre "sensible a placement": nuestro SDC declara
  clk_27m como generated del CLKDIV → la STA firma UNA de las 5 fases
  posibles como verdad; todo path 54↔27 restante queda validado con
  optimismo y cada seed de PnR cae en una fase real distinta. Auditar qué
  sigue cruzando 54↔27 es la vía corta. INT: pulso de anchura determinista
  con auto-clear (mdtang `vdp.v:2224`) y muestreo en frontera de ciclo.
- **F11/turbo** — receta combinada: latch del divisor al expirar (mdtang) +
  reconfigurar la FSM de waits para el periodo turbo (pctang) — o eliminar
  los waits (smstang) si la SDRAM da latencia fija dentro del enable.
- **Fase 27↔54 (la RAÍZ)** — eliminar el CLKDIV: par 27/135 de dos ODIVs de
  la PLLA + SDC de relojes emparentados (generated + multicycle) para que la
  STA cierre el cruce DE VERDAD. nand2mario nunca tiene fase arbitraria.

## D. FASES (revisadas)

**F1 — HDMI siempre arranca** ✅ implementada (`_34`, commit 8aa8c37).
  Criterio: 15-20 power-cycles sin fallo. EN PLACA, pendiente veredicto.

**F2 — base mínima** (siguiente build tras validar _34):
  `ifdef` por subsistema en top.v; fuera SCC, OPLL, sn76489/consola, turbo,
  WiFi-UART. Queda: T80 + memory.v + VDP/HDMI + PSG + SD + teclado companion
  actual. Objetivo: build pequeño, timing holgado, cero lotería; validar
  estabilidad larga (menú+BASIC+juego PSG horas).

**F3 — re-priorizada por el usuario (2026-07-10, tras la victoria del SCC):**
  1. ~~Teclado USB-A directo~~ ✅ (_39)
  2. ~~Fuera el CLKDIV~~ ✅ (absorbido en la 1-REDUX)
  3. ~~SCC~~ ✅ (_55: saga de 15 builds, 3 bugs de toolchain GW5A — crónica
     en los commits 442a257..c4d73ea y en la memoria)
  4. **Opción 4:3/16:9 del menú** (_56): el conmutador config_enable_16_9
     ya llega a v9958_top; el escalador de msx2hdmi lo obedece (960
     centrado vs 1280 estirado).
  5. **Segundo SCC + estéreo** (_57): restaurar SccCh2 con el chip CURADO
     (mismo scc_wave2 vía GHDL) + verificar el modo estéreo del menú
     (mixer ya lo trae: L=PSG1+SCC1+OPLL / R=PSG2+SCC2+OPLL; el segundo
     PSG YA existe en el core — dual PSG estilo OCM).
  6. **Scanlines** (_58): reimplementar en msx2hdmi (el efecto legacy vivía
     en el hdmi de 480p): oscurecer 1 de cada 3 líneas de salida (720p =
     3 líneas por línea nativa), gated por config_enable_scanlines.
  7. **Modos consola** (_59): Coleco/SG-1000 + SN76489 — ANTES de
     reactivar, auditar sn76489.v contra la lección GW5A del SCC
     (patrón captura+reset mismo ciclo).

**F4 — turbo + mandos + endurecimiento (tras F3):**
  - **Turbo WSX** con la receta mdtang/pctang (latch del divisor al expirar
    + FSM de waits consciente del modo).
  - **Mandos USB-A → joystick MSX** (el usb_hid_host ya los lee; falta el
    mapeo a los puertos DB9 virtuales).
  - VRAM 128KB → BRAM dual-port (candidato firme para SCREEN 3).
  - memory.v estilo sdram_nes; reset fan-out replicado; multicycle T80.

**F5 — roadmap largo (validado por el barrido):**
  - Frontend gráfico fase B: `ddr3_framebuffer.v` de gbatang tal cual
    (IP Gowin DDR3-594 1:4, pixel clock = clk_out del IP, `ddr_rst` como
    reset ÚNICO del dominio pixel incl. OSER10, asyncfifo gray + vsync por
    toggle; ~3600 LUT/16 BRAM; page-flip UI ya resuelto en
    `framebuffer2_top.v:96-101`). OJO: refresh OFF — solo framebuffer.
  - OSD de texto 32×28 en 2KB BRAM (textdisp.v de TangCore) como overlay
    ligero de estado.
  - Carga de cores por JTAG del BL616 en ~2s (TangCore programmer.cpp,
    IDCODE GW5AT-60=0x0001481b) — para el multi-core "Game Bub propio";
    protocolo TangCore es UART 2Mbaud (incompatible con el SPI de MiSTle:
    adoptar iosys_bl616.v entero si algún día se cambia).
  - MSX-Audio/OPL4: sample RAM desde BRAM o DDR3-streaming (no DDR3-RAM).

## Aparcados (sin cambio)

SCC mudo (→F3.3) · SCREEN 3 (→F3.2/F4) · F11 (→F3.5) · ESC→BASIC azul/rayas
(re-evaluar tras F3.2: mismo fondo de fase).
