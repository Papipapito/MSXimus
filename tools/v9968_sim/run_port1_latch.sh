#!/bin/bash
# run_port1_latch.sh — banco de HRA del latch del puerto 1 (tb_port1_latch.sv) sobre NUESTRO vdp_cpu_interface.v.
# Uso: bash run_port1_latch.sh [dir con vdp_cpu_interface.v]   (WSL, Icarus)
set -e
S="$(cd "$(dirname "$0")" && pwd)"
R="${1:-$S/../../fpga/v9968}"
B=/tmp/p1latch_$$; mkdir -p "$B"
iverilog -g2012 -s tb_port1_latch_reset -o "$B/tb.vvp" "$S/tb_port1_latch.sv" "$R/vdp_cpu_interface.v"
vvp -n "$B/tb.vvp" | grep -vE "^VCD|dumpfile"
rm -rf "$B"
