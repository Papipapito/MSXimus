#!/bin/bash
# ============================================================================
# run_regresion_165b.sh — regresion del filtro de relleno de la sc-cache,
# ESTA VEZ CON MODOS DE TEXTO.
#
# POR QUE EXISTE ESTE FICHERO. La rc4 rompio el modo texto en placa (menu y
# MSX-DOS ilegibles). El cambio era "solo los SPRITES rellenan la sc-cache", y
# el razonamiento para darlo por seguro fue "el fondo va por la VENTANA, no por
# esta cache". Eso es cierto EN MODOS BITMAP, donde el barrido es lineal. En
# TEXTO no: la tabla de patrones se accede INDEXADA POR EL CODIGO DE CARACTER, y
# un prefetch lineal no puede servir eso — quien lo servia era la cache.
#
# Y LA BATERIA NO LO CAZO PORQUE NO PODIA: sus tres bancos son tb_sc8cmd_full
# (SCREEN 8), tb_sc5line (SCREEN 5) y tb_cpu_bulk (escrituras de CPU). NINGUNO
# configura un modo de texto. Los que si lo hacen —tb_textgeom (R#0=0x00) y
# tb_screen1 (R#0=0x00)— estaban en el directorio sin usar.
#
# LA LECCION, que es lo que hay que llevarse: cuando se toca un recurso
# COMPARTIDO (esta cache la usan fondo, sprites, CPU y comandos), la regresion
# tiene que cubrir A CADA CONSUMIDOR, no "la bateria de siempre".
#
# COMPARA DOS SHIMS:
#   BASE  = el arbol actual con el filtro DESACTIVADO (= lo que lleva la rc3,
#           que Albert valido en placa: incluye el arreglo del SP2)
#   FIX   = el arbol actual tal cual (filtro estrecho: todos MENOS comandos)
# Comparar contra HEAD seria injusto: HEAD no lleva el SP2.
#
# Uso:  bash run_regresion_165b.sh
# ============================================================================
set -u
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
S=$M/tools/v9968_sim
OUT=$S/logs/reg165b
LOG=$S/logs/regresion_165b.log
mkdir -p "$OUT" "$S/logs"
: > "$LOG"

SHIM_FIX=$M/fpga/src/v9968_vram_shim.v
SHIM_BASE=$OUT/shim_base.v

# El BASE se fabrica revirtiendo SOLO la condicion del filtro. Asi la unica
# diferencia entre los dos ficheros es esa linea: ni una variable mas.
sed 's/if (!pf_dirty \&\& (cur_tag\[4:2\] != C_COMMAND)) begin/if (!pf_dirty) begin/' \
    "$SHIM_FIX" > "$SHIM_BASE"
if ! diff -q "$SHIM_FIX" "$SHIM_BASE" > /dev/null; then
    echo "OK: BASE y FIX difieren (solo en la condicion del filtro)"      | tee -a "$LOG"
else
    echo "ABORTADO: el sed no encontro la linea del filtro"               | tee -a "$LOG"; exit 1
fi

# --------------------------------------------------------------------------
run_bank () {          # $1 = tb ; $2 = shim ; $3 = etiqueta ; $4.. = plusargs
    local tb=$1 shim=$2 tag=$3; shift 3
    local d=$OUT/$tag/$tb
    rm -rf "$d"; mkdir -p "$d"; cd "$d" || return 1
    iverilog -g2012 -I"$S" -o sim.out -s "$tb" \
        "$S/$tb.sv" "$shim" $M/fpga/v9968/*.v > build.log 2>&1
    if [ ! -x sim.out ] && [ ! -f sim.out ]; then
        echo "  $tag/$tb : NO COMPILA"                                    | tee -a "$LOG"
        grep -m3 -iE "error" build.log | sed 's/^/      /'                | tee -a "$LOG"
        return 1
    fi
    for pa in "${@:-}"; do
        timeout 900 stdbuf -oL vvp sim.out $pa > "run$pa.log" 2>&1
        printf '  %-6s %-16s %-10s ' "$tag" "$tb" "${pa:-.}"              | tee -a "$LOG"
        grep -hoiE "OK|PASS|FALLO|FAIL|DIFFS?=[0-9]+|ERROR|TIMEOUT|diffs [0-9]+" "run$pa.log" \
            | sort -u | tr '\n' ' '                                       | tee -a "$LOG"
        echo ""                                                           | tee -a "$LOG"
    done
}

echo ""                                                                   | tee -a "$LOG"
echo "########## MODOS DE TEXTO (lo que rompio la rc4) ##########"        | tee -a "$LOG"
for tag in BASE FIX; do
    sh=$SHIM_BASE; [ "$tag" = FIX ] && sh=$SHIM_FIX
    run_bank tb_textgeom "$sh" "$tag" "+MODE=0" "+MODE=1" "+MODE=2" &
    run_bank tb_screen1  "$sh" "$tag" ""                              &
    run_bank tb_t2cursor "$sh" "$tag" ""                              &
done
wait

echo ""                                                                   | tee -a "$LOG"
echo "########## BITMAP + COMANDOS (lo que ya pasaba) ##########"         | tee -a "$LOG"
for tag in BASE FIX; do
    sh=$SHIM_BASE; [ "$tag" = FIX ] && sh=$SHIM_FIX
    run_bank tb_screen5c "$sh" "$tag" "" &
    run_bank tb_screen8  "$sh" "$tag" "" &
done
wait

echo ""                                                                   | tee -a "$LOG"
echo "log: $LOG"
