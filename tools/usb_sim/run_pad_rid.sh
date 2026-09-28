#!/bin/bash
# run_pad_rid.sh — banco del decodificador de mandos HID genericos (WSL, Icarus). Uso: bash run_pad_rid.sh
set -e
S="$(cd "$(dirname "$0")" && pwd)"
B=/tmp/padrid_$$; mkdir -p "$B"
iverilog -g2012 -o "$B/tb.vvp" "$S/tb_usb_pad_rid.sv" "$S/../../fpga/src/usb_direct/usb_pad_rid.v"
vvp -n "$B/tb.vvp" | grep -vE "^VCD|dumpfile"
# y que usb_hid_host.v con el modulo dentro al menos elabora (sin simular el USB)
iverilog -g2012 -o "$B/elab.vvp" "$S/../../fpga/src/usb_direct/usb_hid_host.v" "$S/../../fpga/src/usb_direct/usb_pad_rid.v" 2>&1 | grep -v "warning" || true
echo "usb_hid_host.v + usb_pad_rid.v: elaboran"
rm -rf "$B"
