#!/bin/bash
# run_pan.sh — _116: valida la POLARIDAD del fix de pan de srg320 (5379b34).
# Canon: pan=+3 atenua IZQUIERDA; pan=13 (-3) la deja plena; pan=0 centro.
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/opl4wave_sim
iverilog -g2012 -s tb_yrw801 -o /tmp/typan.out tb_yrw801.v \
    ../../fpga/src/opl4_pcm.v ../../fpga/opl4wave/ymf278b_gowin.v
for p in 0 3 13; do
    vvp /tmp/typan.out +wave=384 +fmt8=1 +nsamp=3000 +pan=$p > /dev/null 2>&1 || true
    mv pcm_dump.txt pan_$p.txt
done
echo "runs completos"
