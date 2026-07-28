#!/bin/bash
# Banco UNITARIO de vdp_command_cache (bug #2: ff_busy que no baja nadie).
# uso: bash run_cmdcache.sh            -> RTL del repo
#      bash run_cmdcache.sh <dir>      -> RTL de otro arbol (A/B)
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
DIR="${1:-$M/fpga/v9968}"
cd /tmp && rm -rf cmdcache && mkdir cmdcache && cd cmdcache
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
    --top-module tb_cmdcache \
    $M/tools/v9968_sim/tb_cmdcache.sv \
    $DIR/vdp_command_cache.v > verilate.log 2>&1
if [ -x obj_dir/Vtb_cmdcache ]; then
    timeout 300 ./obj_dir/Vtb_cmdcache > out.log 2>&1
    cat out.log
else
    echo "VERILATE FALLO"; grep '%Error' verilate.log | head -5
fi
