#!/bin/bash
# Banco del OSD con color (V3.8). Lo lanza check.py; a mano, desde Windows:
#   wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up_v3_port/tools/osd_tb && bash run.sh <N>"
# donde N es el numero de bytes de cmds.hex.
set -e
cd "$(dirname "$0")"
SRC=../../fpga/src/iosys
SIMLIB=/mnt/c/Gowin/Gowin_V1.9.12.03_x64/IDE/simlib/gw5a/prim_sim.v
iverilog -g2012 -o tb_osd.vvp -s tb_osd tb_osd.sv $SRC/iosys_bl616.v $SRC/textdisp.v $SRC/uart_fixed.v \
    $SRC/gowin_dpb_menu.v $SRC/osd_paleta.v $SIMLIB 2>&1 | grep -v -i "warning" || true
vvp -n tb_osd.vvp +N=$1
