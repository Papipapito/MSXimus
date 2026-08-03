#!/bin/bash
# run_widx_ab.sh — _163: ¿el fallo de tb_sc8cmd_full lo causa el fix del indice
# de la ventana (w_idx con el bit de pagina plegado) o ya estaba antes?
#
# Corre EL MISMO banco dos veces cambiando SOLO el fichero del shim:
#   ANTES = la version de HEAD (git show)   DESPUES = el arbol de trabajo
# Cualquier otra diferencia queda descartada por construccion.
#
# Uso:  bash run_widx_ab.sh [tb_sc8cmd_full]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TB="${1:-tb_sc8cmd_full}"
WORK="$HERE/.build/widx_ab"
rm -rf "$WORK"; mkdir -p "$WORK" "$HERE/logs"
LOG="$HERE/logs/widx_ab_$TB.log"
: > "$LOG"

# shim ANTES del fix, sacado de HEAD sin tocar el arbol de trabajo
( cd "$ROOT" && git show HEAD:fpga/src/v9968_vram_shim.v ) > "$WORK/shim_antes.v"
cp "$ROOT/fpga/src/v9968_vram_shim.v" "$WORK/shim_despues.v"
echo "w_idx ANTES  : $(grep -A1 'function \[7:0\] w_idx' "$WORK/shim_antes.v"  | tail -1 | tr -s ' ')" | tee -a "$LOG"
echo "w_idx DESPUES: $(grep -A1 'function \[7:0\] w_idx' "$WORK/shim_despues.v" | tail -1 | tr -s ' ')" | tee -a "$LOG"

one () {                    # $1 = etiqueta, $2 = fichero de shim
  local tag="$1" shim="$2"
  echo "" | tee -a "$LOG"
  echo "################ $TB con shim $tag ################" | tee -a "$LOG"
  local d="$WORK/$tag"; mkdir -p "$d"; cd "$d"
  verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
    --top-module "$TB" \
    "$HERE/$TB.sv" \
    "$shim" \
    "$ROOT/fpga/src/v9968_sdram_bridge.v" \
    "$ROOT/fpga/src/memory.v" \
    "$ROOT/tools/sdr16_tb/w9825_model.v" \
    $ROOT/fpga/v9968/*.v > verilate.log 2>&1
  if [ -x "obj_dir/V$TB" ]; then
    timeout 900 "./obj_dir/V$TB" > out.log 2>&1
    grep -E 'RESULTADO|FALLO|OK|fallos_vram|ce_colgados|FIN' out.log | tail -6 | tee -a "$LOG"
  else
    echo "VERILATE FALLO:" | tee -a "$LOG"
    grep '%Error' verilate.log | head -5 | tee -a "$LOG"
  fi
}

one antes   "$WORK/shim_antes.v"
one despues "$WORK/shim_despues.v"

echo "" | tee -a "$LOG"
echo "=== VEREDICTO ===" | tee -a "$LOG"
echo "Si las dos dan el mismo fallos_vram, el fix del indice es INOCENTE." | tee -a "$LOG"
echo "log: $LOG"
