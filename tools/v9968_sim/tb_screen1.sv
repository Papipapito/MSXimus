// ============================================================================
// tb_screen1.sv — v3: SCREEN 1 (modo de PATRONES) con la pila completa
// (core parcheado + shim v3 + backend SDRAM lenta). Reproduce el caso de las
// fotos HW _117 (texto triturado con bitmap OK): el fetch bg salta
// NT->PGT->CT y la ventana lineal fallaba todo; el v3 lo sirve de la cache.
//
// Estimulo: PGT = patron pseudo-aleatorio por caracter (char c, fila r =
// c^(r*37)), NT = caracter unico por celda ((fila*32+col)&0xFF), CT = colores
// variados. CHECKS: (1) volcado de DOS frames consecutivos -> deben ser
// IDENTICOS (la basura del HW "se movia"); (2) PNG para inspeccion visual.
// ============================================================================
`timescale 1ns/1ps

module tb_screen1;

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
task vram_b(input [7:0] d);
begin
    bus_wr(3'd0, d);
    repeat (150) @(posedge clk);
end
endtask
task vram_ptr(input [13:0] a);   // puntero de escritura (R#14=0)
begin
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b01, a[13:8]});
end
endtask
// puntero de LECTURA (bit6=0) — dispara el pre-fetch del interface
task vram_rdptr(input [13:0] a);
begin
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b00, a[13:8]});
end
endtask
// lectura del puerto 0 con cadencia BIOS (SETRD + IN en ~2us): el caso del
// RASTRO DEL CURSOR en HW — si el pre-fetch no ha llegado, sale dato viejo
task vram_rd(output [7:0] d);
begin
    @(posedge clk);
    bus_address <= 3'd0; bus_ioreq <= 1; bus_write <= 0; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_valid <= 0;
    // el dato de la IN es el buffer prefetcheado: bus_rdata_en lo entrega
    while (!bus_rdata_en) @(posedge clk);
    d = bus_rdata;
    repeat (150) @(posedge clk);   // hueco Z80 entre INs
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
        case (dump_state)
            1: begin $fclose(fd); fd = $fopen("s1_frame_b.txt", "w"); dump_state <= 2; end
            2: begin $fclose(fd); dump_state <= 3;
                     $display("DOS FRAMES VOLCADOS (bg_miss=%0d)", shim_diag); end
            0: if (vs_count == 8) begin fd = $fopen("s1_frame_a.txt", "w"); dump_state <= 1; end
        endcase
    end
    if ((dump_state == 1 || dump_state == 2) && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

integer c, r, i;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    // paleta: 16 colores variados (indices TMS estandar-ish)
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd1,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd4,  3'd1, 3'd1, 3'd7);   // azul
    vdp_pal(4'd15, 3'd7, 3'd7, 3'd7);   // blanco
    vdp_pal(4'd8,  3'd7, 3'd0, 3'd0);
    vdp_pal(4'd2,  3'd0, 3'd6, 3'd0);
    // SCREEN 1: NT=0x1800 (R#2=06), CT=0x2000 (R#3=80), PGT=0x0000 (R#4=00)
    vdp_reg(6'd0,  8'h00);
    vdp_reg(6'd1,  8'h40);              // display on, sprites 8x8 off-ish
    vdp_reg(6'd2,  8'h06);
    vdp_reg(6'd3,  8'h80);
    vdp_reg(6'd4,  8'h00);
    vdp_reg(6'd8,  8'h2A);              // VR=1 (+SPD=1: sin sprites aqui)
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'hF4);              // texto blanco / fondo azul
    vdp_reg(6'd14, 8'h00);
    // PGT: 256 chars x 8 bytes — patron unico por (char, fila)
    vram_ptr(14'h0000);
    for (c = 0; c < 256; c = c + 1)
        for (r = 0; r < 8; r = r + 1) vram_b(c[7:0] ^ (r[7:0] * 8'd37));
    // NT: 32x24 celdas, caracter = (i*7+3)&0xFF (recorre todos)
    vram_ptr(14'h1800);
    for (i = 0; i < 768; i = i + 1) vram_b(((i * 7) + 3) & 8'hFF);
    // CT: 32 entradas de color (fg/bg por grupo de 8 chars)
    vram_ptr(14'h2000);
    for (i = 0; i < 32; i = i + 1) vram_b({i[3:0] == 4'd0 ? 4'hF : i[3:0], 4'h4});
    $display("VRAM SC1 cargada en vs=%0d", vs_count);
    wait (dump_state == 3);

    // ---- verificacion de LECTURAS CPU (el caso del rastro del cursor) ----
    begin : rdcheck
        reg [7:0] rb;
        integer rerr;
        rerr = 0;
        // NT en 0x1800: 32 bytes esperados (i*7+3)&0xFF
        vram_rdptr(14'h1800);
        repeat (150) @(posedge clk);      // margen SETRD->1a IN estilo BIOS
        for (i = 0; i < 32; i = i + 1) begin
            vram_rd(rb);
            if (rb !== (((i * 7) + 3) & 8'hFF)) begin
                rerr = rerr + 1;
                if (rerr <= 8) $display("RD ERR NT[%0d]: got=%02x exp=%02x",
                                        i, rb, ((i * 7) + 3) & 8'hFF);
            end
        end
        // PGT en 0x0000: 16 bytes esperados c^(r*37) (c=0..1, r=0..7)
        vram_rdptr(14'h0000);
        repeat (150) @(posedge clk);
        for (i = 0; i < 16; i = i + 1) begin
            vram_rd(rb);
            if (rb !== (((i / 8) ^ ((i % 8) * 37)) & 8'hFF)) begin
                rerr = rerr + 1;
                if (rerr <= 8) $display("RD ERR PGT[%0d]: got=%02x exp=%02x",
                                        i, rb, ((i / 8) ^ ((i % 8) * 37)) & 8'hFF);
            end
        end
        if (rerr == 0) $display("*** LECTURAS CPU: 48/48 OK (cursor curado) ***");
        else           $display("*** LECTURAS CPU: %0d ERRORES ***", rerr);
    end
    #1000;
    $finish;
end

initial begin
    #300000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
