#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Simulacion del SCC del port Console 60K (glue + chip + megaram) con Icarus.
# Instancia LOS MISMOS ficheros RTL que el bitstream:
#   fpga/src/scc_glue.v  fpga/src/scc_wave2v.v  fpga/src/megaram.v
#
#   Prerequisito (una vez):  sudo apt-get install -y iverilog   (en WSL)
#   Uso (desde Windows):
#     wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/scc_tb && bash run.sh"
#
# Sale con codigo 0 si "RESULT: PASS", !=0 si falla (usable en CI / por Claude).
# Para volcar ondas: bash run.sh --dump  (genera scc_tb.vcd)
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

TB="scc_tb.v"
SRC="../../fpga/src"
OUT="/tmp/scc_tb.vvp"
LOG="/tmp/scc_tb.log"

DUMP=""
if [ "${1:-}" = "--dump" ]; then
    DUMP="-DDUMP"
fi

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog no esta instalado. En WSL:  sudo apt-get install -y iverilog" >&2
    exit 127
fi

iverilog -g2012 $DUMP -o "$OUT" "$TB" "$SRC/scc_glue.v" "$SRC/scc_wave2v.v" "$SRC/megaram.v"
vvp "$OUT" | tee "$LOG"
grep -q "RESULT: PASS" "$LOG"
