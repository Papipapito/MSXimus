// tb_probe98 — ¿por que el latch s020 caza el 0x99 y JAMAS el 0x98?
// Reproduce el latch VERBATIM de top.v y le da ciclos IN realistas del Z80
// (3.58MHz sobre clk 54M, con y sin estiron de /WAIT), puertos 98 y 99,
// y ademas el caso INIR (B en el byte alto del bus).
`timescale 1ns/1ps
module tb_probe98;

logic clk54 = 0;
always #9.26 clk54 = ~clk54;   // 54 MHz

logic [15:0] bus_addr = 16'hFFFF;
logic bus_iorq_n = 1, bus_m1_n = 1, bus_rd_n = 1, bus_wr_n = 1;
logic [7:0] vdp_dout = 8'h00;

wire vdp_io_hit = ( bus_addr[7:2] == 6'b100110 );
wire vdp_csr_n  = (vdp_io_hit == 1 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 0:1;

// ==== latch s020 VERBATIM ====
reg  [1:0] s20_csr_s   = 2'b11;
reg  [7:0] s20_last99  = 8'd0;
reg  [7:0] s20_cnt99   = 8'd0;
reg  [7:0] s20_last98  = 8'd0;
reg  [7:0] s20_cnt98   = 8'd0;
always @(posedge clk54) begin
    s20_csr_s <= { s20_csr_s[0], vdp_csr_n };
    if( s20_csr_s == 2'b01 ) begin
        if( bus_addr[1:0] == 2'b01 ) begin
            s20_last99 <= vdp_dout;  s20_cnt99 <= s20_cnt99 + 8'd1;
        end
        else if( bus_addr[1:0] == 2'b00 ) begin
            s20_last98 <= vdp_dout;  s20_cnt98 <= s20_cnt98 + 8'd1;
        end
    end
end

// ciclo IN del Z80 (T=279ns): addr desde T1, IORQ+RD en T2..T3, hold de addr
task z80_in(input [15:0] port_addr, input [7:0] dat, input integer wait_ns, input [15:0] next_addr);
begin
    bus_addr = port_addr;         // T1: direccion en el bus
    #279;
    bus_iorq_n = 0; bus_rd_n = 0; // T2
    #(279*1.5 + wait_ns);         // TW (estiron /WAIT) + T3
    vdp_dout = dat;
    #279;
    bus_iorq_n = 1; bus_rd_n = 1; // fin del ciclo
    #140;                          // hold de la direccion (~T/2)
    bus_addr = next_addr;          // el bus pasa al siguiente fetch (M1)
    #558;
end
endtask

initial begin
    #200;
    // 3 lecturas de status 0x99 (poll con addr siguiente "normal")
    z80_in(16'h0099, 8'hAC, 0,    16'h2bf8);
    z80_in(16'hFF99, 8'hAC, 0,    16'h2bfa);   // IN A,(99): A en el byte alto
    z80_in(16'h0099, 8'h80, 800,  16'h2bf8);   // con estiron /WAIT
    // 3 lecturas de datos 0x98 (IN A,(98) y INIR con B alto)
    z80_in(16'h0098, 8'h5A, 0,    16'h4001);
    z80_in(16'h7F98, 8'h5B, 2000, 16'h4003);   // INIR: B=0x7F alto, /WAIT largo
    z80_in(16'h0098, 8'h5C, 0,    16'h4005);
    #500;
    $display("cnt99=%0d last99=%02x  cnt98=%0d last98=%02x  (esperado 3/ac|80 y 3/5c)",
             s20_cnt99, s20_last99, s20_cnt98, s20_last98);
    if (s20_cnt98 == 0) $display("*** REPRODUCIDO: el canal 98 NUNCA latchea ***");
    else if (s20_cnt98 != 3) $display("*** PARCIAL: latchea %0d de 3 ***", s20_cnt98);
    else $display("*** el latch es CORRECTO en estas condiciones — el bug esta en otra parte ***");
    $finish;
end
endmodule
