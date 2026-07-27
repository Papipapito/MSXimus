#!/bin/bash
# Rastro del cursor: lecturas de VRAM del Z80 via v9968_cpu_glue con TEXT2 dibujando.
set -e
W=/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958
cd /tmp && rm -rf tbt2cpuread && mkdir tbt2cpuread && cd tbt2cpuread
iverilog -g2012 -o sim -s tb_t2cpuread \
  "$W/tools/v9968_sim/tb_t2cpuread.sv" \
  "$W/fpga/src/v9968_cpu_glue.v" \
  "$W/fpga/src/v9968_vram_shim.v" \
  "$W"/fpga/v9968/*.v
for F in "${@:-3580 5370}"; do vvp sim +FCPU=$F; done
