#!/bin/bash
# run_ddr3_backend.sh — banco del backend DDR3 de la VRAM (bridges reales +
# backend real + modelo conductual de la IP)
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf ddr3bk && mkdir ddr3bk && cd ddr3bk
verilator --binary --timing -j 4 -Wno-fatal -Wno-BLKANDNBLK \
    --top-module tb_ddr3_backend \
    $W/tools/v9968_sim/tb_ddr3_backend.sv \
    $W/tools/v9968_sim/ddr3_ip_model.sv \
    $W/fpga/src/v9968_ddr3_backend.v \
    $W/fpga/src/v9968_sdram_bridge.v > verilate.log 2>&1 || { echo VERILATE FALLO; grep '%Error' verilate.log | head -8; exit 1; }
timeout 300 ./obj_dir/Vtb_ddr3_backend > out.log 2>&1 || true
grep -E 'CALIB|T[0-9]|FALLO|TODO OK|Error' out.log | head -25
