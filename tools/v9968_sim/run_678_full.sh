#!/bin/bash
# run_678_full.sh — _120: shim (canal dual + valid retrasado) Y referencias
# con la linea temporal acelerada (volcado en vs 7, fill a ritmo backpressure)
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v
iverilog -g2012 -o /tmp/s8f.out -s tb_screen8  tb_screen8.sv  "$SHIM" "$CORE"/*.v
iverilog -g2012 -o /tmp/s7f.out -s tb_screen7  tb_screen7.sv  "$SHIM" "$CORE"/*.v
iverilog -g2012 -o /tmp/s6f.out -s tb_screen6  tb_screen6.sv  "$SHIM" "$CORE"/*.v
iverilog -g2012 -o /tmp/s8r.out -s tb_screen8r tb_screen8r.sv "$CORE"/*.v
iverilog -g2012 -o /tmp/s7r.out -s tb_screen7r tb_screen7r.sv "$CORE"/*.v
iverilog -g2012 -o /tmp/s6r.out -s tb_screen6r tb_screen6r.sv "$CORE"/*.v
echo COMPILA_OK
vvp /tmp/s8f.out > s8f_run.log 2>&1 &
vvp /tmp/s7f.out > s7_run.log  2>&1 &
vvp /tmp/s6f.out > s6_run.log  2>&1 &
vvp /tmp/s8r.out > s8r_run.log 2>&1 &
vvp /tmp/s7r.out > s7r_run.log 2>&1 &
vvp /tmp/s6r.out > s6r_run.log 2>&1 &
wait
echo SIMS_DONE
grep -h COMPLETO s8f_run.log s7_run.log s6_run.log s8r_run.log s7r_run.log s6r_run.log
grep -h "LINEA" s8f_run.log | head -20