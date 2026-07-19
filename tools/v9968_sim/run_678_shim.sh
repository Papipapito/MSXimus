#!/bin/bash
# run_678_shim.sh — _120 canal dual: solo los TBs con shim (las referencias
# s6r/s7r/s8r ya estan volcadas y no dependen del shim).
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
CORE=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/v9968
SHIM=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/src/v9968_vram_shim.v

iverilog -g2012 -o /tmp/s8f.out -s tb_screen8 tb_screen8.sv "$SHIM" "$CORE"/*.v
iverilog -g2012 -o /tmp/s7f.out -s tb_screen7 tb_screen7.sv "$SHIM" "$CORE"/*.v
iverilog -g2012 -o /tmp/s6f.out -s tb_screen6 tb_screen6.sv "$SHIM" "$CORE"/*.v
echo COMPILA_OK

vvp /tmp/s8f.out > s8f_run.log 2>&1 &
vvp /tmp/s7f.out > s7_run.log  2>&1 &
vvp /tmp/s6f.out > s6_run.log  2>&1 &
wait
echo SIMS_DONE
tail -n 2 s8f_run.log
tail -n 2 s7_run.log
tail -n 2 s6_run.log
