#!/bin/bash
# run_hid_host.sh — banco del host USB completo (usb_hid_host + usb_pad_rid) contra un dispositivo low-speed
# modelado, barriendo la latencia de respuesta. Uso: bash run_hid_host.sh [DEV=pad|snes|kbd] [LATs...]
# Ejemplo: bash run_hid_host.sh pad 2 3 4 5 6      (WSL, Icarus; se ejecuta desde fpga/ por el $readmemh del ROM)
set -e
S="$(cd "$(dirname "$0")" && pwd)"
DEV="${1:-pad}"; shift || true
LATS="${*:-2 3 4 5 6}"
B=/tmp/hidhost_$$; mkdir -p "$B"
cd "$S/../../fpga"
iverilog -g2012 -o "$B/tb.vvp" "$S/tb_usb_hid_host.sv" "$S/usb_ls_dev_model.sv" \
    src/usb_direct/usb_hid_host.v src/usb_direct/usb_pad_rid.v 2>&1 | grep -v "warning: Static variable" || true
for L in $LATS; do
    vvp -n "$B/tb.vvp" +DEV="$DEV" +LAT="$L" | grep -vE "^VCD|dumpfile"
done
rm -rf "$B"
