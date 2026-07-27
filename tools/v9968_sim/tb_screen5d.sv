// ============================================================================
// tb_screen5d.sv — DEBUG del negro de tb_screen5c: pila identica (core
// parcheado + shim + backend lento) pero carga MINIMA (4 lineas) y volcado
// temprano (frame 3) + trazas: tag de ida de cada fetch, hit/miss del shim,
// eco de vuelta (rtag/rdata). Para localizar donde muere el dato de pantalla.
// ============================================================================
`timescale 1ns/1ps

module tb_screen5d;

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
wire [31:0] bk_wdata;      // _148 FIX B: escritura de PALABRA
wire [3:0]  bk_wmask;      // _148 FIX B: 1 = escribir ese byte
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire [7:0]  shim_diag;
wire        bk2_req;
wire [21:0] bk2_addr;
logic [15:0] bk2_rword = 0;
logic        bk2_done_t = 0;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag)
);

// backend lento identico al de 5c
logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
integer vi;
initial for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
            // _148 FIX B: escritura de PALABRA con mascara de bytes
            if (m_we) begin
                if (m_msk[0]) sdram[{m_addr[21:2],2'b00}] <= m_dat[ 7: 0];
                if (m_msk[1]) sdram[{m_addr[21:2],2'b01}] <= m_dat[15: 8];
                if (m_msk[2]) sdram[{m_addr[21:2],2'b10}] <= m_dat[23:16];
                if (m_msk[3]) sdram[{m_addr[21:2],2'b11}] <= m_dat[31:24];
            end
            else begin
                bk_rword[7:0]  <= sdram[{m_addr[21:1],1'b0}];
                bk_rword[15:8] <= sdram[{m_addr[21:1],1'b1}];
            end
            bk_done_t <= ~bk_done_t;
            m_pend <= 0;
        end
    end
end

// ---- canal B del backend (_120): SOLO lecturas, misma latencia ----
logic        m2_pend = 0;
logic [21:0] m2_addr;
integer      m2_cnt, m2_lat;
always @(posedge clk) begin
    if (bk2_req && !m2_pend) begin
        m2_pend <= 1; m2_addr <= bk2_addr;
        m2_cnt <= 0; m2_lat <= 26 + ({$random} % 18);
    end
    else if (m2_pend) begin
        m2_cnt <= m2_cnt + 1;
        if (m2_cnt == m2_lat) begin
            bk2_rword[7:0]  <= sdram[{m2_addr[21:1],1'b0}];
            bk2_rword[15:8] <= sdram[{m2_addr[21:1],1'b1}];
            bk2_done_t <= ~bk2_done_t;
            m2_pend <= 0;
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
logic vs_d = 0;
integer dump_state = 0;

// ---------- TRAZAS ----------
integer trc_req = 0, trc_rsp = 0;
integer cnt_bg = 0, cnt_idle = 0, cnt_spr = 0, cnt_other = 0;
integer rsp_bg = 0, rsp_bg_nz = 0;
always @(posedge clk) begin
    if (dump_state == 1) begin
        if (vram_valid && !vram_write) begin
            case (vram_tag[4:2])
                3'd1: cnt_bg   <= cnt_bg + 1;
                3'd0: cnt_idle <= cnt_idle + 1;
                3'd2: cnt_spr  <= cnt_spr + 1;
                default: cnt_other <= cnt_other + 1;
            endcase
            if (trc_req < 50) begin
                $display("REQ  t=%0t tag=%b addr=%05x", $time, vram_tag, vram_address);
                trc_req <= trc_req + 1;
            end
        end
        if (vram_rdata_en) begin
            if (vram_rtag[4:2] == 3'd1) begin
                rsp_bg <= rsp_bg + 1;
                if (vram_rdata != 0) rsp_bg_nz <= rsp_bg_nz + 1;
            end
            if (trc_rsp < 50) begin
                $display("RSP  t=%0t rtag=%b data=%08x", $time, vram_rtag, vram_rdata);
                trc_rsp <= trc_rsp + 1;
            end
        end
    end
end

always @(posedge clk) begin
    vs_d <= display_vs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            dump_state <= 2;
            $display("FIN FRAME: bg=%0d idle=%0d spr=%0d otros=%0d | rsp_bg=%0d (no-cero=%0d) | bg_miss=%0d",
                     cnt_bg, cnt_idle, cnt_spr, cnt_other, rsp_bg, rsp_bg_nz, shim_diag);
        end
        else if (dump_state == 0 && vs_count == 3) dump_state <= 1;
    end
end

integer x, y;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd1,  3'd7, 3'd0, 3'd0);
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
    for (y = 0; y < 4; y = y + 1)
        for (x = 0; x < 128; x = x + 1) begin
            bus_wr(3'd0, x[7:0]);  // byte unico por posicion: delata errores de lane
            repeat (150) @(posedge clk);
        end
    $display("VRAM (4 lineas) cargada en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $finish;
end

initial begin
    #130000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
