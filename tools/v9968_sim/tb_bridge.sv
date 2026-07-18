// tb_bridge.sv — unit test del CDC v9968_sdram_bridge (85.909 <-> 108 MHz).
// 200 ops aleatorias; el lado 108 emula memory.v (concesion tras latencia
// aleatoria, palabra = funcion conocida de la direccion) y el test comprueba
// que cada respuesta vuelve integra y en orden.
`timescale 1ns/1ps

module tb_bridge;

logic clk_vdp = 0, clk_108 = 0, rst_n = 0;
always #5.8207 clk_vdp = ~clk_vdp;   // 85.909 MHz
always #4.6296 clk_108 = ~clk_108;   // 108 MHz

logic        bk_req = 0, bk_we = 0;
logic [21:0] bk_addr = 0;
logic [7:0]  bk_wdata = 0;
wire  [15:0] bk_rword;
wire         bk_done_t;

wire         wv2_req, wv2_we;
wire  [21:0] wv2_addr;
wire  [7:0]  wv2_wdata;
logic [15:0] wv2_dout = 0;
logic        wv2_done = 0;

v9968_sdram_bridge dut (
    .clk_vdp(clk_vdp), .rst_n(rst_n),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .clk_108m(clk_108),
    .wv2_req(wv2_req), .wv2_we(wv2_we), .wv2_addr(wv2_addr),
    .wv2_wdata(wv2_wdata), .wv2_dout(wv2_dout), .wv2_done(wv2_done)
);

// lado 108: emula memory.v — al ver req nivel, espera latencia aleatoria,
// responde palabra funcion de addr y pulsa done 1 ciclo
integer lat;
logic busy108 = 0, inflight108 = 0;   // inflight = regla wv_inflight de memory.v
logic [7:0] wr_mem [0:4194303];
always @(posedge clk_108) begin
    wv2_done <= 0;
    if (inflight108 && !wv2_req) inflight108 <= 0;
    if (wv2_req && !busy108 && !inflight108) begin
        busy108 <= 1;
        inflight108 <= 1;
        lat <= 5 + ({$random} % 40);
    end
    else if (busy108) begin
        if (lat == 0) begin
            if (wv2_we) wr_mem[wv2_addr] <= wv2_wdata;
            wv2_dout <= { wv2_addr[7:0] ^ 8'hA5, wv2_addr[15:8] ^ 8'h3C };
            wv2_done <= 1;
            busy108 <= 0;
        end
        else lat <= lat - 1;
    end
end

// lado 85.9: dispara ops y valida
integer i, errors = 0;
logic done_seen;
logic [21:0] a;
logic [15:0] expect_w;
always @(posedge clk_vdp) if (bk_done_t !== dut.bk_done_t) ; // no-op

initial begin
    repeat (10) @(posedge clk_vdp);
    rst_n = 1;
    repeat (5) @(posedge clk_vdp);
    for (i = 0; i < 200; i = i + 1) begin
        a = {$random} % 4194304;
        @(posedge clk_vdp);
        bk_addr  <= a;
        bk_we    <= (i % 3 == 0);
        bk_wdata <= a[7:0] + 8'd7;
        bk_req   <= 1;
        @(posedge clk_vdp);
        bk_req <= 0;
        // esperar el toggle de done
        done_seen = bk_done_t;
        fork : wait_done
            begin
                wait (bk_done_t !== done_seen);
                disable wait_done;
            end
            begin
                repeat (2000) @(posedge clk_vdp);
                $display("ERROR op %0d: TIMEOUT sin done", i);
                errors = errors + 1;
                disable wait_done;
            end
        join
        @(posedge clk_vdp);
        expect_w = { a[7:0] ^ 8'hA5, a[15:8] ^ 8'h3C };
        if (!bk_we && bk_rword !== expect_w) begin
            $display("ERROR op %0d: addr=%h rword=%h esperado=%h", i, a, bk_rword, expect_w);
            errors = errors + 1;
        end
        if (bk_we && wr_mem[a] !== (a[7:0] + 8'd7)) begin
            $display("ERROR op %0d: escritura addr=%h mem=%h esperado=%h",
                     i, a, wr_mem[a], a[7:0] + 8'd7);
            errors = errors + 1;
        end
        // hueco aleatorio entre ops
        repeat ({$random} % 8) @(posedge clk_vdp);
    end
    if (errors == 0) $display("*** BRIDGE CDC: 200/200 OPS OK ***");
    else             $display("*** BRIDGE CDC: %0d ERRORES ***", errors);
    $finish;
end

initial begin
    #4000000;
    $display("TIMEOUT GLOBAL i=%0d errors=%0d", i, errors);
    $finish;
end

endmodule
