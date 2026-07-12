# MSXimus — Ruta del proyecto (INDEPENDIENTE desde 2026-07-11)

> **MSXimus se separa del MSXnano.** La paridad con la v1.9 está COMPLETADA y
> validada en hardware (2026-07-11). El nano (GW2AR-18 al 89%) queda congelado
> en su rama; a partir de aquí MSXimus va por camino propio, con capacidades
> que el nano no tendrá nunca. Los hallazgos compartibles fluyen por las
> memorias de Claude entre sesiones, no por dependencia de código.

## Dónde estamos — candidata a v1.1

Todo validado en HW (2026-07-11), serial de referencia **_71 + pack v5**:

- **Turbo WSX**: F11 + puertos Panasonic $40/$41 + Boot Turbo persistente
  (solo arranque en frío, con nota "(reiniciar físicamente)" en el menú).
  4.33 MHz efectivos con handshake SDRAM propio (la SDRAM externa de 16 bits
  exige lo que la embebida del nano no exigía).
- **Sprites 8/línea** (anti-parpadeo screen 2) en config2 bit3, toggle de menú.
- **Menú variante MSXimus** (flag `MSXIMUS=1` sobre el fuente del nano):
  sprites en su bit + "Pantalla 16:9" restaurada (bit4, aquí sigue viva).
- **LED de turbo** en el LED onboard G11: parpadeo rápido ~7Hz = turbo,
  lento ~1.7Hz = 3.58 y "estoy vivo". U12 = actividad SD.
- **Timing estructuralmente limpio**: la familia de medio-ciclo Z80→FSMs de
  memoria/wait va por multicycle ×2 en el SDC (espejo de las excepciones de
  entrada al Z80 que ya existían; no es un waiver, es la constraint correcta).
- Más lo de v1.0-beta1: 720p BRAM-bridge, 4:3/16:9/scanlines, PSG + doble
  SCC estéreo + OPLL, teclado USB soft-host, Nextor+microSD, megaram, logo v4.

## F0 — Cierre de etapa (CERRADO 2026-07-11)

1. **Tag v1.1** = _71 + pack v5 (validado en HW). Turbo **4.40 MHz**, sprites
   8/línea, LED de turbo, menú con nota "(reiniciar físicamente)", timing
   limpio. (La _72/iter.3-A resultó no arrancar y quedó RETIRADA; post-mortem
   en `fpga/src/memory.v`.)
2. **Turbo: 4.40 es el número de v1.1, aceptado.** Se midió que 4.40 es el
   techo práctico de la SDRAM compartida CPU/VDP (ver más abajo). El 5.37 real
   exigiría VRAM→BRAM, que **se aparca** (congelaría la BRAM al 92-97% y con
   ella OPL4/V9990/frontend). Análisis completo en `docs/VRAM_BRAM_DESIGN.md`.
3. **Fork del menú/pack**: el fuente vive aún en el árbol del nano con el flag
   `MSXIMUS`. Traerlo al repo MSXimus (carpeta `menu/`) cuando toque tocarlo.

## Turbo — techo medido y por qué 4.40 (no reabrir sin releer esto)

`tools/sdr16_tb` (T9b/T10): la SDRAM sirve 6.75 MHz sostenido, pero CPU y VDP
la comparten 50/50 → la CPU recibe 1 slot por ventana de vídeo (6.75 MHz de
cadencia). Las rejillas de slot (6.75) y de T-state turbo (5.369) son
inconmensurables → el 25% de las lecturas pierde 1 T-state → 5.369/1.25 ≈ 4.30.
Retoques baratos agotados (iter.2b=4.33-4.40 según roll; iter.2c/2d corrompieron
lecturas; iter.3-A NI ARRANCA en HW — retirada, post-mortem en memory.v).
**El único camino a ~5.37 es sacar la VRAM de la SDRAM (VRAM→BRAM), aparcado.**
Ese mismo cambio curaría Screen 3 de raíz. Ver `docs/VRAM_BRAM_DESIGN.md`.

## F1 — WiFi (doble vía, empezar domingo)

- **Vía rápida — ESP32-C6 por PMOD** con firmware OFICIAL de ducasp (el C6
  arranca a 859372 = drop-in de nuestro `wifi_lite`). Falta: derivar el mapa
  ball↔pin de los PMOD J6/J7 (hojas BTB + esquemático SOM — 08_Misc está
  vacío) antes de fabricar el adaptador.
- **Vía estratégica — port UNAPI al BL616 onboard** (antena MHF4 localizada
  y en el kit → cero hardware visible): enviar el email a ducasp
  (`docs/email_ducasp_bl616.md`) pidiendo ID de firmware. Fases: P0 bring-up
  UART/wifi_mgr 8-16h → MVP File-Hunter/NetTransfer 30-50h → TLS 15-25h.
  Esquema partner@0x0 + app@0x40000 (conserva el USB-JTAG). SSH excluido.

## F2 — Audio que el nano nunca tendrá

- **Y8950 (MSX-Audio)**: FM primero (jtopl2 GPL + wrapper, puertos 0xC0/C1,
  receta Y8960_Cartridge de HRA!); ADPCM-B después (jt10_adpcmb + RAM de
  muestras en SDRAM). BIOS MSX-Audio al pack si el software la exige.
- **OPL4 / MoonSound FM-only** (mangOPL4): no cabía en el 20K (89% CLS);
  en el GW5AT-60 sí. La vía PicoVerse/ymfm queda como plan B por software.

## F3 — Vídeo, las rocas grandes (en orden: cada paso desriesga el siguiente)

1. **VRAM → BRAM dual-port** (M/L): libera ancho de banda de la SDRAM y
   simplifica el TDM CPU/VDP (menos contención = turbo más estable).
2. **Pista V9968** (S+L/XL): suite de tests Z80 de HRA! contra el VDP actual
   (línea base gratis); después el core v9968 (FakeID=V9958, fijar revisión).
3. **V9990 + 2º HDMI** (L): tiny9990 (BSD-3, 64% de un GW2AR → holgado aquí)
   + decidir la salida física del segundo HDMI.

## F4 — Plataforma / consola

- **SRAM persistente a flash** (diseño de 5 fases ya escrito).
- **Pantalla LCD J3** (5" Seeed, DPI 40-pin, $17.90) → consola portátil:
  batería TP4057 (⚠ errata: serigrafía GND/BAT INVERTIDA en la cara
  inferior), LCD+HDMI simultáneos posibles, pines dedicados.
- **Frontend gráfico** BL616 → framebuffer OSD con carátulas
  (`GRAPHICAL_FRONTEND_DESIGN.md`, estilo Game Bub).
- Gamepads USB→joystick (política msx-joy* de herraa1), MSX-MIDI
  (tr_midi.v), RGB 15 kHz por PMOD, turboR/R800 (vigilar el cr800 de HRA!).

## Cómo trabajamos

- Una variable por build; serial `msximus_60k_YYYYMMDD_NN.fs` a `files/` con
  LEEME; las 5 puertas en CADA artefacto final y verificadas en fresco:
  0 errores, NL0002=18 benignos, **EX3638=11** (baseline desde el bit de
  sprites), 8 relojes críticos PRIMARY, `check_timing.py` limpio.
- Combo PnR canónico p2r1; si un roll no cierra, la respuesta es entender el
  camino (constraint o estructura), no la lotería de combos.
- Pack: base = bin validado + bloques inyectados (menú MSXIMUS=1, logo);
  emparejado con el core por el guard del puerto 0x2F.
- Builds en background SIEMPRE con `cd` absoluto dentro del propio comando.
