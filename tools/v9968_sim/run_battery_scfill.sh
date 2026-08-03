#!/bin/bash
# ============================================================================
# run_battery_scfill.sh — _164: REGRESION del filtro -DSC_FILL_SPRITE_ONLY.
#
# POR QUE HACE FALTA. El experimento de run_cmdthrash.sh demuestra que filtrar
# el relleno de la sc-cache a las lecturas de SPRITE elimina el desalojo que
# provoca el motor de comandos (spmiss/frame en regimen: 1.300 -> 0). Pero ese
# filtro LE QUITA LA CACHE a los otros dos consumidores que hoy la usan: el
# motor de COMANDOS y el puerto de CPU. Si alguno de los dos dependia de sus
# aciertos, esto lo paga en rendimiento o —peor— en correccion.
#
# Los tres bancos de la bateria estandar son justo los que lo tocan:
#   tb_sc8cmd_full : HMMV/HMMM/LMMV con diff byte-exacto  <- el mas expuesto
#   tb_sc5line     : trazado de lineas
#   tb_cpu_bulk    : escrituras masivas por el puerto de CPU
#
# Se corre la bateria DOS VECES, sin y con el define, para poder comparar. Un
# banco que ya falle SIN el define no cuenta como regresion (ver la leccion del
# tb_sc8cmd_full del _163: un gate que siempre sale rojo se deja de mirar).
#
# Uso:  bash run_battery_scfill.sh
# ============================================================================
set -u
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
TBS="tb_sc8cmd_full tb_sc5line tb_cpu_bulk"
OUTLOG=$M/tools/v9968_sim/logs/battery_scfill.log
mkdir -p "$M/tools/v9968_sim/logs"
: > "$OUTLOG"

run_set () {            # $1 = etiqueta ; $2 = defines extra
    local tag=$1 defs=$2
    echo ""                                              | tee -a "$OUTLOG"
    echo "=================== $tag ==================="  | tee -a "$OUTLOG"
    cd /tmp && rm -rf "bat_$tag" && mkdir "bat_$tag" && cd "bat_$tag" || return 1
    for tb in $TBS; do
        mkdir -p "$tb" && cd "$tb" || continue
        # shellcheck disable=SC2086
        verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK $defs \
            --top-module $tb \
            $M/tools/v9968_sim/$tb.sv \
            $M/fpga/src/v9968_vram_shim.v \
            $M/fpga/src/v9968_sdram_bridge.v \
            $M/fpga/src/memory.v \
            $M/tools/sdr16_tb/w9825_model.v \
            $M/fpga/v9968/*.v > verilate.log 2>&1
        if [ -x "obj_dir/V$tb" ]; then
            timeout 700 "./obj_dir/V$tb" > out.log 2>&1
            echo "==== $tb ===="                                     | tee -a "$OUTLOG"
            grep -E 'TURNOS|RESULTADO|FULL:|FIN|OK|FALLO|TIMEOUT|diffs|DIFF|BANCO' \
                 out.log | tail -6                                   | tee -a "$OUTLOG"
        else
            echo "==== $tb ==== VERILATE FALLO"                      | tee -a "$OUTLOG"
            grep '%Error' verilate.log | head -3                     | tee -a "$OUTLOG"
        fi
        cd ..
    done
}

run_set "SIN_FILTRO"  ""
run_set "CON_FILTRO"  "-DSC_FILL_SPRITE_ONLY"

echo ""                                    | tee -a "$OUTLOG"
echo "log: $OUTLOG"
