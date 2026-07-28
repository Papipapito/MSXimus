#!/bin/bash
# Bug #1 del INFORME_NIQUELADO: doble ejecucion de una transaccion de I/O que
# cae dentro de una ventana busy / pre-lectura de vdp_cpu_interface.
# Solo vdp_cpu_interface + el glue REAL + modelo de VRAM de latencia variable:
# corre en segundos.
#
# Por defecto: MODE=3 (escrituras encadenadas con maestro ideal — el caso que
# AISLA este bug del #26 del glue) y un barrido de latencias que va de "no pasa
# nada" (40) a las de placa (190 ciclos = 2,2 us, ORIGEN.txt _149) y mas alla.
# ANTES del fix _162: LAT>=120 acaba en BUS ATASCADO. DESPUES: 0 ejecuciones de
# mas y 0 fallos funcionales.
#   MODE=0 lecturas encadenadas   MODE=1 SETRD+IN   MODE=2 escrituras
#   MODE=3 escrituras/maestro ideal   MODE=4 barrido de fase IN->OUT de registro
# Uso: [MODE=n] [FCPU=kHz] run_cpuif_dbl.sh [latencias...]
set -e
W="${MSXUP:-/mnt/c/Users/alber/proyectosAI/msx/MSX_up}"
M="${MODE:-3}"
F="${FCPU:-3580}"
cd /tmp && rm -rf tbcpuifdbl && mkdir tbcpuifdbl && cd tbcpuifdbl
iverilog -g2012 -o sim -s tb_cpuif_dbl \
  "$W/tools/v9968_sim/tb_cpuif_dbl.sv" \
  "$W/fpga/src/v9968_cpu_glue.v" \
  "$W/fpga/v9968/vdp_cpu_interface.v"
for L in ${@:-40 120 200 280}; do
  vvp sim +LAT=$L +N=40 +MODE=$M +FCPU=$F
done
