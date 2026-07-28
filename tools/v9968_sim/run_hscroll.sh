#!/bin/bash
#	run_hscroll.sh — BUG #18 / parche _162: equivalencia CICLO A CICLO del
#	scroll horizontal de los sprites (screen_pos_x_sprite) entre la semantica
#	original de HRA (_ref), el parche _120 (_bug) y el _162 (_fix).
#
#	Uso:   ./run_hscroll.sh [ciclos] [ssg_pre_162.v]
#	         ciclos          por defecto 2900000 (~2 campos NTSC, ~3,5 min)
#	         ssg_pre_162.v   opcional: fichero anterior al _162 del que sacar
#	                         la variante _bug (por defecto se deriva del arbol)
#	Icarus Verilog. En Windows:  wsl -d Ubuntu-24.04 bash tools/v9968_sim/run_hscroll.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SSG="$ROOT/fpga/v9968/vdp_timing_control_ssg.v"
OUT="${TMPDIR:-/tmp}/v9968_hscroll"
CYCLES="${1:-2900000}"
HEADSSG="${2:-}"

mkdir -p "$OUT"
python3 "$HERE/gen_ssg_variants.py" "$SSG" "$OUT/gen" $HEADSSG

iverilog -g2012 -o "$OUT/tb_hscroll_sprite.out" -s tb_hscroll_sprite \
	"$HERE/tb_hscroll_sprite.sv" \
	"$OUT/gen/ssg_ref.v" "$OUT/gen/ssg_bug.v" "$OUT/gen/ssg_fix.v"

echo "### pasada A: CON splits de R#27 ($CYCLES ciclos)"
vvp "$OUT/tb_hscroll_sprite.out" +cycles=$CYCLES

echo "### pasada B: SIN escrituras de R#27 (control: no debe haber diferencias)"
vvp "$OUT/tb_hscroll_sprite.out" +cycles=$((CYCLES/4)) +nosplit

#	La pasada C necesita al menos un campo completo (la interrupcion de linea
#	cae en la linea 100 de cada campo): por debajo de ~1,5 M de ciclos no
#	habria NI UN split y el banco lo cantaria como falta de actividad.
if [ "$CYCLES" -ge 1500000 ]; then
	echo "### pasada C: SOLO el split por interrupcion de linea"
	vvp "$OUT/tb_hscroll_sprite.out" +cycles=$CYCLES +isronly
else
	echo "### pasada C OMITIDA: hacen falta >= 1500000 ciclos (un campo) para que salte intr_line"
fi
