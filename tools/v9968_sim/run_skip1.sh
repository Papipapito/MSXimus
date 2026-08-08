#!/bin/bash
# run_skip1.sh — caza del "+1" del puerto CPU del V9968.
#
# Compila y lanza tb_skip1 con un barrido de latencias de backend.
# Uso (desde WSL Ubuntu-24.04):  bash run_skip1.sh [NRD] [SEED]
#
# ⚠️ Este runner usaba COPIAS locales en ./src y ./src_fix, que ya no existen.
#    Ahora apunta al ARBOL REAL: asi el banco caza contra lo que se va a
#    sintetizar de verdad, y no contra una foto vieja que se queda rancia sin
#    que nadie se entere (es justo lo que habia pasado: el glue se reescribio
#    en la era _177 y el banco llevaba tiempo sin compilar).
#
# COMO LEER EL VERDE: no basta con "ERRORES: 0". Hay que mirar el bloque
# ACTIVIDAD y, sobre todo, que leak_pre > 0 — leak_pre es el PRECURSOR del
# bug (una respuesta de CPU seguida en el ciclo siguiente por otra). Si
# leak_pre es 0, el camino no se ha ejercitado y el verde no dice nada.
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="$(cd "$S/../.." && pwd)"
NRD="${1:-600}"
SEED="${2:-1}"
B=/tmp/tbskip1
rm -rf "$B" && mkdir -p "$B" && cd "$B"

iverilog -g2012 -o sim -s tb_skip1 \
  "$S/tb_skip1.sv" \
  "$R/fpga/src/v9968_cpu_glue.v" \
  "$R/fpga/src/v9968_vram_shim.v" \
  "$R"/fpga/v9968/*.v

mkdir -p "$S/logs"
# DDR3 rapido (~93-140ns/op), SDRAM medida (26+rnd18 = 300-510ns), lenta (50+rnd20)
for L in "8 4" "26 18" "50 20"; do
    set -- $L
    ( vvp sim +NRD=$NRD +LATMIN=$1 +LATRND=$2 +SEED=$SEED \
        > "$S/logs/skip1_lat$1_s$SEED.log" 2>&1 ) &
done
wait

echo "===== RESUMEN  NRD=$NRD  SEED=$SEED ====="
for f in "$S"/logs/skip1_lat*_s$SEED.log; do
    echo "--- $(basename "$f")"
    awk '/lecturas:/,0' "$f" | head -26
done
