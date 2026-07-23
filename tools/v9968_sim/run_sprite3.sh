#!/bin/bash
# run_sprite3.sh — reproduce el thrashing de la cache de sprites mode3:
# compila tb_sprite3 (shim) y tb_sprite3r (perfecta), corre las dos, y
# compara los volcados de frame. diffs > 0 = glitch del shim reproducido.
M=/mnt/c/Users/alber/proyectosAI/msx/MSX_up
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf sprite3 && mkdir sprite3 && cd sprite3

verilate_one () {
    local tb=$1
    mkdir -p $tb && cd $tb
    verilator --binary --timing -j 8 -Wno-fatal -Wno-BLKANDNBLK \
        -I$M/tools/v9968_sim \
        --top-module $tb \
        $M/tools/v9968_sim/$tb.sv \
        $W/fpga/src/v9968_vram_shim.v \
        $W/fpga/src/v9968_sdram_bridge.v \
        $W/fpga/src/memory.v \
        $M/tools/sdr16_tb/w9825_model.v \
        $W/fpga/v9968/*.v > verilate.log 2>&1
    if [ -x obj_dir/V$tb ]; then
        timeout 900 ./obj_dir/V$tb > out.log 2>&1
        echo "== $tb =="; grep -E 'SETUP|COMPLETO|VOLCADO|TIMEOUT' out.log | tail -3
    else
        echo "== $tb VERILATE FALLO =="; grep '%Error' verilate.log | head -6
    fi
    cd ..
}

verilate_one tb_sprite3
verilate_one tb_sprite3r

SA=/tmp/sprite3/tb_sprite3/s3_frame.txt
SB=/tmp/sprite3/tb_sprite3r/s3r_frame.txt
if [ -f "$SA" ] && [ -f "$SB" ]; then
    la=$(wc -l < "$SA"); lb=$(wc -l < "$SB")
    d=$(diff "$SA" "$SB" | grep -c '^[<>]')
    echo "----------------------------------------"
    echo "shim=$la lineas  perfecta=$lb lineas  DIFFS=$d"
    if [ "$la" = "$lb" ] && [ "$d" = "0" ]; then
        echo "*** SPRITE3: SIN GLITCH (shim == perfecta) ***"
    else
        echo "*** SPRITE3: GLITCH REPRODUCIDO ($d lineas distintas) ***"
    fi
else
    echo "FALTA algun volcado (SA=$SA SB=$SB)"
fi
