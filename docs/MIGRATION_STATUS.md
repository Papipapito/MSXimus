# Estado de la migración

Tracker vivo del port. Ver [PORT_PLAN.md](PORT_PLAN.md) para el plan y [PORT_FINDINGS.md](PORT_FINDINGS.md) para los hallazgos.

## 🏆 HITO (2026-07-07): PRIMER BITSTREAM GW5AT-60 — serial `msxup_60k_20260707_01`
**TNS 0.000 (0 endpoints violados, setup+hold, 9 relojes) · Logic 25% · BSRAM 13%** (vs 89% CLS del TN20K). Entrega en `files/20260707/` (solo `.fs`; el `.bin` del pack requiere re-mapear el layout de flash: el bitstream ocupa 2.26MB > 0x200000). Prueba: **carga a SRAM** (no flashear; la flash la comparte el BL616). Esperable sin pack: configura + PLL lock + señal HDMI estable.

### Iteración de bring-up de la síntesis (7 pasadas)
1. `BUFG` no existe en GW5A → assigns (red global automática)
2-3. BSRAM SP `WRITE_MODE=2'b10` (PA2122) → `syn_srlstyle="registers"` en jtopl (`syn_ramstyle` NO aplica a shift-extraction, SUG550 §5.17)
4. Parser SDC sin `\` de continuación
5. Pines dedicados: DONE/READY (los 2 LED onboard) + CPU/MSPI (flash) → `-use_done/ready/cpu_as_gpio`
6. ✅ primer bitstream (con 1 violación 54MHz por excepciones ausentes)
7. ✅ SDC completo (excepciones del TN20K portadas; las de `env_reset` OBSOLETAS por el fix #2) → **timing limpio**

### Layout de flash del 60K (re-mapeado 2026-07-07)
| Rango | Contenido |
|---|---|
| `0x000000-0x3FFFFF` | bitstream GW5AT-60 (2.26 MB reales, margen a 4 MB) |
| `0x400000-0x47FFFF` | **pack BIOS** (512 KB) — antes `0x200000` en TN20K |
| `0x480000-0x480005` | **config** (6 bytes, cola del pack) — antes `0x280000` |
| `0x480006-0x7FFFFF` | libre (~3.5 MB: futuro SRM/ROMs) |

Flasheo del pack: `openFPGALoader --external-flash -o 0x400000 goauld_rom_int.bin` (o programmer Gowin a esa dirección). `flash_rw` recibe la dirección por puerto (sin cambios). `/WP`+`/HOLD` de la QSPI conducidos a alto (P21/R21).

### Bring-up en placa (2026-07-07/08) — crónica
1. **Causa raíz #1 (serial _12)**: botón S1 activo-alto del TN20K + PULL_UP del 60K = core MSX en **reset permanente** desde el primer bitstream. Descubierta gracias a que los módulos PMOD-LED son **activos-bajo** (todas las lecturas de nivel estaban invertidas; los parpadeos eran válidos).
2. Con `_12`: **señal HDMI + frames** (pantalla negra). Con `_13/_14/_15dbg`: pack carga de flash ✓ (~3s), strobes VDP ✓, bus 3.58 ✓, memoria sirviendo ✓, **el menú LLEGÓ a escribir al VDP al arrancar** y luego se degrada; sin bucle de soft-reset.
3. Fixes de paso: bucle de resincronización VDP→HDMI (align-once, `_09`) — necesario aunque no suficiente; excepciones SDC RD/WR_n→mem (cuasi-estáticas).
4. **Auto-test de SDRAM en HW** (`fpga/test_sdram/`, seriales `_16test`/`_17test_inv`): usa el `memory_ctrl` real, veredicto por HDMI (verde/rojo/magenta). Verificado en sim contra el modelo W9825 — la depuración del tester documentó el **contrato implícito del puerto VRAM** (inputs estables la ventana entera; fila fase 0, write fase 1: pre-armar addr antes de write). `memory_ctrl` ganó el parámetro `SDCLK_INVERT` (reloj SDRAM 180°, fix clásico SDR externo) para el A/B.

### Pendiente inmediato
- [x] **Re-mapear layout de flash** → hecho (FLASH_START 0x400000, config 0x480000, WP/HOLD altos)
- [ ] Pines definitivos de `led[2..5]`, `ws2812`, UART ESP (hoy auto-colocados: U8/W16/E18/U9/P6/U21/R19 — no conectar PMODs al probar)
- [ ] Companion BL616: nets `jtagseln`/`bl616_jtagsel` estilo C64Nano (líneas del CST comentadas) para el modo JTAG→SPI
- [ ] Smoke en HW (SRAM load) → luego pack a 0x400000 + bitstream a flash → boot MSX completo
- [ ] PackBuilder/README: documentar el offset nuevo del pack (tooling, no RTL)

## Decisiones tomadas (2026-07-06)

| Decisión | Elección | Consecuencia |
|---|---|---|
| Enfoque | **Híbrido** | Scaffolding 60K ya; flash_rw/SD/YM2149 con fixes en P1 |
| Memoria core | **SDR SDRAM (W9825, 16b/32MB)** ⭐ | Reusar `memory.v` (rework 32→16b); DDR3 = fase 2 framebuffer. Ver [MEMORY_OPTIONS.md](MEMORY_OPTIONS.md) (revierte la decisión DDR3 previa) |
| Companion | **BL616 onboard** | Pines JTAG-repurposed; quitar `spi_ext`/mux (→ fuera TA1132); dock M0S eliminado |

## Toolchain confirmado (Gowin 1.9.11.03 Education, local)
GW5AT-60B (PBGA484) ✅ · PLL_ADV/Gowin_PLL fraccional ✅ · DDR3 Memory Interface v5.9 ✅ — los tres soportan `GW5AT-60B` (ipspec locales). El build del 60K va por el flujo propietario Gowin (`gw_sh`), NO yosys/apicula (PLLA no soportada ahí).

## Open-items

1. ✅ **RESUELTO — Reloj base**: el PLL del GW5A es **fraccional** → 108/54/27 EXACTOS desde 50 (PLL generada). Ver [CLOCK_PLAN.md](CLOCK_PLAN.md).
2. ✅ **RESUELTO — VRAM en BRAM**: la VRAM (128KB) va a BRAM dual-port → disuelve el requisito MG2 y da latencia fija; DDR3 solo CPU/mapper/megaram. Ver [DDR3_WRAPPER.md](DDR3_WRAPPER.md §0). (Confirmar presupuesto BRAM tras 1er build.)
3. **Pines INCIERTOS** — `ws2812`, UART ESP-01S (×2), `led[2..5]` (×4): pendientes del schematic oficial.
4. **Part del chip DDR3 del SOM** — confirmar (densidad/timings para generar la IP). Ref: `nand2mario/ddr3_framebuffer_gowin`.
5. **CDC DDR3 vs alinear clk_out=54** — decidir en el wrapper (CDC explícito por defecto).

## P0 — scaffolding (EN CURSO)

| Item | Estado | Nota |
|---|---|---|
| `fpga/src/clock_config.vh` | ✅ | 15 constantes derivadas de `CLK_108_HZ` + casos RTC/WiFi |
| `fpga/constraints/msx_console60k.cst` | ✅ (skeleton) | 27 pines ALTA (companion onboard, HDMI, SD, clk, botones, flash, 2 LED); INCIERTOS marcados; DDR3 sin pines |
| `fpga/constraints/msx_console60k.sdc` | ✅ (skeleton) | create_clock 50 MHz + SPI; generados 108/54/27/135 = TODO (nombres PLLA) |
| Migrar IP PORTA-TAL-CUAL | ✅ (76 ficheros) | ver abajo |
| Plan de reloj (open-item 1) | ✅ | [CLOCK_PLAN.md](CLOCK_PLAN.md): 1 Gowin_PLL fraccional 50→108/54/27 + PLL#2 135 |
| Generar IP `Gowin_PLL` #1 (108/54/27) | ✅ | proyecto `fpga/msx_console60k/` (device gw5at60b-002); **108/54/27 EXACTOS** (VCO 1350 = 50×27, div 12.5/25/50), fase estática, Lock. ⚠️ integración: el módulo trae `PLL_INIT` y necesita puerto `mdclk` alimentado con 50 MHz |
| Proyecto Gowin 60K (`msx_console60k.gprj`) | ✅ | seed del proyecto de build P2 (device correcto) |
| Wrapper DDR3 (stub de interfaz) | ⬜ | preservar `ram_*`/`vram_*` @54MHz; **siguiente entregable** |

### Ficheros migrados tal cual (76 RTL, P0)
- **G80A** (Z80/T80): 7 `.vhd` (sin `T80_RegX`, muerto).
- **jtopl** (OPLL/YM2413, jotego GPLv3): dir completo (+ LICENSE, common.yaml).
- **VDP core** (`tn_vdp_v3_v9958/src/vdp/`): 19 `.vhd` + `ram.vhd`.
- **HDMI** (`tn_vdp/src/hdmi/`): 8 `.sv` agnósticos (sin `serializer.sv`/`audio_clock_regeneration_packet.sv` = SE-RETOCA).
- **src**: `ws2812.v`, `wondertang/crc16.v`, `wondertang/pinfilter.v`, `ocm/lpf.vhd`, `ocm/fifo.vhd`, `usb/hid.v` (revisar con topología onboard).

## P1 — módulos con fix previo (traer ya arreglados)
| Módulo | Fix | Estado |
|---|---|---|
| `flash_rw.v` | #1 write_terminate output→input + WIP post-program | ⬜ |
| `sd_reader.sv` (+`sdcmd_ctrl.sv`) | #3/#4/#5 SD-hardening + 2FF | ⬜ |
| `YM2149.vhdl` | #2 carga síncrona del envelope (lotería placement GW5A) | ⬜ |

## P2 — top-level + integración

### Memoria del core = SDR SDRAM (camino ACTIVO) — ✅ FRENTE COMPLETADO EN RTL
| Item | Estado | Nota |
|---|---|---|
| Decisión + comparativa | ✅ | [MEMORY_OPTIONS.md](MEMORY_OPTIONS.md) |
| Cirugía 32→16b APLICADA | ✅ | `fpga/src/memory.v` de 16 bits; mapeo geometría-preservante (addr[1]→LSB col); tristate explícito dq_oe/dq_in (fix del idioma Gowin-mágico); initializers para sim |
| Testbench Icarus (modelo W9825) | ✅ **ALL TESTS PASS** | `tools/sdr16_tb/`: init real+MRS validado, lanes/DQM, 600 accesos random, words VDP, **aliasing de geometría (T6)**, **MG2 (T7)** |
| Pines SDRAM en el CST | ✅ | bloque completo de 34 pines verbatim de C64Nano console60k (CKE sin pin: atado en placa) |
| Spec + hallazgos | ✅ | [SDR_MEMORY_PORT.md](SDR_MEMORY_PORT.md) (4 hallazgos de implementación documentados) |

### DDR3 = FASE 2 (framebuffer del frontend gráfico) — diseño listo, no activo
| Item | Estado | Nota |
|---|---|---|
| Diseño wrapper DDR3 | ✅ (fase 2) | [DDR3_WRAPPER.md](DDR3_WRAPPER.md) + skeleton `memory_ddr3.v`. Uso probado en el 60K = framebuffer (nand2mario, 297MHz, refresh off) |

### Resto P2
| Item | Estado | Nota |
|---|---|---|
| `top.v` portado | ⬜ | magic-ports→GPIO SDRAM, quitar `spi_ext`, `mdclk`=50MHz al PLL, banco por sdram_addr[22:21] |
| resto SE-RETOCA (v9958_top, megaram+SDC, companion…) | ⬜ | |

## P3 — bring-up en placa
Checklist de revalidación (ver PORT_PLAN): matches SDC>0, turbo 5.369318, RTC/DOS, WiFi 859372, MG2/R#13, SD + extracción, keypad Coleco, A/B PSG.
