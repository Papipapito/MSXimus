#!/bin/bash
# ============================================================================
# run_sprite3_ref.sh — regenera la REFERENCIA de tb_sprite3 (s3r_frame.txt).
#
# QUE ES ESA REFERENCIA, Y POR QUE HAY QUE REHACERLA TRAS UN CAMBIO DE RTL.
# s3r_frame.txt NO es una fotografia de "asi se veia bien". Sale de tb_sprite3r,
# que es EL MISMO RTL del V9968 pero con una VRAM PERFECTA (sin shim). Es un
# CO-MODELO: el diff tb_sprite3 - tb_sprite3r mide EXACTAMENTE cuanto ensucia el
# shim, y nada mas.
# => Tras tocar el RTL del VDP hay que regenerarla. Si no, el banco se queda en
#    ROJO PERMANENTE marcando diferencias que son del cambio, no del shim — el
#    mismo fallo que ya tuvieron tb_sc8cmd_full (_163) y tb_t2cursor.
#
# ⚠️ -DRU66 ES OBLIGATORIO Y EL SCRIPT DE LA CASA NO LO PONE. run_sprite3_iv.sh
# compila SIN -DRU66, o sea con el setup SINTETICO (sprite3_setup.svh) en vez del
# layout real de la demo ru66 (sprite3_ru66_setup.svh + ru66_preload.svh).
# Generar la referencia con un setup y correr el banco con el otro produce un
# diff sin sentido. Ademas ese script apunta por defecto a OTRO worktree
# (MSX_up_th9958), que es un segundo modo de equivocarse.
#
# Uso:  bash run_sprite3_ref.sh          (regenera y la instala en el repo)
#       bash run_sprite3_ref.sh --dry    (la genera pero NO la instala)
# ============================================================================
set -u
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
S=$M/tools/v9968_sim
D=$S/.build/sprite3ref
DRY=${1:-}

rm -rf "$D"; mkdir -p "$D"; cd "$D" || exit 1

echo "compilando tb_sprite3r (VRAM perfecta, layout ru66)..."
iverilog -g2012 -DRU66 -I"$S" -o ref.out -s tb_sprite3r \
    "$S/tb_sprite3r.sv" "$M"/fpga/v9968/*.v > build.log 2>&1
if [ ! -f ref.out ]; then
    echo "NO COMPILA:"; tail -8 build.log; exit 1
fi

echo "corriendo hasta el volcado (vs=12; tarda ~20-40 min)..."
timeout 5400 stdbuf -oL vvp ref.out > run.log 2>&1
grep -E "VOLCADO|COMPLETO|TIMEOUT" run.log | tail -3

if [ ! -f s3r_frame.txt ]; then
    echo "*** NO HUBO VOLCADO — la referencia NO se toca ***"; exit 1
fi

NUEVA=$(wc -l < s3r_frame.txt)
VIEJA=$(wc -l < "$S/s3r_frame.txt" 2>/dev/null || echo 0)
echo ""
echo "referencia nueva : $NUEVA lineas"
echo "referencia vieja : $VIEJA lineas"
echo "lineas distintas : $(diff s3r_frame.txt "$S/s3r_frame.txt" 2>/dev/null | grep -c '^[<>]')"

if [ "$DRY" = "--dry" ]; then
    echo ""
    echo "(--dry: NO se instala. Queda en $D/s3r_frame.txt)"
else
    cp s3r_frame.txt "$S/s3r_frame.txt"
    echo ""
    echo "INSTALADA en $S/s3r_frame.txt"
    echo "Ahora tb_sprite3 vuelve a medir SOLO el ruido del shim."
fi
