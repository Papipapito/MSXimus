#!/bin/bash
# A/B bit a bit del magnificador: fase del Bresenham 0 (pre-_147) vs 64 (fix).
# Compila DOS copias de vdp_video_out.v y compara las 768 columnas nativas
# de cada familia de modo.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
SRC="$W/fpga/v9968"
COMMON="$SRC/vdp_upscan.v $SRC/vdp_upscan_line_buffer.v $SRC/vdp_video_out_bilinear.v $SRC/vdp_video_double_buffer.v $SRC/vdp_video_ram_line_buffer.v"

rm -rf /tmp/geomdiff && mkdir -p /tmp/geomdiff/old /tmp/geomdiff/new
sed 's/c_start_numerator = 8.d64/c_start_numerator = 8'"'"'d0/' "$SRC/vdp_video_out.v" > /tmp/geomdiff/vdp_video_out_old.v
grep -n "c_start_numerator = " /tmp/geomdiff/vdp_video_out_old.v

cd /tmp/geomdiff/old
iverilog -g2012 -o sim -s tb_geomfast "$W/tools/v9968_sim/tb_geomfast.sv" /tmp/geomdiff/vdp_video_out_old.v $COMMON
cd /tmp/geomdiff/new
iverilog -g2012 -o sim -s tb_geomfast "$W/tools/v9968_sim/tb_geomfast.sv" "$SRC/vdp_video_out.v" $COMMON

for M in 0 1 2 3; do
  (cd /tmp/geomdiff/old && vvp sim +MODE=$M > log.txt)
  (cd /tmp/geomdiff/new && vvp sim +MODE=$M > log.txt)
  if diff -q /tmp/geomdiff/old/cols_M$M.txt /tmp/geomdiff/new/cols_M$M.txt > /dev/null; then
    echo "MODE=$M : columnas nativas IDENTICAS (0 diferencias de 768)"
  else
    n=$(diff /tmp/geomdiff/old/cols_M$M.txt /tmp/geomdiff/new/cols_M$M.txt | grep -c '^<' || true)
    echo "MODE=$M : $n columnas nativas DIFERENTES de 768"
  fi
done
