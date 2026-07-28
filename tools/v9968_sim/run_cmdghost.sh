#!/bin/bash
# Banco de SISTEMA del "rectangulo fantasma" (bug #2 + #2b): vdp + shim +
# modelo de SDRAM, con el R#46 del comando nuevo colocado ciclo a ciclo dentro
# del flush del comando anterior (de solo lectura).
# PASA (15/15) solo con los DOS arreglos: el de vdp_command_cache.v (ff_busy en
# el cierre del flush) y el de vdp_command.v (guarda de w_cache_flush_end).
# uso: bash run_cmdghost.sh            -> RTL del repo
#      bash run_cmdghost.sh <dir>      -> RTL de otro arbol (A/B)
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
DIR="${1:-$M/fpga/v9968}"
cd /tmp && rm -rf cmdghost && mkdir cmdghost && cd cmdghost
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK -DK_TRACE=99 \
    --top-module tb_cmdghost \
    $M/tools/v9968_sim/tb_cmdghost.sv \
    $M/fpga/src/v9968_vram_shim.v \
    $DIR/*.v > verilate.log 2>&1
if [ -x obj_dir/Vtb_cmdghost ]; then
    timeout 1800 ./obj_dir/Vtb_cmdghost > out.log 2>&1
    grep -E 'fila=|ACTIVIDAD|RESULTADO|GHOST|AVISO' out.log
else
    echo "VERILATE FALLO"; grep '%Error' verilate.log | head -5
fi
