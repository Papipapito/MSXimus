// ============================================================================
// tb_t2cursor.sv — CURSOR y BLINK de TEXT2 (SCREEN 0 WIDTH 80) en la PILA
// COMPLETA (vdp.v real + v9968_vram_shim + modelo de memoria).
//
// GROUND TRUTH medido en openMSX (Philips NMS 8250, V9938) en el prompt de
// BASIC/MSX-DOS en W80:
//   R#0=04 R#1=70 R#2=03 R#3=27 R#4=02 R#7=F4 R#10=00 R#12=00 R#13=00
//   -> NT=0x0000, tabla de BLINK=0x0800, PGT=0x1000
//   -> EL CURSOR NO ES EL BLINK: la BIOS escribe el CODIGO 0xFF en la celda
//      del cursor y reescribe el PATRON del caracter 255 (PGT+0x7F8..0x7FF)
//      con el COMPLEMENTO del glifo que hay debajo. Al mover el cursor
//      RESTAURA el codigo original en la celda vieja.
//   -> R#13 = 0x00 (blink PARADO) y la tabla de blink 0x0800 NUNCA se
//      inicializa: contiene la FUENTE de TEXT1 rancia => ~29% de bits a 1.
//      Si el core no apaga el blink con R#13=0, salen celdas sueltas con los
//      colores de R#12 (=0x00, negro) por toda la pantalla.
//
// El banco reproduce ESO:
//   FASE A (frame 2): pantalla "Ok" + cursor (0xFF) en fila 1 col 0, tabla de
//                     blink LLENA DE BASURA, R#13 = 0x00.
//   MOVIMIENTO DEL CURSOR por el PUERTO CPU (como la BIOS): restaura la celda
//                     vieja, pone 0xFF en la fila 3 col 0 y reescribe PGT[255].
//   FASE B (frame 4): se vuelve a volcar. Un RESIDUO = la celda vieja sigue
//                     dando 0xFF.
//   FASE B tambien FUERZA el blink activo (ff_interleaving_page=0) con R#13
//                     != 0 para verificar el MAPEO caracter->bit de la tabla
//                     de blink (los parches _127E / _127F) contra el valor
//                     EXACTO de la basura, celda a celda.
//
// SONDA: en cada par de caracteres, al final de la fase 5 (sub_phase 12, ya
// cargados los patrones) se registran los codigos, los patrones y los colores
// que el CORE ha traido de VRAM. Es "lo que el core cree que hay en pantalla".
// ============================================================================
`timescale 1ns/1ps

module tb_t2cursor;

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
wire [31:0] bk_wdata;
wire [3:0]  bk_wmask;
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
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
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

// ---------------------------------------------------------------------------
//  Puerto CPU
// ---------------------------------------------------------------------------
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
// escritura VRAM como la BIOS: R#14 + puerto 1 (A7..A0, 01|A13..A8) + puerto 0
task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b01, a[13:8]});
end
endtask
task vram_wr1(input [17:0] a, input [7:0] d);
begin vram_set_wr(a); bus_wr(3'd0, d); end
endtask

// ---------------------------------------------------------------------------
//  SONDA: lo que el CORE trae de VRAM por celda
// ---------------------------------------------------------------------------
`define SM u_vdp.u_timing_control.u_screen_mode

integer vs_cnt = 0;
logic vs_d = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    if (display_vs && !vs_d) vs_cnt <= vs_cnt + 1;
end

wire [9:0] sm_spy   = `SM.screen_pos_y;
wire [7:0] sm_ppy   = `SM.pixel_pos_y;
wire [3:0] sm_sub   = `SM.w_sub_phase;
wire [2:0] sm_phase = `SM.ff_phase;
wire [5:0] sm_posx  = `SM.ff_pos_x;
wire       sm_act   = `SM.w_screen_in_active;
wire       sm_blink = `SM.blink;
wire [1:0] sm_wblk  = `SM.w_blink;

// w_blink es COMBINACIONAL sobre ff_next_vram2, y ff_next_vram2 se PISA con el
// color en la fase 4 (sub 12). El unico instante en que w_blink vale es
// EXACTAMENTE ese flanco: se latchea aqui para poder mirarlo en la fase 5.
reg [1:0] blk_lat = 2'b00;
always @(posedge clk)
    if (sm_phase == 3'd4 && sm_sub == 4'd12) blk_lat <= sm_wblk;

// snapshot[fase][fila][col]
localparam NROW = 5, NCOL = 80;
integer snap_chr [0:1][0:NROW-1][0:NCOL-1];
integer snap_pat [0:1][0:NROW-1][0:NCOL-1];
integer snap_col [0:1][0:NROW-1][0:NCOL-1];
integer snap_blk [0:1][0:NROW-1][0:NCOL-1];
integer cap_ph = -1;                    // -1 = no capturar
integer nsamp = 0;
integer r, c;

always @(posedge clk) begin
    if (cap_ph >= 0 && sm_act && sm_phase == 3'd5 && sm_sub == 4'd12
        && sm_ppy[2:0] == 3'd0 && sm_spy[9:8] == 2'b00 && sm_spy[7:3] < NROW) begin
        r = sm_spy[7:3];
        c = 2*sm_posx;
        if (c < NCOL-1) begin
            snap_chr[cap_ph][r][c]   = `SM.ff_next_vram0;
            snap_pat[cap_ph][r][c]   = `SM.ff_next_vram1;
            snap_col[cap_ph][r][c]   = `SM.ff_next_vram2;
            snap_blk[cap_ph][r][c]   = blk_lat[1];
            snap_chr[cap_ph][r][c+1] = `SM.ff_next_vram4;
            snap_pat[cap_ph][r][c+1] = `SM.ff_next_vram5;
            snap_col[cap_ph][r][c+1] = `SM.ff_next_vram3;
            snap_blk[cap_ph][r][c+1] = blk_lat[0];
            nsamp = nsamp + 1;
        end
    end
end

// ---------------------------------------------------------------------------
//  Utilidades
// ---------------------------------------------------------------------------
localparam [17:0] NT   = 18'h00000;
localparam [17:0] BLK  = 18'h00800;
localparam [17:0] PGT  = 18'h01000;
localparam [21:0] VB   = 22'h280000;

integer i, j, k;
integer errs = 0;

task dump(input integer ph, input [200*8:1] title);
    integer rr, cc, lin, byt, bit_, expb;
    begin
        $display("");
        $display("---------------- %0s ----------------", title);
        for (rr = 0; rr < NROW; rr = rr + 1) begin
            $write("  fila %0d codigos:", rr);
            for (cc = 0; cc < 12; cc = cc + 1) $write(" %02h", snap_chr[ph][rr][cc][7:0]);
            $write("   |blinkbit:");
            for (cc = 0; cc < 12; cc = cc + 1) $write(" %0d", snap_blk[ph][rr][cc]);
            $write("   |color:");
            for (cc = 0; cc < 6; cc = cc + 1) $write(" %02h", snap_col[ph][rr][cc][7:0]);
            $write("\n");
        end
    end
endtask

// comprueba que el bit de blink que aplica el core coincide con el bit EXACTO
// de la tabla de VRAM (mapeo caracter -> byte/bit de los parches _127E/_127F)
task check_blink_map(input integer ph);
    integer rr, cc, lin, byt, bit_, expb, bad, tot;
    begin
        bad = 0; tot = 0;
        for (rr = 0; rr < NROW; rr = rr + 1)
            for (cc = 0; cc < NCOL-1; cc = cc + 1) begin
                lin  = rr*80 + cc;
                byt  = sdram[VB + BLK + (lin >> 3)];
                bit_ = 7 - (lin & 7);
                expb = (byt >> bit_) & 1;
                tot  = tot + 1;
                if (snap_blk[ph][rr][cc] !== expb) begin
                    bad = bad + 1;
                    if (bad <= 12)
                        $display("    MAPEO MAL fila %0d col %0d: core=%0d esperado=%0d (byte 0x%04h=0x%02h bit %0d)",
                                 rr, cc, snap_blk[ph][rr][cc], expb, BLK + (lin>>3), byt, bit_);
                end
            end
        if (bad == 0) $display("  MAPEO BLINK caracter->bit: OK en las %0d celdas comprobadas", tot);
        else begin
            $display("  *** MAPEO BLINK MAL en %0d de %0d celdas ***", bad, tot);
            errs = errs + 1;
        end
    end
endtask

initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;

    // ---- FUENTE en PGT=0x1000 --------------------------------------------
    // 0x20 espacio = 0x00; 'O','k' patrones distinguibles; 0xFF = cursor
    for (i = 0; i < 8; i = i + 1) begin
        sdram[VB + PGT + 8'h4F*8 + i] = 8'hFC;   // 'O'
        sdram[VB + PGT + 8'h6B*8 + i] = 8'h88;   // 'k'
        sdram[VB + PGT + 8'h41*8 + i] = 8'hA0;   // 'A'
        sdram[VB + PGT + 8'hFF*8 + i] = 8'hFF;   // cursor = NOT(espacio)
    end

    // ---- NT: todo espacios; "Ok" en la fila 0; cursor 0xFF en fila 1 col 0
    for (i = 0; i < 24*80; i = i + 1) sdram[VB + NT + i] = 8'h20;
    sdram[VB + NT + 0]  = 8'h4F;   // 'O'
    sdram[VB + NT + 1]  = 8'h6B;   // 'k'
    sdram[VB + NT + 80] = 8'hFF;   // CURSOR en fila 1 col 0

    // ---- TABLA DE BLINK 0x0800: BASURA, como la deja la BIOS de verdad ----
    //      (fuente de TEXT1 rancia; ~50% de bits a 1 aqui, ~29% en el dump real)
    for (i = 0; i < 240; i = i + 1)
        sdram[VB + BLK + i] = (i < 8) ? 8'h00 :
                              ((i % 4 == 0) ? 8'h3C : (i % 4 == 1) ? 8'hA5 :
                               (i % 4 == 2) ? 8'h81 : 8'hFF);

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);

    // paleta: 4 = azul (fondo), 15 = blanco (texto), 9 = rojo (blink fg)
    vdp_pal(4'd4,  3'd0, 3'd0, 3'd7);
    vdp_pal(4'd15, 3'd7, 3'd7, 3'd7);
    vdp_pal(4'd9,  3'd7, 3'd0, 3'd0);

    // registros EXACTOS medidos en openMSX en el prompt W80
    vdp_reg(6'd0,  8'h04);
    vdp_reg(6'd1,  8'h70);
    vdp_reg(6'd2,  8'h03);      // NT  = 0x0000
    vdp_reg(6'd3,  8'h27);      // BLK = 0x0800 (A8..A6 = 111 obligatorio)
    vdp_reg(6'd4,  8'h02);      // PGT = 0x1000
    vdp_reg(6'd7,  8'hF4);      // texto 15 / fondo 4
    vdp_reg(6'd10, 8'h00);
    vdp_reg(6'd12, 8'h00);      // colores de blink (0 = negro, como la BIOS)
    vdp_reg(6'd13, 8'h00);      // *** BLINK PARADO ***
    vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd23, 8'h00);

    // ================= FASE A =================
    wait (vs_cnt >= 2);
    @(posedge clk); cap_ph = 0;
    wait (vs_cnt >= 3);
    @(posedge clk); cap_ph = -1;
    $display("FASE A: %0d muestras", nsamp);
    dump(0, "FASE A  R#13=0 (blink PARADO) + tabla de blink CON BASURA");
    $display("  [comprobacion] con R#13=0 NINGUNA celda debe llevar bit de blink:");
    begin : chkA
        integer rr, cc, nb;
        nb = 0;
        for (rr = 0; rr < NROW; rr = rr + 1)
            for (cc = 0; cc < NCOL-1; cc = cc + 1)
                if (snap_blk[0][rr][cc] !== 0) nb = nb + 1;
        if (nb == 0) $display("  OK: 0 celdas con blink (R#13=0 apaga el blink correctamente)");
        else begin $display("  *** MAL: %0d celdas con blink activo pese a R#13=0 ***", nb); errs = errs + 1; end
    end
    $display("  [comprobacion] celda (1,0) debe ser 0xFF (cursor) y (1,1) 0x20:");
    if (snap_chr[0][1][0][7:0] === 8'hFF && snap_chr[0][1][1][7:0] === 8'h20)
        $display("  OK: cursor visto en (1,0)");
    else begin
        $display("  *** MAL: (1,0)=%02h (1,1)=%02h ***", snap_chr[0][1][0][7:0], snap_chr[0][1][1][7:0]);
        errs = errs + 1;
    end

    // ================= MOVIMIENTO DEL CURSOR (lo que hace la BIOS) =========
    $display("");
    $display(">>> MOVIENDO EL CURSOR por el PUERTO CPU: (1,0) -> (3,0)");
    vram_wr1(NT + 80,  8'h20);          // restaura la celda vieja
    vram_wr1(NT + 240, 8'hFF);          // cursor en la fila 3 col 0
    vram_set_wr(PGT + 18'h7F8);         // reescribe el patron del caracter 255
    for (i = 0; i < 8; i = i + 1) bus_wr(3'd0, 8'h5F);   // patron NUEVO 0x5F

    // ademas: activa el blink FORZANDO el estado (esperar 10 campos costaria
    // 25 min de sim) para verificar el MAPEO caracter -> bit de la tabla
    vdp_reg(6'd12, 8'h94);              // blink fg=9 (rojo) / bg=4
    vdp_reg(6'd13, 8'h11);
    force u_vdp.u_timing_control.u_ssg.ff_interleaving_page = 1'b0;

    // ================= FASE B =================
    wait (vs_cnt >= 4);
    @(posedge clk); cap_ph = 1;
    wait (vs_cnt >= 5);
    @(posedge clk); cap_ph = -1;
    dump(1, "FASE B  tras mover el cursor (y con blink FORZADO a activo)");

    $display("");
    $display("  [RESIDUO] celda (1,0) deberia valer 0x20 tras la restauracion:");
    if (snap_chr[1][1][0][7:0] === 8'h20)
        $display("  OK: sin residuo — el core lee el codigo restaurado");
    else begin
        $display("  *** RESIDUO: (1,0) sigue valiendo 0x%02h (patron 0x%02h) ***",
                 snap_chr[1][1][0][7:0], snap_pat[1][1][0][7:0]);
        errs = errs + 1;
    end
    $display("  [CURSOR NUEVO] celda (3,0) deberia valer 0xFF con patron 0x5F:");
    if (snap_chr[1][3][0][7:0] === 8'hFF && snap_pat[1][3][0][7:0] === 8'h5F)
        $display("  OK: cursor nuevo con el patron reescrito");
    else begin
        $display("  *** MAL: (3,0) codigo=0x%02h patron=0x%02h (esperado FF/5F) ***",
                 snap_chr[1][3][0][7:0], snap_pat[1][3][0][7:0]);
        errs = errs + 1;
    end
    $display("  [MAPEO BLINK] con blink activo, bit aplicado vs tabla de VRAM:");
    check_blink_map(1);

    $display("");
    if (errs == 0) $display("========== RESULTADO: TODO OK (%0d fallos) ==========", errs);
    else           $display("========== RESULTADO: %0d COMPROBACIONES FALLIDAS ==========", errs);
    #1000;
    $finish;
end

initial begin
    #400000000;
    $display("TIMEOUT vs_cnt=%0d nsamp=%0d", vs_cnt, nsamp);
    $finish;
end

endmodule
