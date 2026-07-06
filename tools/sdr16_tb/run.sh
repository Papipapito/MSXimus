#!/bin/bash
# Testbench del memory_ctrl 16-bit (port Console 60K) contra el modelo W9825G6KH.
# Uso (desde Windows):
#   wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/sdr16_tb && bash run.sh"
set -e
cd "$(dirname "$0")"
iverilog -g2012 -o sdr16_tb.vvp memory_tb.v w9825_model.v ../../fpga/src/memory.v
vvp sdr16_tb.vvp
