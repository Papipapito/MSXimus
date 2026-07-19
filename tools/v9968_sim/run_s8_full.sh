#!/bin/bash
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SRC=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src
TBM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/sdr16_tb
iverilog -g2012 -o /tmp/s8full.out -s tb_screen8_full tb_screen8_full.sv \
  "$SRC/v9968_vram_shim.v" "$SRC/v9968_sdram_bridge.v" "$SRC/memory.v" \
  "$TBM/w9825_model.v" "$CORE"/*.v
echo COMPILA_OK
vvp /tmp/s8full.out 2>&1 | grep -E "LAT|TURNOS|MISS|FRAME|VRAM|init|FIN|TIMEOUT" | head -30