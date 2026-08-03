#!/bin/bash
# ============================================================================
# run_soak4.sh — _164: DISCRIMINAR LOS DOS MECANISMOS del bug #26.
#
# POR QUE ESTE BANCO EXISTE. La cura que se venia proponiendo para el #26 era
# PARAR LA CPU (un termino nuevo en el FSM wait_io del top). Al auditarla salio
# que es PELIGROSA: en memory.v:302 el refresco de la SDRAM SOLO ocurre con
# bus_rfsh_n==0, o sea colgado del ciclo RFSH del Z80. Parar la CPU para el
# refresco ENTERO, y el propio memory.v:309-316 documenta que matar de hambre al
# refresh ya reventó esta placa una vez ("la SDRAM se descargaba en segundos,
# cuelgue total"). El presupuesto es ~4.7us (rfsh_gap) contra 7.8us/fila del
# W9825; el timeout propuesto eran ~19us. 2.4x por encima.
#
# Antes de pagar ese riesgo hay que saber CUAL de los dos mecanismos produce los
# 9 fallos de placa, porque solo uno de ellos justifica tocar la CPU:
#
#   (1) DATO RANCIO POR LATENCIA — el Z80 muestrea cdi_r antes de que llegue el
#       dato. Es el que cura un /WAIT. Firma: el byte malo es el de la lectura
#       ANTERIOR EN EL TIEMPO (n_prev). Umbral medido: LAT>=340.
#
#   (2) FLANCO TIRADO POR EL GLUE — v9968_cpu_glue.v:58-72 no tiene cola: si
#       llega un ciclo de I/O con bus_valid todavia alto, el flanco SE PIERDE en
#       silencio, la transaccion nunca se emite y cdi_r se queda como estaba.
#       Esto NO lo cura un /WAIT (la CPU ya iba parada) y SI se cura en el glue,
#       sin tocar la CPU y por tanto sin tocar el refresco.
#
# La firma REAL de placa es la TERCERA: n_minus1, el byte vale f(dir-1) — una
# direccion por debajo. Eso no es dato rancio en el tiempo: es un problema de
# DIRECCION. Este banco los cuenta los tres por separado y ADEMAS saca
# n_edgelost (los flancos que el glue tira, monitor ya existente en la linea
# 235 del banco) para poder CORRELACIONARLOS.
#
# LO QUE DECIDE:
#   * n_minus1 > 0 con n_edgelost == 0  -> el /WAIT no pinta nada aqui; el fallo
#     esta en el camino de direccion del pre-read. NO tocar la CPU.
#   * n_minus1 correlaciona con n_edgelost -> se arregla en el GLUE. NO tocar la
#     CPU.
#   * solo n_prev, y solo a LAT>=340 -> ese si es el caso del /WAIT, pero la
#     peor latencia de placa es ~190, asi que estaria fuera del rango real.
#
# Uso:  bash run_soak4.sh [N]      (por defecto 60 accesos por combinacion)
# ============================================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
N="${1:-60}"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -o "$OUT/cpuif4.out" -s tb_cpuif_dbl \
  "$HERE/tb_cpuif_dbl.sv" \
  "$ROOT/fpga/v9968/vdp_cpu_interface.v" \
  "$ROOT/fpga/src/v9968_cpu_glue.v"
echo "compilado OK"

LOG="$HERE/logs/soak4.log"
: > "$LOG"

# LAT: 40 rapida | 120/190 placa tipica/peor medida | 260 borde | 340/420 el
# umbral del otro bug. STEP: 1 contiguo, 211 disperso (el del soak real).
for L in 40 120 190 260 340 420; do
  for S in 1 211; do
    echo ""                                       | tee -a "$LOG"
    echo "########## LAT=$L  STEP=$S ##########"  | tee -a "$LOG"
    # SIN grep: se quiere la salida COMPLETA, incluido n_edgelost, que es lo
    # que run_soak3.sh filtraba y por eso no se veia la correlacion.
    stdbuf -oL vvp "$OUT/cpuif4.out" +MODE=5 +LAT=$L +N=$N +STEP=$S 2>&1 \
      | tee -a "$LOG"
  done
done
echo ""
echo "log: $LOG"
