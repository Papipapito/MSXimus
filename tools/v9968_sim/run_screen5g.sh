#!/bin/bash
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
iverilog -g2012 -o /tmp/v9968_s5g.out -s tb_screen5g tb_screen5g.sv /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968/*.v
stdbuf -oL vvp /tmp/v9968_s5g.out