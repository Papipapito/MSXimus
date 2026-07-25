#!/bin/bash
# Bateria del arbol MIGRADO th9958.
# _148: los TB salen AHORA del WORKTREE, no de MSX_up. Motivo: el bus de
# escritura del shim paso a PALABRA de 32b + mascara (FIX B) y los TB de main
# siguen con el bk_wdata de 8 bits — compilarlos contra este shim daria una
# VRAM mal escrita (solo el byte 0 de cada palabra) y un falso rojo.
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
TBS="${@:-tb_scroll tb_sc8cmd_full tb_sc5line tb_cpu_bulk}"
cd /tmp && rm -rf v9968th && mkdir v9968th && cd v9968th
for tb in $TBS; do
    mkdir -p $tb && cd $tb
    verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
        --top-module $tb \
        $W/tools/v9968_sim/$tb.sv \
        $W/fpga/src/v9968_vram_shim.v \
        $W/fpga/src/v9968_sdram_bridge.v \
        $W/fpga/src/memory.v \
        $M/tools/sdr16_tb/w9825_model.v \
        $W/fpga/v9968/*.v > verilate.log 2>&1
    if [ -x obj_dir/V$tb ]; then
        timeout 700 ./obj_dir/V$tb > out.log 2>&1
        echo "==== $tb (th9958) ===="
        grep -E 'TURNOS|RESULTADO|FULL:|FIN|OK|FALLO|TIMEOUT|diffs|DIFF|BANCO|SCROLL:' out.log | tail -5
    else
        echo "==== $tb (th9958) ==== VERILATE FALLO"
        grep '%Error' verilate.log | head -5
    fi
    cd ..
done
