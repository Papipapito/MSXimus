#!/bin/bash
# run_screen5d.sh — debug del negro: trazas tag/eco con carga minima.
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v
iverilog -g2012 -o /tmp/v9968_s5d.out -s tb_screen5d tb_screen5d.sv "$SHIM" "$CORE"/*.v
vvp /tmp/v9968_s5d.out
