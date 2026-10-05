#!/bin/bash
# run_slotrd.sh — relectura de registros de slot por 7Fh A LA PRIMERA
# (opl4_pcm.v + motor, con /WAIT). Uso: wsl -d Ubuntu-24.04 -- bash run_slotrd.sh
# Barre tres semillas de fase; falla si alguna lectura no devuelve lo escrito.
set -e
cd "$(dirname "$0")"
iverilog -g2012 -s tb_slotrd -o /tmp/tb_slotrd.out \
    tb_slotrd.v \
    ../../fpga/src/opl4_pcm.v \
    ../../fpga/opl4wave/ymf278b_gowin.v
for seed in ${SEEDS:-1 2 3}; do
    echo "################ semilla $seed ################"
    vvp -n /tmp/tb_slotrd.out +seed=$seed "$@" | tee /tmp/tb_slotrd_$seed.log
done
! grep -L "TODOS LOS TESTS PASAN" $(for s in ${SEEDS:-1 2 3}; do echo /tmp/tb_slotrd_$s.log; done) | grep -q .
