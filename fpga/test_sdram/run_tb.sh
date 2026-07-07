#!/bin/bash
set -e
cd "$(dirname "$0")"
iverilog -g2012 -o tester_tb.vvp tester_tb.v sdram_tester.v ../src/memory.v ../../tools/sdr16_tb/w9825_model.v
vvp tester_tb.vvp
