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
# (sin clock_VideoD*: en este build dh/dl son señales de DATOS 108M-nativas,
#  ver nota abajo — sus "clocks" del SDC clasico no existen aqui)
set_clock_groups -asynchronous -group [get_clocks {clk_86}] -group [get_clocks {clk_in clk_108m clk_54m clk_27m clk_135m eng_clk375}] -group [get_clocks {clk27_video clk_hdmi clk_hdmi5}]

# _127I (bug #14): el reloj de fabric clk_audio YA NO EXISTE — el audio del
# puente V9968 corre con clock-enable (audio_ce) sincrono a clk_pixel. El
# create_clock clock_audio68 sobre clk_audio_s0/Q y su grupo asincrono quedan
# RETIRADOS (aquel FF era la CAUSA del bug: LOCAL_CLOCK => skew => CTS
# corrupto => el monitor re-enganchaba su PLL de audio cada ~3s). Todo el
# camino de audio se analiza ahora como logica normal del dominio clk_hdmi.

# NOTA dh/dl: en el build V9968 el divisor libre ÷8/÷16 vive EN clk_108m y
# dh/dl entran a mem1 como DATOS single-cycle del mismo dominio — no son
# relojes generados (Gowin ademas valida la derivacion y el assign se
# renombra en sintesis: la declaracion vieja da TA2003). El combinador de
# build.tcl RETIRA las declaraciones y referencias del SDC principal.
