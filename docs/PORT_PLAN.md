# Plan del port — MSXnano (GW2AR-18) → Tang Console 60K (GW5AT-60)

Documento vivo. Fuente: [AUDIT_PRE_PORT_60K.md](AUDIT_PRE_PORT_60K.md) + roadmap del 60K.

- **Target**: Tang Console 60K — SOM Tang Mega 60K = Gowin **GW5AT-60** (GW5AT-LV60PG484). DDR3 512 MB, BL616 onboard, 2× USB-A host, HDMI, microSD, 2× PMOD, 2× 40-pin.
- **Base**: `Papipapito/MSXnano` @ `dev` `390132d` (F0+F1 de limpieza pre-port ya hechas). Copia limpia de referencia (worktree): `../_MSXnano_dev_ref`.
- **Build TN20K de referencia** (para diffs netlist-neutros): `gw_sh.exe` **solo en Windows** — `C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe`. El 60K necesitará toolchain GW5A (verificar soporte del device en la edición instalada).

## Enfoque elegido: HÍBRIDO (confirmado)

Arrancar **ya** con lo específico del 60K que **no** depende de los fixes pre-port; `flash_rw`/SD/`YM2149` se migran **después**, ya con sus fixes aplicados (no se porta código sin arreglar). No se necesita placa TN20K para empezar el scaffolding.

## Los 4 frentes

### 1. Memoria (SDRAM → DDR3) — el bloque más caro · SE REESCRIBE
- `fpga/src/memory.v`: secuenciador fijo de 8 fases @108 MHz, comandos SDR crudos, latencia determinista. DDR3 (latencia variable, colas) no da ese contrato → **hard-core DDR3 de Gowin + wrapper** que preserve `ram_req/ram_busy/ram_dout` @27 MHz y `vram_*` 16 bits como frontera estable.
- **Requisito trasladable (no código)**: "toda escritura VDP aceptada se COMPLETA; el arbitraje jamás la descarta" (`memory.v:204-213`, fix MG2). Si el arbiter nuevo no lo honra, reaparece el bug de agujeros en VRAM.
- **Requisito 2**: activar/portar la rama `ENABLE_WAIT_ADAPTIVE` (waits con handshake `ram_busy`, hoy dormida) — con DDR3 los waits de duración fija son corrupción garantizada. **Requisito, no optimización.**
- Estrategia candidata: **VRAM en BRAM del GW5A** (sobra) y DDR3 solo para mapper/megaram → simplifica el contrato de latencia del vídeo. → Ver [MEMORY_CONTRACT.md](MEMORY_CONTRACT.md).

### 2. Árbol de relojes · SE REESCRIBE (IP) + SE RETOCA (constantes)
- Regenerar 4 IP para GW5A: `CLK_108P` (rPLL→**PLLA**, verificar VCO 864 MHz), `Gowin_CLKDIV` (÷4), `Gowin_CLKDIV2` (÷2, ¡el actual es para GW1NR-9!), `CLK_135` (TMDS ×5; valorar SERDES nativo GW5A para HDMI).
- **Crítico**: cruces 27↔54 registro-a-registro **sin sincronizadores**, seguros solo por la alineación de fase del árbol CLKDIV. Garantizarla en el PLLA nuevo **o** añadir sincronizadores.
- Recalcular constantes absolutas a la base nueva (turbo WSX 5.369318 MHz exacto, 859372 bps del ESP, LFSR del RTC, autofire, boot ESP, prescalers PSG…). Centralizar en localparams derivados de `CLK_HZ`. → Ver [CLOCK_CONSTANTS.md](CLOCK_CONSTANTS.md).

### 3. Constraints (`.sdc` + `.cst`) · NUEVOS DESDE CERO — fallan EN SILENCIO
- `.sdc`: `create_clock` sobre pines/nombres GW5A (no los del GW2A). Un `get_pins` que no matchea **no da error**: pierde la constraint. **Tras el primer PnR verificar en el log que cada constraint matchea >0 objetos.**
- `.cst` entero nuevo: pinout GW5AT-60 (HDMI, SD, BL616/JTAG-SPI, botones, LEDs; la DDR3 es hard-IP, sin pines de usuario). Referencia de pinout: **TangCore / nand2mario**. → Ver [BOARD_60K.md](BOARD_60K.md).

### 4. Companion BL616 · DECIDIR TOPOLOGÍA
- En la Console 60K el BL616 onboard es el debugger con pines TangCore (SPI por JTAG repurposed, IRQ=IO27; build `TANG_CONSOLE60K` en FPGA-Companion). El secure-boot del TN20K nuevo no aplica igual.
- **Decidir**: ¿sigue teniendo sentido el dock M0S externo? Si NO → borrar `spi_ext`/mux → desaparece el TA1132. Limpiar `sys_ctrl.v` (restos Atari ST) **preservando CMD0/CMD5/CMD6 e int_out_n = el teclado**.

## Orden de trabajo (híbrido)

- **P0 — scaffolding 60K (SIN placa, arrancando):**
  1. Skeletons `msx_console60k.cst` + `.sdc` (pinout TangCore + create_clock GW5A, con checklist matches>0).
  2. IP de reloj GW5A: `PLLA` (108 MHz), CLKDIV ÷4/÷2, TMDS ×5 — regeneradas.
  3. Wrapper DDR3: definir la interfaz-frontera `ram_*`/`vram_*` + stub del controlador Gowin DDR3.
  4. Migrar **IP que porta tal cual** sin fixes pendientes: `ws2812.v`, jtopl/OPLL, G80A, core VDP, `lpf.vhd` OCM, `megaram.v` (+ constraint del cruce 27 MHz→controlador).
- **P1 — módulos con fix previo (traer ya arreglados):** `flash_rw.v` (fix #1 write_terminate + plausibles WIP), bloque SD (`sd_reader.sv` fixes #3/#4/#5), `YM2149.vhdl` (fix #2 carga síncrona del envelope).
- **P2 — top-level + integración:** `top.v` adaptado (magic-ports SDRAM fuera, mapa de bancos, waits adaptativos), companion según topología decidida.
- **P3 — bring-up en placa:** verificar matches SDC>0, timing, HDMI, DDR3, teclado; checklist de revalidación.

## Checklist de revalidación (tras bring-up)
- [ ] SDC: cada constraint matchea >0 objetos (log del primer PnR)
- [ ] Turbo WSX = **5.369318 MHz exacto** (÷20 + swallow 175/176)
- [ ] RTC / MSX-DOS con hora correcta (LFSR del segundo recalculado)
- [ ] WiFi UNAPI a **859372 bps** (prescaler recalculado)
- [ ] MG2 / R#13 (sin agujeros en VRAM; el requisito "escritura VDP no se descarta" honrado)
- [ ] Cargas SD + extracción en caliente (fixes SD)
- [ ] Keypad ColecoVision
- [ ] A/B de envelopes PSG (fix YM2149 síncrono)

## Docs code-grounded (se rellenan en la pasada de análisis)
- [CLOCK_CONSTANTS.md](CLOCK_CONSTANTS.md) — tabla exhaustiva de constantes dependientes de la base de reloj (file:line, valor actual, fórmula, valor 60K).
- [MEMORY_CONTRACT.md](MEMORY_CONTRACT.md) — contrato exacto de la interfaz `ram_*`/`vram_*` a preservar + estrategia DDR3.
- [FILE_MANIFEST.md](FILE_MANIFEST.md) — clasificación por fichero: PORTA-TAL-CUAL / SE-RETOCA / SE-REESCRIBE, con pre-req de fix.
- [BOARD_60K.md](BOARD_60K.md) — pinout GW5AT-60, IP DDR3, PLLA, topología del companion.
