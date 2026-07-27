#!/bin/bash
# run_skip1_fix.sh — mismo banco compilado contra src_fix (vdp_vram_interface
# con el fix del strobe). Esperado: 0 errores, 0 en2, con cualquier latencia.
set -e
S="$(cd "$(dirname "$0")" && pwd)"
NRD="${1:-600}"
SEED="${2:-1}"
B=/tmp/tbskip1fix
rm -rf "$B" && mkdir -p "$B" && cd "$B"
iverilog -g2012 -o sim -s tb_skip1 \
  "$S/tb_skip1.sv" \
  "$S/src_fix/shim/v9968_cpu_glue.v" \
  "$S/src_fix/shim/v9968_vram_shim.v" \
  "$S"/src_fix/v9968/*.v
mkdir -p "$S/logs"
for L in "8 4" "26 18" "50 20"; do
  set -- $L
  ( vvp sim +NRD=$NRD +LATMIN=$1 +LATRND=$2 +SEED=$SEED > "$S/logs/skip1fix_lat$1_s$SEED.log" 2>&1 ) &
done
wait
echo "== RESUMEN FIX =="
for f in "$S"/logs/skip1fix_lat*_s$SEED.log; do
  echo "--- $f"
  grep -E "lecturas:|firma:|S1 |S2 |S3 |=>|INVALIDO" "$f" | head -10
done
