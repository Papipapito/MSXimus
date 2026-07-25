#!/bin/bash
# A/B CONTROLADO de la pila COMPLETA (vdp.v + shim + backend): la UNICA
# diferencia entre las dos compilaciones es c_active_start
#   731 = _143/_144/_146 (lo que hay en HW ahora)
#   729 = fix _147
# Cada corrida analiza LAS DOS fases posibles de captura del ring (ce86).
# Las fuentes se copian al FS de Linux para evitar el cache de DrvFs.
# Uso: run_textgeom_ab.sh [modos...]   (por defecto 0 1 2)
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
SRC="$W/fpga/v9968"
MODES=${@:-0 1 2}

rm -rf /tmp/tbab && mkdir -p /tmp/tbab/src731 /tmp/tbab/src729 /tmp/tbab/run731 /tmp/tbab/run729
cp "$SRC"/*.v /tmp/tbab/src731/
cp "$SRC"/*.v /tmp/tbab/src729/
cp "$W/fpga/src/v9968_vram_shim.v" /tmp/tbab/
cp "$W/tools/v9968_sim/tb_textgeom.sv" /tmp/tbab/
sed -i "s/c_active_start = 12'd[0-9]*/c_active_start = 12'd731/" /tmp/tbab/src731/vdp_video_out.v
sed -i "s/c_active_start = 12'd[0-9]*/c_active_start = 12'd729/" /tmp/tbab/src729/vdp_video_out.v
for A in 731 729; do
  echo "src$A: $(grep -o "c_active_start = 12'd[0-9]*" /tmp/tbab/src$A/vdp_video_out.v)  $(grep -o "c_start_numerator = 8'd[0-9]*" /tmp/tbab/src$A/vdp_video_out.v)"
  (cd /tmp/tbab/run$A && iverilog -g2012 -o sim -s tb_textgeom /tmp/tbab/tb_textgeom.sv \
      /tmp/tbab/v9968_vram_shim.v /tmp/tbab/src$A/*.v)
done

for M in $MODES; do
  for A in 731 729; do
    echo "######## c_active_start=$A  MODE=$M ########"
    (cd /tmp/tbab/run$A && vvp sim +MODE=$M | grep -v "finish called")
  done
done
