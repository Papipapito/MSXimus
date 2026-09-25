#!/bin/bash
# run_t2vpoke.sh — guiones en TEXT2 al escribir la tabla de nombres (25/09/2026).
# Uso (WSL Ubuntu-24.04): bash run_t2vpoke.sh [+GAP=250] [+FRAMES=6] [+LATMIN=26] [+LATRND=18] [+SEED=1]
# Compila contra el ARBOL REAL (fpga/src/v9968_vram_shim.v + fpga/v9968/*.v).
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
B=/tmp/tbt2vpoke
rm -rf "$B" && mkdir -p "$B" && cd "$B"
iverilog -g2012 -o sim -s tb_t2vpoke "$S/tb_t2vpoke.sv" "$R/fpga/src/v9968_vram_shim.v" "$R"/fpga/v9968/*.v 2>&1 | grep -v "warning: Port\|sorry: constant selects" | head -20
vvp sim "$@"
