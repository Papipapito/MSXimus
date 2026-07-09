#!/usr/bin/env bash
# Testbench del puente msx2hdmi (solo lógica: captura + ring + lock + escalado)
# Uso desde Windows:
#   wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/video720/tb && bash run.sh"
set -e
cd "$(dirname "$0")"

echo "== compilando (iverilog -g2012 -DSIM_NO_HDMI) =="
iverilog -g2012 -DSIM_NO_HDMI -o msx2hdmi_tb.vvp ../msx2hdmi.sv msx2hdmi_tb.v

echo "== simulando =="
vvp msx2hdmi_tb.vvp
