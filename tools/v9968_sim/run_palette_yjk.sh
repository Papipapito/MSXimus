#!/bin/bash
# run_palette_yjk.sh - tb_palette_yjk.sv (vdp_color_palette.v a solas: SCREEN 8 / 10-11 / 12 contra un modelo del libro del V9958).
# Uso (WSL): bash run_palette_yjk.sh [dir con vdp_color_palette.v y vdp_color_palette_ram.v]   (por defecto fpga/v9968 de este repo)
# Con el RTL anterior a bee8f7e de HRA (01/11/2026) las filas con A = 1 de SCREEN 10/11 FALLAN; con el actual, TB_OK.
S="$(cd "$(dirname "$0")" && pwd)"
R="${1:-$S/../../fpga/v9968}"
B=/tmp/palyjk_$$; mkdir -p "$B"
iverilog -g2012 -o "$B/t.vvp" "$S/tb_palette_yjk.sv" "$R/vdp_color_palette.v" "$R/vdp_color_palette_ram.v" || exit 1
vvp -n "$B/t.vvp" | grep -vE "^VCD|dumpfile" | tee "$B/out.log"
grep -q TB_OK "$B/out.log"; E=$?
rm -rf "$B"
exit $E
