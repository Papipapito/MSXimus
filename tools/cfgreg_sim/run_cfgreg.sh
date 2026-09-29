#!/bin/bash
# run_cfgreg.sh — V3.7.5: escrituras a los puertos de config (#40-#46) y al mapper (FC-FF) con y sin la etapa de
# registro, 20.000 OUT realistas (Icarus, WSL). Uso: bash run_cfgreg.sh
set -e
S="$(cd "$(dirname "$0")" && pwd)"
iverilog -g2012 -o /tmp/tb_cfgreg.vvp "$S/tb_cfgreg.sv" && vvp -n /tmp/tb_cfgreg.vvp
