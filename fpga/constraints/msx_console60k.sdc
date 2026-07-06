# ============================================================================
#  msx_console60k.sdc — Timing constraints · MSXnano port · Tang Console 60K
# ----------------------------------------------------------------------------
#  SKELETON. El SDC del TN20K (Z80_goauld.sdc) NO se copia: sus create_clock y
#  generated_clocks están anclados a nombres GW2A (rpll_inst/CLKOUT, O_sdram_clk)
#  y a la RED en vez del puerto (origen de fallos silenciosos, AUDIT §5.A3).
#
#  ⚠ Tras el 1er PnR en GW5A, VERIFICAR EN EL LOG que cada get_ports/get_pins/
#    get_nets casa >0 objetos. Un match vacío NO da error: pierde la constraint.
#
#  Los generated clocks (108/54/27/135) se anclan a los nombres de instancia del
#  PLLA/CLKDIV del GW5A, que aún no existen (IP por regenerar, docs/GW5A_IP.md).
#  Dejados como TODO hasta portar top.v + IP de reloj.
# ============================================================================

# ---- Reloj de ENTRADA: 50 MHz en V22 (¡NO 27!) ----
#  Confirmado por el .sdc de C64Nano (period 20 ns = 50 MHz). El net del top se
#  llama ex_clk_27m (engañoso) hasta que se renombre en el port.
create_clock -name clk_in -period 20.000 [get_ports {ex_clk_27m}]   ;# 50 MHz

# ---- Reloj SPI del BL616 onboard (dominio del companion) ----
#  Resuelve el hueco TA1132 del TN20K (mcu_spi_new.v:43/117): con el pin SPI
#  limpio del 60K, create_clock directo sobre spi_sclk (C64Nano usa period 50).
create_clock -name spi_sclk -period 50.000 [get_ports {spi_sclk}]
# spi_io_clk se declara como LOCAL_CLOCK en el .cst (reloj interno del mux SPI).

# ============================================================================
#  TODO (al portar top.v + regenerar la IP de reloj PLLA/CLKDIV):
# ============================================================================
# 1) generated clocks del árbol PLLA (sustituir <PLLA_INST> por el nombre real):
#    create_generated_clock -name clk_108m -source [get_ports {ex_clk_27m}] \
#        -master_clock clk_in [get_pins {<PLLA_INST>/CLKOUT0}]     ;# 108 MHz
#    create_generated_clock -name clk_54m  -source [get_pins {<PLLA_INST>/CLKOUT0}] \
#        -divide_by 2 [get_pins {<CLKDIV2_INST>/CLKOUT}]           ;# 54 MHz
#    create_generated_clock -name clk_27m  -source [get_pins {<PLLA_INST>/CLKOUT0}] \
#        -divide_by 4 [get_pins {<CLKDIV_INST>/CLKOUT}]            ;# 27 MHz
#    create_generated_clock -name clk_135m -source [get_ports {ex_clk_27m}] \
#        -master_clock clk_in [get_pins {<PLLA135_INST>/CLKOUT0}]  ;# 135 MHz TMDS
#    (Recomendado GW5A_IP §2/§4.4: generar 108/54/27 desde UNA sola PLLA de 7
#     salidas → garantiza alineación de fase de los cruces 27↔54 sin sync.)
#
# 2) generated clocks de vídeo (VideoDHClk ÷2 / VideoDLClk ÷4 de 27) que fasan
#    el secuenciador de memoria — re-anclar a los pines reales del port.
#
# 3) Reloj de usuario de la DDR3 IP (memory_clk / clk de usuario): declararlo y,
#    si es independiente del árbol PLLA, marcar los cruces al wrapper ram_*/vram_*
#    como frontera CDC (set_false_path / set_max_delay). Ver docs/MEMORY_CONTRACT.
#
# 4) set_false_path de los cruces asíncronos reales (companion SPI ↔ core, etc.).
#    NO copiar los false_path del SDC viejo: re-derivarlos con nombres GW5A.
