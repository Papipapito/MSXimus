#!/bin/bash
# Banco del raton MSX. Uso (desde WSL Ubuntu-24.04): bash run_mouse.sh
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
B=/tmp/tbmouse; rm -rf "$B" && mkdir -p "$B" && cd "$B"
iverilog -g2012 -o sim -s tb_msx_mouse "$S/tb_msx_mouse.sv" "$R/fpga/src/msx_mouse.v"
vvp sim
