#!/bin/bash
# run_smoke.sh — F0 V9968: compila el core del repo clonado + tb_smoke y corre.
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/V9968_Cartridge/fpga/V9968_Cartridge_TangNano20K/src/v9968
iverilog -g2012 -o /tmp/v9968_smoke.out -s tb_smoke tb_smoke.sv "$CORE"/*.v
vvp /tmp/v9968_smoke.out
