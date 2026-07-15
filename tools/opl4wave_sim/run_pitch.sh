#!/bin/bash
# run_pitch.sh — mide el pitch real del motor (tb_yrw801) con varios FNUM/OCT
# (_104c: validacion del fix del reg 0x38). Uso: wsl bash run_pitch.sh
set -e
cd "$(dirname "$0")"
iverilog -g2012 -s tb_yrw801 -o /tmp/tby104c.out \
    tb_yrw801.v ../../fpga/src/opl4_pcm.v ../../fpga/opl4wave/ymf278b_gowin.v

run() {  # run <tag> <wave> <fnum> <oct>
    vvp /tmp/tby104c.out +wave=$2 +fnum=$3 +oct=$4 +nsamp=2400 > /tmp/pitch_log_$1.txt 2>&1
    mv pcm_dump.txt pitch_$1.txt
    echo "dump $1: wave=$2 fnum=$3 oct=$4 -> $(wc -l < pitch_$1.txt) muestras ($(grep -c VOLCADAS /tmp/pitch_log_$1.txt) ok)"
}

run A 303 0   1
run B 303 699 0
run C 303 910 0
run D 303 194 1
run E 303 424 1
