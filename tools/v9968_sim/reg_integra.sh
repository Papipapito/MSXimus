cd "$(dirname "$0")"
RTL="$(ls ../../fpga/v9968/*.v | tr '\n' ' ') ../../fpga/src/v9968_vram_shim.v ../../fpga/src/v9968_cpu_glue.v"
run() {  # nombre, defines, banco
  echo "########## $1"
  iverilog -g2012 -o r_$1.vvp $2 $3 $RTL 2>&1 | grep -iE "error" | head -3
  timeout 900 vvp r_$1.vvp 2>&1 | grep -viE "^VCD|dumpfile|WARNING: .*Port" | tail -8
  echo "   [exit $?]"
}
run seam    ""            tb_lmmcseam.sv
run intsw   ""            tb_intswallow.sv
run spcol1  "-DSPMODE=1"  tb_spcol.sv
run spcol2  "-DSPMODE=2"  tb_spcol.sv
run spcount ""            tb_spcount4.sv
run vsoak   ""            tb_vramsoak_glue.sv
echo "########## FIN DE LA REGRESION"
