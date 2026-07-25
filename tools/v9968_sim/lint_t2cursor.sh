#!/bin/bash
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf t2c_lint && mkdir t2c_lint && cd t2c_lint
iverilog -g2012 -o sim -s tb_t2cursor \
  "$W/tools/v9968_sim/tb_t2cursor.sv" \
  "$W/fpga/src/v9968_vram_shim.v" \
  "$W"/fpga/v9968/*.v
echo COMPILA_OK
