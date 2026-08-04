module probe_sa;
// era v3: volcado del grupo SA/LA/EA en cada CYCLE0_CE — para comparar el
// TDM (una BSRAM + barridos) contra los 7 arrays originales. Cada linea:
// tiempo, CYCLE_NUM, SLOT/OP2/OP3/OP4.SLOT, LOAD, y los tres Q.
integer fd;
initial fd = $fopen("sa_trace.txt", "w");
`define ENG tb_yrw801.dut.u_engine
// OP2 aplanado por sv2v: [44:40]=SLOT (los offsets de pipeline son fijos,
// con SLOT y CYCLE_NUM basta para reconstruir las direcciones)
always @(posedge tb_yrw801.clk_eng) begin
  if (`ENG.CYCLE0_CE)
    $fdisplay(fd, "%0t c%0d s%0d ra%0d SA=%h LA=%h EA=%h",
      $time, `ENG.CYCLE_NUM, `ENG.SLOT, `ENG.SA_RA,
      `ENG.REG_SA_Q, `ENG.REG_LA_Q, `ENG.REG_EA_Q);
  // escrituras LOAD del grupo SA (pos 0..6): momento y direccion reales
  // (aplanado sv2v: OP3[57]=LOAD, OP3[56:53]=LOAD_POS, OP3[65:61]=SLOT)
  if (`ENG.SLOT0_CE && `ENG.OP3[57])
    $fdisplay(fd, "%0t W c%0d s%0d pos%0d o3slot%0d dato=%h",
      $time, `ENG.CYCLE_NUM, `ENG.SLOT, `ENG.OP3[56:53],
      `ENG.OP3[65-:5], `ENG.MEM_D);
end
endmodule
