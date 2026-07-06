# FILE MANIFEST — Port MSXnano (GW2AR-18C / Tang Nano 20K) → Tang Console 60K (GW5AT-60, DDR3)

Manifiesto autoritativo **por fichero** para el port. Cruzado con la **sección 5** de
`fpga/AUDIT_PRE_PORT_60K.md` (clasificación A=se reescribe / B=se retoca / C=porta tal cual)
y con los bugs de la sección 3 y plausibles de la sección 4.

Todo está anclado a código real (rutas relativas a `fpga/`, `file:line`, valores exactos).
Repo base: `C:\Users\alber\proyectosAI\msx\_MSXnano_dev_ref` (copia limpia de `dev`).

## Convenciones

**Clasificación:**
- `PORTA-TAL-CUAL` — RTL agnóstico a familia/placa; a lo sumo re-ubicar un pin en el CST.
- `SE-RETOCA` — porta con cambios acotados (constante de reloj, constraint, un 2FF, re-mapear flash…).
- `SE-REESCRIBE` — hay que rehacerlo para GW5A/DDR3 (memoria, PLLs, constraints).
- `NO-PORTAR` — código muerto en disco (no entra al build) o IP que se sustituye por la del 60K.

**Fase del plan** (sec. 6 de la auditoría):
- `P0` = scaffolding (limpieza/higiene, sin cambio de familia).
- `P1` = fixes pre-port (bugs confirmados #1–#6 en TN20K, antes de tocar la familia).
- `P2` = port real (PLL/CLKDIV + DDR3 + SDC/CST + companion, ya en GW5A).

**Estado de esta copia (verificado disco-vs-build):** `build.tcl` tiene **108 `add_file`**;
en disco hay **115** ficheros RTL. La poda de la auditoría **§2.2 ya está aplicada aquí**:
9 ficheros quedan en disco fuera del build (ver §5). `src/print.v` ya fue borrado.
`impulse.v` que la auditoría cita en `build.tcl:46` **ya no está** en este `build.tcl`
(divergencia menor con el texto de la auditoría, marcada abajo).

---

## 1. TOP-LEVEL, MEMORIA Y RELOJES — el núcleo del port

| Ruta | Rol (1 línea) | Clasificación | Pre-req (bug/plausible) | Fase |
|---|---|---|---|---|
| `top.v` | Top del core: instancia todo, bus Z80↔slots, mixer audio, mapa de bancos, waits, magic-ports SDRAM | **SE-REESCRIBE** (parcial: los bloques de memoria/PLL/waits) + **SE-RETOCA** (constantes de reloj, higiene) | write_terminate #1 (mux L2236-2246); waits `ram_busy` sec.5 A1-Req2 (L689, 886-887, rama `ENABLE_WAIT_ADAPTIVE` 717-755 **NO borrar**); mixer clamp plausible#1 (L1913); `sn_wr` strobe (L1829) | P1/P2/P3 |
| `src/memory.v` | Controlador SDRAM: secuenciador fijo 8 fases @108MHz, VRAM + RAM CPU/mapper, `O_sdram_clk=clk_108m` | **SE-REESCRIBE** (bloque más caro) | Requisito MG2 `memory.v:204-213` ("escritura VDP aceptada nunca se descarta") a trasladar al arbiter DDR3 | P2 |
| `src/gowin/clk_108p.v` | IP PLL Gowin `CLK_108P` (rPLL, VCO 864MHz) — inst. `top.v:123` | **SE-REESCRIBE** (rPLL→PLLA GW5A, verificar VCO) | — | P2 |
| `src/gowin_clkdiv/gowin_clkdiv.v` | IP `Gowin_CLKDIV` ÷4 (108→27) — inst. `top.v:141` | **SE-REESCRIBE** (regenerar para GW5A) | mantener alineación de fase 108/54/27 (cruces sin sync sec.5 A2) | P2 |
| `src/gowin_clkdiv2/gowin_clkdiv2.vhd` | IP `Gowin_CLKDIV2` ÷2 (108→54) — inst. `top.v:185`; **generado para GW1NR-9** | **SE-REESCRIBE** (regenerar para GW5A) | ídem alineación de fase | P2 |
| `tn_vdp_v3_v9958/src/gowin/clk_135.v` | IP PLL `CLK_135` (TMDS ×5 para HDMI) — inst. `v9958_top.v:140`; lleva `DYN_DA_EN="true"` fantasma | **SE-REESCRIBE** (fase estática; valorar serdes nativo GW5A) | — | P2 |

**Notas top.v (higiene P3, netlist-neutra, sec.5 B):** mover 5 declaraciones multi-bit usadas
antes de declararse (`console_mode[1:0]`, `config3_ff`, `audio_sample`, `audio_sample_r`,
`VrmDbi2` — EX3638); `` `default_nettype none ``; unificar blocking/non-blocking (flash loader
`top.v:2287`); `bus_m1_n` en latch `console_live` (`top.v:2119`). **NO tocar** el mux turbo WSX
$40/$41 (`top.v:2137-2140`) ni la cadena de FFs que forma `reset3_n`.

---

## 2. CPU Z80 (G80A) — VHDL puro

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `G80A/g80a.vhd` | Wrapper del core Z80 (glue T80↔MSX) | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/T80s.vhd` | Top síncrono T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/t80.vhd` | Núcleo T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/t80_alu.vhd` | ALU del T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/t80_mcode.vhd` | Microcódigo/decodificador T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/t80_pack.vhd` | Paquete de tipos T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/t80_reg.vhd` | Banco de registros T80 | **PORTA-TAL-CUAL** | — | P2 |
| `G80A/T80_RegX.vhd` | Variante de registros **no compilada** (no en build.tcl) | **NO-PORTAR** (borrar en disco, sec.§2.1) | — | P0 |

Núcleo IP upstream exonerado por la auditoría (sec.5 C: "G80a … porta tal cual").

---

## 3. VDP V9958 (core gráfico) — VHDL, exonerado en la investigación R-Type

Todos **PORTA-TAL-CUAL** (sec.5 C: "core VDP (exonerado) … porta tal cual"). La VRAM real
la sirve `src/memory.v` (SE-REESCRIBE); estos módulos consumen la interfaz `vram_*`, que es la
frontera estable del wrapper DDR3.

| Ruta | Rol | Clasificación | Fase |
|---|---|---|---|
| `tn_vdp_v3_v9958/src/v9958_top.v` | Top del subsistema VDP+HDMI: PLL 135, encode NTSC/PAL, serializer | **SE-RETOCA** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp.vhd` | Top del VDP V9958 | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_colordec.vhd` | Decodificador de color | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_command.vhd` | Motor de comandos (blitter) | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_doublebuf.vhd` | Doble buffer de línea | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_graphic123m.vhd` | Modos gráficos 1/2/3 (+multicolor) | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_graphic4567.vhd` | Modos gráficos 4/5/6/7 | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_hvcounter.vhd` | Contadores H/V | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_interrupt.vhd` | Generación de interrupción VDP | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_linebuf.vhd` | Line buffer | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_ntsc_pal.vhd` | Selección NTSC/PAL | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_package.vhd` | Paquete de tipos VDP | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_register.vhd` | Registros del VDP | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_spinforam.vhd` | RAM de info de sprites | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_sprite.vhd` | Motor de sprites | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_ssg.vhd` | Screen split / scroll R#27 (smooth-scroll; core exonerado, `vdp_ssg.vhd:283`) | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_text12.vhd` | Modos texto 1/2 | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_vga.vhd` | Timing VGA/salida | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vdp_wait_control.vhd` | Control de wait del VDP | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/vdp/vencode.vhd` | Video encoder | **PORTA-TAL-CUAL** | P2 |
| `tn_vdp_v3_v9958/src/ram.vhd` | BRAM 256 bytes (ESE) auxiliar del VDP | **PORTA-TAL-CUAL** | P2 |

**Notas v9958_top.v (SE-RETOCA):** además del PLL `CLK_135` (SE-REESCRIBE, fila §1), la
auditoría §2.3 lista restos a limpiar: L69-70 + L108-110 (restos del PLL), 4 puertos `adc_*`,
instancia `cpuclkd`. El PLL en sí y HDMI serializer se retocan para GW5A. Fase P3 (limpieza) + P2 (PLL).

---

## 4. HDMI (tn_vdp) — SystemVerilog, depende de la frecuencia de reloj TMDS

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `tn_vdp_v3_v9958/src/hdmi/hdmi.sv` | Top HDMI (TMDS, guard bands, data islands) | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/serializer.sv` | Serializador TMDS 10:1; **instancia `CLOCK_DIV` de `clockdiv.v`** | **SE-RETOCA** (¿serdes nativo GW5A? / reloj ×5) | ligado a `clk_135` | P2 |
| `tn_vdp_v3_v9958/src/clockdiv.v` | `module CLOCK_DIV`: divisor diferencial fino (audio/píxel), inst. en `serializer.sv` | **SE-RETOCA** (constante depende de la freq. base) | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/tmds_channel.sv` | Codificación TMDS 8b/10b | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/packet_assembler.sv` | Ensamblador de paquetes data-island | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/packet_picker.sv` | Selector de paquetes | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/audio_clock_regeneration_packet.sv` | Paquete de regeneración de reloj de audio (CTS/N) | **SE-RETOCA** (CTS/N dependen de la freq. base) | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/audio_sample_packet.sv` | Paquete de muestra de audio | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/audio_info_frame.sv` | InfoFrame de audio | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/auxiliary_video_information_info_frame.sv` | AVI InfoFrame | **PORTA-TAL-CUAL** | — | P2 |
| `tn_vdp_v3_v9958/src/hdmi/source_product_description_info_frame.sv` | SPD InfoFrame | **PORTA-TAL-CUAL** | — | P2 |

---

## 5. MEMORIA MAPPER / MEGARAM / FLASH — portan, pero flash con fixes previos

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `src/megaram.v` | Emulación de mapper Konami/ASCII/SCC+/megaram (bus Z80 puro) | **SE-RETOCA** (porta la lógica; **NO tocar** `ff_scc_mode`/`map_sel` L41-48) | añadir SDC del cruce 27MHz→dominio DDR3 nuevo (sec.5 B) | P2 |
| `src/flash_rw.v` | Lector/escritor SPI de la flash (pack @0x200000, config @0x280000) | **SE-RETOCA** (re-mapear offsets) + **PORTA-TAL-CUAL** (tras fixes) | **#1** `write_terminate` output→input (L24); plausibles L383 (WIP erase) y L464 (WIP tras PAGE PROGRAM) **obligatorios antes del auto-commit SRAM 60K**; huérfanos §2.3 | P1→P2 |

**Nota flash_rw:** el plan SRAM_PERSIST_CONSOLE60K reutiliza este escritor "cerrando con
write_terminate", por eso #1 y los 2 plausibles son bloqueantes. >16MB de flash requeriría
comando de dirección de 4 bytes (BL616 comparte la flash en el 60K).

---

## 6. SD / WonderTANG — porta, con SD-hardening (#3+#4+#5) antes

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `src/wondertang/sd_reader.sv` | FSM lector/escritor de sector SD (LBA cruda) | **SE-RETOCA** (monodominio; 2FF a sdcmd/sddat0; parametrizar CLK_DIV) | **#3** rdone `sddat_stat` vs CMD12 (L123); **#4** reintento infinito (L287); **#5** WTAIL timeout inalcanzable (L439); **#6** CRC16 lectura ignorado — documentar (L380) | P1→P2 |
| `src/wondertang/sdcmd_ctrl.sv` | Control de línea sdcmd (CMD/respuesta), sub-IP de sd_reader | **SE-RETOCA** (`input reg`→`input wire` L15, higiene) | — | P1/P3 |
| `src/wondertang/crc16.v` | `sd_crc_16` LFSR CRC16 (GHSi, LGPL) | **PORTA-TAL-CUAL** | — | P2 |
| `src/wondertang/dpram.v` | DPRAM parametrizada (buffer de sector) | **SE-RETOCA** (`$pow`→`1<<widthad_a` en L21; yosys no implementa $pow) | — | P3 |
| `src/wondertang/pinfilter.v` | `module PINFILTER`: filtro de rebotes de pin; inst. `dn1` (vivo) / `dn2`,`dn3` (limpieza) en top.v | **PORTA-TAL-CUAL** (el módulo; limpiar instancias muertas en top.v §2.3) | — | P2/P3 |

**SD-hardening**: #3+#4+#5 = un solo batch con una re-síntesis y prueba de extracción de SD en caliente.

---

## 7. AUDIO — PSG, OPLL (jtopl), SN76489, filtros

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `PSG_YM2149/YM2149.vhdl` | PSG AY-3-8910/YM2149 | **SE-RETOCA** | **#2** bucle combinacional (L448): hacer carga de env síncrona — **lotería de placement en GW5A** | P1 |
| `src/psg_filter.v` | Envoltorio de filtros de audio: instancia OPLL (`jt2413 opll`, en top.v) y `lpf1`/`lpf2` (de `src/ocm/lpf.vhd`, binding cross-language) | **SE-RETOCA** (divisores `clk_enable_2m7`/`270k` dependen de la freq. base) | documentar el binding lpf1/lpf2 con `src/ocm/lpf.vhd` | P2 |
| `src/ocm/lpf.vhd` | Filtros paso-bajo OCM (entidades LPF1/LPF2) usadas por `psg_filter.v` | **PORTA-TAL-CUAL** (⚠️ **nunca** añadir al build el `lpf.vhd` de tn_vdp: colisiona) | — | P2 |
| `src/sn76489.v` | PSG SN76489 (SG-1000/ColecoVision); clk_en 3.58MHz | **SE-RETOCA** (clk_en 3m6 depende de freq. base; opcional: fidelidad LFSR taps 0^3 vs 0^1, reset-on-write; keypad `kp_code` top.v:1858 pendiente HW) | convertir `sn_wr` a strobe 1 ciclo (top.v:1829) antes de mejoras | P2 |
| `src/ocm/scc_wave2.vhd` | Generador de onda SCC/SCC+ | **SE-RETOCA** (limpieza §2.3: entidad `scc_mix_mul` + `lpf*_wave` muertos) | — | P3 |
| `src/ocm/fifo.vhd` | FIFO genérico (TBBlue/Trucco); lo usa `wifi_lite.vhd` | **PORTA-TAL-CUAL** | — | P2 |
| `src/psg_filter.v`→ver arriba | — | — | — | — |

### jtopl (OPLL/YM2413 — jt2413) — todos **PORTA-TAL-CUAL** (sec.5 C: "jtopl … porta tal cual")

Inst. real: `jt2413 opll` en `top.v:1614`. 43 ficheros:

`jtopl/jt2413.v` · `jtopl.v` · `jtopl2.v` · `jtopl_acc.v` · `jtopl_csr.v` · `jtopl_div.v` ·
`jtopl_eg.v` · `jtopl_eg_cnt.v` · `jtopl_eg_comb.v` · `jtopl_eg_ctrl.v` · `jtopl_eg_final.v` ·
`jtopl_eg_pure.v` · `jtopl_eg_step.v` · `jtopl_exprom.v` · `jtopl_lfo.v` · `jtopl_logsin.v` ·
`jtopl_mmr.v` · `jtopl_noise.v` · `jtopl_op.v` · `jtopl_pg.v` · `jtopl_pg_comb.v` ·
`jtopl_pg_inc.v` · `jtopl_pg_rhy.v` · `jtopl_pg_sum.v` · `jtopl_pm.v` · `jtopl_reg.v` ·
`jtopl_reg_ch.v` · `jtopl_sh.v` · `jtopl_sh_rst.v` · `jtopl_single_acc.v` · `jtopl_slot_cnt.v` ·
`jtopl_timers.v` · `jtopll_mmr.v` · `jtopll_reg.v` · `jtopll_reg_ch.v`
→ **todos PORTA-TAL-CUAL, fase P2.**

---

## 8. OCM (KdL) — RTC, WiFi/UART, swioports, kanji

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `src/ocm/rtc.v` | RTC del OCM (segundos por cuenta LFSR) | **SE-RETOCA** (constante LFSR del segundo L66: **recalcular con el generador de KdL**, no restando; puerto reset sin uso §2.3) | — | P2 |
| `src/ocm/wifi_lite.vhd` | Puente WiFi UNAPI ↔ ESP (859372 bps FIJOS del firmware de ducasp) | **SE-RETOCA** (prescaler=31 L205 y timeout 25ms L243 dependen de freq. base; añadir `out_uart_status(5)<='0'` §2.3) | — | P2 |
| `src/ocm/uart_lite.vhd` | UART mínima (KdL) usada por wifi_lite | **SE-RETOCA** (2º FF en `rx_sync` L81) | — | P2/P3 |
| `src/ocm/swioports.vhd` | Puertos SWIO $40-$4F (FKeys/DIP/smart-resets), turbo, config | **SE-RETOCA** (~80% inerte; conservar EXACTO readback $40-$4F; `io43_id212` 'X'→'0' L241; limpieza `nose/btn_scan/scanlines` §2.3; **NO tocar** mux turbo WSX top.v:2137-2140) | — | P2 |
| `src/ocm/kanji.v` | Controlador de ROM kanji (ESE) | **SE-RETOCA** (añadir initializers para simulación §2.3; porta tal cual en HW) | — | P2/P3 |

---

## 9. COMPANION BL616 / USB — topología a decidir (dock M0S vs onboard 60K)

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `src/usb/fpga_companion.v` | Interfaz FPGA↔MCU companion; mux `spi_ext` del dock M0S | **SE-REESCRIBE** (topología distinta en 60K; si se quita el dock, borrar `spi_ext`/mux L47-59 → desaparece TA1132) | decidir topología (sec.5 A4) | P2 |
| `src/usb/mcu_spi_new.v` | SPI del companion (BL616); `spi_io_clk` usado como reloj sin create_clock | **SE-REESCRIBE/RETOCA** (según topología; +2FF a `spi_io_ss` L89 plausible#4; create_clock sobre pin limpio si se quita el dock) | plausible #4 (CDC) | P2 |
| `src/usb/sys_ctrl.v` | Control de sistema por comandos SPI (CMD0/4/5/6/7); teclado | **SE-RETOCA** (limpiar restos Atari ST: CMD4 chipset/TOS, rs232 CMD7 ~50 EX2565; **preservar CMD0/CMD5/CMD6 e int_out_n = teclado**) | — | P2 |
| `src/usb/hid.v` | Interfaz HID (teclado/ratón/db9) ↔ MCU | **PORTA-TAL-CUAL** (revisar con la topología nueva) | — | P2 |
| `src/usb/usb_keyboard_msx.vhd` | Traductor de teclas USB→matriz MSX | **SE-RETOCA** (quitar `STD_LOGIC_ARITH` §2.3; lógica porta) | — | P2/P3 |

Referencia de pinout/firmware para el 60K: TangCore/NESTang (nand2mario). Ver también `fpga/bl616/`.

---

## 10. MISCELÁNEO — LED, denoise, monostable

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `src/ws2812.v` | Driver LED WS2812 | **PORTA-TAL-CUAL** (re-ubicar pin; parámetros dependen de `CLK_FRE`) | — | P2 |
| `denoise/denoise.vhd` | Filtro anti-rebote; inst. `denoise dn4` en top.v:242 (limpieza fase 3 lo saca del build) | **SE-RETOCA→NO-PORTAR** (al quitar `dn4` en §2.3, sale del build) | — | P3 |
| `monostable/monostable.vhd` | One-shot 0.5s @27MHz; inst. `mono` (vivo) y `mono2` (muerto, §2.3) en top.v | **SE-RETOCA** (constante 0.5s depende de freq.; limpiar `mono2`) | — | P2/P3 |

---

## 11. NO-PORTAR — código muerto en disco (fuera del build), sec.§2.1

Verificado por diff `find` (disco) vs `build.tcl` (108 add_file): **9 ficheros RTL en disco no
entran al build**. Todos **NO-PORTAR** (borrar en disco, fase **P0**, cero riesgo):

| Ruta | Motivo |
|---|---|
| `msx_debug/timing_debug.v` | debug fuera del build (§2.2 ya podado del tcl) |
| `pulse_min_max/pulse_max.v` | debug fuera del build (top.v:2757 documenta que se quitó) |
| `pulse_min_max/pulse_min.v` | ídem |
| `src/impulse.v` | 0 instanciaciones; **ya no está en este `build.tcl`** (divergencia con AUDIT §2.2 que lo cita en build.tcl:46) |
| `src/msx2p_debug.v` | instancia comentada en top.v:2742-2755 |
| `src/uart_tx.v` | fuera del build (§2.2) |
| `tn_vdp_v3_v9958/src/memory_controller.v` | instancia comentada en v9958_top.v:180-211 (VRAM la sirve `src/memory.v`) |
| `tn_vdp_v3_v9958/src/sdram.v` | ídem, controlador SDRAM del tn_vdp standalone, muerto |
| `tn_vdp_v3_v9958/src/vram.v` | ídem |

**Además** (citados por AUDIT §2.1 pero **no presentes** en esta copia — ya borrados): `T80_RegX.vhd`
(sí presente, arriba §2), `denoise2/denoise_8/denoise_low/denoise_low8.vhd`, `msx1_debug.v`,
`print.v`/`uart_tx.v`/`msx2p_debug.v` duplicados, `clk_108p_tmp.v` y demás `*_tmp`, `logo.v`,
`SPI_MCP3202.v`, `pinfilter.v`(tn_vdp), `lpf.vhd`(tn_vdp), `clk_*` de tn_vdp. `T80_RegX.vhd` SÍ
sigue en disco → NO-PORTAR (borrar). El resto de la lista §2.1 ya no está en esta copia.

> ⚠️ El `lpf.vhd` de `tn_vdp_v3_v9958/src/` **NUNCA** debe entrar al build (colisiona con las
> entidades LPF1/LPF2 de `src/ocm/lpf.vhd`). En esta copia ya no está en `tn_vdp_v3_v9958/src/`.

---

## 12. CONSTRAINTS — se rehacen desde cero (fallan EN SILENCIO)

| Ruta | Rol | Clasificación | Pre-req | Fase |
|---|---|---|---|---|
| `Z80_goauld.sdc` | Timing constraints: create_clock, generated clocks anclados a nombres GW2A (`rpll_inst/CLKOUT`, `O_sdram_clk`), false_paths | **SE-REESCRIBE** (candidato nº1 a rehacer; **verificar tras 1º PnR que cada constraint matchea >0 objetos**) | añadir create_clock a `spi_sclk`/`spi_io_clk` (TA1132); constraint del cruce megaram 27→DDR3 | P2 |
| `tang9k.cst` | Pin constraints (companion, SD, ws2812, HDMI); mal nombrado (dice 9k siendo 20k) | **SE-REESCRIBE** (CST entero nuevo para la Console 60K; renombrar) | PULL_MODE=UP en m0s[] si se mantiene dock (A4) | P2 |
| `build.tcl` | Script de build gw_sh (set_device GW2AR-…, place/route option 2) | **SE-REESCRIBE** (`set_device` GW5AT-60; opciones PnR; add_file de IPs nuevas) | — | P2 |
| `Z80_goauld.gprj` | Proyecto GUI Gowin (Device GW2AR-18C) | **SE-REESCRIBE** (Device GW5AT-60; lista de ficheros) | — | P2 |
| `Makefile` | Wrapper de build | **SE-RETOCA** (rutas de toolchain GW5A) | — | P2 |

---

## 13. RESUMEN DE CUENTAS (solo ficheros RTL + constraints/scripts relevantes al build)

**RTL en el build (108 `add_file`):**
- PORTA-TAL-CUAL: **~78** (43 jtopl + 20 vdp + 8 hdmi PORTA + G80A×7 [core, 1 T80_RegX es NO-PORTAR] + crc16 + ram.vhd + lpf.vhd + fifo.vhd + kanji-en-HW + ws2812 + hid + pinfilter…).
- SE-RETOCA: **~24** (memory-adjacentes de top, megaram, flash_rw, sd_reader, sdcmd_ctrl, dpram, YM2149, psg_filter, sn76489, scc_wave2, rtc, wifi_lite, uart_lite, swioports, kanji, usb_keyboard_msx, sys_ctrl, monostable, clockdiv, serializer, audio_clock_regen, v9958_top, denoise).
- SE-REESCRIBE: **~7** (`memory.v`, `clk_108p.v`, `gowin_clkdiv.v`, `gowin_clkdiv2.vhd`, `clk_135.v`, `fpga_companion.v`, `mcu_spi_new.v`) + `top.v` (parcial, cuenta en las 3).
- NO-PORTAR (en disco, fuera del build): **9** RTL + `T80_RegX.vhd` (10 en total).

**Constraints/scripts:** 5 → SE-REESCRIBE (sdc, cst, tcl, gprj) / SE-RETOCA (Makefile).

---

## 14. FICHEROS QUE LA AUDITORÍA §5 NO CLASIFICA EXPLÍCITAMENTE (marcados aquí)

La sección 5 clasifica por bloques temáticos, no fichero a fichero. Estos entran al build pero
la §5 no les da una etiqueta A/B/C directa — clasificación **propia** de este manifiesto, anclada:

- **jtopl (43 ficheros)** — §5 C solo dice "jtopl … porta tal cual" genérico → aquí desglosados: **PORTA-TAL-CUAL**.
- **20 ficheros `vdp/*.vhd`** — §5 C dice "core VDP (exonerado)" genérico → **PORTA-TAL-CUAL** cada uno.
- **8 ficheros `hdmi/*.sv`** (los que no son serializer/clockdiv/audio_clock_regen) — §5 no los cita → **PORTA-TAL-CUAL** (TMDS es agnóstico; el reloj ×5 viene por interfaz).
- **`src/ocm/fifo.vhd`** — no citado por §5 → **PORTA-TAL-CUAL** (FIFO genérico, lo usa wifi_lite).
- **`src/wondertang/crc16.v`** — no citado → **PORTA-TAL-CUAL** (LFSR puro).
- **`tn_vdp_v3_v9958/src/ram.vhd`** — no citado → **PORTA-TAL-CUAL** (BRAM 256B).
- **`src/usb/hid.v`** — §5 cita fpga_companion/mcu_spi/sys_ctrl pero no hid.v → **PORTA-TAL-CUAL** (revisar con topología BL616).
- **`monostable/monostable.vhd`** — §5 no lo cita → **SE-RETOCA** (one-shot 0.5s @27MHz, constante dependiente de reloj).
- **`tn_vdp_v3_v9958/src/clockdiv.v`** — §5 no lo cita explícitamente → **SE-RETOCA** (divisor diferencial, constante depende de la base; inst. en serializer.sv).
- **`audio_clock_regeneration_packet.sv`** — §5 no lo cita → **SE-RETOCA** (CTS/N dependen de la freq. base).

## 15. DIVERGENCIAS DETECTADAS ENTRE LA AUDITORÍA Y ESTA COPIA (dev_ref)

1. **`build.tcl` ya podado**: la §2.2 pide quitar `impulse.v`, `msx2p_debug.v`, `uart_tx.v`,
   `timing_debug.v`, `pulse_max/min.v`, `memory_controller.v`, `sdram.v`, `vram.v` — **ya no están
   en este `build.tcl`** (108 add_file). La Fase 0/1 de limpieza está aplicada aquí.
2. **`src/print.v` ya borrado** (no existe en disco).
3. **`impulse.v` citado en `build.tcl:46`** por la auditoría, pero **este `build.tcl` no lo incluye**.
   Sigue en disco como código muerto → NO-PORTAR.
4. Los `*_tmp.v`, `logo.v`, `SPI_MCP3202.v`, `denoise2/_8/_low*`, `msx1_debug.v`, `clk_*` de tn_vdp
   citados en §2.1 **ya no están en disco** en esta copia. Los únicos muertos-en-disco reales son
   los 9 de §11 + `G80A/T80_RegX.vhd`.
