#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Igual que run.sh pero con el chip GENERADO POR GHDL (fpga/src/scc_wave2_ghdl.v,
# convertido desde src/ocm/scc_wave2.vhd) en lugar del scc_wave2v.v manual.
# El TB scc_tb_ghdl.v es copia de scc_tb.v con la instancia cambiada a scc_wave2.
#
#   Uso (desde Windows):
#     wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/scc_tb && bash run_ghdl.sh"
#
# Sale con codigo 0 si "RESULT: PASS". Para ondas: bash run_ghdl.sh --dump
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

TB="scc_tb_ghdl.v"
SRC="../../fpga/src"
OUT="/tmp/scc_tb_ghdl.vvp"
LOG="/tmp/scc_tb_ghdl.log"

DUMP=""
if [ "${1:-}" = "--dump" ]; then
    DUMP="-DDUMP"
fi

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog no esta instalado. En WSL:  sudo apt-get install -y iverilog" >&2
    exit 127
fi

iverilog -g2012 $DUMP -o "$OUT" "$TB" "$SRC/scc_glue.v" "$SRC/scc_wave2_ghdl.v" "$SRC/megaram.v"
vvp "$OUT" | tee "$LOG"
grep -q "RESULT: PASS" "$LOG"
