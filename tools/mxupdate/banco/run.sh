#!/bin/bash
# run.sh - banco de MXUPDATE.COM (banco_mxu.py + red_mxu.py): el .COM de verdad en un Z80 emulado con MSX-DOS, el puente
# de la flash y un ESP32 UNAPI + web de imitacion. En el WSL; una vez: python3 -m pip install --user --break-system-packages z80
# Usa las entregas del 02/10/2026 (60K: files/20261002; MSXnano 2.1.1: ../MSXnano/files/20261002) y las carpetas del
# servidor de desarrollo (MSXimus_zynq/fpga/zynq/ota/servidor). Desde Windows (Git Bash):
#   MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up_v3_port/tools/mxupdate/banco && bash run.sh"
set -e
cd "$(dirname "$0")"
M=/mnt/c/Users/alber/proyectosAI/msx
python3 banco_mxu.py --com ../mxupdate.com \
    --upd60 $M/MSX_up_v3_port/files/20261002/PACK_ES.UPD \
    --updnano $M/MSXnano/files/20261002/NANO_ES.UPD \
    --updnanopack $M/MSXnano/files/20261002/PACK_NANO_ES.UPD \
    --web-nano $M/MSXimus_zynq/fpga/zynq/ota/servidor/msxnano \
    --web-60k $M/MSXimus_zynq/fpga/zynq/ota/servidor/tang60k "$@"
