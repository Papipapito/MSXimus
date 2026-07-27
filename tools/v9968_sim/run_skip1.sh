#!/bin/bash
# run_skip1.sh — compila y lanza tb_skip1 con barrido de latencias de backend.
# Uso (desde WSL Ubuntu-24.04):  bash run_skip1.sh [NRD]
# Fuentes: COPIAS locales en ./src (los repos del usuario son solo lectura).
set -e
S="$(cd "$(dirname "$0")" && pwd)"
NRD="${1:-600}"
SEED="${2:-1}"
B=/tmp/tbskip1
rm -rf "$B" && mkdir -p "$B" && cd "$B"
iverilog -g2012 -o sim -s tb_skip1 \
  "$S/tb_skip1.sv" \
  "$S/src/shim/v9968_cpu_glue.v" \
  "$S/src/shim/v9968_vram_shim.v" \
  "$S"/src/v9968/*.v
mkdir -p "$S/logs"
# DDR3 rapido (~93-140ns/op), SDRAM medida (26+rnd18 = 300-510ns), lenta (50+rnd20)
for L in "8 4" "26 18" "50 20"; do
  set -- $L
  ( vvp sim +NRD=$NRD +LATMIN=$1 +LATRND=$2 +SEED=$SEED > "$S/logs/skip1_lat$1_s$SEED.log" 2>&1 ) &
done
wait
echo "== RESUMEN =="
for f in "$S"/logs/skip1_lat*_s$SEED.log; do
  echo "--- $f"
  grep -E "RESULTADO|lecturas:|firma:|S1 |S2 |S3 |=>|INVALIDO|relectura" "$f" | head -12
done
