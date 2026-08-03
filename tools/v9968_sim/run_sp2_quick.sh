#!/bin/bash
# run_sp2_quick.sh — VEREDICTO RAPIDO del frente SP2 con pocos frames.
#
# Con los sprites encendidos (32 x 16x16 activos en todas las lineas) cada
# frame cuesta ordenes de magnitud mas de simular que el banco viejo, asi que
# el barrido completo (48 frames) son horas. Este guion saca la respuesta que
# importa —¿conmuta la pagina? ¿ensucia el shim la imagen con SP2?— con
# 1 warm + 2 control + 2 SP2 quieto + 2 hscroll + 1 recentrado + 1 v+h = 9.
#
# El log va SIN tee (tee bufea al escribir el fichero y ayer nos costo la
# pasada entera): redireccion directa y stdbuf -oL.
#
# Uso:  bash run_sp2_quick.sh [HSN] [VSN] [WARM]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
HSN="${1:-2}"
VSN="${2:-1}"
WARM="${3:-1}"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -o "$OUT/sp2.out" -s tb_sp2 \
  "$HERE/tb_sp2.sv" \
  "$ROOT/fpga/src/v9968_vram_shim.v" \
  "$ROOT"/fpga/v9968/*.v
echo "compilado OK"

LOG="$HERE/logs/sp2_quick.log"
echo "log -> $LOG  (HSN=$HSN VSN=$VSN WARM=$WARM)"
stdbuf -oL vvp "$OUT/sp2.out" \
  +LATMIN=26 +LATRND=18 +SEED=1 \
  +HSN=$HSN +VSN=$VSN +WARM=$WARM > "$LOG" 2>&1
echo "=== RESULTADO ==="
cat "$LOG"
