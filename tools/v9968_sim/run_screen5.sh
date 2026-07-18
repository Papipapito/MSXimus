#!/bin/bash
# run_screen5.sh — F0 V9968: render SCREEN5 con contenido + volcado a frame.
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/V9968_Cartridge/fpga/V9968_Cartridge_TangNano20K/src/v9968
iverilog -g2012 -o /tmp/v9968_s5.out -s tb_screen5 tb_screen5.sv "$CORE"/*.v
vvp /tmp/v9968_s5.out
