#!/bin/bash
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
iverilog -g2012 -o /tmp/v9968_s5f.out -s tb_screen5f tb_screen5f.sv /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968/*.v
vvp /tmp/v9968_s5f.out