#!/bin/bash
# run_spcol_vl.sh — tb_spcol (colision / 5S de sprites, la bateria de Fleet y DQ2) con VERILATOR (--timing): con
# Icarus la pila completa no acaba en 40 min por modo. Mismo patron que run_t2drop_vl.sh.
# Uso (WSL Ubuntu-24.04): bash run_spcol_vl.sh [dir_rtl_v9968]      (por defecto el ARBOL: fpga/v9968)
#   Corre +VMODE=2 (DQ2, sprites modo 1) y +VMODE=5 (Fleet, sprites modo 2).
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
RTL="${1:-$R/fpga/v9968}"
B=/tmp/vspcol_$$
rm -rf "$B" && mkdir -p "$B" && cd "$B"
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK -Wno-WIDTH --top-module tb_spcol \
    "$S/tb_spcol.sv" "$R/fpga/src/v9968_vram_shim.v" "$R/fpga/src/v9968_cpu_glue.v" "$RTL"/*.v > verilate.log 2>&1 \
    || { grep -E '%Error' verilate.log | head -12; exit 1; }
for V in 2 5; do
    echo "########## tb_spcol +VMODE=$V ($([ $V = 2 ] && echo 'DQ2, sprites modo 1' || echo 'Fleet, sprites modo 2')) RTL=$RTL"
    ./obj_dir/Vtb_spcol +VMODE=$V 2>&1 | grep -viE "^VCD|dumpfile" | tail -24
done
rm -rf "$B"
