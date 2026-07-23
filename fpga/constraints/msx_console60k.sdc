# ============================================================================
#  msx_console60k.sdc — Timing constraints · MSXnano port · Tang Console 60K
# ----------------------------------------------------------------------------
#  El SDC del TN20K NO se copia (nombres GW2A, red-vs-puerto: fallos silenciosos,
#  AUDIT §5.A3). Este es el SDC nuevo, minimo y correcto para el primer bring-up.
#
#  ⚠ Tras CADA PnR, VERIFICAR EN EL LOG que cada get_ports/get_pins casa >0
#    objetos. Un match vacio NO da error: pierde la constraint.
#
#  Relojes: un unico PLLA (pll_main/u_pll/PLLA_inst) con VCO 1350 MHz y 4
#  salidas de divisor entero/fraccional: 108 / 54 / 27 / 135, todas alineadas
#  (PE=0, mismo VCO). Los periodos de abajo usan RATIOS EXACTOS entre si
#  (hiperperiodo 74.08 ns) para que la STA modele la alineacion de fase:
#  cruces 27<->54 registro-a-registro seguros como en el TN20K.
# ============================================================================

# ---- Reloj de ENTRADA: 50 MHz en V22 (el net conserva el nombre del TN20K) ----
create_clock -name clk_in -period 20.000 [get_ports {ex_clk_27m}]

# ---- Salidas del PLLA (ratios exactos: 9.26*2=18.52, *4=37.04, 37.04/5=7.408) ----
create_clock -name clk_108m -period 9.260  [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT0}]
create_clock -name clk_54m  -period 18.520 [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT1}]
create_clock -name clk_135m -period 7.408  [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT3}]
# v3.0: clk_27m del PLLA (CLKOUT2) — fase CONOCIDA vs 54/108 (mismo VCO, como
# el rPLL del TN20K). El CLKDIV desaparecio con el video 720p: ya no hay OSER10
# a 27M. La STA asume flancos alineados en t=0 entre los base clocks del PLLA,
# que es la realidad fisica tras el lock de PLL_INIT (disciplina TN20K).
create_clock -name clk_27m -period 37.040 [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT2}]

# ---- v3.0 relojes de VIDEO 720p (cascada monitorcore, dominio propio) ----
create_clock -name clk27_video -period 37.037 [get_pins {pll27_video/PLLA_inst/CLKOUT0}]
create_clock -name clk_hdmi    -period 13.468 [get_pins {pll74_video/PLLA_inst/CLKOUT0}]
create_clock -name clk_hdmi5   -period  2.694 [get_pins {pll74_video/PLLA_inst/CLKOUT1}]

# ---- F3 (_39): reloj del soft-host USB (teclado USB-A directo) ----
create_clock -name clk_usb12 -period 83.333 [get_pins {pll12_usb/PLLA_inst/CLKOUT0}]

# ---- F1 V9968: las constraints del dominio clk_86 viven en un SDC APARTE
# (constraints/msx_v9968.sdc) que build.tcl solo añade con USE_V9968=1 —
# un create_clock con match vacio podria romper el parse del build clasico.
# En el build V9968, las lineas vdp4/* de ESTE fichero dan match vacio
# (warning esperado; verificar la lista por build como siempre).

# ---- F2 (_84): el OPL3 corre en clk_27m (PLLA principal, mismo grupo que
# clk_54m) -> el cruce del host_if queda CRONOMETRADO por el STA. El reloj
# dedicado de la _82/_83 (pll_opl3 a 33.75) se elimino.

# ---- _104: reloj del motor PCM OPL4 = 37.5 MHz (CLKOUT4 del PLLA, VCO/36,
# PE=0 -> flancos alineados en t=0 con 27/54/108/135). La wave vive en la
# SDRAM del dock; la DDR3 del SOM queda FUERA (analogicamente marginal en
# esta placa). Todo en la MISMA familia: cruces cronometrados, cero CDC.
# Periodo exacto: 1350/36 = 37.5 -> 26.667ns (26.66666... redondeado abajo
# = conservador). CE del motor: 14112/15625 = 33.8688 MHz exactos.
create_clock -name eng_clk375 -period 26.666 [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT4}]

# ---- Relojes derivados/gated del diseño (intencion del SDC del TN20K) ----
# bus_reset_n y clk_audio clockean FFs propios (gated); VideoDH/DLClk (÷2/÷4 de
# 27) fasan el secuenciador de memoria.
create_clock -name clock_reset -period 277.778 [get_nets {bus_reset_n}] -add
# v3.0 VIDEO720 / _127I: el clk_audio de fabric YA NO EXISTE — el audio del
# puente corre con clock-enable sincrono a clk_pixel (fix del bug #14: el
# reloj de fabric con LOCAL_CLOCK tenia skew sin garantias => CTS corrupto).
# El create_clock clock_audio y su grupo asincrono quedan RETIRADOS.
create_generated_clock -name clock_VideoDHClk -source [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT2}] -master_clock clk_27m -divide_by 2 [get_nets {VideoDHClk}] -add
create_generated_clock -name clock_VideoDLClk -source [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT2}] -master_clock clk_27m -divide_by 4 [get_nets {VideoDLClk}] -add

# ---- Reloj SPI del BL616 onboard (resuelve el hueco TA1132 del TN20K) ----
create_clock -name spi_sclk -period 50.000 [get_ports {spi_sclk}]
# Grupos asincronos: SPI del companion (handshake 2FF propio) y reset gated.
# NOTA: las false_path pin-a-pin del companion del SDC viejo quedan SUBSUMIDAS
# por este clock-group (el mux spi_ext del dock ya no existe). clock_audio se
# queda SIN agrupar (sincrono a 27, como en el TN20K; su unico path critico
# tiene false_path abajo).
set_clock_groups -asynchronous -group [get_clocks {spi_sclk}] -group [get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m clock_VideoDHClk clock_VideoDLClk eng_clk375}] -group [get_clocks {clock_reset}] -group [get_clocks {clk27_video clk_hdmi clk_hdmi5}] -group [get_clocks {clk_usb12}]
# v3.0: el grupo de video 720p es ASINCRONO al arbol del MSX por construccion:
# los unicos cruces son la BRAM dual-clock del ring, los toggles 2FF y el audio
# 2FF de msx2hdmi (patron smstang/486tang).

# ============================================================================
#  EXCEPCIONES portadas del Z80_goauld.sdc del TN20K (misma justificacion de
#  diseño; nombres de instancia verificados supervivientes). Descartado lo
#  obsoleto: spi_ext (mux eliminado), clock_env_reset/env_reset2 y los
#  false_path 27->psg (el fix #2 hizo SINCRONA la carga del envelope del
#  YM2149: ya no hay gated clock), lineas debug.
# ============================================================================

# --- Z80 (T80 con wait-states; bus efectivo 3.58 MHz): multicycle x2 en 54 ---
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/Regs/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/CE}] -setup -end 2
# _139 (Gowin 1.9.12): linea RegsL_RegsL*/DI* RETIRADA — la sintesis nueva
# ya no infiere el banco de registros del T80 como SSRAM (va en fabric,
# cubierto por los patrones cpu1/u0/Regs/?*?/?* de arriba); el match vacio
# era ERROR TA2003 en el PnR 1.9.12.
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/Regs/?*?/?*}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/?*}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/CE}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/CE}] -hold -end 2
# (idem -hold, retirada en _139)

# --- P1b-por-constraint (_70): salidas del Z80 -> FSMs de memoria/wait ---
# Espejo de las excepciones -to cpu1 de arriba: las SALIDAS del T80 (RD/WR/
# IORQ samplers y estado) solo cambian en flancos HABILITADOS (3.58/5.37
# efectivos = >=5 ciclos de 54M entre cambios) y sus consumidores (wait FSM,
# mem1) son FSMs de NIVEL tolerantes a +1 ciclo de propagacion (medidas T9 de
# tools/sdr16_tb: engage peor ~190ns de ~280ns de presupuesto; a 3.58 sobran
# >150ns). Era la familia cronica de -0.2/-0.3 en cada re-roll (RD_s0 ->
# ram_busy_s0 / state_wait / wait_io_ff, medio ciclo F->R para ~10 niveles).
# ACOTADA por origen Y destino: ram_busy y demas señales full-rate que entran
# a esos mismos CEs mantienen su restriccion de ciclo completo.
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {mem1/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {mem1/?*?/CE}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {state_wait*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {state_wait*/CE}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {wait_io_ff*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {wait_io_ff*/CE}] -hold -end 2
# (_71: la misma familia puede aterrizar en los pines D de esos FSMs segun el
#  roll — p.ej. RD_s0 -> mem1/sdram_seq_*/D. Identico argumento, mismos limites.)
# (_73: y el ORIGEN puede ser un pin DO de la SSRAM interna del T80 (IStatus
#  etc.), que el patron /Q no cubre. Mismo argumento: estado del Z80, cambia
#  solo en flancos habilitados.)
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {mem1/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {mem1/?*?/CE}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {mem1/?*?/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {mem1/?*?/D}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {state_wait*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {state_wait*/CE}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {state_wait*/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {state_wait*/D}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {wait_io_ff*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {wait_io_ff*/CE}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {wait_io_ff*/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/u0/IStatus*/DO*}] -to [get_pins {wait_io_ff*/D}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {mem1/?*?/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {mem1/?*?/D}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {state_wait*/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {state_wait*/D}] -hold -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {wait_io_ff*/D}] -setup -end 2
set_multicycle_path -from [get_pins {cpu1/?*?/Q}] -to [get_pins {wait_io_ff*/D}] -hold -end 2

# --- Dispositivos I/O cuasi-estaticos por protocolo de bus (~280 ns) ---
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {rtc1/u_mem/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {kanji1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {ocm_ports/?*?/CE}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {ocm_ports/?*?/D}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {psg1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {psg2/?*?/?*}]
# v3.4 (_44): chips SCC de vuelta a 27M (config TN20K, fase alineada v3.0) —
# misma clase cuasi-estatica por protocolo de bus que rtc/kanji/psg
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {SccCh/?*?/?*}]
# v4.2 (_57): SccCh2 RESTAURADO (F3.5) -> excepcion de vuelta (misma clase que SccCh)
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {SccCh2/?*?/?*}]
# v3.0 BASE MINIMA: sn1 fuera del netlist -> excepcion retirada
# set_false_path -from [get_clocks {clk_54m}] -to [get_pins {sn1/?*?/?*}]
# F3 (_38): OPLL de vuelta A 54M+cen (mismo dominio que el bus) -> la
# excepcion 54->27 ya no aplica; sin excepciones: timing real y estricto.
# set_false_path -from [get_clocks {clk_54m}] -to [get_pins {opll/?*?/?*?/CE}]
# set_false_path -from [get_clocks {clk_54m}] -to [get_pins {uwifi/wait_o*/CE}]
# set_false_path -from [get_clocks {clk_54m}] -to [get_pins {uwifi/my_tx_state*/CE}]

# --- Sprite engine del VDP: cruce 108->27 protegido por fase (dh/dl) ---
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/SPRENDERPLANES*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST*/D}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/D}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/CE}]

# --- HDMI audio packet (transferencia con handshake propio) ---
# v3.0 VIDEO720: el audio cruza 54M->74.25 dentro de msx2hdmi (grupo asincrono) -> retirada
# set_false_path -from [get_clocks {clk_27m}] -to [get_pins {vdp4/hdmi_ntsc/...audio_sample_word_transfer.../D}]

# --- Presupuestos de cruce con disciplina de fase (del TN20K) ---
# ⚠️ LECCION (F11/turbo 60K): los caminos strobes del Z80 -> FSM de waits y
# secuenciador de memoria DEBEN cumplir su timing de diseño (medio periodo
# F->R / un periodo R->R). Las relajaciones 18.0/27.0 que hubo aqui dejaban
# al router servirlos a ~13.7ns = el FSM veia el strobe UN CICLO TARDE: a
# 3.58 MHz lo absorben los waits adaptativos, con turbo 5.37 (F11) CUELGA.
# El TN20K cerraba estos caminos SIN excepciones: aqui igual — si una pasada
# de PnR no cierra (-0.3..-1.4ns de loteria), se itera el placement, NO se
# relaja la constraint.
# EXCEPCIONES QUIRURGICAS (clases seguras a turbo, distintas de los strobes):
# - IStatus (T80) = estado POR-INSTRUCCION (EI/DI/IM), no un strobe de bus:
#   estable ordenes de magnitud mas que un ciclo; su mux hacia addr/seq del
#   secuenciador tolera +1 ciclo sin ambiguedad (mismo valor).
# - uwifi/qckbase_cnt = prescaler de baudios (859372 bps, bit de 1.16us):
#   +18ns de jitter en el CE es ruido; ademas el ESP no tiene pines en el 60K.
# GENERALIZADA (la loteria fue mutando el lanzador: IStatus -> ISet -> ...):
# TODO el estado por-instruccion del NUCLEO T80 (cpu1/u0/*: PC/IR/IStatus/
# ISet/registros) hacia secuenciador y waits es cuasi-estatico por protocolo
# de bus. Los STROBES (RD_s0/WR_n_i_s0) viven en el wrapper cpu1/ (no u0/)
# y quedan FUERA de esta excepcion: rigor completo (leccion F11).
set_max_delay -from [get_pins {cpu1/u0/?*?/?*}] -to [get_pins {mem1/sdram_seq*/*}] 27.0
set_max_delay -from [get_pins {cpu1/u0/?*?/?*}] -to [get_pins {mem1/sdram_addr*/*}] 27.0
# ram_busy = patron FRAGIL, RETIRADO (leccion: TA2003 tres veces — la loteria
# del netlist lo renombra/fusiona segun seed, y el parser SDC de Gowin no
# soporta catch). Sus paths van a timing por defecto (18.52ns, MAS estricto);
# si algun dia no cierran, check_timing.py dara el nombre real del FF y se
# constriñe ESE. NUNCA re-anclar por 'ram_busy*'.
# set_max_delay -from [get_pins {cpu1/u0/?*?/?*}] -to [get_pins {mem1/ram_busy*/*}] 27.0
set_max_delay -from [get_pins {cpu1/u0/?*?/?*}] -to [get_pins {state_wait_*/*}] 27.0
set_max_delay -from [get_pins {cpu1/u0/?*?/?*}] -to [get_pins {wait_io_ff*/*}] 27.0
# v3.0 BASE MINIMA: uwifi fuera -> excepcion retirada
# set_false_path -from [get_pins {cpu1/IORQ_n_i_s0/Q}] -to [get_pins {uwifi/qckbase_cnt*/CE}]
# cpu_din: 18.2 en el TN20K (guia de PnR para su congestion). El requisito real
# es el protocolo del bus Z80 (3.58MHz + waits, cientos de ns); en GW5A el
# placement del T80 varia y 18.2 fallaba por ~0.3ns -> 27.0 (1.5 periodos).
set_max_delay -from [get_clocks {clk_54m}] -to [get_pins {cpu_din_*/D}] 27.0
# _102: 10.5 -> 18.0. El 10.5 era una conjetura sin justificar del bring-up
# (1 periodo de 108M + skew). GEOMETRIA REAL del slot: vram_dout se latchea
# en las fases 5-6 del burst de 8 fases de 108M (46-56ns tras el inicio del
# slot, alineado a dhclk del dominio 27M); el flanco de 27M mas cercano
# posible queda a >=18.5ns (fase 6) y el consumo real del VDP (estado de
# puntos) llega >=1 ciclo completo (37ns) despues. 18.0 sigue siendo MAS
# estricto que el peor caso fisico. Con 10.5, la familia fallaba -0.2..-2.3
# en 15 tiradas de placement (la unica familia negativa tras curar el TMDS).
set_max_delay -from [get_pins {mem1/vram_dout_*/Q}] -to [get_clocks {clk_27m}] 18.0

# --- v3.0: OSER10 con RESET=0 fijo (nestang/z8086) ---
# La false_path antigua s1_n->gwSer*/RESET se ELIMINA: los OSER10 ya no
# reciben reset de fabric (serializer.sv). El realineado 1:5 lo provoca el
# reset del CLKDIV (div5_video), gated por el lock filtrado de PLL_INIT.
# lock_s135 es un sincronizador 2FF: clock_locked (dominio mdclk 50M del
# PLL_INIT) -> dominio 135M. Cruce asincrono por construccion.
# v3.0: lock_s135 eliminado con el CLKDIV -> retirada
# set_false_path -to [get_pins {lock_s135_0_*/D}]

# --- SD: registros de comando/sector cuasi-estaticos ---
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_sector_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_sector_*/CE}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/CE}] -hold -end 2

# ============================================================================
# _102: vram_dout (latch VDP en mem1, clk_108m) -> consumidores internos del
# VDP (clk_27m). MULTICICLO REAL: el dato se latchea en las fases 5-6 del
# burst de 8 fases de 108M dentro del slot de video y el VDP lo consume en
# su ESTADO DE PUNTOS, >=1 ciclo completo de 27M (37ns) despues — la ventana
# single-cycle de 10.5ns que asumia el STA es ficticia. Con MCP=2 reclamamos
# 21ns de los >=37 reales (margen 16ns). Evidencia: 15 tiradas de placement
# fallaron -0.2..-2.3 con el analisis conservador; la familia entrego -0.008
# (_90) y +0.1 (_97) con CERO artefactos de sprites en decenas de horas de
# HW (Solid Snake incluido). El hold queda en el flanco original (recipe
# estandar setup=2/hold=1). SOLO lecturas: el invariante MG2 (escrituras
# VDP comprometidas) no se toca.
# ============================================================================
#  TODO (iterar tras el primer PnR, con el netlist real delante):
#   1) generated clocks de video del VDP (VideoDHClk/VideoDLClk, ÷2/÷4 de 27):
#      re-derivar sobre los pines reales del netlist GW5A (el SDC viejo los
#      declaraba sobre nombres GW2A). Fasan el secuenciador de memoria.
#   2) constraint del reloj SDRAM reenviado (O_sdram_clk por GPIO B17, 108 MHz):
#      set_output_delay de addr/dq/dqm/cmd referidos a ese reloj + compensacion
#      de skew del modulo externo. EL PUNTO DELICADO del SDR externo.
#   3) false_paths reales (config estatica, LEDs, ws2812) — NO copiar los viejos.
#   4) cruce megaram 27MHz->controlador (AUDIT §5.B megaram) si aplica.
# ============================================================================

# (v2.3: clk27_align eliminado)
