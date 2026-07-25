#!/bin/bash
# ============================================================================
# run_sprite3_iv.sh — _148 FIX 0: sprites mode3 bajo ICARUS (iverilog -g2012).
#
# ⚠ POR QUE NO VERILATOR: run_sprite3.sh (flujo Verilator) esta MUERTO — compila
# y corre, pero da CERO trafico VRAM (bg=0 sp=0 cpu=0 cmd=0 wr=0) y un frame
# entero de pixeles negros; el `--timing` sobre esta pila (vdp.v + shim + los
# modelos de memoria con `always @(posedge clk)` y $random) no arranca el core.
# Diagnosticado el 25/07 comparando el MISMO tb_sprite3 en los dos motores:
# Icarus da el trafico esperado (bg=6996 sp=6709/frame), Verilator da 0.
# NO usar run_sprite3.sh para medir nada hasta que alguien lo arregle.
#
# Modos:
#   ./run_sprite3_iv.sh ref     -> solo la REFERENCIA DORADA (VRAM perfecta)
#                                  => tools/v9968_sim/s3r_frame.txt  (se commitea)
#   ./run_sprite3_iv.sh shim    -> solo la pila con shim  => /tmp/sp3iv/shim/s3_frame.txt
#   ./run_sprite3_iv.sh both    -> las dos + DIFF (por defecto)
#
# Variables: SHIM=<ruta> para probar una variante del shim sin tocar el worktree.
# Salida clave: SPDIAG (miss de sprite por frame) + DIFFS del frame.
# ============================================================================
set -u
W=${W:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958}
SHIM=${SHIM:-$W/fpga/src/v9968_vram_shim.v}
SIM=$W/tools/v9968_sim
MODE=${1:-both}
OUT=/tmp/sp3iv
GOLD=$SIM/s3r_frame.txt

run_one () {          # $1 = tb_sprite3 | tb_sprite3r ; $2 = subdir
    local tb=$1 dir=$OUT/$2
    rm -rf "$dir"; mkdir -p "$dir"; cd "$dir" || exit 1
    local srcs="$SIM/$tb.sv"
    [ "$tb" = "tb_sprite3" ] && srcs="$srcs $SHIM"
    echo "### BUILD $tb  $(date +%H:%M:%S)"
    iverilog -g2012 -I"$SIM" -o sp3.out -s $tb $srcs $W/fpga/v9968/*.v 2>&1 | head -20
    if [ ! -f sp3.out ]; then echo "### BUILD FALLO $tb"; return 1; fi
    echo "### RUN $tb  $(date +%H:%M:%S)"
    timeout 7200 stdbuf -oL vvp sp3.out 2>&1 | \
        stdbuf -oL grep -E 'SETUP|SPDIAG|SPTEL|VOLCADO|COMPLETO|TIMEOUT'
    echo "### FIN $tb  $(date +%H:%M:%S)"
}

case "$MODE" in
  ref)  run_one tb_sprite3r ref  && cp "$OUT/ref/s3r_frame.txt" "$GOLD" &&
        echo "REFERENCIA DORADA -> $GOLD ($(wc -l < "$GOLD") lineas)" ;;
  shim) run_one tb_sprite3 shim ;;
  both)
        run_one tb_sprite3r ref  && cp "$OUT/ref/s3r_frame.txt" "$GOLD"
        run_one tb_sprite3  shim
        ;;
  *) echo "uso: $0 [ref|shim|both]"; exit 2 ;;
esac

A=$OUT/shim/s3_frame.txt
if [ -f "$A" ] && [ -f "$GOLD" ]; then
    la=$(wc -l < "$A"); lb=$(wc -l < "$GOLD")
    d=$(diff "$A" "$GOLD" | grep -c '^[<>]')
    echo "----------------------------------------"
    echo "shim=$la lineas  dorada=$lb lineas  DIFFS=$d"
    if [ "$la" = "$lb" ] && [ "$d" = "0" ]; then
        echo "*** SPRITE3: SIN GLITCH (shim == dorada) ***"
    else
        echo "*** SPRITE3: GLITCH ($d lineas distintas) ***"
    fi
fi
