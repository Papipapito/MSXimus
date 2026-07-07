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
# clk_27m nace en el CLKDIV /5 del 135 (alineacion PCLK/FCLK del OSER10)
create_generated_clock -name clk_27m -source [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT3}] -master_clock clk_135m -divide_by 5 [get_pins {div5_video/CLKOUT}]

# ---- Relojes derivados/gated del diseño (intencion del SDC del TN20K) ----
# bus_reset_n y clk_audio clockean FFs propios (gated); VideoDH/DLClk (÷2/÷4 de
# 27) fasan el secuenciador de memoria.
create_clock -name clock_reset -period 277.778 [get_nets {bus_reset_n}] -add
create_clock -name clock_audio -period 277.778 [get_nets {vdp4/clk_audio}] -add
create_generated_clock -name clock_VideoDHClk -source [get_pins {div5_video/CLKOUT}] -master_clock clk_27m -divide_by 2 [get_nets {VideoDHClk}] -add
create_generated_clock -name clock_VideoDLClk -source [get_pins {div5_video/CLKOUT}] -master_clock clk_27m -divide_by 4 [get_nets {VideoDLClk}] -add

# ---- Reloj SPI del BL616 onboard (resuelve el hueco TA1132 del TN20K) ----
create_clock -name spi_sclk -period 50.000 [get_ports {spi_sclk}]
# Grupos asincronos: SPI del companion (handshake 2FF propio) y reset gated.
# NOTA: las false_path pin-a-pin del companion del SDC viejo quedan SUBSUMIDAS
# por este clock-group (el mux spi_ext del dock ya no existe). clock_audio se
# queda SIN agrupar (sincrono a 27, como en el TN20K; su unico path critico
# tiene false_path abajo).
set_clock_groups -asynchronous -group [get_clocks {spi_sclk}] -group [get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m clock_VideoDHClk clock_VideoDLClk}] -group [get_clocks {clock_reset}]

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
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/Regs/RegsL_RegsL*/DI*}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/Regs/?*?/?*}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/?*}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/?*?/CE}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/?*?/CE}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {cpu1/u0/Regs/RegsL_RegsL*/DI*}] -hold -end 2

# --- Dispositivos I/O cuasi-estaticos por protocolo de bus (~280 ns) ---
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {rtc1/u_mem/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {kanji1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {ocm_ports/?*?/CE}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {ocm_ports/?*?/D}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {psg1/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {psg2/?*?/?*}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {opll/?*?/?*?/CE}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {uwifi/wait_o*/CE}]
set_false_path -from [get_clocks {clk_54m}] -to [get_pins {uwifi/my_tx_state*/CE}]

# --- Sprite engine del VDP: cruce 108->27 protegido por fase (dh/dl) ---
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/SPRENDERPLANES*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST*/CE}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST*/D}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/D}]
set_false_path -from [get_clocks {clk_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/CE}]

# --- HDMI audio packet (transferencia con handshake propio) ---
set_false_path -from [get_clocks {clk_27m}] -to [get_pins {vdp4/hdmi_ntsc/true_hdmi_output.packet_picker/audio_sample_word_transfer?*?/D}]

# --- Presupuestos de cruce con disciplina de fase (del TN20K) ---
# cpu_din: 18.2 en el TN20K (guia de PnR para su congestion). El requisito real
# es el protocolo del bus Z80 (3.58MHz + waits, cientos de ns); en GW5A el
# placement del T80 varia y 18.2 fallaba por ~0.3ns -> 27.0 (1.5 periodos).
set_max_delay -from [get_clocks {clk_54m}] -to [get_pins {cpu_din_*/D}] 27.0
set_max_delay -from [get_pins {mem1/vram_dout_*/Q}] -to [get_clocks {clk_27m}] 10.5

# --- SD: registros de comando/sector cuasi-estaticos ---
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/D}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_sector_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_sector_*/CE}] -hold -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clk_54m}] -to [get_pins {ff_sd_cd_*/CE}] -hold -end 2

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
