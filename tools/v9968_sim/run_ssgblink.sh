#!/bin/bash
# Cadencia del blink del V9968 (solo vdp_timing_control_ssg). Rapido.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbssgblink && mkdir tbssgblink && cd tbssgblink
iverilog -g2012 -o sim -s tb_ssgblink \
  "$W/tools/v9968_sim/tb_ssgblink.sv" \
  "$W/fpga/v9968/vdp_timing_control_ssg.v"
for P in "${@:-0 17 16 1 34 68}"; do
  vvp sim +P=$P
done
