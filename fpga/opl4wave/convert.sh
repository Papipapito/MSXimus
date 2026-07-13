#!/bin/bash
# Regenera ymf278b_gowin.v desde las fuentes SystemVerilog (motor PCM OPL4).
# Requiere sv2v (https://github.com/zachjs/sv2v) — en WSL: ~/bin/sv2v.
# El build de Gowin usa SOLO ymf278b_gowin.v; los .sv son la fuente mantenida.
set -e
cd "$(dirname "$0")"
SV2V=$(command -v sv2v || echo ~/bin/sv2v)
$SV2V YMF278B_pkg.sv YMF278B.sv > ymf278b_gowin.v
python3 postproc.py ymf278b_gowin.v   # init a 0 (semantica `bit`) — ver postproc.py
echo "OK: ymf278b_gowin.v regenerado ($(wc -l < ymf278b_gowin.v) lineas)"
