#!/bin/bash
# run_soak3.sh — _163b: banco del residuo del VRAMSOAK con el ORACULO CORRECTO.
#
# La firma de placa (9 de 9 casos decodificados con el patron real del
# VRAMSOK2, dir^(dir>>8)^A5/5A) es que la PRIMERA lectura tras re-apuntar la
# direccion devuelve f(dir-1): lee una direccion por debajo. Este banco cuenta
# las tres hipotesis por separado (f(dir-1) / byte de la lectura previa /
# ninguna) para que no se puedan volver a confundir.
#
# Barrido de latencias desde muy por debajo de la de placa hasta muy por
# encima, y de pasos de recorrido, porque el defecto puede depender de la fase
# entre el SETRD y el IN.
#
# Uso:  bash run_soak3.sh [N]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
N="${1:-60}"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -o "$OUT/cpuif.out" -s tb_cpuif_dbl \
  "$HERE/tb_cpuif_dbl.sv" \
  "$ROOT/fpga/v9968/vdp_cpu_interface.v" \
  "$ROOT/fpga/src/v9968_cpu_glue.v"
echo "compilado OK"

LOG="$HERE/logs/soak3.log"
: > "$LOG"

# Latencias: 40 (rapida), 120/190 (placa tipica/peor medida), 260, 340 (umbral
# del OTRO bug), 420. Pasos: 1 (contiguo), 4, 211 (disperso).
for L in 40 120 190 260 340 420; do
  for S in 1 4 211; do
    echo ""                                            | tee -a "$LOG"
    echo "########## LAT=$L  STEP=$S ##########"       | tee -a "$LOG"
    stdbuf -oL vvp "$OUT/cpuif.out" +MODE=5 +LAT=$L +N=$N +STEP=$S 2>&1 \
      | grep -E "1a LECTURA|FALLO DISTINTO|SOLO la|  A\)|  B\)|  C\)|otros fallos|aterrizaron|INVALIDADAS|\*\*\*" \
      | tee -a "$LOG"
  done
done
echo ""
echo "log: $LOG"
