module probe_rate;
// era v3: mide el grupo RATE0/1/2+AM antes de fusionarlo (la leccion del
// grupo SA: dos supuestos mios sobre el pipeline eran falsos). Vuelca en
// cada CYCLE0_CE la direccion de lectura efectiva y los cuatro Q, y marca
// las lecturas de CPU (REG_RD) que desvian la direccion al indice del
// registro. Si OP4.SLOT resulta estable todo el slot y REG_RD es raro y
// espaciado, UN barrido por slot + un hueco para la CPU bastan.
integer fd;
initial fd = $fopen("rate_trace.txt", "w");
`define ENG tb_yrw801.dut.u_engine
always @(posedge tb_yrw801.clk_eng) begin
  if (`ENG.CYCLE0_CE)
    $fdisplay(fd, "%0t c%0d s%0d o4=%0d rd%b R0=%h R1=%h R2=%h AM=%h",
      $time, `ENG.CYCLE_NUM, `ENG.SLOT, `ENG.OP4[13-:5], `ENG.REG_RD,
      `ENG.REG_RATE0_Q, `ENG.REG_RATE1_Q, `ENG.REG_RATE2_Q, `ENG.REG_AM_Q);
  // toda lectura de CPU: cuantas hay y con que separacion
  if (`ENG.REG_RD)
    $fdisplay(fd, "%0t CPURD a=%h", $time, `ENG.REG_A);
end
endmodule
