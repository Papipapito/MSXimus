#!/bin/bash
# run_screen5b.sh — SCREEN5 con ip_sdram de HRA + modelo Micron (latencia real)
set -e
cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/v9968_sim
BASE=/mnt/c/Users/alber/proyectosAI/msx/V9968_Cartridge/fpga/V9968_Cartridge_TangNano20K/src
iverilog -g2012 -o /tmp/v9968_s5b.out -s tb_screen5b tb_screen5b.sv \
    "$BASE"/v9968/*.v \
    "$BASE"/sdram/ip_sdram_tangnano20k_c.v \
    "$BASE"/test_top_SCREEN5_HMMV/MT48LC2M32B2.v
vvp /tmp/v9968_s5b.out
