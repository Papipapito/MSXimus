#!/bin/bash
# run_palette_yjk_ab.sh - tb_palette_yjk_ab.sv: vdp_color_palette.v del repo frente al ANTERIOR (b9, ea53294) con el mismo estimulo aleatorio.
# Debe salir identico salvo con YJK y un sprite en curso (el arreglo de Z1.3.2b10: sprites en SCREEN 10/11/12).
# Uso (WSL): bash run_palette_yjk_ab.sh <dir con el vdp_color_palette.v de referencia>
# MSXimus 60K/138K: la referencia buena es el de la Zynq de antes del cambio de sprites, `git show ea53294:fpga/v9968/vdp_color_palette.v`
# en el repo MSXimus_zynq (rama beta): con ella sale TB_OK. Con el de la Zynq b10 (el SRL) salen 0 ciclos distintos (el banco
# dice TB_FAIL solo porque espera algun cambio). Con el de la V3.8.4 sale TB_FAIL a proposito: la paleta de A = 1 tambien cambio.
S="$(cd "$(dirname "$0")" && pwd)"
R="$S/../../fpga/v9968"
B=/tmp/palyjkab_$$; mkdir -p "$B"
if [ -n "$1" ]; then cp "$1/vdp_color_palette.v" "$B/old.v"
else
    echo "uso: run_palette_yjk_ab.sh <dir con el vdp_color_palette.v de referencia> (ver la cabecera)"; exit 1
fi
# el anterior con otro nombre de modulo (comparten vdp_color_palette_ram, que no cambia)
sed -i 's/^module vdp_color_palette[[:space:]]*(/module vdp_color_palette_old (/' "$B/old.v"
grep -q 'module vdp_color_palette_old' "$B/old.v" || { echo "no se pudo renombrar el modulo anterior"; exit 1; }
iverilog -g2012 -o "$B/t.vvp" "$S/tb_palette_yjk_ab.sv" "$R/vdp_color_palette.v" "$R/vdp_color_palette_ram.v" "$B/old.v" || exit 1
vvp -n "$B/t.vvp" | grep -vE "^VCD|dumpfile" | tee "$B/out.log"
grep -q TB_OK "$B/out.log"; E=$?
rm -rf "$B"
exit $E
