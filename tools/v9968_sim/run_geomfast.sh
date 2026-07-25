#!/bin/bash
# Geometria horizontal por familia de modo (rapido: upscan real -> video_out real).
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbgeomfast && mkdir tbgeomfast && cd tbgeomfast
iverilog -g2012 -o sim -s tb_geomfast \
  "$W/tools/v9968_sim/tb_geomfast.sv" \
  "$W/fpga/v9968/vdp_upscan.v" \
  "$W/fpga/v9968/vdp_upscan_line_buffer.v" \
  "$W/fpga/v9968/vdp_video_out.v" \
  "$W/fpga/v9968/vdp_video_out_bilinear.v" \
  "$W/fpga/v9968/vdp_video_double_buffer.v" \
  "$W/fpga/v9968/vdp_video_ram_line_buffer.v"
for M in ${@:-0 1 2 3}; do
  vvp sim +MODE=$M
done
