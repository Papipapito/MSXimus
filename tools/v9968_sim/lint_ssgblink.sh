#!/bin/bash
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf ssgb_lint && mkdir ssgb_lint && cd ssgb_lint
iverilog -g2012 -o sim -s tb_ssgblink \
  "$W/tools/v9968_sim/tb_ssgblink.sv" \
  "$W/fpga/v9968/vdp_timing_control_ssg.v"
echo COMPILA_OK
