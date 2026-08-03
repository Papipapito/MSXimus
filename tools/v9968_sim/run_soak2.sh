#!/bin/bash
# run_soak2.sh — _163: LA PRUEBA QUE DISTINGUE LOS DOS MECANISMOS.
#
# En placa el byte malo difiere del bueno SOLO en los bits bajos (XOR 07/0F en
# los 9 casos). Hay dos explicaciones posibles y esta prueba las separa:
#   (A) el byte es el de la LECTURA ANTERIOR (cdi_r rancio, sin /WAIT en el
#       glue). Con recorrido de paso PEQUENO, f(anterior) y f(objetivo) se
#       parecen => XOR confinado a los bits bajos. Con paso GRANDE, XOR de
#       rango completo.
#   (B) el byte es el de una direccion VECINA de la objetivo (contador de
#       direccion desalineado). Entonces el XOR sale confinado con CUALQUIER
#       paso de recorrido.
# => Si al bajar el paso el XOR se confina y n_prev sube, gana (A).
#
# Uso:  bash run_soak2.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -o "$OUT/cpuif.out" -s tb_cpuif_dbl \
  "$HERE/tb_cpuif_dbl.sv" \
  "$ROOT/fpga/v9968/vdp_cpu_interface.v" \
  "$ROOT/fpga/src/v9968_cpu_glue.v"
echo "compilado OK"

LOG="$HERE/logs/soak2.log"
: > "$LOG"

echo "===== A) misma latencia (360), TRES pasos de recorrido =====" | tee -a "$LOG"
for S in 4 64 7817; do
  echo ""                                  | tee -a "$LOG"
  echo "########## STEP=$S ##########"     | tee -a "$LOG"
  stdbuf -oL vvp "$OUT/cpuif.out" +MODE=5 +LAT=360 +N=60 +STEP=$S 2>&1 \
    | grep -E "PRIMERA|paso del|SOLO la|ERA EL ANTERIOR|otros fallos|INVALIDADAS|\*\*\* REPRO|\*\*\* NO REPRO" \
    | tee -a "$LOG"
done

echo ""                                                        | tee -a "$LOG"
echo "===== B) umbral de latencia (paso 4, el del soak) =====" | tee -a "$LOG"
for L in 280 300 320 340 360; do
  echo ""                                  | tee -a "$LOG"
  echo "########## LAT=$L ##########"      | tee -a "$LOG"
  stdbuf -oL vvp "$OUT/cpuif.out" +MODE=5 +LAT=$L +N=60 +STEP=4 2>&1 \
    | grep -E "SOLO la|ERA EL ANTERIOR" \
    | tee -a "$LOG"
done
echo ""
echo "log: $LOG"
