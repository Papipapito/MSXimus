#!/bin/bash
# run_sp2_pf.sh — _163: MIDE EL ARREGLO DE SP2 (prefetch a traves de la
# frontera de pagina), con la misma instrumentacion del reparto.
#
# El "antes" ya esta medido en logs/sp2_split.log con esta MISMA config y
# semilla, asi que basta con correr el "despues" y comparar.
#
# NUMEROS A BATIR (antes, dado unico, LATMIN=26 semilla 1):
#   ctrl SP2=0                 : pxdiff    64   miss   2   ventana 12666
#   ctrl SP2=0 + hscroll       : pxdiff    64   miss   2   <- el scroll solo NO dana
#   SP2 on, quieto             : pxdiff     0   miss 262
#   SP2 on + hscroll moviendose: pxdiff  7336   miss 387
#
# LO QUE HARIA VALIDO EL ARREGLO: que baje el miss de las fases con SP2 (y con
# el el pxdiff de 7336). Si el miss no baja, el arreglo NO sirve y se retira,
# igual que se retiro el del indice.
#
# Uso:  bash run_sp2_pf.sh [HSN] [VSN] [WARM]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
HSN="${1:-2}"; VSN="${2:-0}"; WARM="${3:-1}"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -DSHIM_SP2_PF -DSHIM_DBG_SPLIT -o "$OUT/sp2pf.out" -s tb_sp2 \
  "$HERE/tb_sp2.sv" \
  "$ROOT/fpga/src/v9968_vram_shim.v" \
  "$ROOT"/fpga/v9968/*.v
echo "compilado OK (SHIM_SP2_PF + SHIM_DBG_SPLIT)"

LOG="$HERE/logs/sp2_pf.log"
echo "log -> $LOG  (HSN=$HSN VSN=$VSN WARM=$WARM)"
stdbuf -oL vvp "$OUT/sp2pf.out" \
  +LATMIN=26 +LATRND=18 +SEED=1 \
  +HSN=$HSN +VSN=$VSN +WARM=$WARM > "$LOG" 2>&1

echo ""
echo "================= ANTES (sin el arreglo) ================="
grep -E "^FRAME" "$HERE/logs/sp2_split.log" 2>/dev/null || echo "(falta el log del antes)"
echo ""
echo "================= DESPUES (con el arreglo) ==============="
grep -E "^FRAME" "$LOG"
