#!/bin/bash
# mkclones.sh — recrea los clones de build del MSXimus en un directorio
# de trabajo (tipicamente el scratchpad de la sesion). LECCION 2026-07-22:
# los scratchpads son POR SESION y el sistema los limpia — una ronda de
# builds murio a medias cuando el scratchpad viejo se evaporo debajo.
# Este script vive en el repo y reconstruye todo en 30 segundos.
#
# uso: bash mkclones.sh <destino> <dado_a> <dado_b> <dado_c> [v9968|ddr3|clasico]
#   v9968  = ENABLE_V9968_VDP (default)
#   ddr3   = V9968 + ENABLE_VRAM_DDR3 (experimento _128X)
#   clasico= sin defines (v9958)
set -e
DEST=${1:?destino}
DA=${2:?dado a}; DB=${3:?dado b}; DC=${4:?dado c}
MODE=${5:-v9968}
W="$(cd "$(dirname "$0")/.." && pwd)"
echo "fuente: $W  modo: $MODE  dados: $DA/$DB/$DC"
i=0
for D in $DA $DB $DC; do
    i=$((i+1)); C=$DEST/bx_c$i
    rm -rf "$C" && mkdir -p "$C" && cp -r "$W/fpga" "$C/fpga"
    rm -rf "$C/fpga/impl"
    if [ "$MODE" != "clasico" ]; then
        sed -i 's|^//`define ENABLE_V9968_VDP|`define ENABLE_V9968_VDP|' "$C/fpga/top.v"
        sed -i 's/^set USE_V9968 0/set USE_V9968 1/' "$C/fpga/build.tcl"
    fi
    if [ "$MODE" = "ddr3" ]; then
        sed -i 's|^//`define ENABLE_VRAM_DDR3|`define ENABLE_VRAM_DDR3|' "$C/fpga/top.v"
        sed -i 's/^set USE_VRAM_DDR3 0/set USE_VRAM_DDR3 1/' "$C/fpga/build.tcl"
    fi
    sed -i "s/PERIOD_MS = [0-9]*/PERIOD_MS = $D/" "$C/fpga/src/dbg_uart.v"
    echo "clon bx_c$i listo (dado $D)"
done
echo "lanzar: cd <clon>/fpga && gw_sh build.tcl  (gate: python check_timing.py"
echo "        + grep -ci error del log ANTES, y verificar mtime del informe)"
