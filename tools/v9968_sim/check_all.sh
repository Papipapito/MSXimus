#!/bin/bash
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
for t in tb_screen1 tb_screen5c tb_screen5d tb_screen5e tb_screen5g; do
  iverilog -g2012 -o /dev/null -s $t $t.sv /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v /mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968/*.v && echo OK_$t || echo FALLO_$t
done