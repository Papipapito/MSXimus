# ============================================================================
#  msx_v9968.sdc — constraints EXTRA del build V9968 (ENABLE_V9968_VDP).
#  build.tcl lo añade SOLO con USE_V9968=1 (un create_clock con match vacio
#  podria romper el parse del build clasico). Complementa msx_console60k.sdc.
#
#  ⚠ Tras el PnR, verificar matches>0 de TODAS estas lineas (disciplina SDC).
# ============================================================================

# clk_86 = 27 x 35/11 = 85.909090 MHz (pll_86 en cascada de clk27_video;
# periodo declarado 11.640 = ligeramente MAS estricto que el real 11.6402).
create_clock -name clk_86 -period 11.640 [get_pins {pll86_vdp/PLLA_inst/CLKOUT0}]

# Dominio ASINCRONO a todo por construccion:
#  - bridge 85.9<->108: toggles req/ack con 2FF, datos cuasi-estaticos
#  - glue 54->85.9: cs con 2FF, addr/dato cuasi-estaticos (protocolo Z80)
#  - msx2hdmi_v9968 85.9<->74.25: ring BRAM dual-clock + toggles 2FF + audio 2FF
set_clock_groups -asynchronous -group [get_clocks {clk_86}] -group [get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m clock_VideoDHClk clock_VideoDLClk eng_clk375}] -group [get_clocks {clk27_video clk_hdmi clk_hdmi5}]

# clk_audio del puente V9968 (mismo caso que el clock_audio del vdp4: divisor
# a 44.1 kHz dentro del puente, handshake propio del packet_picker)
create_clock -name clock_audio68 -period 22675.737 [get_nets {u_msx2hdmi68/clk_audio}] -add
set_clock_groups -asynchronous -group [get_clocks {clock_audio68}] -group [get_clocks {clk_hdmi clk_hdmi5}]

# NOTA dh/dl: el divisor libre ÷8/÷16 de clk_108m da EXACTAMENTE 13.5/6.75 MHz
# = los mismos periodos que los generated clocks del SDC principal (÷2/÷4 de
# 27) — siguen validos; ademas dh/dl pasan a ser 108-nativos (paths ordinarios
# single-cycle, MAS estrictos que el cruce 27->108 del build clasico).
