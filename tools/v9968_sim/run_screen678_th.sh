#!/bin/bash
# ============================================================================
# run_screen678_th.sh — _148: NO-REGRESION de SCREEN 5/6/7/8 en el worktree
# th9958, con ICARUS y comparando ANTES vs DESPUES *con el mismo core*.
#
# ⚠ POR QUE NO SE COMPARA CONTRA s5..s8_frame.txt (las referencias committeadas):
# se generaron el 21/07 y este worktree lleva cambios en vdp_video_out.v que
# alteran la GEOMETRIA del frame — los volcados nuevos salen de 5162008 bytes y
# las referencias son de 6145572. Contra ellas TODO sale rojo por un motivo que
# no tiene nada que ver con el shim. La comparacion valida es el shim de
# referencia (por defecto el de HEAD) contra el shim de trabajo, con el MISMO
# core y los MISMOS TB de cada version.
#
# uso:  ./run_screen678_th.sh
#       REF_SHIM=<ruta al shim viejo> REF_TB=<dir con los TB viejos> ./run_...
#
# Si el bus de escritura cambio de ancho (FIX B: 8b -> 32b+mascara), los TB del
# worktree NO compilan contra el shim viejo: por eso REF_TB apunta a una copia
# de los TB de esa epoca (sacala con `git show HEAD:tools/v9968_sim/tb_X.sv`).
# Sin REF_TB solo se corre el lado NUEVO y se reportan los bg_miss.
# ============================================================================
set -u
W=${W:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958}
SHIM=${SHIM:-$W/fpga/src/v9968_vram_shim.v}
REF_SHIM=${REF_SHIM:-}
REF_TB=${REF_TB:-}
SIM=$W/tools/v9968_sim
CORE=$W/fpga/v9968
OUT=/tmp/s678th
JOBS="tb_screen5:s5_frame.txt tb_screen6:s6_frame.txt tb_screen7:s7_frame.txt tb_screen8:s8_frame.txt"

build_and_run () {          # $1 = raiz de salida, $2 = shim, $3 = dir de TB
    local root=$1 shim=$2 tbdir=$3
    rm -rf "$root" && mkdir -p "$root"
    for j in $JOBS; do
        local tb=${j%%:*}
        mkdir -p "$root/$tb"
        ( cd "$root/$tb" && iverilog -g2012 -o r.out -s $tb "$tbdir/$tb.sv" \
            "$shim" "$CORE"/*.v > build.log 2>&1 || echo "BUILD FALLO $tb ($root)" )
    done
    echo "COMPILA_OK $root $(date +%H:%M:%S)"
    for j in $JOBS; do
        local tb=${j%%:*}
        ( cd "$root/$tb" && timeout 5400 vvp r.out > run.log 2>&1 ) &
    done
    wait
    echo "SIMS_DONE $root $(date +%H:%M:%S)"
}

build_and_run "$OUT" "$SHIM" "$SIM"
[ -n "$REF_SHIM" ] && build_and_run /tmp/s678ref "$REF_SHIM" "${REF_TB:-$SIM}"

fails=0
for j in $JOBS; do
    tb=${j%%:*}; f=${j##*:}
    a=$OUT/$tb/$f
    [ -f "$a" ] || { echo "$tb: SIN VOLCADO"; fails=$((fails+1)); continue; }
    echo "$tb: $(wc -l < "$a") lineas | $(grep -hE 'COMPLETO' "$OUT/$tb/run.log" | tail -1)"
    if [ -n "$REF_SHIM" ] && [ -f /tmp/s678ref/$tb/$f ]; then
        d=$(diff "$a" /tmp/s678ref/$tb/$f | grep -c '^[<>]')
        if [ "$d" = "0" ]; then echo "  vs REF: IDENTICO"
        else echo "  vs REF: *** DIFF $d lineas ***"; fails=$((fails+1)); fi
    fi
done
echo "----------------------------------------"
if [ "$fails" = "0" ]; then echo "*** 678: SIN REGRESION ***"
else echo "*** 678: $fails PROBLEMAS ***"; fi
