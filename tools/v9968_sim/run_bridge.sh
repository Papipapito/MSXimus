#!/bin/bash
# run_bridge.sh — unit test del CDC v9968_sdram_bridge
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
iverilog -g2012 -o /tmp/v9968_bridge.out -s tb_bridge tb_bridge.sv \
  /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_sdram_bridge.v
vvp /tmp/v9968_bridge.out
