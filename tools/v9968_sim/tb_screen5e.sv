// ============================================================================
// tb_screen5e.sv — F1a sprites: pila completa (core parcheado + shim + backend
// lento) con SPRITES HABILITADOS en SCREEN5, para medir si los deadlines de
// los fetches de sprite (c_sprite=2, servidos por el camino rq/late del shim)
// llegan a tiempo o hace falta particion propia de prefetch.
//
// Mide: latencia REQ->RSP de cada fetch de sprite (min/max/avg, en ciclos) y
// cuantos se pierden (rq lleno). Ademas vuelca el frame para ver si los
// sprites RENDERIZAN (4 sprites de patron solido en posiciones conocidas).
// ============================================================================
`timescale 1ns/1ps

module tb_screen5e;

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
// escritura de un byte de VRAM con cadencia Z80 (puntero ya colocado)
task vram_b(input [7:0] d);
begin
    bus_wr(3'd0, d);
    repeat (150) @(posedge clk);
end
endtask

integer vs_count = 0;
logic vs_d = 0;
integer dump_state = 0;
integer fd = 0;
logic hs_d = 0;
integer sp_req_d0 = -1, sp_rsp_d0 = -1;   // snapshot al empezar el dump

// ---- medidor de latencia de fetches de sprite (rq es FIFO -> en orden) ----
integer sp_req = 0, sp_rsp = 0;
real    sp_tq [0:4095];
real    lat_ns, lat_min, lat_max, lat_sum;
initial begin lat_min = 1e9; lat_max = 0; lat_sum = 0; end
always @(posedge clk) begin
    if (vram_valid && !vram_write && vram_tag[4:2] == 3'd2) begin
        if (sp_req < 4096) sp_tq[sp_req] = $realtime;
        sp_req <= sp_req + 1;
    end
    if (vram_rdata_en && vram_rtag[4:2] == 3'd2) begin
        if (sp_rsp < sp_req && sp_rsp < 4096) begin
            lat_ns = $realtime - sp_tq[sp_rsp];
            if (lat_ns < lat_min) lat_min = lat_ns;
            if (lat_ns > lat_max) lat_max = lat_ns;
            lat_sum = lat_sum + lat_ns;
        end
        sp_rsp <= sp_rsp + 1;
    end
end

always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
        end
        else if (dump_state == 0 && vs_count == 8) begin
            fd = $fopen("s5e_frame.txt", "w");
            dump_state <= 1;
            sp_req_d0 = sp_req;
            sp_rsp_d0 = sp_rsp;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

integer x, y, s;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd4,  3'd0, 3'd0, 3'd7);   // fondo azul oscuro (color 4)
    vdp_pal(4'd9,  3'd0, 3'd7, 3'd0);   // sprite verde
    vdp_pal(4'd10, 3'd7, 3'd7, 3'd0);   // sprite amarillo
    vdp_pal(4'd11, 3'd7, 3'd0, 3'd0);   // sprite rojo
    vdp_pal(4'd12, 3'd7, 3'd7, 3'd7);   // sprite blanco
    vdp_pal(4'd15, 3'd7, 3'd4, 3'd0);
    vdp_reg(6'd0,  8'h06);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h28);              // VR=1, SPD=0 -> SPRITES ON
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    // tablas de sprites: atributos en #1E00 (R#5=3F canonico SC5 — modo 2
    // exige bits 2:0 a 1; color table implicita en attr-512 = #1C00),
    // patrones en #1800 (R#6=03)
    vdp_reg(6'd5,  8'h3F);
    vdp_reg(6'd11, 8'h00);
    vdp_reg(6'd6,  8'h03);
    vdp_reg(6'd1,  8'h42);              // SIZE=1 (16x16), MAG=0... R#1=42h: 16x16
    // fondo: color 4 solido en las primeras 64 lineas (rapido)
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, 8'h40);
    for (y = 0; y < 64; y = y + 1)
        for (x = 0; x < 128; x = x + 1) vram_b(8'h44);
    // patrones: sprite pattern 0 = 16x16 solido (32 bytes FF) en #1800
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, {2'b01, 6'h18});       // #1800 write
    for (x = 0; x < 32; x = x + 1) vram_b(8'hFF);
    // color table (modo2): en attr-#200 = #1C00: 16 lineas de color por sprite
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, {2'b01, 6'h1C});
    for (s = 0; s < 4; s = s + 1)
        for (x = 0; x < 16; x = x + 1) vram_b(8'h09 + s[7:0]);  // colores 9,A,B,C
    // atributos en #1E00: 4 sprites en Y=20/30/40/50, X=32/80/128/176, pat 0
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, {2'b01, 6'h1E});
    for (s = 0; s < 4; s = s + 1) begin
        vram_b(8'd20 + s[7:0]*8'd10);   // Y
        vram_b(8'd32 + s[7:0]*8'd48);   // X
        vram_b(8'h00);                  // patron 0
        vram_b(8'h00);                  // (color en modo2 va en tabla aparte)
    end
    vram_b(8'd216);                     // Y=216 = fin de lista (D8h)
    $display("VRAM sprites cargada en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("SPRITES: req=%0d rsp=%0d perdidos=%0d", sp_req, sp_rsp, sp_req - sp_rsp);
    $display("FRAME DUMP: req=%0d perdidos_en_frame=%0d",
             sp_req - sp_req_d0, (sp_req - sp_req_d0) - (sp_rsp - sp_rsp_d0));
    if (sp_rsp > 0)
        $display("LATENCIA sprite (ns): min=%0.0f max=%0.0f avg=%0.0f  [8 ciclos=93ns]",
                 lat_min, lat_max, lat_sum / sp_rsp);
    $display("bg_miss=%0d", shim_diag);
    $finish;
end

initial begin
    #200000000;
    $display("TIMEOUT vs=%0d dump=%0d sp_req=%0d sp_rsp=%0d", vs_count, dump_state, sp_req, sp_rsp);
    $finish;
end

endmodule
