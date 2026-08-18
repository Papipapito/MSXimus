cd "$(dirname "$0")"
RTL="$(ls ../../fpga/v9968/*.v | tr '\n' ' ') ../../fpga/src/v9968_vram_shim.v ../../fpga/src/v9968_cpu_glue.v"
echo "--- elaboracion del RTL integrado (tb_lmmcseam como arnes):"
iverilog -g2012 -o /tmp/elab.vvp tb_lmmcseam.sv $RTL 2>&1 | head -12
echo "EXIT=$?"
