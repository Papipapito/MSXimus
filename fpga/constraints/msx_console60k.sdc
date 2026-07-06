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
create_clock -name clk_27m  -period 37.040 [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT2}]
create_clock -name clk_135m -period 7.408  [get_pins {pll_main/u_pll/PLLA_inst/CLKOUT3}]

# ---- Reloj SPI del BL616 onboard (resuelve el hueco TA1132 del TN20K) ----
create_clock -name spi_sclk -period 50.000 [get_ports {spi_sclk}]
# El dominio SPI es asincrono respecto al arbol del PLLA (el companion cruza por
# sincronizadores propios):
set_clock_groups -asynchronous -group [get_clocks {spi_sclk}] \
    -group [get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m}]

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
