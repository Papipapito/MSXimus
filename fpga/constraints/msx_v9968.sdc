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

# clk_audio del puente V9968 (divisor a 44.1 kHz, FF clk_audio_s0 en dominio
# clk_hdmi; el handshake del packet_picker de hdl-util es tolerante a fase =
# mismo caso que el clasico). El get_nets del estilo clasico dio match vacio
# aqui (TA2003); el PIN del FF SI casa (verificado VERBATIM en el informe de
# timing del PnR _117: u_msx2hdmi68/clk_audio_s0/Q).
# El CLOCK_LOC LOCAL_CLOCK del .cst (leccion _45) se parchea via sed del clon.
create_clock -name clock_audio68 -period 22675.737 [get_pins {u_msx2hdmi68/clk_audio_s0/Q}] -add
set_clock_groups -asynchronous -group [get_clocks {clock_audio68}] -group [get_clocks {clk27_video clk_hdmi clk_hdmi5}]

# NOTA dh/dl: en el build V9968 el divisor libre ÷8/÷16 vive EN clk_108m y
# dh/dl entran a mem1 como DATOS single-cycle del mismo dominio — no son
# relojes generados (Gowin ademas valida la derivacion y el assign se
# renombra en sintesis: la declaracion vieja da TA2003). El combinador de
# build.tcl RETIRA las declaraciones y referencias del SDC principal.
