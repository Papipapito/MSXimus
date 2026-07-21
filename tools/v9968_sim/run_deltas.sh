#!/bin/bash
# radiografia de deltas: compila tb_scroll con SHIM_DBG_DROPS, corre y analiza
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
cd /tmp && rm -rf vdelta && mkdir vdelta && cd vdelta
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK -DSHIM_DBG_DROPS \
    --top-module tb_scroll \
    $M/tools/v9968_sim/tb_scroll.sv \
    $M/fpga/src/v9968_vram_shim.v \
    $M/fpga/src/v9968_sdram_bridge.v \
    $M/fpga/src/memory.v \
    $M/tools/sdr16_tb/w9825_model.v \
    $M/fpga/v9968/*.v > /dev/null 2>&1
timeout 700 ./obj_dir/Vtb_scroll > out.log 2>&1
echo "=== 12 DELTA en fase quieta (t 110-130ms) ==="
grep 'DELTA' out.log | awk -F 't=' '{ if ($2+0 > 110000000000 && $2+0 < 130000000000) print }' | head -12
echo "=== 20 DELTA en fase H-scroll (t>240ms) ==="
grep 'DELTA' out.log | awk -F 't=' '{ if ($2+0 > 240000000000) print }' | head -20
echo "=== histograma de deltas ==="
grep -o 'd=[-0-9]*' out.log | sort | uniq -c | sort -rn | head -12
echo "=== conteo total ==="
grep -c 'DELTA' out.log
cp out.log $M/tools/v9968_sim/deltas.log
