#!/bin/bash
# ============================================================================
# lint.sh — LINT ESTATICO del RTL del MSXimus con Verilator (--lint-only -Wall).
#
# POR QUE: no necesita que el diseno simule ni sintetice, tarda segundos, y caza
# la clase de defecto que hasta ahora se buscaba A MANO (la campana del
# "niquelado" del 27/07 se dedico justamente a eso): senales declaradas y no
# usadas, redes implicitas sin driver, anchos que no cuadran, latches
# involuntarios, senales con dos drivers.
# PRUEBA de que sirve: la primera pasada al shim, ya auditado a mano, encontro
# dos senales MUERTAS en 3 segundos (cur_half y nxt_w).
#
# LO QUE NO HACE, para no crear falsa confianza: no encuentra errores de
# SIGNIFICADO. Los tres bugs de verdad del 30/07 —el "- obl_la" que apuntaba dos
# palabras corto, el mem_idx rancio del banco, el reset que quedo bajo ifdef—
# los encontro una MEDICION CON ORACULO, no una herramienta. Esto sube el suelo;
# no sustituye a la bateria.
#
# Cada fichero se lintea POR SEPARADO (--top-module = su propio modulo): asi no
# hay que resolver la jerarquia entera ni los defines del top, y un fichero roto
# no tapa a los demas.
#
# Uso:  bash tools/lint.sh [propio|v9968|todo]     (por defecto: propio)
#   propio = fpga/src + fpga/video720 (codigo del MSXimus)
#   v9968  = el core de HRA (informativo: NO es nuestro, no "arreglar" a ciegas)
#   todo   = los dos
# Se EXCLUYEN a proposito los cores de terceros vendorizados (opl3, jtopl, jt10,
# opl4wave, ddr3, tn_vdp_v3_v9958): su ruido ahogaria el informe y no los tocamos.
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MODE="${1:-propio}"
OUT="$ROOT/tools/v9968_sim/logs"
mkdir -p "$OUT"
LOG="$OUT/lint.log"
: > "$LOG"

# Ficheros que NO tiene sentido lintear. Se excluyen por PATRON, no por lista
# cerrada, para que un fichero nuevo no se cuele solo:
#   pll_*.v      envoltorios de IP generados por Gowin (81 avisos cada uno, todos
#                DEFPARAM/PINCONNECTEMPTY del generador: ruido puro que tapaba
#                los hallazgos de verdad)
#   *_tb.v/.sv   bancos de prueba: no son diseno
#   *_ghdl.v     variante para GHDL del mismo modulo
skip_this () {
    case "$(basename "$1")" in
        pll_*.v|pll_*.sv)  return 0 ;;
        *_tb.v|*_tb.sv)    return 0 ;;
        *_ghdl.v)          return 0 ;;
        *)                 return 1 ;;
    esac
}

lint_one () {
    local f="$1"
    local base mod n
    base="$(basename "$f")"
    if skip_this "$f"; then
        N_SKIP=$((N_SKIP+1)); SKIPPED="$SKIPPED $base(no-diseno)"
        return 0
    fi
    # nombre del primer modulo del fichero
    mod="$(grep -m1 -oE '^[[:space:]]*module[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$f" \
           | awk '{print $2}')"
    if [ -z "$mod" ]; then
        N_SKIP=$((N_SKIP+1)); SKIPPED="$SKIPPED $base(sin modulo)"
        printf '%-28s  SALTADO: no se encontro declaracion de modulo\n' "$base" | tee -a "$LOG"
        return 0
    fi
    N_LINT=$((N_LINT+1))
    verilator --lint-only -Wall --timing -Wno-fatal \
        --top-module "$mod" "$f" > "$OUT/.lint_tmp" 2>&1
    n="$(grep -c '^%Warning\|^%Error' "$OUT/.lint_tmp" || true)"
    if [ "$n" -gt 0 ]; then
        printf '%-28s %3d avisos\n' "$base" "$n" | tee -a "$LOG"
        grep -E '^%(Warning|Error)' "$OUT/.lint_tmp" \
            | sed 's/^/    /' | sort | uniq -c | sort -rn | head -8 >> "$LOG"
        echo "" >> "$LOG"
    else
        printf '%-28s  limpio\n' "$base" | tee -a "$LOG"
    fi
}

# ⚠️ CONTABILIDAD EXPLICITA. La primera version de este script globeaba
# "fpga/src/*.v" SIN recursar y dejaba 13 ficheros fuera (ocm/, usb/,
# usb_direct/, wondertang/) sin decir NADA. Un lint que omite un tercio del
# codigo en silencio es PEOR que no tener lint: da falsa confianza. Es el mismo
# defecto que tenia la bateria con su banco en rojo permanente.
# Ahora se cuenta lo linteado, lo saltado y por que, y se imprime siempre.
N_LINT=0; N_SKIP=0; SKIPPED=""

do_dir () {
    echo ""                                  | tee -a "$LOG"
    echo "########## $1 ##########"          | tee -a "$LOG"
    for f in $2; do [ -f "$f" ] && lint_one "$f"; done
}

case "$MODE" in
  propio|todo)
    do_dir "fpga/src (MSXimus, recursivo)" \
      "$(find "$ROOT/fpga/src" -name '*.v' -o -name '*.sv' | sort)"
    do_dir "fpga/video720" \
      "$(find "$ROOT/fpga/video720" -name '*.v' -o -name '*.sv' | sort)"
    do_dir "fpga/top.v" "$ROOT/fpga/top.v"
    ;;
esac
case "$MODE" in
  v9968|todo)
    do_dir "fpga/v9968 (core de HRA — informativo)" "$ROOT/fpga/v9968/*.v"
    ;;
esac

rm -f "$OUT/.lint_tmp"
echo ""                                                        | tee -a "$LOG"
echo "=================== COBERTURA ==================="       | tee -a "$LOG"
echo "  ficheros linteados : $N_LINT"                          | tee -a "$LOG"
echo "  ficheros saltados  : $N_SKIP"                          | tee -a "$LOG"
[ "$N_SKIP" -gt 0 ] && echo "     ->$SKIPPED"                  | tee -a "$LOG"
echo ""                                                        | tee -a "$LOG"
echo "=================== AVISOS POR TIPO ============="        | tee -a "$LOG"
grep -oE '%Warning-[A-Z]+|%Error-[A-Z]+' "$LOG" | sort | uniq -c | sort -rn | tee -a "$LOG"
echo ""
echo "PRIORIDAD: WIDTHTRUNC (bits descartados en silencio) > CASEINCOMPLETE"
echo "(latch/valor retenido) > BLKSEQ (bloqueante en secuencial) > el resto."
echo "detalle por fichero en: $LOG"
