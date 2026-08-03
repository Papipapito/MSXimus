#!/bin/bash
# ============================================================================
# run_tmds_equiv.sh — _169: banco de equivalencia del corte del codificador TMDS.
#
# Es el PASO 0 antes de tocar nada: decide el 90% del riesgo sin gastar un dado.
# Criterio: CERO discrepancias en tmds y en acc. Tolerancia cero.
#
# Uso:  bash run_tmds_equiv.sh
# ============================================================================
set -u
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
S=$M/tools/v9968_sim
H=$M/fpga/tn_vdp_v3_v9958/src/hdmi
D=$S/.build/tmds_equiv

rm -rf "$D"; mkdir -p "$D"; cd "$D" || exit 1

iverilog -g2012 -o eq.out -s tb_tmds_equiv \
    "$S/tb_tmds_equiv.sv" "$H/tmds_channel.sv" > build.log 2>&1
if [ ! -f eq.out ]; then
    echo "NO COMPILA:"; tail -12 build.log; exit 1
fi
echo "compilado OK"
timeout 1800 stdbuf -oL vvp eq.out 2>&1 | tail -20
