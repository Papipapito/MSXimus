# Estado de la migración

Tracker vivo del port. Ver [PORT_PLAN.md](PORT_PLAN.md) para el plan y [PORT_FINDINGS.md](PORT_FINDINGS.md) para los hallazgos.

## Decisiones tomadas (2026-07-06)

| Decisión | Elección | Consecuencia |
|---|---|---|
| Enfoque | **Híbrido** | Scaffolding 60K ya; flash_rw/SD/YM2149 con fixes en P1 |
| Memoria | **DDR3 onboard** | Reescribir `memory.v` + wrapper `ram_*`/`vram_*`; VRAM en BRAM; desbloquea roadmap |
| Companion | **BL616 onboard** | Pines JTAG-repurposed; quitar `spi_ext`/mux (→ fuera TA1132); dock M0S eliminado |

## Toolchain confirmado (Gowin 1.9.11.03 Education, local)
GW5AT-60B (PBGA484) ✅ · PLL_ADV/Gowin_PLL fraccional ✅ · DDR3 Memory Interface v5.9 ✅ — los tres soportan `GW5AT-60B` (ipspec locales). El build del 60K va por el flujo propietario Gowin (`gw_sh`), NO yosys/apicula (PLLA no soportada ahí).

## Open-items

1. ✅ **RESUELTO — Reloj base**: el PLL del GW5A es **fraccional** → ~108 MHz desde 50 sin re-derivar constantes ni necesitar 27 MHz en placa. Ver [CLOCK_PLAN.md](CLOCK_PLAN.md). (Validar tolerancia ~0 al generar la IP.)
2. **VRAM en BRAM vs DDR3** — recomendado BRAM; cerrar con presupuesto BRAM + latencia DDR3.
3. **Pines INCIERTOS** — `ws2812`, UART ESP-01S (×2), `led[2..5]` (×4): pendientes del schematic oficial.
4. **Reloj de usuario DDR3** — fijar a 54 MHz (= dominio `ram_*`) para evitar CDC; `Memory_Clock=216`, `CLK_Ratio=1:4`. Cerrar en el wrapper.

## P0 — scaffolding (EN CURSO)

| Item | Estado | Nota |
|---|---|---|
| `fpga/src/clock_config.vh` | ✅ | 15 constantes derivadas de `CLK_108_HZ` + casos RTC/WiFi |
| `fpga/constraints/msx_console60k.cst` | ✅ (skeleton) | 27 pines ALTA (companion onboard, HDMI, SD, clk, botones, flash, 2 LED); INCIERTOS marcados; DDR3 sin pines |
| `fpga/constraints/msx_console60k.sdc` | ✅ (skeleton) | create_clock 50 MHz + SPI; generados 108/54/27/135 = TODO (nombres PLLA) |
| Migrar IP PORTA-TAL-CUAL | ✅ (76 ficheros) | ver abajo |
| Plan de reloj (open-item 1) | ✅ | [CLOCK_PLAN.md](CLOCK_PLAN.md): 1 Gowin_PLL fraccional 50→108/54/27 + PLL#2 135 |
| Generar IP `Gowin_PLL` #1 (108/54/27) | ⬜ | IDE o gw_sh → `fpga/ip/gowin_pll/` |
| Wrapper DDR3 (stub de interfaz) | ⬜ | preservar `ram_*`/`vram_*` @54MHz; siguiente entregable |

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
`top.v` (magic-ports SDRAM fuera, mapa de bancos, waits adaptativos, quitar `spi_ext`), `memory.v`→wrapper DDR3, `v9958_top.v`, companion, `megaram.v` (+SDC cruce), resto SE-RETOCA.

## P3 — bring-up en placa
Checklist de revalidación (ver PORT_PLAN): matches SDC>0, turbo 5.369318, RTC/DOS, WiFi 859372, MG2/R#13, SD + extracción, keypad Coleco, A/B PSG.
