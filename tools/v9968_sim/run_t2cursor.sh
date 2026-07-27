#!/bin/bash
# Cursor + blink de TEXT2 (SCREEN 0 W80) con la pila completa. ~12 min.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbt2cursor && mkdir tbt2cursor && cd tbt2cursor
iverilog -g2012 -o sim -s tb_t2cursor \
  "$W/tools/v9968_sim/tb_t2cursor.sv" \
  "$W/fpga/src/v9968_vram_shim.v" \
  "$W"/fpga/v9968/*.v
vvp sim
