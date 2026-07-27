#!/bin/bash
# VR de S#2 vs intr_frame (solo vdp_timing_control_ssg). Rapido.
# W se puede sobreescribir por entorno (para correr sobre una copia).
set -e
W=${UPFIX_W:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958}
cd /tmp && rm -rf tbupfixs2vr && mkdir tbupfixs2vr && cd tbupfixs2vr
iverilog -g2012 -o sim -s tb_upfix_s2vr \
  "$W/tools/v9968_sim/tb_upfix_s2vr.sv" \
  "$W/fpga/v9968/vdp_timing_control_ssg.v"
vvp sim
