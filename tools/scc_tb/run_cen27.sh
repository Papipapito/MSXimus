#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# TB del SCC con el camino REAL de clk_enable_3m6_27 (div30@108M -> PINFILTER
# real @54M -> cadena 8FF @27M -> edge detect) y el chip GHDL a clk_27m --
# replica exacta de top.v:240-328 + 1951. Mismos 21 checks de run.sh + N1
# (avance del puntero ch.A: cambios de valor de scc_wav + toggles dbg_ptr_lsb).
#
#   Uso (desde Windows):
#     wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up/tools/scc_tb && bash run_cen27.sh"
#
# Sale con codigo 0 si "RESULT: PASS". Para ondas: bash run_cen27.sh --dump
# -----------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

TB="scc_tb_cen27.v"
SRC="../../fpga/src"
OUT="/tmp/scc_tb_cen27.vvp"
LOG="/tmp/scc_tb_cen27.log"

DUMP=""
if [ "${1:-}" = "--dump" ]; then
    DUMP="-DDUMP"
fi

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: iverilog no esta instalado. En WSL:  sudo apt-get install -y iverilog" >&2
    exit 127
fi

iverilog -g2012 $DUMP -o "$OUT" "$TB" "$SRC/scc_glue.v" "$SRC/scc_wave2_ghdl.v" "$SRC/megaram.v" "$SRC/wondertang/pinfilter.v"
vvp "$OUT" | tee "$LOG"
grep -q "RESULT: PASS" "$LOG"
