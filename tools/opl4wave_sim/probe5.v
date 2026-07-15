module probe5;
// _98: volcado de INSTANTE + VALOR de cada muestra del motor — para medir
// el JITTER de produccion (los stalls DDR3 congelan la CE y las rafagas de
// credito la recuperan: el valor medio es exacto pero cada muestra sale
// cuando puede). El DAC real hace sample-and-hold en esos instantes.
integer fd;
reg tgl_d = 0;
initial fd = $fopen("jitter_dump.txt", "w");
always @(posedge tb_yrw801.clk_eng) begin
  tgl_d <= tb_yrw801.dut.pcm_t_x;
  if (tb_yrw801.dut.pcm_t_x !== tgl_d)
    $fdisplay(fd, "%0t %0d", $time, $signed(tb_yrw801.dut.pcm_l_x));
end
endmodule
