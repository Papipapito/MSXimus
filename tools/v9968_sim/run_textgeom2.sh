#!/bin/bash
# Igual que run_textgeom.sh pero en su propio directorio de trabajo, para poder
# correr un A/B (antes/despues) en paralelo sin pisarse los binarios.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
D=${TBDIR:-tbtextgeom2}
cd /tmp && rm -rf "$D" && mkdir "$D" && cd "$D"
iverilog -g2012 -o sim -s tb_textgeom \
  "$W/tools/v9968_sim/tb_textgeom.sv" \
  "$W/fpga/src/v9968_vram_shim.v" \
  "$W"/fpga/v9968/*.v
for M in ${@:-0 1 2}; do
  vvp sim +MODE=$M
done
