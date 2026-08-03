#!/bin/bash
# ============================================================================
# run_textgeom_roto.sh — _165b: DEMOSTRAR que la variante de la rc4 rompe el
# modo texto, y dejar el banco que lo caza.
#
# POR QUE. La rc4 rompio el texto en placa. Mi explicacion es que el filtro
# "solo los SPRITES rellenan la sc-cache" le quita la cache al fondo, y en TEXTO
# el fondo la necesita (la tabla de patrones se accede indexada por el codigo de
# caracter, cosa que un prefetch lineal no cubre). Pero ESO ERA UNA TEORIA: la
# regresion que corri comparaba BASE (sin filtro) contra FIX (filtro estrecho),
# y en un banco SIN comandos esos dos son identicos POR CONSTRUCCION, porque lo
# unico que cambia entre ellos es que pasa con los rellenos del motor de
# comandos y ahi no hay ninguno. O sea: demostraba que el arreglo no regresa,
# pero NO reproducia la rotura.
#
# Este script corre la TERCERA variante, la que de verdad se flasheo:
#   ROTO = if (!pf_dirty && (cur_tag[4:2] == C_SPRITE))
# Si tb_textgeom sale distinto de BASE, la explicacion queda demostrada Y este
# banco pasa a ser el guardian que faltaba en la bateria.
# Si sale IGUAL, mi explicacion es falsa y hay que buscar otra cosa antes de
# tocar nada mas.
#
# Uso:  bash run_textgeom_roto.sh
# ============================================================================
set -u
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
S=$M/tools/v9968_sim
O=$S/logs/reg165b
ROTO=$O/shim_roto.v

if [ ! -f "$ROTO" ]; then
    sed 's/if (!pf_dirty && (cur_tag\[4:2\] != C_COMMAND)) begin/if (!pf_dirty \&\& (cur_tag[4:2] == C_SPRITE)) begin/' \
        "$M/fpga/src/v9968_vram_shim.v" > "$ROTO"
fi
if diff -q "$M/fpga/src/v9968_vram_shim.v" "$ROTO" > /dev/null; then
    echo "ABORTADO: el shim ROTO es identico al actual (el sed no encontro la linea)"; exit 1
fi
grep -q "cur_tag\[4:2\] == C_SPRITE" "$ROTO" || { echo "ABORTADO: el ROTO no lleva == C_SPRITE"; exit 1; }
echo "OK: shim ROTO listo (== C_SPRITE, exactamente lo que se flasheo en la rc4)"

d=$O/ROTO/tb_textgeom
rm -rf "$d"; mkdir -p "$d"; cd "$d" || exit 1
iverilog -g2012 -I"$S" -o sim.out -s tb_textgeom \
    "$S/tb_textgeom.sv" "$ROTO" "$M"/fpga/v9968/*.v > build.log 2>&1
if [ ! -f sim.out ]; then echo "NO COMPILA:"; tail -6 build.log; exit 1; fi
echo "compilado OK, corriendo MODE=0 (SCREEN1 Graphic1)..."
timeout 900 stdbuf -oL vvp sim.out +MODE=0 > "run+MODE=0.log" 2>&1

BASE=$O/BASE/tb_textgeom/run+MODE=0.log
echo ""
echo "==================== ROTO (rc4) vs BASE (rc3) ===================="
diff "$BASE" "$d/run+MODE=0.log" | head -30
n=$(diff "$BASE" "$d/run+MODE=0.log" | grep -c '^[<>]')
echo ""
echo "lineas distintas: $n"
if [ "$n" -gt 0 ]; then
    echo "*** DIAGNOSTICO CONFIRMADO: la variante de la rc4 CAMBIA el modo texto."
    echo "*** tb_textgeom es el banco que faltaba en la bateria."
else
    echo "*** DIAGNOSTICO NO CONFIRMADO: el banco no ve diferencia."
    echo "*** La explicacion del fallo de texto NO esta demostrada; no tocar mas hasta entenderlo."
fi
