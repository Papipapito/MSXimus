#!/bin/bash
# run_t2drop_vl.sh — tb_t2drop con VERILATOR (--timing), ~20x mas rapido que Icarus.
# Uso (WSL Ubuntu-24.04): bash run_t2drop_vl.sh [+PERFECT=0] [+WARM=3] [+FRAMES=1] [+TRACE=1] [+CPUFONT=1] ...
# Compila contra el ARBOL REAL (fpga/src/v9968_vram_shim.v + fpga/v9968/*.v), con SHIM_DBG_DROPS.
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
B=/tmp/vt2drop_$$
rm -rf "$B" && mkdir -p "$B" && cd "$B"
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK -Wno-WIDTH --top-module tb_t2drop -DSHIM_DBG_DROPS \
    "$S/tb_t2drop.sv" "$R/fpga/src/v9968_vram_shim.v" "$R"/fpga/v9968/*.v > verilate.log 2>&1 \
    || { grep -E '%Error' verilate.log | head -12; exit 1; }
./obj_dir/Vtb_t2drop "$@"
rm -rf "$B"
