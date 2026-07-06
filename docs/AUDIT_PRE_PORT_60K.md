# Auditoría pre-port MSXnano → Tang Console 60K — Informe final

Repo: `C:\Users\alber\proyectosAI\msx\MSXnano` · Base: v1.8 en producción / v1.9 validada en HW · Evidencia: código real + `gowin_syn_warnings.txt` (297 líneas del build real) · ~45 findings de 6 áreas, deduplicados y con veredicto de escéptico sobre los 10 bugs candidatos.

---

## 1. Resumen ejecutivo

**El core está sano.** Ningún hallazgo explica un fallo observable hoy: v1.8/v1.9 funcionan y ninguna de las decisiones deliberadas de timing (megaram registrado, retardo 3m6, turbo WSX) está en cuestión. Lo encontrado es:

- **Mucho código muerto** heredado del diseño con bus MSX externo y del tn_vdp standalone: 2 FSMs completas, ~20 ficheros fuera del build, 3 ficheros que se compilan y se podan en cada build, decenas de señales sin lector. Inofensivo, pero ensucia el port.
- **6 bugs confirmados, todos latentes**: viven en rutas de error (SD extraída, flash sin responder) o en zonas que la STA no analiza (bucle combinacional del PSG). Ninguno urge en TN20K, pero **tres muerden exactamente donde el port se apoyará**: el plan SRAM-persistente reutiliza `flash_rw.v` (2 fixes obligatorios antes), y el bucle del YM2149 es una lotería de placement al cambiar a GW5A.
- **El port real se concentra en 4 frentes**: controlador de memoria (SDRAM→DDR3, el bloque más caro), árbol de relojes (rPLL→PLLA + constantes absolutas dispersas), constraints (SDC y CST enteros nuevos, con fallos *silenciosos* si se copian) y companion BL616 (topología distinta en el 60K).

---

## 2. LIMPIEZA SEGURA

### 2.1 Borrar ficheros en disco NO compilados — cero riesgo, ni siquiera requiere rebuild
Confirmado contra `build.tcl`:
- `fpga/G80A/T80_RegX.vhd`
- `fpga/denoise/denoise2.vhd`, `denoise_8.vhd`, `denoise_low.vhd`, `denoise_low8.vhd` (mantener `denoise.vhd`: aún instanciado como `dn4` hasta la fase 3)
- `fpga/msx_debug/msx1_debug.v`, `msx2p_debug.v`, `print.v`, `uart_tx.v` (duplicados)
- `fpga/src/gowin/clk_108p_tmp.v` · `fpga/src/gowin_clkdiv/gowin_clkdiv_tmp.v` · `fpga/src/gowin_clkdiv2/gowin_clkdiv2_tmp.vhd`
- `fpga/src/logo.v`
- `fpga/tn_vdp_v3_v9958/src/SPI_MCP3202.v`, `pinfilter.v`, `lpf.vhd` (⚠️ este `lpf.vhd` NUNCA debe entrar al build: colisionaría con `src/ocm/lpf.vhd`, cuyas entidades LPF1/LPF2 usa `psg_filter.v` por binding cross-language)
- `fpga/tn_vdp_v3_v9958/src/gowin/clk_108p.v`, `clk_108p_tmp.v`, `clk_135_tmp.v`, `clk_135p_tmp.v`, `clk_81p_tmp.v`
- ⚠️ `fpga/src/print.v` NO todavía: entra por `` `include `` desde `src/msx2p_debug.v` (build.tcl:50). Borrarlo en 2.2.

### 2.2 Podar `build.tcl` — netlist idéntico en teoría (el sintetizador ya los barre); verificar con un build y diff del resource summary
- Líneas 40-42: `msx_debug/timing_debug.v`, `pulse_min_max/pulse_max.v`, `pulse_min.v` (top.v:2757 documenta que se quitó en producción)
- Línea 46: `src/impulse.v` (cero instanciaciones) + entrada en `Z80_goauld.gprj:49`
- Líneas 50 y 54: `src/msx2p_debug.v` y `src/uart_tx.v` (instancia comentada en top.v:2742-2755) → después ya se puede borrar `src/print.v`
- Líneas 73-76: `tn_vdp_v3_v9958/src/memory_controller.v`, `sdram.v`, `vram.v` (instancias comentadas en v9958_top.v:180-211; la VRAM real la sirve `src/memory.v`)

### 2.3 Limpieza RTL netlist-neutra — requiere `make clean && build` de verificación + humo en HW (política del proyecto)
Todo esto lo poda o ignora ya el sintetizador; borrarlo solo cambia el fuente:

**top.v** (deduplicado entre áreas):
- Línea 1515 `reg psgPB = 8'hff;` — Gowin la IGNORA (EX3671): el init a FF nunca ha existido; borrar solo la línea (no tocar I_IOB/O_IOB, validado)
- Línea 2707 `wire swio_req;` duplicado
- Bloque comentado 2447-2500 (FSM flash antigua) + `flash_wait_n` (2228) + `sram_addr_w/ff_sram_*` (2520-2523) + localparam `SCC_ENABLE` (2517) y comentarios 2553-2555
- FSM demux muerta 330-395 + sinks `ex_msel/ex_bus_mp` (110-118) + `update_demux`
- FSM "bus isolation" muerta 613-665 + sinks `ex_bus_rd_n/wr_n`
- `bus_data` + 8 PINFILTER 248-269 + rama `` `ifdef SWAP23 `` 431-474; filtros de constantes `dn2`/`dn4` 202-208/242-246 (sustituir por assigns directos; al quitar `dn4`, `denoise.vhd` sale también del build)
- `clk_enable_27m/54m` 131-138; wires/assigns `reset1_n/reset2_n` (los FFs de la cadena SÍ participan en reset3_n — no tocar); `msx_logo_req` 1149-1154/1175-1176; `bios_dout/subrom_dout/msx_logo_dout`; `function_keys` (544); `psg_dout`, `clk_1m8_prev`, `mapper_dout`; restos del 2º SCC viejo (`scc2_req_r/scc2_dout/scc2_wav/megaram_enabled` — OJO: `scc2_req`/`scc2_wrt` SÍ viven); `mono2`/`send` 2735-2755; `initial` vacío 85-87
- Rama `else` de ENABLE_CONFIG 2172-2205 (está ROTA: no define console_mode/config3_ff/config4_ff que se usan fuera del ifdef — borrarla es lo honesto); `config_keyboard`, `config_megaram_slot_ff`, cadena `config_sdcard_slot*` (documentar que los bits 2:1 del puerto #42 no hacen nada); `;;` en 2165

**Otros ficheros**: `memory.v` (sdram_read/sdram_dout/enable_sdram/SdrSize/FreeCounter2); `flash_rw.v` (4 localparams de comandos huérfanos, reg `command` constante); `megaram.v` (megaram_reg_H/L — verificar que tools/megaram_equiv sigue 26/26); `scc_wave2.vhd` (entidad scc_mix_mul + lpf*_wave); `swioports.vhd` (nose/btn_scan/prev_scan/bloque scanlines 1065-1070); `wifi_lite.vhd` (añadir `out_uart_status(5) <= '0'`); `rtc.v` (puerto reset sin uso); `v9958_top.v` (líneas 69-70 + 108-110 restos del PLL, 4 puertos adc_*, instancia cpuclkd); `sd_reader.sv` (card_stat 4 vs 5 bits, salida muerta en top.v:2530).

---

## 3. BUGS CONFIRMADOS (6) — por severidad

| # | Sev | Dónde | Bug | Fix | Rebuild/HW |
|---|-----|-------|-----|-----|------------|
| 1 | **alta** | `fpga/src/flash_rw.v:24` | `write_terminate` declarado `output`, leído en L455 y jamás asignado (EX0211): la señal de corte de top.v:2246 nunca entra; el PAGE PROGRAM siempre escribe los 256 bytes. Benigno hoy (el mux de top.v:2236-2244 rellena con 0xFF, que no altera flash borrada) — pero el plan SRAM_PERSIST_CONSOLE60K reutiliza este escritor "cerrando con write_terminate". En simulación se comporta DISTINTO que en HW (red sin driver = x). | Cambiar a `input wire write_terminate` | Sí; revalidar guardado de config en HW (OUT #42) |
| 2 | **alta** (riesgo port, no audible hoy) | `fpga/PSG_YM2149/YM2149.vhdl:448` | Bucle combinacional real (AG0100 ×2, "netlist is not one DAG"): carga asíncrona de `env_vol`/`env_inc` con valor dependiente de `reg(13)(2)` — no mapea a DFF Gowin, se emula con realimentación y la STA NO analiza esos caminos. Funciona en GW2A por suerte de placement; lotería al re-plazar en GW5A. | Hacer la carga síncrona (`if rising_edge(CLK) then if env_reset='1'...`); env_reset es pulso registrado en el mismo clk → no se pierde; el load se retrasa 37 ns, inaudible | Sí; A/B de envelopes PSG en openMSX/HW (2 instancias) |
| 3 | media | `fpga/src/wondertang/sd_reader.sv:123` | `rdone` compara `sddat_stat` (4 bits) contra `CMD12=5'd9` del enum de COMANDOS (en el de datos 9=WDONE): término de lectura imposible, el de escritura duplicado. Tras RTIMEOUT `rdone` nunca pulsa → top.v:2636-2645 no limpia `ff_sd_rstart/wstart` → reintento eterno del sector, `timeout_error` se auto-borra, SD colgada hasta reset si se extrae la tarjeta en mitad de una carga | `sdcmd_stat==CMD12` en rdone + en top.v limpiar rstart/wstart cuando `timeout_error` active | Sí; prueba HW: extraer SD durante carga |
| 4 | media | `fpga/src/wondertang/sd_reader.sv:287` | Reintento infinito sin contador en READING/WRITING (timeout/syntaxe → relanza CMD17/24 para siempre; CMD55_41 del init ídem) → `rbusy`/bit7 de SDC_STATUS pegado. El menú tiene backstop software (~2-3 s en menu_main.asm:3748), pero Nextor u otro driver que haga poll sin timeout se cuelga | Contador de reintentos (p.ej. 3) → IDLING + `timeout_error` | Sí; misma sesión HW que #3 |
| 5 | media | `fpga/src/wondertang/sd_reader.sv:439` | En WTAIL el check `ridx > 13000000` está DENTRO de `if (!sddat0)` (el `end` engaña): si la tarjeta nunca baja DAT0 tras el CRC status, el timeout es inalcanzable → WTAIL para siempre, la propia ruta de recuperación de errores está rota. Además mezcla `=`/`<=` sobre sddat_stat | Sacar el if del guard (como en WBUSY, L445-453) y unificar a nonblocking | Sí; misma sesión HW |
| 6 | media | `fpga/src/wondertang/sd_reader.sv:380` | CRC16 de LECTURA ignorado por diseño del IP WonderTANG ("ignores crc and end bit"): corrupción de bus llega al Z80 como datos válidos; `crc_error` además retiene el valor rancio de la última ESCRITURA durante lecturas | Disposición: **documentar la limitación** (herencia upstream). Si se arregla: alimentar sd_crc_16 en RDURING, comparar en RTAIL, limpiar crc_error al entrar en READING | Solo si se implementa |

**Recomendación**: #3+#4+#5 son un solo batch "SD hardening" con una re-síntesis y una sesión de pruebas (extracción de SD). #1 y #2 pueden ir en el mismo batch. #6 se documenta.

---

## 4. VEREDICTOS: ninguno REFUTADO; 4 quedaron en PLAUSIBLE (hueco real, efecto no demostrable hoy)

- **top.v:1913 (mixer 16 bits sin saturación)** — el wrap es alcanzable aritméticamente pero no con cargas reales (SCC tope ±19200, no ±32766; OPLL satura internamente; SN76489 gated a modo consola donde los demás callan). Deuda de headroom: acumulador 18-19 bits + clamp **en el port**.
- **flash_rw.v:383 (poll WIP del erase sin timeout)** — indisparable en la placa: es la flash de la que arranca el propio FPGA. Hardening para el auto-commit SRAM del 60K.
- **flash_rw.v:464 (no espera WIP tras PAGE PROGRAM)** — defecto estructural cierto, pero hoy no hay NINGUNA lectura post-write ni escritura en ráfaga posible (única escritora: config de 6 bytes por acción humana). **Obligatorio arreglar antes del auto-commit SRAM del 60K** (escrituras en ráfaga <3ms → program-sin-borrado).
- **mcu_spi_new.v:89 (spi_io_ss sin sincronizador 2FF)** — hueco CDC real (el .sdc no lo cubre) pero el reset por nivel se auto-corrige y el desalineamiento a mitad de transacción es imposible por construcción. Higiene de 3 líneas al portar (upstream MiSTeryNano).

---

## 5. RIESGOS PORT60K — guía del port

### A. Se reescribe entero
**A1. Memoria (el bloque más caro del port)**
- `fpga/src/memory.v` completo: secuenciador fijo de 8 fases @108MHz encajado en video_dhclk/dlclk, comandos SDR crudos, `O_sdram_clk = clk_108m`, latencia determinista 1 acceso CPU + 1 VDP por slot. DDR3 (latencia variable, colas) no ofrece ese contrato.
- `top.v:70-79` "magic ports" SDRAM del GW2AR-18 — no existen en GW5AT-60.
- `top.v:1389-1411` mapa de bancos por prefijos de bits inline.
- **Estrategia**: hard-core DDR3 de Gowin + wrapper que preserve la interfaz `ram_req/ram_busy/ram_dout` @27MHz + `vram_*` 16 bits como frontera estable; valorar VRAM en BRAM del GW5A (sobra) dejando DDR3 para mapper/megaram.
- **Requisito de diseño a trasladar por escrito** (no código a traducir): el fix MG2 de `memory.v:204-213` codifica "toda escritura VDP aceptada se COMPLETA; el refresh/arbitraje jamás la descarta". Si el arbiter nuevo no lo honra, el bug "agujeros en VRAM" reaparece con otra cara.
- **Requisito 2**: `top.v:689` — los wait states son de duración FIJA sin handshake `ram_busy` (el propio código lo avisa en 886-887). Con DDR3 es corrupción garantizada. Activar/portar la rama dormida `ENABLE_WAIT_ADAPTIVE` (717-755) como **requisito del port**, no optimización. NO borrar esa rama en la limpieza.

**A2. Árbol de relojes**
- Regenerar 4 IPs para GW5A: `CLK_108P` (rPLL→PLLA, verificar VCO 864MHz), `Gowin_CLKDIV` (÷4) y `Gowin_CLKDIV2` (÷2 — ¡generado para GW1NR-9!), `CLK_135` (TMDS ×5; lleva DYN_DA_EN="true" fantasma — pedir fase estática; valorar serdes nativo del GW5A para HDMI).
- **Crítico**: hay cruces 27↔54 registro-a-registro SIN sincronizadores (`ppi_port_a` 1032-1040, `exp_slot*` 1071-1090, keyboard/joystick 486-501/860) seguros SOLO por la alineación de fase 108/54/27 del mismo árbol CLKDIV. Garantizarla en el PLLA nuevo o añadir sincronizadores.
- Constantes absolutas a recalcular si cambia la base (el 60K lleva otro oscilador): ÷30→3.6MHz (225), ÷20+swallow 175/176→**5.369318MHz EXACTO turbo WSX** (899-935), `esp_boot_cnt` 3s (836), autofire (512-516), `counter_reset` (290), `rtc.v:66` constante LFSR del segundo (⚠️ es cuenta LFSR, recalcular con el generador de KdL, no restando), `wifi_lite.vhd:205` prescaler=31 para **859372 bps FIJOS del firmware ESP de ducasp** + timeout 25ms (243), divisores de `psg_filter.v`. Centralizar en localparams derivados de CLK_HZ.

**A3. Constraints (fallan EN SILENCIO — candidato nº1 a rehacer, no a copiar)**
- `Z80_goauld.sdc`: create_clock sobre la RED (no el puerto, origen del PR1014), generated clocks anclados a nombres GW2A (`clk_main/rpll_inst/CLKOUT`, `O_sdram_clk`), false_path con rutas de instancia. Un `get_pins` que no matchea no da error: pierde la constraint. **Tras el primer PnR en GW5A verificar en el log que cada constraint matchea >0 objetos.**
- TA1132 (`fpga_companion_inst/mcu/n4_24`): `spi_io_clk` (salida del mux spi_ext) se usa como RELOJ en `mcu_spi_new.v:43/117` sin create_clock — el dominio SPI del BL616 no se analiza. Si se elimina el dock (A4), pasa a ser un pin limpio: `create_clock` directo sobre `spi_sclk`.
- `tang9k.cst` entero nuevo (companion 10 pines, SD 6 pines, ws2812, HDMI); de paso renombrarlo (dice 9k siendo 20k).

**A4. Companion BL616**
- Decidir topología primero: en el Console 60K el BL616 onboard es el debugger con pines TangCore (nand2mario; hay ports 60K funcionando: NESTang/TangCore de donde sacar pinout y firmware). ¿Sigue teniendo sentido el dock M0S externo (mitigación secure-boot)?
  - Si NO: borrar `spi_ext`/mux (fpga_companion.v:47-59) → desaparece el TA1132.
  - Si SÍ: PULL_MODE=UP en los 5 pines m0s[] OBLIGATORIO en el CST nuevo (hoy salva el latch sin-vuelta-atrás de spi_ext) + exigir N muestras a 0 antes de conmutar.
- Limpiar `sys_ctrl.v` (restos del core Atari ST: CMD4 con ids de chipset/TOS, bloque rs232 CMD7 — origen de ~50 EX2565) **preservando CMD0/CMD5/CMD6 e int_out_n: son el teclado**. Higiene CDC de `spi_io_ss` (plausible #4).
- Aclarar `joystick0_console` (top.v:2835 sin conectar): ¿resto de una iteración del #20 o pendiente de cablear? Decidir antes de portar código ambiguo.

### B. Se retoca
- **Flash**: re-mapear 0x200000 (pack) y 0x280000 (config) — el bitstream GW5AT-60 es mayor y el BL616 comparte la flash; aplicar ANTES los fixes #1 + plausibles de `flash_rw.v` (el plan SRAM-persist lo reutiliza); >16MB requeriría comando 4-byte address. El resto del módulo porta tal cual.
- **megaram.v**: portable (bus Z80 puro), PERO el registro de `ff_scc_mode/map_sel` (líneas 41-48, NO tocar) era la mitigación contra el muestreo @108 del controlador VIEJO sin SDC. Con DDR3: mantener los registros Y añadir constraint SDC explícita del cruce 27MHz→dominio del controlador nuevo.
- **SD**: portable (monodominio en clk); mantener clk 25-50MHz o parametrizar CLK_DIV; añadir 2FF a sdcmd/sddat0; conservar `sd_dat1/2/3=1`; aplicar fixes #3-#5 antes.
- **swioports.vhd**: ~80% inerte (FKeys/DIP/smart-resets sin consumidores — SETSMART reset no hace nada hoy). Decidir: conectar de verdad o sustituir por register-file mínimo conservando EXACTO el readback $40-$4F. **NO tocar el mux turbo WSX $40/$41 de top.v:2137-2140 (mod validado).** Cambiar la 'X' de `io43_id212` (línea 241) por '0' — con GW5A el don't-care puede resolverse distinto.
- **uart_lite.vhd:81**: 2º FF en rx_sync (un FF, casi gratis en fabric nueva).
- **Higiene que evita fallos silenciosos con otro front-end/toolchain** (hacer en fase 3): mover las 5 declaraciones multi-bit usadas antes de declararse (`console_mode [1:0]`, `config3_ff`, `audio_sample`, `audio_sample_r`, `VrmDbi2` — EX3638; colapsarían a 1 bit en silencio) + `` `default_nettype none ``; `$pow`→`1<<widthad_a` en `dpram.v:21` (yosys no implementa $pow); unificar blocking/non-blocking (flash loader top.v:2287, pinfilter, clockdiv, hid/sysctrl, flash_rw:302); quitar STD_LOGIC_ARITH de `usb_keyboard_msx.vhd`; `input reg`→`input wire` en sdcmd_ctrl.sv:15; añadir bus_m1_n al latch de console_live (top.v:2119) o corregir el comentario; initializers en kanji.v para simulación.
- **Audio (opcional, decisiones de producto)**: clamp del mixer (plausible #1); fidelidad SN76489 (taps LFSR 0^3 vs 0^1, reset LFSR on-write, periodo 0 — pero ANTES convertir `sn_wr` a strobe de 1 ciclo, top.v:1829; irónicamente el muerto `impulse.v` es justo ese detector); keypad Coleco `kp_code` (top.v:1858) pendiente conocido de validar en HW.

### C. Porta tal cual
`megaram.v` (lógica) · `flash_rw.v` (tras fixes) · `ws2812.v` (solo re-ubicar pin; parámetros dependen de CLK_FRE) · bloque SD RTL · divisores fabric ÷30 y ÷20+swallow (mientras clk_108m sea 108 exactos) · `lpf.vhd` OCM (⚠️ documentar en `psg_filter.v` el binding cross-language lpf1/lpf2; nunca añadir el lpf.vhd de tn_vdp al build) · G80a, jtopl, core VDP (exonerado en la investigación R-Type) y demás IP upstream.

---

## 6. Orden de ejecución recomendado

1. **Fase 0 — hoy, sin rebuild**: 2.1 (borrar ficheros muertos en disco, excepto `src/print.v`). Commit.
2. **Fase 1 — un rebuild de verificación**: 2.2 (podar build.tcl + borrar `src/print.v`) → `make clean` + build → comparar resource summary + humo en HW (menú + un juego).
3. **Fase 2 — fixes pre-port en TN20K (un batch, una sesión HW)**: bugs confirmados #1 (write_terminate), #3+#4+#5 (SD hardening) y #2 (YM2149 síncrono), opcionalmente los 2 plausibles de flash_rw. Pruebas: guardado de config, cargas SD, extracción de SD en caliente, A/B de envelopes PSG. **Hacerlo ANTES del port**: si algo se rompe, sabes que es el fix y no la familia nueva.
4. **Fase 3 — limpieza RTL 2.3 + higiene B (declaraciones, $pow, blocking)**: en TN20K, donde el bitstream conocido sirve de referencia; habilita de paso simular top.v con Icarus/Verilator para el port.
5. **Fase 4 — port**: (a) PLL/CLKDIV para GW5A + SDC/CST desde cero (verificar matches >0); (b) wrapper DDR3 preservando la interfaz ram_*/vram + handshake adaptativo de waits + requisito "escritura VDP nunca se descarta"; (c) companion según topología BL616 del 60K (pinout de TangCore); (d) revalidación con checklist: turbo 5.369318 exacto, RTC/DOS, WiFi 859372 bps, MG2/R#13, SD, keypad Coleco.

Ficheros clave citados: `fpga/top.v`, `fpga/src/memory.v`, `fpga/src/flash_rw.v`, `fpga/src/megaram.v`, `fpga/src/wondertang/sd_reader.sv`, `fpga/PSG_YM2149/YM2149.vhdl`, `fpga/src/ocm/{swioports,wifi_lite,uart_lite,scc_wave2,lpf}.vhd`, `fpga/src/ocm/rtc.v`, `fpga/src/usb/{fpga_companion,mcu_spi_new,sys_ctrl,hid}.v`, `fpga/tn_vdp_v3_v9958/src/v9958_top.v`, `fpga/Z80_goauld.sdc`, `fpga/tang9k.cst`, `fpga/build.tcl`.