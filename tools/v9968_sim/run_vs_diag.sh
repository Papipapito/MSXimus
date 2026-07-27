#!/bin/bash
# Radiografia del residuo VERTICAL post-_137: bateria tb_scroll con
# +define+SHIM_DBG_DROPS (trazas BGMISS/WRAP/DROP) para correlacionar los
# misses con la fase de vscroll (R#23).
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf vs_diag && mkdir vs_diag && cd vs_diag
verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
    --top-module tb_scroll +define+SHIM_DBG_DROPS \
    $M/tools/v9968_sim/tb_scroll.sv \
    $W/fpga/src/v9968_vram_shim.v \
    $W/fpga/src/v9968_sdram_bridge.v \
    $W/fpga/src/memory.v \
    $M/tools/sdr16_tb/w9825_model.v \
    $W/fpga/v9968/*.v > verilate.log 2>&1
if [ -x obj_dir/Vtb_scroll ]; then
    timeout 700 ./obj_dir/Vtb_scroll > out.log 2>&1
    # conservar la traza en disco Windows (el /tmp de WSL se evapora al
    # reiniciarse la VM) — OJO: out.log puede ser grande, filtramos
    DEST=${VS_DIAG_DEST:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958/tools/v9968_sim/vs_diag_out.log}
    grep -E 'BGMISS|WRAP|DROP|PXDIFF|RESULTADO|SCROLL:|FASE|fase' out.log > "$DEST"
    echo "BGMISS totales: $(grep -c BGMISS out.log)"
    grep -E 'RESULTADO|SCROLL:' out.log
    echo "traza filtrada en: $DEST ($(wc -l < "$DEST") lineas)"
else
    echo VERILATE_FALLO
    grep '%Error' verilate.log | head -5
fi
