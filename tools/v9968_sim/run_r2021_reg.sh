#!/bin/bash
# run_r2021_reg.sh — _163: REGRESION del port del mapa R#20/R#21 (0683e7e).
#
# El cambio mueve tres bits de sitio (CEIE R#21[7]->R#20[6], ILN R#21[6]->
# R#20[5], y fakeID/ECOM/EVR fusionados en R#21[0]=V58), asi que hay que
# demostrar que nada de lo que dependia de ellos se rompe:
#   1. tb_upfix_s10  — el CEIE se arma (ahora por R#20[6]) y el bug del S#10
#                      sigue arreglado. Es el banco que mas de cerca toca el
#                      cambio.
#   2. tb_upfix_s2vr — el bit VR del S#2 (no deberia verse afectado; control).
#   3. tb_sprite3    — sprites mode3 de la demo ru66 con el valor NUEVO de R#20
#                      (0x9F, el que trae el binario del upstream vivo).
#                      OJO: se usa el flujo ICARUS; el de Verilator esta MUERTO
#                      (run_sprite3.sh lo documenta: da cero trafico de VRAM).
#
# Los guiones canonicos apuntan por defecto al worktree th9958: aqui se les
# fuerza a ESTE arbol con W / UPFIX_W.
#
# Uso:  bash run_r2021_reg.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/.build"
mkdir -p "$OUT" "$HERE/logs"
LOG="$HERE/logs/r2021_reg.log"
: > "$LOG"

echo "########## 1. tb_upfix_s10 (CEIE + fix del S#10) ##########" | tee -a "$LOG"
iverilog -g2012 -o "$OUT/s10.out" -s tb_upfix_s10 \
  "$HERE/tb_upfix_s10.sv" "$ROOT/fpga/v9968/vdp_cpu_interface.v" 2>&1 | tee -a "$LOG"
stdbuf -oL vvp "$OUT/s10.out" 2>&1 | tee -a "$LOG" | grep -E "OK|FALLO|BANCO"

echo "" | tee -a "$LOG"
echo "########## 2. tb_upfix_s2vr (control: bit VR del S#2) ##########" | tee -a "$LOG"
iverilog -g2012 -o "$OUT/s2vr.out" -s tb_upfix_s2vr \
  "$HERE/tb_upfix_s2vr.sv" "$ROOT/fpga/v9968/vdp_timing_control_ssg.v" 2>&1 | tee -a "$LOG"
stdbuf -oL vvp "$OUT/s2vr.out" 2>&1 | tee -a "$LOG" | grep -E "OK|FALLO|BANCO|delta"

echo "" | tee -a "$LOG"
echo "########## 3. tb_sprite3 (mode3 ru66 con R#20=0x9F) ##########" | tee -a "$LOG"
W="$ROOT" bash "$HERE/run_sprite3_iv.sh" both 2>&1 | tee -a "$LOG" | tail -25

echo ""
echo "log completo: $LOG"
