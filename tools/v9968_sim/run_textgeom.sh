#!/bin/bash
# Geometria horizontal por modo del V9968 (SCREEN1 / TEXT1 / TEXT2).
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbtextgeom && mkdir tbtextgeom && cd tbtextgeom
iverilog -g2012 -o sim -s tb_textgeom \
  "$W/tools/v9968_sim/tb_textgeom.sv" \
  "$W/fpga/src/v9968_vram_shim.v" \
  "$W"/fpga/v9968/*.v
for M in "${@:-0 1 2}"; do
  vvp sim +MODE=$M
done
