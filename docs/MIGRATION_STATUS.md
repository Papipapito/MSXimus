# Estado de la migración

Tracker vivo del port. Ver [PORT_PLAN.md](PORT_PLAN.md) para el plan y [PORT_FINDINGS.md](PORT_FINDINGS.md) para los hallazgos.

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
