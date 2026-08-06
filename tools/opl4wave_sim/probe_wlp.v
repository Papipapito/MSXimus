module probe_wlp;
// era v3: mide el grupo WTN/LEVEL/PAN antes de fusionarlo. Necesito saber
// (a) si SLOT, OP5.SLOT y OP7.SLOT son estables DENTRO de un slot y
// (b) que la direccion del slot SIGUIENTE es, respectivamente, SLOT+1
// (con vuelta en 23), OP4.SLOT y OP6.SLOT — que es lo que el barrido
// pre-frontera tendria que leer. Posiciones aplanadas por sv2v:
// OP4[13-:5], OP5[41-:5], OP6[33-:5], OP7[23-:5].
integer fd;
initial fd = $fopen("wlp_trace.txt", "w");
`define ENG tb_yrw801.dut.u_engine
always @(posedge tb_yrw801.clk_eng) begin
  if (`ENG.CYCLE0_CE)
    $fdisplay(fd, "%0t s%0d o4=%0d o5=%0d o6=%0d o7=%0d",
      $time, `ENG.SLOT, `ENG.OP4[13-:5], `ENG.OP5[41-:5],
      `ENG.OP6[33-:5], `ENG.OP7[23-:5]);
end
endmodule
