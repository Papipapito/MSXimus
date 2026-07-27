#!/bin/bash
# Pila COMPLETA con la FASE ANTIGUA del Bresenham (c_start_numerator=0):
# reproduce la regresion _144 tal cual salio en HW, para el A/B del informe.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
SRC="$W/fpga/v9968"
rm -rf /tmp/tbtg_before && mkdir -p /tmp/tbtg_before/src
for f in "$SRC"/*.v; do cp "$f" /tmp/tbtg_before/src/; done
sed -i "s/c_start_numerator = 8'd64/c_start_numerator = 8'd0/" /tmp/tbtg_before/src/vdp_video_out.v
grep -n "c_start_numerator = " /tmp/tbtg_before/src/vdp_video_out.v
cd /tmp/tbtg_before
iverilog -g2012 -o sim -s tb_textgeom \
  "$W/tools/v9968_sim/tb_textgeom.sv" \
  "$W/fpga/src/v9968_vram_shim.v" \
  /tmp/tbtg_before/src/*.v
for M in ${@:-0 1 2}; do
  vvp sim +MODE=$M
done
