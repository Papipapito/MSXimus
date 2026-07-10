# MSXimus — Ruta del proyecto (desde v1.0-beta1)

> Actualizado 2026-07-10. La base MSXimus parte del MSXnano `dev@390132d`;
> el MSXnano recibió después su **v1.9** (`ce46ef9`, último gran commit previsto:
> el GW2AR-18 está al 89% y queda congelado). Plan: **igualar la v1.9 primero**
> y a partir de ahí MSXimus vuela solo.

## Dónde estamos — v1.0-beta1 (tag)

Validado en hardware: vídeo 720p por puente BRAM propio (HDMI arranca siempre),
4:3/16:9 y scanlines por menú, PSG, doble SCC + estéreo, OPLL, teclado USB
directo (soft-host, sin hub), Nextor + microSD, megaram (Konami4/Konami-SCC/
ASCII8/16), logo de arranque (bug histórico `ifdef ENABLE_WIFI` arreglado en
la _61; rutina v4 con clear de VRAM + display-off). Modos consola eliminados
(core 100% MSX). Serial de referencia: `msximus_60k_20260710_61.fs`.

## Fase P — Paridad con MSXnano v1.9

Lo que la v1.9 tiene y MSXimus aún no:

- **P1 — Turbo WSX 5.37 MHz, receta v1.9** (esfuerzo M): portar el
  `turbo_eff` con conmutación de cadencia SIN glitch (adopción solo en
  límite de T-estado limpio — arregla el cuelgue de F11 en el menú), el
  boot-turbo SOLO en arranque en frío (`boot_done`/`warm_reset_pending`,
  fix de la pantalla negra en Save&Reset), puertos $40/$41 + guard 0x2F,
  y el testbench `tools/turbo_cadence_equiv`. **Va emparejado con el
  endurecimiento INS_LOC** de los strobes cpu1/RD_s0→mem1 (con turbo esos
  caminos son críticos de verdad; coordenadas del informe binario de Gowin).
- **P2 — Quitar el "Compatible Mode" vestigial** (S): `config_enable_wait`
  y el wait del bus del goauld fuera del FSM + plumbing + opción del menú,
  igual que hizo la v1.9.
- **P3 — Pack alineado a v1.9** (S, lado pack): el menú de la v1.9 ya viene
  sin consola (fm_logo_menu.bin nuevo) → montar pack v1.9 + logo MSXimus v4.
  Aprovechar la tanda para valorar: ROM patches OPLL libres (CC BY-SA) y el
  heurístico del mapper de Aleste.
- **P4 (opcional, depende de HW) — WiFi + File-Hunter** (M + hardware): el
  driver UNAPI y el File-Hunter (pares 1-14) YA están en la base, dormidos
  con `ENABLE_WIFI` off. Necesita decidir el HW (ESP-01 por PMOD en la
  Console 60K) y re-encender el define. Sin prisa: puede esperar a F8.

Con P1-P3 hecho: **paridad completa** (la _60/_61 ya cubrió la limpieza de
consola del RTL, que la v1.9 hizo en paralelo el mismo día).

## Volando solos — fases propias

- **F5 — Gamepads USB → joystick MSX** (M): el soft-host ya trae soporte de
  pads; política de mapeo de referencia = serie msx-joy* de herraa1 (umbral
  1/3 de stick, lockout SOCD, A/B→triggers, 60 Hz).
- **F6 — Audio: MSX-Audio Y8950** (M + M/L): primero FM-only (receta del
  Y8960_Cartridge de HRA!: jtopl2 GPL + wrapper, puertos 0xC0/C1); después
  ADPCM-B (jt10 de jt12 + RAM de muestras en SDRAM). BIOS de MSX-Audio al
  pack si algún software la exige.
- **F7 — Vídeo, las rocas grandes** (en este orden, cada paso desriesga el
  siguiente):
  1. VRAM → BRAM dual-port (M/L): candidato al fix de SCREEN 3, libera
     ancho de banda de SDRAM.
  2. Pista **V9968** (S+L/XL): correr la suite de tests Z80 de HRA! contra
     nuestro VDP actual (línea base gratis) y después integrar el core
     `v9968` (Verilog puro, FakeID=V9958, fijar revisión — aún tiene
     breaking changes). Manual en Downloads + demo RU66 como aceptación.
  3. **V9990** (L): tiny9990 (BSD-3, números reales: 64% de un GW2AR →
     holgado aquí) + decidir la salida física del 2º HDMI.
- **F8 — Plataforma** (según HW y ganas): SRAM persistente a flash (diseño
  hecho, 5 fases), RGB 15 kHz analógico por PMOD (DAC resistivo, tap
  pre-doubler del VDP), MSX-MIDI (tr_midi.v de OCM-Kai casi directo),
  frontend gráfico BL616/OSD, modo turboR/R800 (vigilar el cr800 de HRA!).
- **Aparcado**: megaram 4MB (informe hecho, descartado por ahora), PAL 50Hz
  nativo, Gowin 1.9.12 Education.

## Reglas de trabajo (las de siempre)

Una variable por build; serial `msximus_60k_YYYYMMDD_NN.fs` a `files/` con
LEEME; 5 puertas en cada build (0 errores, NL0002=18 benignos, EX3638=10,
relojes críticos en PRIMARY, `check_timing.py` limpio); las finales sin
waivers de timing; pack siempre desde `MSXnano/fpga/src/rom/` (jamás de los
`bin/`), emparejado por guard 0x2F.
