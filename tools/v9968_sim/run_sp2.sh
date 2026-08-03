#!/bin/bash
# run_sp2.sh — FRENTE 1: scroll de DOS PAGINAS (R#25 SP2) con SPRITES ON.
# Compila contra el ARBOL VIVO del repo (convencion _162 de run_hscroll.sh),
# no contra copias en src/: lo que se mide es el RTL que se va a sintetizar.
#
# Uso:   bash run_sp2.sh [LATMIN] [LATRND] [SEED]
# Windows:  wsl -d Ubuntu-24.04 bash tools/v9968_sim/run_sp2.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/v9968_sp2"
LATMIN="${1:-26}"
LATRND="${2:-18}"
SEED="${3:-1}"

rm -rf "$OUT" && mkdir -p "$OUT"
mkdir -p "$HERE/logs"

echo "### compilando contra $ROOT/fpga (arbol vivo)"
iverilog -g2012 -o "$OUT/tb_sp2.out" -s tb_sp2 \
  "$HERE/tb_sp2.sv" \
  "$ROOT/fpga/src/v9968_vram_shim.v" \
  "$ROOT"/fpga/v9968/*.v

LOG="$HERE/logs/sp2_lat${LATMIN}_s${SEED}.log"
echo "### simulando (lat ${LATMIN}+rnd${LATRND}, seed ${SEED}) -> $LOG"
# stdbuf -oL: sin esto vvp bloquea la salida en trozos de 4KB al no ir a un
# TTY y no se ve NADA hasta ~30 frames. La respuesta importante (¿sube
# pgflips?) sale en el frame 5: hay que poder abortar antes de gastar la hora.
stdbuf -oL vvp "$OUT/tb_sp2.out" +LATMIN=$LATMIN +LATRND=$LATRND +SEED=$SEED 2>&1 | tee "$LOG"

echo ""
echo "=================== LO QUE IMPORTA ==================="
grep -E "RESUMEN|stride|conmutaciones|fetches de sprite|fase |control |SP2 |\*\*\*" "$LOG" || true
