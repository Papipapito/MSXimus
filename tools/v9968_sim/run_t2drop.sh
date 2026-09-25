#!/bin/bash
# run_t2drop.sh — guiones en TEXT2 al escribir la tabla de nombres: ¿core o shim? (25/09/2026)
# Uso (WSL): [DBG=1] bash run_t2drop.sh [+PERFECT=1|0] [+GAP=250] [+FRAMES=4] [+WARM=4] [+NOWR=1] [+CPUFONT=1] [+CPUALL=1] [+TRACE=1|2]
# DBG=1 compila con SHIM_DBG_DROPS (BGMISS/DROP del propio shim). Icarus tarda ~16 min por cuadro:
# para iterar usar run_t2drop_vl.sh (Verilator, ~30 s), este queda como contraste.
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
B=/tmp/tbt2drop_$$
rm -rf "$B" && mkdir -p "$B" && cd "$B"
iverilog -g2012 ${DBG:+-DSHIM_DBG_DROPS} -o sim -s tb_t2drop "$S/tb_t2drop.sv" "$R/fpga/src/v9968_vram_shim.v" "$R"/fpga/v9968/*.v 2>&1 | grep -v "warning: Port\|sorry: constant selects" | head -20
vvp sim "$@"
rm -rf "$B"
