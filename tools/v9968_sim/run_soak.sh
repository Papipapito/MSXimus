#!/bin/bash
# run_soak.sh — _163: reproduce en simulacion la firma del VRAMSOAK de placa
# (v2.1-rc1): por cada direccion, TRES ciclos independientes de "fijar
# direccion + leer", con la 1a lectura mala y la 2a/3a buenas.
#
# Barre latencias de VRAM alrededor de la de placa (~190 ciclos) porque el
# defecto solo puede vivir en la ventana en la que la pre-lectura sigue en
# vuelo cuando llega el siguiente SETRD.
#
# Uso:  bash run_soak.sh [N_direcciones]
# Windows:  wsl -d Ubuntu-24.04 bash tools/v9968_sim/run_soak.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
N="${1:-80}"

mkdir -p "$OUT" "$HERE/logs"
iverilog -g2012 -o "$OUT/cpuif.out" -s tb_cpuif_dbl \
  "$HERE/tb_cpuif_dbl.sv" \
  "$ROOT/fpga/v9968/vdp_cpu_interface.v" \
  "$ROOT/fpga/src/v9968_cpu_glue.v"
echo "compilado OK"

LOG="$HERE/logs/soak.log"
: > "$LOG"
for L in 60 120 160 190 220 280 360; do
  echo ""                                    | tee -a "$LOG"
  echo "########## LAT=$L ciclos ##########" | tee -a "$LOG"
  stdbuf -oL vvp "$OUT/cpuif.out" +MODE=5 +LAT=$L +N=$N 2>&1 \
    | grep -E "tb_cpuif_dbl:|PRIMERA|FALLO DIST|SOLO la|otros fallos|aterrizaron|INVALIDADAS|\*\*\*" \
    | tee -a "$LOG"
done
echo ""
echo "log completo: $LOG"
