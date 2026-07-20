#!/bin/bash
# Bateria de regresion del shim V9968 (Verilator, WSL)
# uso: bash run_battery.sh [tb...]  (por defecto: sc8full + sc5line + bulk)
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
TBS="${@:-tb_sc8cmd_full tb_sc5line tb_cpu_bulk}"
cd /tmp && rm -rf v9968bat && mkdir v9968bat && cd v9968bat
for tb in $TBS; do
    mkdir -p $tb && cd $tb
    verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
        --top-module $tb \
        $M/tools/v9968_sim/$tb.sv \
        $M/fpga/src/v9968_vram_shim.v \
        $M/fpga/src/v9968_sdram_bridge.v \
        $M/fpga/src/memory.v \
        $M/tools/sdr16_tb/w9825_model.v \
        $M/fpga/v9968/*.v > verilate.log 2>&1
    if [ -x obj_dir/V$tb ]; then
        timeout 700 ./obj_dir/V$tb > out.log 2>&1
        echo "==== $tb ===="
        grep -E 'TURNOS|RESULTADO|FULL:|FIN|OK|FALLO|TIMEOUT|diffs|DIFF|BANCO' out.log | tail -6
    else
        echo "==== $tb ==== VERILATE FALLO"
        grep '%Error' verilate.log | head -3
    fi
    cd ..
done
