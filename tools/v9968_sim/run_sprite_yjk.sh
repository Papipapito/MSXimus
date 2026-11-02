#!/bin/bash
# run_sprite_yjk.sh - tb_sprite_yjk_vdp.sv: sprites en SCREEN 10/11/12 con el VDP completo (generador de sprites y de modos reales)
# frente a SCREEN 8 (referencia de alineacion). Un frame por modo; analiza_sprite_yjk.py compara.
# Uso (WSL): bash run_sprite_yjk.sh [dir con fpga/v9968]      (por defecto, el de este repo; otro dir = A/B con el RTL anterior)
# KEEP=1 conserva los volcados (sprite_8.txt, sprite_11.txt, sprite_12.txt). Verilator: ~1,5 min (Icarus tarda unos 15, mismo resultado).
S="$(cd "$(dirname "$0")" && pwd)"
R="${1:-$S/../../fpga/v9968}"
B=/tmp/spryjk_$$; mkdir -p "$B"
cd "$B"
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK -Wno-WIDTH --top-module tb_sprite_yjk_vdp \
    "$S/tb_sprite_yjk_vdp.sv" "$R"/*.v > verilate.log 2>&1 || { grep -E '%Error' verilate.log | head -12; exit 1; }
for m in 8 11 12; do
    ./obj_dir/Vtb_sprite_yjk_vdp +MODE=$m | grep -E "FRAME|TIMEOUT|FIN" &
done
wait
python3 "$S/analiza_sprite_yjk.py" "$B"
E=$?
cd /
if [ -n "$KEEP" ]; then echo "volcados en $B"; else rm -rf "$B"; fi
exit $E
