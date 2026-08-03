#!/bin/bash
# run_sp2_split.sh — _163: ¿QUIEN sirve el fondo, la VENTANA o la sc-CACHE?
#
# La campana de SP2 se quedo sin esta respuesta y sin ella no se puede proponer
# un arreglo con fundamento: el pliegue del bit de pagina en w_idx salio
# BYTE-IDENTICO en 7 frames, que es exactamente lo que pasaria si la ventana no
# fuese quien manda en este caso de uso.
#
# Compila con -DSHIM_DBG_SPLIT (contadores c_wnhit / c_schit del shim, que en la
# build real no existen) e imprime por frame el reparto
#     FONDO: ventana=N sccache=M miss=K (total=N+M+K)
# Ademas el banco ya trae la FASE 0b que faltaba: mover el H-scroll con SP2
# APAGADO, con los MISMOS valores de R#26/R#27 que la fase con SP2 encendido.
# Eso separa "dano del cambio de scroll" de "dano de SP2".
#
# Uso:  bash run_sp2_split.sh [HSN] [VSN] [WARM]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
HSN="${1:-2}"; VSN="${2:-0}"; WARM="${3:-1}"
mkdir -p "$OUT" "$HERE/logs"

iverilog -g2012 -DSHIM_DBG_SPLIT -o "$OUT/sp2split.out" -s tb_sp2 \
  "$HERE/tb_sp2.sv" \
  "$ROOT/fpga/src/v9968_vram_shim.v" \
  "$ROOT"/fpga/v9968/*.v
echo "compilado OK (con SHIM_DBG_SPLIT)"

LOG="$HERE/logs/sp2_split.log"
echo "log -> $LOG  (HSN=$HSN VSN=$VSN WARM=$WARM)"
stdbuf -oL vvp "$OUT/sp2split.out" \
  +LATMIN=26 +LATRND=18 +SEED=1 \
  +HSN=$HSN +VSN=$VSN +WARM=$WARM > "$LOG" 2>&1
echo "=== RESULTADO ==="
grep -vE "^PXDIFF" "$LOG"
