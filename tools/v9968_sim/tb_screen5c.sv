// ============================================================================
// tb_screen5c.sv — F1a: el tablero SCREEN5 con NUESTRA pila: core V9968
// PARCHEADO (tag+eco) + v9968_vram_shim + backend con la latencia de la
// SDRAM COMPARTIDA del 60K (300-500ns aleatoria = 26-43 ciclos de 85.9,
// las cifras medidas en la saga wave). Si el tablero sale identico al de
// tb_screen5, el shim cumple el contrato de 8 ciclos con memoria lenta.
// ============================================================================
`timescale 1ns/1ps

module tb_screen5c;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [2:0]  bus_address = 0;
logic        bus_ioreq = 0, bus_write = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;
wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vram_address;
wire         vram_write, vram_valid, vram_refresh;
wire  [31:0] vram_wdata;
wire  [3:0]  vram_wdata_mask;
wire  [4:0]  vram_tag;
wire  [31:0] vram_rdata;
wire         vram_rdata_en;
wire  [4:0]  vram_rtag;
wire         display_hs, display_vs, display_en;
wire  [7:0]  display_r, display_g, display_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_tag(vram_tag), .vram_rtag(vram_rtag),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

wire        bk_req, bk_we;
wire [21:0] bk_addr;
wire [7:0]  bk_wdata;
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire [7:0]  shim_diag;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .diag(shim_diag)
);

// ---- backend: SDRAM compartida modelada (byte write / word16 read,
//      latencia 300-500ns aleatoria = 26-43 ciclos de 85.9) ----
logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [7:0]  m_dat;
integer      m_cnt, m_lat;
integer vi;
initial for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
            if (m_we) sdram[m_addr] <= m_dat;
            else begin
                bk_rword[7:0]  <= sdram[{m_addr[21:1],1'b0}];
                bk_rword[15:8] <= sdram[{m_addr[21:1],1'b1}];
            end
            bk_done_t <= ~bk_done_t;
            m_pend <= 0;
        end
    end
end

// ---- bus / paleta / registros (identico a tb_screen5) ----
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (20) @(posedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask
task vdp_pal(input [3:0] idx, input [2:0] r, input [2:0] g, input [2:0] b);
begin
    vdp_reg(6'd16, {4'd0, idx});
    bus_wr(3'd2, {1'b0, r, 1'b0, b});
    bus_wr(3'd2, {5'd0, g});
end
endtask

integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
            $display("FRAME VOLCADO (bg_miss acumulado=%0d)", shim_diag);
        end
        else if (dump_state == 0 && vs_count == 12) begin
            fd = $fopen("s5_frame.txt", "w");
            dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

integer x, y;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd1,  3'd7, 3'd0, 3'd0);
    vdp_pal(4'd2,  3'd0, 3'd7, 3'd0);
    vdp_pal(4'd3,  3'd0, 3'd0, 3'd7);
    vdp_pal(4'd4,  3'd7, 3'd7, 3'd0);
    vdp_pal(4'd5,  3'd7, 3'd0, 3'd7);
    vdp_pal(4'd6,  3'd0, 3'd7, 3'd7);
    vdp_pal(4'd7,  3'd7, 3'd7, 3'd7);
    vdp_pal(4'd8,  3'd3, 3'd0, 3'd0);
    vdp_pal(4'd9,  3'd0, 3'd3, 3'd0);
    vdp_pal(4'd10, 3'd0, 3'd0, 3'd3);
    vdp_pal(4'd11, 3'd3, 3'd3, 3'd0);
    vdp_pal(4'd12, 3'd3, 3'd0, 3'd3);
    vdp_pal(4'd13, 3'd0, 3'd3, 3'd3);
    vdp_pal(4'd14, 3'd3, 3'd3, 3'd3);
    vdp_pal(4'd15, 3'd7, 3'd4, 3'd0);
    vdp_reg(6'd0,  8'h06);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, 8'h40);
    for (y = 0; y < 212; y = y + 1)
        for (x = 0; x < 128; x = x + 1) begin : fill_p0
            logic [3:0] c0, c1;
            c0 = ((x*2) >> 4) ^ (y >> 4);
            c1 = ((x*2+1) >> 4) ^ (y >> 4);
            bus_wr(3'd0, {c0, c1});
            repeat (150) @(posedge clk);
        end
    $display("VRAM cargada en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("*** SCREEN5 CON SHIM: COMPLETO (vs=%0d, bg_miss=%0d) ***", vs_count, shim_diag);
    $finish;
end

initial begin
    #420000000;
    $display("TIMEOUT vs=%0d dump=%0d bg_miss=%0d", vs_count, dump_state, shim_diag);
    $finish;
end

endmodule
