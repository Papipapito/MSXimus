// ============================================================================
// tb_screen5g.sv — v3c: COMANDOS VDP en SCREEN 5 con la pila completa.
// Reproduce el caso del CUELGUE HW de la _118 (SC5 "solo 2 colores y se
// cuelga"): HMMV (escrituras multi-byte, mascara 0000 = 4 bytes/palabra —
// camino JAMAS simulado) + LMMM (lecturas de comando — un drop = motor de
// comandos colgado esperando su rdata_en). Con polling REAL del bit CE.
// PASA si: ambos comandos completan (CE baja) y el frame muestra los dos
// rectangulos rellenos.
// ============================================================================
`timescale 1ns/1ps

module tb_screen5g;

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
wire         vram_stall;
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
    .vram_stall(vram_stall),
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
    .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .diag(shim_diag)
);

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
task bus_rd(input [2:0] a, output [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_ioreq <= 1; bus_write <= 0; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_valid <= 0;
    while (!bus_rdata_en) @(posedge clk);
    d = bus_rdata;
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

// espera a que el bit CE (S#2 bit0) baje — con timeout: el CUELGUE del HW
task wait_ce(input [31:0] max_us, output ok);
    reg [7:0] st;
    integer t;
begin
    ok = 0;
    for (t = 0; t < max_us; t = t + 1) begin
        vdp_reg(6'd15, 8'h02);       // S#2
        bus_rd(3'd1, st);
        vdp_reg(6'd15, 8'h00);
        if (t < 3 || (t % 500) == 0)
            $display("POLL t=%0dus st=%02x eng=%0d | stall=%b wq=%0d rq=%0d bsy=%b wp=%b kind=%0d | cmd_wr=%0d cmd_rd=%0d rango=%0x..%0x",
                     t, st, u_vdp.u_command.ff_state,
                     u_shim.vram_stall, u_shim.wq_used, u_shim.rq_used,
                     u_shim.bsy, u_shim.word_pend, u_shim.cur_kind,
                     cmd_wr, cmd_rd, cmd_amin, cmd_amax);
        if (!st[0]) begin ok = 1; t = max_us; end
        else repeat (86) @(posedge clk);   // ~1us
    end
end
endtask

integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;

// contadores del trafico VRAM del COMANDO (tag c_command=4)
integer cmd_wr = 0, cmd_rd = 0;
integer cmd_amin = 999999, cmd_amax = -1;
always @(posedge clk) begin
    if (vram_valid && vram_tag[4:2] == 3'd4) begin
        if (vram_write) cmd_wr <= cmd_wr + 1;
        else            cmd_rd <= cmd_rd + 1;
        if (vram_address < cmd_amin) cmd_amin <= vram_address;
        if (vram_address > cmd_amax) cmd_amax <= vram_address;
    end
    else if (vram_valid && vram_write) begin
        // escrituras con OTRO tag durante el test (no deberia haber)
        if (vram_tag[4:2] != 3'd4) cmd_wr <= cmd_wr;  // no-op, punto de sonda
    end
end
always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd); dump_state <= 2;
        end
        else if (dump_state == 10) begin
            fd = $fopen("s5g_frame.txt", "w"); dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

logic okA, okB;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd5,  3'd7, 3'd0, 3'd7);   // magenta
    vdp_pal(4'd15, 3'd7, 3'd4, 3'd0);
    vdp_reg(6'd0,  8'h06);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);

    // ---- HMMV: rectangulo 64x64 en (16,8) color 0x55 ----
    vdp_reg(6'd36, 8'd16);  vdp_reg(6'd37, 8'd0);    // DX
    vdp_reg(6'd38, 8'd8);   vdp_reg(6'd39, 8'd0);    // DY
    vdp_reg(6'd40, 8'd64);  vdp_reg(6'd41, 8'd0);    // NX
    vdp_reg(6'd42, 8'd64);  vdp_reg(6'd43, 8'd0);    // NY
    vdp_reg(6'd44, 8'h55);                            // CLR (color 5 ambos)
    vdp_reg(6'd45, 8'h00);                            // ARG
    // SONDA: registros del motor JUSTO antes del GO
    $display("PRE-GO: reg_dx=%0d ff_dy=%0d reg_nx=%0d reg_ny=%0d",
             u_vdp.u_command.reg_dx, u_vdp.u_command.ff_dy,
             u_vdp.u_command.reg_nx, u_vdp.u_command.reg_ny);
    vdp_reg(6'd46, 8'hC0);                            // HMMV
    repeat (200) @(posedge clk);
    $display("POST-GO: dx=%0d dy=%0d nx=%0d ny=%0d state=%0d",
             u_vdp.u_command.ff_dx, u_vdp.u_command.ff_dy,
             u_vdp.u_command.ff_nx, u_vdp.u_command.ff_ny,
             u_vdp.u_command.ff_state);
    wait_ce(32'd20000, okA);                          // hasta 20ms
    if (okA) $display("HMMV COMPLETO (CE bajo)");
    else     $display("HMMV COLGADO (CE nunca bajo) — EL BUG DEL HW");

    // ---- LMMM: copia logica (16,8)-(79,71) -> (144,100) ----
    vdp_reg(6'd32, 8'd16);  vdp_reg(6'd33, 8'd0);    // SX
    vdp_reg(6'd34, 8'd8);   vdp_reg(6'd35, 8'd0);    // SY
    vdp_reg(6'd36, 8'd144); vdp_reg(6'd37, 8'd0);    // DX
    vdp_reg(6'd38, 8'd100); vdp_reg(6'd39, 8'd0);    // DY
    vdp_reg(6'd40, 8'd64);  vdp_reg(6'd41, 8'd0);
    vdp_reg(6'd42, 8'd64);  vdp_reg(6'd43, 8'd0);
    vdp_reg(6'd45, 8'h00);
    vdp_reg(6'd46, 8'h90);                            // LMMM (IMP)
    wait_ce(32'd40000, okB);
    if (okB) $display("LMMM COMPLETO (CE bajo)");
    else     $display("LMMM COLGADO — lecturas de comando perdidas");

    dump_state = 10;
    wait (dump_state == 2);
    $display("FRAME VOLCADO. RESULTADO: HMMV=%0d LMMM=%0d bg_miss=%0d",
             okA, okB, shim_diag);
    if (okA && okB) $display("*** COMANDOS VDP: OK ***");
    else            $display("*** COMANDOS VDP: FALLO ***");
    #1000;
    $finish;
end

initial begin
    #400000000;
    $display("TIMEOUT GLOBAL vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
