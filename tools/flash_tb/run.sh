#!/bin/bash
# Banco del puente de la flash (V3.8). Uso: ver la cabecera de tb_fbr.sv.
set -e
cd "$(dirname "$0")"
iverilog -g2012 -o tb_fbr.vvp -s tb_fbr tb_fbr.sv ../../fpga/src/flash_rw.v ../../fpga/src/flash_bridge.v
vvp -n tb_fbr.vvp
