#!/bin/bash
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v
iverilog -g2012 -o /tmp/s8p.out -s tb_screen8 tb_screen8.sv "$SHIM" "$CORE"/*.v
vvp /tmp/s8p.out 2>&1 | grep -E "MISS|COMPLETO" | head -50