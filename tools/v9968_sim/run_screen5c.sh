#!/bin/bash
# run_screen5c.sh — F1a: SCREEN5 con core PARCHEADO (tag+eco) + v9968_vram_shim
# + backend con latencia de SDRAM compartida (300-500ns aleatoria).
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v
iverilog -g2012 -o /tmp/v9968_s5c.out -s tb_screen5c tb_screen5c.sv "$SHIM" "$CORE"/*.v
vvp /tmp/v9968_s5c.out
