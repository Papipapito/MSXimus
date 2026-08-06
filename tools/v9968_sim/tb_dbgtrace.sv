// tb_dbgtrace — banco del analizador logico antes de gastar un horno:
// trafico del Z80 (fetches M1 + I/O), luego CORTE de I/O (el cuelgue), y se
// comprueba que (a) congela, (b) vuelca por el UART, (c) lo volcado son los
// ULTIMOS eventos ANTES del corte (que es todo el objetivo del instrumento).
// Sin `string` (iverilog no lo digiere): los hex se decodifican a numeros.
`timescale 1ns/1ps
module tb_dbgtrace;

localparam real CLK_HALF  = 9.26;                  // 54 MHz
localparam integer DIVB   = 53996000/115200;       // ciclos por bit
localparam real BITT      = DIVB * 2.0 * CLK_HALF; // ns por bit

logic clk = 0; always #(CLK_HALF) clk = ~clk;
logic rst_n = 0;

logic [15:0] bus_addr = 16'h0000;
logic [7:0]  cpu_dout = 8'h00, cpu_din = 8'h00;
logic bus_m1_n = 1, bus_iorq_n = 1, bus_mreq_n = 1, bus_rd_n = 1, bus_wr_n = 1;
logic disk_window = 0, trig_manual = 0;
wire  tx, frozen;

dbg_trace #(.QUIET_MS(1), .AW(6), .WARM_IO(8)) dut (     // anillo de 64 para que el banco sea corto
    .clk(clk), .rst_n(rst_n),
    .bus_addr(bus_addr), .cpu_dout(cpu_dout), .cpu_din(cpu_din),
    .bus_m1_n(bus_m1_n), .bus_iorq_n(bus_iorq_n), .bus_mreq_n(bus_mreq_n),
    .bus_rd_n(bus_rd_n), .bus_wr_n(bus_wr_n), .disk_window(disk_window),
    .trig_manual(trig_manual), .tx(tx), .frozen(frozen)
);

// ---- receptor UART: acumula hex y guarda una palabra por linea ----
integer nev = 0, nhdr = 0, ntail = 0;
integer evs [0:255];
integer acc = 0, ndig = 0;
logic [7:0] rb;
integer bi;
initial begin
    forever begin
        @(negedge tx);
        #(BITT*1.5);
        for (bi = 0; bi < 8; bi = bi + 1) begin
            rb[bi] = tx;
            #(BITT);
        end
        if (rb == 8'h0A) begin
            if (ndig == 8) begin evs[nev] = acc; nev = nev + 1; end
            acc = 0; ndig = 0;
        end
        else if (rb >= "0" && rb <= "9") begin acc = (acc<<4) | (rb - "0");      ndig = ndig + 1; end
        else if (rb >= "a" && rb <= "f") begin acc = (acc<<4) | (rb - "a" + 10); ndig = ndig + 1; end
        else if (rb == "T") begin if (ndig == 0) nhdr = nhdr + 1; end
        else if (rb == "D") ntail = ntail + 1;
    end
end

task m1(input [15:0] pc);
begin bus_addr = pc; bus_m1_n = 0; #40; bus_m1_n = 1; #60; end
endtask
task iow(input [15:0] port, input [7:0] d);
begin
    bus_addr = port; cpu_dout = d; bus_iorq_n = 0; bus_wr_n = 0; #60;
    bus_iorq_n = 1; bus_wr_n = 1; #60;
end
endtask

integer i, nloop, nio, tipo;
integer dir;
initial begin
    repeat(4) @(posedge clk); rst_n = 1; repeat(4) @(posedge clk);
    // s032c: PRIMERO comprobar que el silencio del ARRANQUE no dispara
    for (i = 0; i < 30; i = i + 1) m1(16'h0000 + i[15:0]);   // solo fetches
    #3_000_000;                                              // 3 ms de silencio
    if (frozen === 1'b1) begin
        $display("##### ROJO: disparo en el ARRANQUE (sin I/O previa) — el bug de la s032b #####");
        $finish;
    end
    $display("OK: el silencio del arranque NO dispara (calentamiento activo)");
    // 100 eventos "sanos" (el anillo de 64 rota varias veces)
    for (i = 0; i < 100; i = i + 1) begin
        m1(16'h4000 + i[15:0]);
        if (i % 4 == 0) iow(16'h0099, 8'h80 + i[7:0]);
    end
    // ... y el CUELGUE: bucle de 4 instrucciones, CERO I/O
    for (i = 0; i < 40; i = i + 1) m1(16'hFEE0 + (i[15:0] % 4));

    wait (frozen === 1'b1);
    $display("*** CONGELADO por silencio de I/O (el disparador del cuelgue) ***");
    #120_000_000;   // margen real: 64 eventos x 9 chars x 10 bits / 115200 = ~50ms
    $display("cabeceras=%0d  eventos=%0d  colas=%0d", nhdr, nev, ntail);
    nloop = 0; nio = 0;
    for (i = 0; i < nev; i = i + 1) begin
        tipo = (evs[i] >> 28) & 4'hF;
        dir  = (evs[i] >> 4) & 16'hFFFF;
        if (tipo == 0 && dir >= 16'hFEE0 && dir <= 16'hFEE3) nloop = nloop + 1;
        if (tipo == 1) nio = nio + 1;
    end
    $display("  del bucle de la muerte (fee0-fee3): %0d de %0d eventos", nloop, nev);
    $display("  accesos de I/O anteriores al cuelgue: %0d", nio);
    if (nev >= 60 && nloop >= 30)
        $display("##### VERDE: el anillo conserva la VENTANA ANTERIOR AL DISPARO #####");
    else
        $display("##### ROJO: nev=%0d nloop=%0d (esperado ~64 y >=30) #####", nev, nloop);
    $finish;
end
endmodule
