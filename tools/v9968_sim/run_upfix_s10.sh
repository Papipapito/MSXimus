#!/bin/bash
# S#10 no debe borrar el interrupt de fin de comando (solo vdp_cpu_interface).
# W se puede sobreescribir por entorno (para correr sobre una copia).
set -e
W=${UPFIX_W:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up_th9958}
cd /tmp && rm -rf tbupfixs10 && mkdir tbupfixs10 && cd tbupfixs10
iverilog -g2012 -o sim -s tb_upfix_s10 \
  "$W/tools/v9968_sim/tb_upfix_s10.sv" \
  "$W/fpga/v9968/vdp_cpu_interface.v"
vvp sim
