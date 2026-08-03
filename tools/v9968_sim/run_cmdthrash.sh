#!/bin/bash
# ============================================================================
# run_cmdthrash.sh — _164: ¿el motor de comandos desaloja los patrones de
# sprites de la sc-cache del shim?
#
# TRES VARIANTES, UNA SOLA VARIABLE ENTRE CADA PAR:
#   A  base      : escena ru66 tal cual (linea base ya validada, DIFFS=0)
#   B  +CMDTRAF  : idem + LMMM|OR continuo cuyo DESTINO es la SPT (0x8000)
#   C  B + fix   : idem B, con -DSC_FILL_SPRITE_ONLY (el relleno de la cache
#                  filtrado a lecturas de SPRITE, como la _150 ya hizo con el
#                  victim buffer)
#
# LECTURA DEL RESULTADO (el numero que decide es c_spmiss por frame, linea
# SPTEL, columna "(+N)"):
#   B >> A  y  C ~= A   -> hipotesis CONFIRMADA y el filtro la cura.
#   B ~= A              -> hipotesis MUERTA: el trafico de comando no desaloja.
#   B >> A  y  C >> A   -> el desalojo existe pero el filtro NO es la cura.
# Mirar tambien SPCLS: "FILLS" clasifica QUIEN rellena la cache por region.
# En B deberia dispararse el relleno de la region SPT; en C tiene que caer.
#
# ⚠ NO USAR VERILATOR en esta pila: da cero trafico VRAM y frame negro
# (diagnosticado el 25/07, ver la cabecera de run_sprite3_iv.sh). Icarus.
# ⚠ El script de la casa (run_sprite3_iv.sh) apunta por defecto a OTRO worktree
# (MSX_up_th9958) y NO pasa -DRU66; por eso este no lo reutiliza.
#
# Uso:  bash run_cmdthrash.sh <A|B|C> [segundos]     (por defecto 150 s)
# Las corridas se cortan por tiempo A PROPOSITO: no hace falta el volcado del
# frame (que tarda horas), solo los contadores por frame, que se imprimen desde
# el primer vs.
# ============================================================================
set -u
W=${W:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up}
SIM=$W/tools/v9968_sim
VAR=${1:-A}
SECS=${2:-150}
OUT=$SIM/.build/cmdthrash/$VAR
LOG=$SIM/logs/cmdthrash_$VAR.log

case "$VAR" in
  A) DEFS="-DRU66" ;;
  B) DEFS="-DRU66 -DCMDTRAF" ;;
  C) DEFS="-DRU66 -DCMDTRAF -DSC_FILL_SPRITE_ONLY" ;;
  *) echo "uso: $0 <A|B|C> [segundos]"; exit 2 ;;
esac

rm -rf "$OUT"; mkdir -p "$OUT" "$SIM/logs"
cd "$OUT" || exit 1

echo "### VARIANTE $VAR   defines: $DEFS"
# shellcheck disable=SC2086
iverilog -g2012 $DEFS -I"$SIM" -o sp3.out -s tb_sprite3 \
    "$SIM/tb_sprite3.sv" "$W/fpga/src/v9968_vram_shim.v" $W/fpga/v9968/*.v 2>&1 | head -25
if [ ! -f sp3.out ]; then echo "### BUILD FALLO ($VAR)"; exit 1; fi
echo "### compilado OK, corriendo ${SECS}s"

timeout "$SECS" stdbuf -oL vvp sp3.out 2>&1 \
  | stdbuf -oL grep -E 'SETUP|SPTEL|SPCLS|CMDTRAF|COMPLETO' \
  | tee "$LOG"

echo "### FIN $VAR   log: $LOG"
