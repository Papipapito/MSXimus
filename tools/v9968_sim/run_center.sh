#!/bin/bash
# Build + run tb_center (V9968 magnifier centering check) under iverilog.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbcenter && mkdir tbcenter && cd tbcenter
iverilog -g2012 -o sim \
  "$W/fpga/v9968/tb_center.sv" \
  "$W/fpga/v9968/vdp_upscan.v" \
  "$W/fpga/v9968/vdp_upscan_line_buffer.v" \
  "$W/fpga/v9968/vdp_video_out.v" \
  "$W/fpga/v9968/vdp_video_out_bilinear.v" \
  "$W/fpga/v9968/vdp_video_double_buffer.v" \
  "$W/fpga/v9968/vdp_video_ram_line_buffer.v"
for A in "$@"; do
  echo "############ ADJ=$A ############"
  vvp sim +ADJ=$A
done
