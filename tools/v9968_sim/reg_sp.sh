cd "$(dirname "$0")"
RTL="$(ls ../../fpga/v9968/*.v | tr '\n' ' ') ../../fpga/src/v9968_vram_shim.v ../../fpga/src/v9968_cpu_glue.v"
iverilog -g2012 -o sp.vvp tb_spcol.sv $RTL 2>&1 | grep -iE "error" | head -3
for V in 2 5; do
  echo "########## tb_spcol +VMODE=$V   ($([ $V = 2 ] && echo 'DQ2, sprites modo 1' || echo 'Fleet, sprites modo 2'))"
  timeout 2400 vvp sp.vvp +VMODE=$V 2>&1 | grep -viE "^VCD|dumpfile" | tail -18
done
echo "########## FIN SP"
