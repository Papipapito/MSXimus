// ============================================================================
// tb_screen8_full.sv — _121: CADENA REAL COMPLETA en SCREEN 8.
// HW _120 sigue glitcheado aunque la sim del shim (backend IDEALIZADO) salio
// perfecta: el sospechoso es la cadena real. Este TB instancia TODO:
//   V9968 (85.9) -> shim -> 2x v9968_sdram_bridge (CDC) -> memory_ctrl
//   (arbitro wave/wv2/wv3, 108MHz) -> modelo W9825G6KH.
// Mismo guion que tb_screen8 (G7, fill 64 lineas, volcado en vs7) — el dump
// se compara contra s8r_frame.txt (la referencia perfecta de siempre).
// ============================================================================
`timescale 1ns/1ps

module tb_screen8_full;

// ---------------- relojes ----------------
localparam real CLK86_HALF = 5.8207;
logic clk86 = 0;
always #(CLK86_HALF) clk86 = ~clk86;

reg clk108 = 0;
always #4.63 clk108 = ~clk108;

reg clk54 = 0;
initial begin
    #4.63;
    forever begin clk54 = ~clk54; #9.26; end
end

reg [3:0] phc = 0;
always @(posedge clk108) phc <= phc + 1;
wire video_dhclk = ~phc[2];
wire video_dlclk = ~phc[3];

// ---------------- reset ----------------
logic reset_n = 0;          // dominio 85.9 (V9968 + shim + bridges)
reg   bus_reset_n = 0;      // dominio memoria

// ---------------- V9968 ----------------
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
wire         vram_stall;
wire         display_hs, display_vs, display_en;
wire  [7:0]  display_r, display_g, display_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk86), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_tag(vram_tag), .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// ---------------- shim (canal dual) ----------------
wire        bk_req, bk_we;
wire [21:0] bk_addr;
wire [7:0]  bk_wdata;
wire [15:0] bk_rword;
wire        bk_done_t;
wire        bk2_req;
wire [21:0] bk2_addr;
wire [15:0] bk2_rword;
wire        bk2_done_t;
wire [7:0]  shim_diag;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk86), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag)
);

// ---------------- bridges CDC reales ----------------
wire        wv2_req, wv2_we, wv2_done;
wire [21:0] wv2_addr;
wire [7:0]  wv2_wdata;
wire [15:0] wv2_dout;
wire        wv3_req, wv3_we, wv3_done;
wire [21:0] wv3_addr;
wire [7:0]  wv3_wdata;
wire [15:0] wv3_dout;

v9968_sdram_bridge u_bridge (
    .clk_vdp(clk86), .rst_n(reset_n),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr),
    .bk_wdata(bk_wdata), .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .clk_108m(clk108),
    .wv2_req(wv2_req), .wv2_we(wv2_we), .wv2_addr(wv2_addr),
    .wv2_wdata(wv2_wdata), .wv2_dout(wv2_dout), .wv2_done(wv2_done)
);
v9968_sdram_bridge u_bridge2 (
    .clk_vdp(clk86), .rst_n(reset_n),
    .bk_req(bk2_req), .bk_we(1'b0), .bk_addr(bk2_addr),
    .bk_wdata(8'd0), .bk_rword(bk2_rword), .bk_done_t(bk2_done_t),
    .clk_108m(clk108),
    .wv2_req(wv3_req), .wv2_we(wv3_we), .wv2_addr(wv3_addr),
    .wv2_wdata(wv3_wdata), .wv2_dout(wv3_dout), .wv2_done(wv3_done)
);

// ---------------- memoria REAL + modelo W9825 ----------------
reg  [7:0]  ram_din  = 0;
reg         ram_req  = 0;
reg         ram_write = 0;
reg  [22:0] ram_addr = 0;
reg  [7:0]  vram_din = 0;
reg         vdpc_write = 0;
reg  [16:0] vdpc_addr = 0;
reg         bus_rfsh_n = 1;
// _121b: RFSH del Z80 real (M1 ~1.25us, bajo ~560ns = ~45%% de ocupacion)
initial begin
    #100000;
    forever begin
        bus_rfsh_n = 1; #690;
        bus_rfsh_n = 0; #560;
    end
end
wire [7:0]  ram_dout;
wire [15:0] vdpc_dout;
wire        ram_busy;
reg         wv_req = 0, wv_we = 0;
reg  [21:0] wv_addr = 0;
reg  [7:0]  wv_wdata = 0;
wire [15:0] wv_dout;
wire        wv_done;

wire        sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
wire [15:0] sd_dq;
wire [12:0] sd_addr;
wire [1:0]  sd_ba;
wire [1:0]  sd_dqm;

memory_ctrl dut (
    .clk_27m     (clk54),
    .clk_108m    (clk108),
    .bus_reset_n (bus_reset_n),
    .video_dhclk (video_dhclk),
    .video_dlclk (video_dlclk),
    .ram_din     (ram_din),
    .ram_req     (ram_req),
    .ram_write   (ram_write),
    .ram_addr    (ram_addr),
    .vram_din    (vram_din),
    .vram_write  (vdpc_write),
    .vram_addr   (vdpc_addr),
    .bus_rfsh_n  (bus_rfsh_n),
    .ram_dout    (ram_dout),
    .vram_dout   (vdpc_dout),
    .ram_busy    (ram_busy),
    .wv_req      (wv_req),
    .wv_we       (wv_we),
    .wv_addr     (wv_addr),
    .wv_wdata    (wv_wdata),
    .wv_dout     (wv_dout),
    .wv_done     (wv_done),
    .wv2_req     (wv2_req),
    .wv2_we      (wv2_we),
    .wv2_addr    (wv2_addr),
    .wv2_wdata   (wv2_wdata),
    .wv2_dout    (wv2_dout),
    .wv2_done    (wv2_done),
    .wv3_req     (wv3_req),
    .wv3_we      (wv3_we),
    .wv3_addr    (wv3_addr),
    .wv3_wdata   (wv3_wdata),
    .wv3_dout    (wv3_dout),
    .wv3_done    (wv3_done),
    .O_sdram_clk   (sd_clk),
    .O_sdram_cke   (sd_cke),
    .O_sdram_cs_n  (sd_cs_n),
    .O_sdram_cas_n (sd_cas_n),
    .O_sdram_ras_n (sd_ras_n),
    .O_sdram_wen_n (sd_wen_n),
    .IO_sdram_dq   (sd_dq),
    .O_sdram_addr  (sd_addr),
    .O_sdram_ba    (sd_ba),
    .O_sdram_dqm   (sd_dqm)
);

// _121b: trafico CPU estilo Z80 (fetch continuo ~1M/s) — protocolo
// req->busy sube->req abajo (patron cpu_op del memory_tb)
reg [22:0] z80_a = 23'h4000;
initial begin
    #150000;
    forever begin
        @(negedge clk54);
        ram_addr  = z80_a;
        ram_write = 0;
        ram_req   = 1;
        @(posedge ram_busy);
        @(negedge clk54);
        ram_req   = 0;
        @(negedge ram_busy);
        z80_a = z80_a + 23'd1;
        repeat (2) @(negedge clk54);   // ~1 op/us a 54MHz/2... ajustado abajo
    end
end

// 3) contadores de ocupacion de TURNOS (fase 0 de cada media CPU)
integer t_total = 0, t_rfsh = 0, t_cpu = 0, t_wav = 0, t_wv2 = 0, t_wv3 = 0, t_idle = 0;
always @(posedge clk108) begin
    if (dut.ff_sdr_seq == 3'b000 && video_dlclk == 0 && dut.RstSeq == 5'b11111) begin
        t_total <= t_total + 1;
        if (dut.SdrSta[2:0] == 3'b010) t_rfsh <= t_rfsh + 1;
        else if (dut.SdrWav) t_wav <= t_wav + 1;
        else if (dut.SdrWv2) t_wv2 <= t_wv2 + 1;
        else if (dut.SdrWv3) t_wv3 <= t_wv3 + 1;
        else if (dut.enable_sdram) t_cpu <= t_cpu + 1;
        else t_idle <= t_idle + 1;
    end
end
// _121c: sonda de LATENCIA por tramo del canal A (donde se van los ns):
//   t_req  = pulso bk_req del shim (86)
//   t_wreq = subida de wv2_req en el 108 (tras el CDC)
//   t_gnt  = concesion (SdrWv2 sube)
//   t_done = wv2_done
//   t_bkd  = bk_done_t de vuelta en el 86
integer lat_n = 0;
realtime t_req, t_wreq, t_gnt, t_done;
reg wv2_req_d = 0, sdrwv2_d = 0, bkdone_d = 0;
always @(posedge clk86) begin
    if (bk_req) t_req = $realtime;
    if (bk_done_t != bkdone_d) begin
        bkdone_d <= bk_done_t;
        if (lat_n < 30 && dump_state == 1) begin
            lat_n <= lat_n + 1;
            $display("LAT req->wreq=%0.0f wreq->gnt=%0.0f gnt->done=%0.0f done->bk=%0.0f TOTAL=%0.0f",
                     t_wreq-t_req, t_gnt-t_wreq, t_done-t_gnt,
                     $realtime-t_done, $realtime-t_req);
        end
    end
end
always @(posedge clk108) begin
    wv2_req_d <= wv2_req;
    sdrwv2_d  <= dut.SdrWv2;
    if (wv2_req && !wv2_req_d) t_wreq = $realtime;
    if (dut.SdrWv2 && !sdrwv2_d) t_gnt = $realtime;
    if (wv2_done) t_done = $realtime;
end

integer rep_n = 0;
always @(posedge clk86) begin
    if (display_vs && !vs_d && vs_count > 2) begin
        rep_n <= rep_n + 1;
        if (rep_n[0] == 0)
            $display("TURNOS total=%0d rfsh=%0d cpu=%0d idle=%0d | bkA=%0d bkB=%0d miss=%0d pfqdrop=%0d rqdrop=%0d",
                     t_total, t_rfsh, t_cpu, t_idle,
                     u_shim.c_bka, u_shim.c_bkb, u_shim.c_miss, c_pfqdrop, c_rqdrop);
    end
end

w9825_model sdram (
    .clk   (sd_clk),
    .cke   (sd_cke),
    .cs_n  (sd_cs_n),
    .ras_n (sd_ras_n),
    .cas_n (sd_cas_n),
    .we_n  (sd_wen_n),
    .addr  (sd_addr),
    .ba    (sd_ba),
    .dqm   (sd_dqm),
    .dq    (sd_dq)
);

// ---------------- bus del VDP ----------------
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk86);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk86);
    while (!bus_ready) @(posedge clk86);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (20) @(posedge clk86);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

// ---------------- volcado ----------------
integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;
always @(posedge clk86) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
            $display("FRAME VOLCADO (bg_miss acumulado=%0d)", shim_diag);
        end
        else if (dump_state == 0 && vs_count == 7) begin
            fd = $fopen("s8full_frame.txt", "w");
            dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

// ---------------- sondas por linea ----------------
integer ln_miss = 0, ln_num = 0;
integer c_pfqdrop = 0, c_rqdrop = 0;
always @(posedge clk86) begin
    if (u_shim.obl_do && u_shim.pfq_full) c_pfqdrop <= c_pfqdrop + 1;
    if (dbg_bg1 && !dbg_whit && !dbg_chit && !u_shim.rq_room_soft) c_rqdrop <= c_rqdrop + 1;
end
wire dbg_bg1  = u_shim.spr_p1 && (u_shim.spr_tag1[4:2] == 3'd1);
wire dbg_whit = dbg_bg1 && u_shim.pwq_v && (u_shim.pwq[41:32] == u_shim.spr_addr1[15:6]);
wire dbg_chit = dbg_bg1 && !dbg_whit && u_shim.scq_v && (u_shim.scq_tag == u_shim.spr_addr1[15:12]);
always @(posedge clk86) begin
    if (dump_state == 1) begin
        if (dbg_bg1 && !dbg_whit && !dbg_chit) begin : misscause
            reg in_pfq, in_rq, infl;
            reg [15:0] wtag_have;
            integer qi;
            ln_miss <= ln_miss + 1;
            in_pfq = 0; in_rq = 0;
            for (qi = 0; qi < 8; qi = qi + 1)
                if (u_shim.pfq_wp != u_shim.pfq_rp &&
                    u_shim.pfq[qi] == u_shim.spr_addr1) in_pfq = 1;
            for (qi = 0; qi < 16; qi = qi + 1)
                if (u_shim.rq[qi][15:0] == u_shim.spr_addr1) in_rq = 1;
            infl = u_shim.bsy && (u_shim.cur_addrw == u_shim.spr_addr1);
            if (ln_miss < 3)
                $display("MISS ln=%0d addr=%04x pfq=%b rq=%b infl=%b wv=%b wtag=%03x pfqn=%0d",
                         ln_num, u_shim.spr_addr1, in_pfq, in_rq, infl,
                         u_shim.pwq_v, u_shim.pwq[41:32],
                         (u_shim.pfq_wp - u_shim.pfq_rp) & 3'd7);
        end
        if (display_hs && !hs_d) begin
            ln_miss <= 0; ln_num <= ln_num + 1;
        end
    end
end

// ---------------- secuencia ----------------
integer x, y;
initial begin
    // reset + init acelerada de la SDRAM (patron sdr16_tb)
    bus_reset_n = 0; reset_n = 0;
    repeat (40) @(posedge clk108);
    bus_reset_n = 1;
    while (dut.RstSeq !== 5'b11111) begin
        @(negedge clk108);
        force dut.FreeCounter = 16'hFFF0;
        @(negedge clk108);
        release dut.FreeCounter;
        repeat (90) @(posedge clk108);
    end
    repeat (64) @(posedge clk108);
    $display("SDRAM init OK");
    reset_n = 1;

    wait (vs_count >= 1);
    vdp_reg(6'd0,  8'h0E);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, 8'h40);
    for (y = 0; y < 64; y = y + 1)
        for (x = 0; x < 256; x = x + 1) begin
            bus_wr(3'd0, x[7:0] ^ y[7:0]);
            repeat (40) @(posedge clk86);
        end
    $display("VRAM cargada en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("*** SCREEN8 CADENA COMPLETA: FIN (vs=%0d, bg_miss=%0d) ***", vs_count, shim_diag);
    $finish;
end

initial begin
    #700000000;
    $display("TIMEOUT vs=%0d dump=%0d bg_miss=%0d", vs_count, dump_state, shim_diag);
    $finish;
end

endmodule
