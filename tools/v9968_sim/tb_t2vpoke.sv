// ============================================================================
// tb_t2vpoke.sv — GUIONES EN TEXT2 AL ESCRIBIR LA TABLA DE NOMBRES (25/09/2026).
//
// Sintoma en placa (Zynq, capturadora a 60 fps): cuando la CPU escribe la
// tabla de nombres de SCREEN 0 W80 (el menu imprimiendo, o un VPOKE en bucle
// sobre la fila 10), en la fila que se escribe aparecen durante UN fotograma
// guiones blancos de una celda de ancho, sobre todo en las lineas 0 y 7 del
// caracter, en las celdas recien escritas. No es dato viejo: es dato de
// PATRON erroneo (barras) para esas celdas en esa linea.
//
// Dos pilas con el MISMO estimulo de puerto CPU:
//   A = vdp + v9968_vram_shim + modelo de memoria con latencia variable
//   B = vdp + modelo perfecto (respuesta a 8 ciclos)
// y se comparan los pixeles de salida ciclo a ciclo. Ademas se vigila cada
// respuesta de fondo (tag C_BG) de la pila A contra la VRAM perfecta: dato
// ACTUAL (bien), dato ANTERIOR a la ultima escritura (rancio, tolerable) o
// NINGUNO de los dos (BASURA: el fallo).
//
// +GAP=ciclos entre VPOKEs (defecto 250 ~ 2,9 us), +FRAMES=fotogramas de
// escritura (defecto 6), +LATMIN/+LATRND latencia del backend (26+rnd18 =
// SDRAM medida; 8+rnd4 = DDR3 rapida).
// ============================================================================
`timescale 1ns/1ps

module tb_t2vpoke;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

integer GAP = 250, FRAMES = 6, LATMIN = 26, LATRND = 18, SEED = 1;

// ---------------- bus compartido, ioreq/valid por pila ----------------
logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic [7:0]  bus_wdata = 0;
logic        A_ioreq = 0, A_valid = 0;
logic        B_ioreq = 0, B_valid = 0;

// ---------------- PILA A: shim + memoria con latencia ----------------
wire  [7:0]  A_rdata;
wire         A_rdata_en, A_ready, A_int_n;
wire  [17:2] A_vaddr;
wire         A_vwrite, A_vvalid, A_vrefresh;
wire  [31:0] A_vwdata;
wire  [3:0]  A_vmask;
wire  [4:0]  A_vtag;
wire  [31:0] A_vrdata;
wire         A_vrdata_en;
wire  [4:0]  A_vrtag;
wire         A_vstall;
wire         A_hs, A_vs, A_en;
wire  [7:0]  A_r, A_g, A_b;

vdp u_vdpA (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(A_ioreq), .bus_write(bus_write),
    .bus_valid(A_valid), .bus_ready(A_ready),
    .bus_wdata(bus_wdata), .bus_rdata(A_rdata), .bus_rdata_en(A_rdata_en),
    .int_n(A_int_n),
    .vram_address(A_vaddr), .vram_write(A_vwrite),
    .vram_valid(A_vvalid), .vram_wdata(A_vwdata),
    .vram_wdata_mask(A_vmask),
    .vram_rdata(A_vrdata), .vram_rdata_en(A_vrdata_en),
    .vram_tag(A_vtag), .vram_rtag(A_vrtag),
    .vram_stall(A_vstall),
    .vram_refresh(A_vrefresh),
    .display_hs(A_hs), .display_vs(A_vs), .display_en(A_en),
    .display_r(A_r), .display_g(A_g), .display_b(A_b),
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
wire [31:0] dbg_miss, dbg_bka, dbg_park, dbg_bkb, dbg_drops;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(A_vaddr), .vram_write(A_vwrite),
    .vram_valid(A_vvalid), .vram_wdata(A_vwdata),
    .vram_wdata_mask(A_vmask), .vram_tag(A_vtag),
    .vram_rdata(A_vrdata), .vram_rdata_en(A_vrdata_en),
    .vram_rtag(A_vrtag),
    .vram_stall(A_vstall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag),
    .dbg_miss(dbg_miss), .dbg_bka(dbg_bka), .dbg_park(dbg_park),
    .dbg_bkb(dbg_bkb), .dbg_drops(dbg_drops)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask;
        m_cnt <= 0; m_lat <= LATMIN + ({$random} % LATRND);
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
        m2_cnt <= 0; m2_lat <= LATMIN + ({$random} % LATRND);
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

// ---------------- PILA B: modelo perfecto (8 ciclos) ----------------
wire  [7:0]  B_rdata;
wire         B_rdata_en, B_ready, B_int_n;
wire  [17:2] B_vaddr;
wire         B_vwrite, B_vvalid, B_vrefresh;
wire  [31:0] B_vwdata;
wire  [3:0]  B_vmask;
wire  [4:0]  B_vtag;
logic [31:0] B_vrdata_r = 0;
logic        B_vrdata_en_r = 0;
logic [4:0]  B_vrtag_r = 0;
wire         B_hs, B_vs, B_en;
wire  [7:0]  B_r, B_g, B_b;

vdp u_vdpB (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(B_ioreq), .bus_write(bus_write),
    .bus_valid(B_valid), .bus_ready(B_ready),
    .bus_wdata(bus_wdata), .bus_rdata(B_rdata), .bus_rdata_en(B_rdata_en),
    .int_n(B_int_n),
    .vram_address(B_vaddr), .vram_write(B_vwrite),
    .vram_valid(B_vvalid), .vram_wdata(B_vwdata),
    .vram_wdata_mask(B_vmask),
    .vram_rdata(B_vrdata_r), .vram_rdata_en(B_vrdata_en_r),
    .vram_tag(B_vtag), .vram_rtag(B_vrtag_r),
    .vram_stall(1'b0),
    .vram_refresh(B_vrefresh),
    .display_hs(B_hs), .display_vs(B_vs), .display_en(B_en),
    .display_r(B_r), .display_g(B_g), .display_b(B_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

logic [31:0] vram_mem  [0:65535];      // VRAM perfecta (palabras de 32 bits)
logic [31:0] vram_prev [0:65535];      // valor ANTERIOR a la ultima escritura
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
always @(posedge clk) begin
    B_vrdata_en_r <= 1'b0;
    if (B_vvalid && B_vwrite) begin
        vram_prev[B_vaddr] <= vram_mem[B_vaddr];
        if (!B_vmask[0]) vram_mem[B_vaddr][ 7: 0] <= B_vwdata[ 7: 0];
        if (!B_vmask[1]) vram_mem[B_vaddr][15: 8] <= B_vwdata[15: 8];
        if (!B_vmask[2]) vram_mem[B_vaddr][23:16] <= B_vwdata[23:16];
        if (!B_vmask[3]) vram_mem[B_vaddr][31:24] <= B_vwdata[31:24];
    end
    else if (B_vvalid && !B_vwrite && !p_pend) begin
        p_pend <= 1'b1; p_addr <= B_vaddr; p_tag <= B_vtag; p_cnt <= 0;
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == 6) begin
            B_vrdata_r    <= vram_mem[p_addr];
            B_vrtag_r     <= p_tag;
            B_vrdata_en_r <= 1'b1;
            p_pend        <= 1'b0;
        end
    end
end

// ---------------- puerto CPU (a las dos pilas) ----------------
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d; bus_write <= 1;
    fork
        begin
            A_ioreq <= 1; A_valid <= 1;
            @(posedge clk);
            while (!A_ready) @(posedge clk);
            A_ioreq <= 0; A_valid <= 0;
        end
        begin
            B_ioreq <= 1; B_valid <= 1;
            @(posedge clk);
            while (!B_ready) @(posedge clk);
            B_ioreq <= 0; B_valid <= 0;
        end
    join
    @(posedge clk);
    bus_write <= 0;
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
// VPOKE como la BIOS: R#14 + puerto 1 (A7..A0, 01|A13..A8) + puerto 0
task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b01, a[13:8]});
end
endtask
integer last_wr_t = 0, last_wr_addr = -1;
task vram_wr1(input [17:0] a, input [7:0] d);
begin
    vram_set_wr(a);
    bus_wr(3'd0, d);
    last_wr_t = $time; last_wr_addr = a;
end
endtask

// ---------------- posicion en pantalla (pila B como reloj) ----------------
integer vs_cnt = 0, line = 0, xpix = 0;
logic vs_d = 0, hs_d = 0;
always @(posedge clk) begin
    vs_d <= B_vs; hs_d <= B_hs;
    if (B_vs && !vs_d) begin vs_cnt <= vs_cnt + 1; line <= 0; end
    else if (B_hs && !hs_d) begin line <= line + 1; xpix <= 0; end
    else if (B_en) xpix <= xpix + 1;
end
`define SMB u_vdpB.u_timing_control.u_screen_mode
`define SMA u_vdpA.u_timing_control.u_screen_mode

// ---------------- comparacion de pixeles ----------------
integer n_mis = 0, n_mis_shown = 0, n_lock = 0;
integer hist_line [0:7];
integer hist_frame [0:63];
integer mis_cells [0:79];
integer ii;
initial begin
    for (ii = 0; ii < 8; ii = ii + 1) hist_line[ii] = 0;
    for (ii = 0; ii < 64; ii = ii + 1) hist_frame[ii] = 0;
    for (ii = 0; ii < 80; ii = ii + 1) mis_cells[ii] = 0;
end
integer capturing = 0;
always @(posedge clk) begin
    if (capturing) begin
        if (A_en != B_en || A_hs != B_hs || A_vs != B_vs) n_lock <= n_lock + 1;
        if (A_en && B_en && ({A_r, A_g, A_b} != {B_r, B_g, B_b})) begin
            n_mis <= n_mis + 1;
            hist_line[`SMB.pixel_pos_y[2:0]] <= hist_line[`SMB.pixel_pos_y[2:0]] + 1;
            if (vs_cnt < 64) hist_frame[vs_cnt] <= hist_frame[vs_cnt] + 1;
            if (n_mis_shown < 40) begin
                n_mis_shown <= n_mis_shown + 1;
                $display("MIS t=%0t frame=%0d linea=%0d x=%0d  A=%02h%02h%02h B=%02h%02h%02h  ppy=%0d fila=%0d  ult.escritura hace %0d ns a %05h",
                         $time, vs_cnt, line, xpix, A_r, A_g, A_b, B_r, B_g, B_b,
                         `SMB.pixel_pos_y[2:0], `SMB.pixel_pos_y[7:3], $time - last_wr_t, last_wr_addr);
            end
        end
    end
end

// ---------------- vigilancia de las respuestas de fondo de A ----------------
// cola de direcciones de fetch de A (bg = tag[4:2] == 1) y comparacion de
// cada respuesta con la VRAM perfecta (actual / anterior / basura)
logic [15:0] rq_addr [0:63];
logic [4:0]  rq_tag  [0:63];
integer rq_wp = 0, rq_rp = 0;
integer n_bg = 0, n_bg_ok = 0, n_bg_stale = 0, n_bg_garb = 0, n_garb_shown = 0;
always @(posedge clk) begin
    if (A_vvalid && !A_vwrite) begin
        rq_addr[rq_wp % 64] <= A_vaddr; rq_tag[rq_wp % 64] <= A_vtag; rq_wp <= rq_wp + 1;
    end
    if (A_vrdata_en) begin : chk
        integer k; logic found; logic [15:0] ad;
        // la respuesta lleva solo el tag: casar con la peticion mas antigua del mismo tag
        found = 0;
        for (k = rq_rp; k < rq_wp && !found; k = k + 1)
            if (rq_tag[k % 64] == A_vrtag) begin found = 1; ad = rq_addr[k % 64]; end
        if (found && capturing && A_vrtag[4:2] == 3'd1) begin
            n_bg <= n_bg + 1;
            if (A_vrdata == vram_mem[ad]) n_bg_ok <= n_bg_ok + 1;
            else if (A_vrdata == vram_prev[ad]) n_bg_stale <= n_bg_stale + 1;
            else begin
                n_bg_garb <= n_bg_garb + 1;
                if (n_garb_shown < 30) begin
                    n_garb_shown <= n_garb_shown + 1;
                    $display("GARB t=%0t frame=%0d linea=%0d  bg addr=%05h (byte %05h) got=%08h  actual=%08h  anterior=%08h  ult.escr hace %0d ns a %05h",
                             $time, vs_cnt, line, ad, {ad, 2'b00}, A_vrdata, vram_mem[ad], vram_prev[ad],
                             $time - last_wr_t, last_wr_addr);
                end
            end
        end
        // avanzar el puntero de lectura por encima de lo consumido (aprox.)
        if (found) begin
            if (k - 1 == rq_rp) rq_rp <= rq_rp + 1;
            else rq_rp <= k - 1 + 1;
        end
    end
end

// ---------------- precarga ----------------
localparam [17:0] NT  = 18'h00000;
localparam [17:0] BLK = 18'h00800;
localparam [17:0] PGT = 18'h01000;
localparam [21:0] VB  = 22'h280000;
logic [7:0] fontA [0:7];
logic [7:0] fontB [0:7];
integer i, j, k, c, frames_done;
task preload_byte(input [17:0] a, input [7:0] d);
begin
    sdram[VB + a] = d;
    vram_mem[a[17:2]][8*a[1:0] +: 8] = d;
    vram_prev[a[17:2]][8*a[1:0] +: 8] = d;
end
endtask

initial begin
    if (!$value$plusargs("GAP=%d", GAP)) GAP = 250;
    if (!$value$plusargs("FRAMES=%d", FRAMES)) FRAMES = 6;
    if (!$value$plusargs("LATMIN=%d", LATMIN)) LATMIN = 26;
    if (!$value$plusargs("LATRND=%d", LATRND)) LATRND = 18;
    if (!$value$plusargs("SEED=%d", SEED)) SEED = 1;
    i = $random(SEED);
    fontA[0]=8'h20; fontA[1]=8'h50; fontA[2]=8'h88; fontA[3]=8'h88; fontA[4]=8'hF8; fontA[5]=8'h88; fontA[6]=8'h88; fontA[7]=8'h00;
    fontB[0]=8'hF0; fontB[1]=8'h88; fontB[2]=8'h88; fontB[3]=8'hF0; fontB[4]=8'h88; fontB[5]=8'h88; fontB[6]=8'hF0; fontB[7]=8'h00;
    for (i = 0; i < 4194304; i = i + 1) sdram[i] = 8'h00;
    for (i = 0; i < 65536; i = i + 1) begin vram_mem[i] = 32'd0; vram_prev[i] = 32'd0; end
    for (i = 0; i < 8; i = i + 1) begin
        preload_byte(PGT + 8'h41*8 + i, fontA[i]);
        preload_byte(PGT + 8'h42*8 + i, fontB[i]);
    end
    for (i = 0; i < 24*80; i = i + 1) preload_byte(NT + i, 8'h41);
    for (i = 0; i < 270; i = i + 1) preload_byte(BLK + i, 8'h00);

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);
    vdp_pal(4'd4,  3'd0, 3'd0, 3'd7);
    vdp_pal(4'd15, 3'd7, 3'd7, 3'd7);
    vdp_reg(6'd0,  8'h04);
    vdp_reg(6'd1,  8'h70);
    vdp_reg(6'd2,  8'h03);      // NT  = 0x0000
    vdp_reg(6'd3,  8'h27);      // BLK = 0x0800
    vdp_reg(6'd4,  8'h02);      // PGT = 0x1000
    vdp_reg(6'd7,  8'hF4);
    vdp_reg(6'd10, 8'h00);
    vdp_reg(6'd12, 8'h00);
    vdp_reg(6'd13, 8'h00);
    vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd23, 8'h00);

    wait (vs_cnt >= 4);                 // calentamiento: cache residente
    @(posedge clk); capturing = 1;
    $display("=== tb_t2vpoke: GAP=%0d ciclos, FRAMES=%0d, backend LAT=%0d+rnd%0d, SEED=%0d ===", GAP, FRAMES, LATMIN, LATRND, SEED);
    frames_done = vs_cnt;
    k = 0;
    while (vs_cnt < frames_done + FRAMES) begin
        for (c = 0; c < 80 && vs_cnt < frames_done + FRAMES; c = c + 1) begin
            vram_wr1(NT + 10*80 + c, (k[0]) ? 8'h41 : 8'h42);
            repeat (GAP) @(posedge clk);
        end
        k = k + 1;
    end
    @(posedge clk); capturing = 0;
    $display("");
    $display("================= RESULTADO =================");
    $display("  pixeles distintos A/B: %0d   (desalineamientos hs/vs/en: %0d)", n_mis, n_lock);
    $display("  por linea del caracter (0-7): %0d %0d %0d %0d %0d %0d %0d %0d",
             hist_line[0], hist_line[1], hist_line[2], hist_line[3], hist_line[4], hist_line[5], hist_line[6], hist_line[7]);
    $display("  respuestas bg de A: %0d  OK=%0d  RANCIAS(anterior)=%0d  BASURA=%0d", n_bg, n_bg_ok, n_bg_stale, n_bg_garb);
    $display("  shim: miss=%0d drops=%08h", dbg_miss, dbg_drops);
    if (n_mis == 0) $display("  => SIN DIFERENCIAS");
    else if (n_bg_garb > 0) $display("  => REPRODUCIDO: respuestas de fondo con dato que no es ni el actual ni el anterior");
    else $display("  => diferencias solo por dato rancio (latencia de la cola de escritura)");
    $finish;
end

initial begin
    #(400_000_000);
    $display("TIMEOUT vs_cnt=%0d", vs_cnt);
    $finish;
end
endmodule
