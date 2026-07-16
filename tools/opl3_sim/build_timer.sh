#!/bin/bash
# build_timer.sh — test unitario _108 del timer canon (patron VGMPlay/MBWave)
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/opl3_sim
SRC=/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/opl3
FILES="$SRC/opl3_pkg.sv $SRC/afifo.v $SRC/opl3.sv $SRC/host_if.sv $SRC/trick_sw_detection.sv $SRC/channels.sv $SRC/control_operators.sv $SRC/dac_prep.sv $SRC/clk_div.sv $SRC/reset_sync.sv $SRC/edge_detector.sv $SRC/leds.sv $SRC/mem_multi_bank.sv $SRC/mem_multi_bank_reset.sv $SRC/mem_simple_dual_port.sv $SRC/mem_simple_dual_port_async_read.sv $SRC/pipeline_sr.sv $SRC/synchronizer.sv $SRC/operator.sv $SRC/calc_envelope_shift.sv $SRC/calc_phase_inc.sv $SRC/calc_rhythm_phase.sv $SRC/envelope_generator.sv $SRC/ksl_add_rom.sv $SRC/opl3_exp_lut.sv $SRC/opl3_log_sine_lut.sv $SRC/phase_generator.sv $SRC/tremolo.sv $SRC/vibrato.sv $SRC/timer.sv $SRC/timers.sv"
rm -rf obj_timer
verilator --cc --exe --build -j 4 -Wno-fatal --Mdir obj_timer --top-module opl3 $FILES tb_timer.cpp 2>&1 | tail -2
./obj_timer/Vopl3
