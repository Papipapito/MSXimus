// ============================================================================
// tb_screen5b.sv — F1 del V9968: el MISMO test SCREEN5 pero con la memoria
// AUTENTICA de HRA!: ip_sdram (su controlador) + MT48LC2M32B2 (modelo Micron
// de SDRAM real). Latencia verdadera por construccion. Si esto renderiza, el
// estimulo del tb_screen5 era correcto y solo el timing de mi modelo casero
// fallaba; ademas queda el banco de referencia para MEDIR la tolerancia real
// de latencia (la spec del shim de la SDRAM compartida del 60K).
// ============================================================================
`timescale 1ns/1ps

module tb_screen5b;

localparam real CLK_HALF = 5.8207;   // 85.90908 MHz
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;
wire clk_sdram = ~clk;               // 180 grados, como su top (clk85m_n)

logic [2:0]  bus_address = 0;
logic        bus_ioreq = 0, bus_write = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;
wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vram_address;
wire         vram_write, vram_valid, vram_refresh;
wire  [31:0] vram_wdata;
wire  [3:0]  vram_wdata_mask;
wire  [31:0] vram_rdata;
wire         vram_rdata_en;
wire         display_hs, display_vs, display_en;
wire  [7:0]  display_r, display_g, display_b;
wire         sdram_init_busy;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(sdram_init_busy),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// ---- memoria AUTENTICA: su controlador + modelo Micron ----
wire        sd_clk, sd_cke, sd_cs_n, sd_ras_n, sd_cas_n, sd_wen_n;
wire [10:0] sd_addr;
wire [1:0]  sd_ba;
wire [3:0]  sd_dqm;
wire [31:0] sd_dq;

ip_sdram #(
    .FREQ(85_909_080)
) u_sdram (
    .reset_n(reset_n), .clk(clk), .clk_sdram(clk_sdram),
    .sdram_init_busy(sdram_init_busy),
    .bus_address({5'd0, vram_address}),   // 22:2 <- 17:2 (VDP en los 256KB bajos)
    .bus_valid(vram_valid), .bus_write(vram_write),
    .bus_refresh(vram_refresh),
    .bus_wdata(vram_wdata), .bus_wdata_mask(vram_wdata_mask),
    .bus_rdata(vram_rdata), .bus_rdata_en(vram_rdata_en),
    .O_sdram_clk(sd_clk), .O_sdram_cke(sd_cke), .O_sdram_cs_n(sd_cs_n),
    .O_sdram_ras_n(sd_ras_n), .O_sdram_cas_n(sd_cas_n), .O_sdram_wen_n(sd_wen_n),
    .IO_sdram_dq(sd_dq),
    .O_sdram_addr(sd_addr), .O_sdram_ba(sd_ba), .O_sdram_dqm(sd_dqm)
);

mt48lc2m32b2 u_micron (
    .Dq(sd_dq), .Addr(sd_addr), .Ba(sd_ba), .Clk(sd_clk), .Cke(sd_cke),
    .Cs_n(sd_cs_n), .Ras_n(sd_ras_n), .Cas_n(sd_cas_n), .We_n(sd_wen_n),
    .Dqm(sd_dqm)
);

// ---- medidor de latencia real peticion->rdata_en ----
integer lat_cnt = 0;
integer lat_min = 999, lat_max = 0;
integer t_req = 0;
logic   in_flight = 0;
always @(posedge clk) begin
    if (vram_valid && !vram_write) begin
        t_req <= 0; in_flight <= 1;
    end
    else if (in_flight) t_req <= t_req + 1;
    if (vram_rdata_en && in_flight) begin
        in_flight <= 0;
        if (t_req + 1 < lat_min) lat_min = t_req + 1;
        if (t_req + 1 > lat_max) lat_max = t_req + 1;
    end
end

// ---- bus ----
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

// ---- vida + volcado ----
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
            $display("FRAME VOLCADO. Latencia real ip_sdram: min=%0d max=%0d ciclos", lat_min, lat_max);
        end
        else if (dump_state == 0 && vs_count == 16) begin
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
    wait (!sdram_init_busy);
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
        end
    $display("VRAM cargada por puerto 0 en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("*** SCREEN5+SDRAM-REAL: COMPLETO (vs=%0d) ***", vs_count);
    $finish;
end

initial begin
    #400000000;
    $display("TIMEOUT vs=%0d dump=%0d initbusy=%0d", vs_count, dump_state, sdram_init_busy);
    $finish;
end

endmodule
