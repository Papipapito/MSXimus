#!/bin/bash
# run_screen5e.sh — sprites ON con el shim: medir deadlines de fetch de sprite.
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v
iverilog -g2012 -o /tmp/v9968_s5e.out -s tb_screen5e tb_screen5e.sv "$SHIM" "$CORE"/*.v
vvp /tmp/v9968_s5e.out
