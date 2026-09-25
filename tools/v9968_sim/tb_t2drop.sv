// ============================================================================
// tb_t2drop.sv — TEXT2 + VPOKE: ¿de donde salen los guiones? (25/09/2026)
//
// Un solo vdp en SCREEN 0 W80 con la pantalla llena de 'A' y un bucle de
// VPOKE (como la BIOS: R#14 + 99h + 99h + 98h) sobre la fila 10 alternando
// 'B'/'A', con separacion +GAP ciclos. Memoria: +PERFECT=1 modelo perfecto de
// 8 ciclos (aisla el CORE); +PERFECT=0 v9968_vram_shim + memoria con latencia
// (+LATMIN/+LATRND).
//
// SONDAS (todas independientes de la geometria de la salida de video):
//  S1  peticion de fondo PERDIDA en vdp_vram_interface: screen_mode_vram_valid
//      llega con el puerto ocupado (ff_vram_valid) o pisada por un sprite.
//  S2  por par de celdas y linea, al final de la fase 5 (sub-fase 12): los
//      NOMBRES que el core cree (ff_next_vram0/4) contra la VRAM perfecta
//      (vale el actual o el anterior a la ultima escritura), y los PATRONES
//      (ff_next_vram1/5) contra la fuente del nombre que el core tiene.
//      Un patron que no es el de su nombre = el guion.
//  S3  latch sin respuesta: en la sub-fase 12 de las fases 0-3 no ha llegado
//      ninguna respuesta de fondo desde la peticion de la sub-fase 0.
// ============================================================================
`timescale 1ns/1ps

module tb_t2drop;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

integer GAP = 250, FRAMES = 4, LATMIN = 26, LATRND = 18, SEED = 1, PERFECT = 1, WARM = 4, NOWR = 0;
integer TRACE = 0, CPUFONT = 0, CPUALL = 0;   // +TRACE=1 traza del shim; +CPUFONT=1 la fuente de 'B' la escribe la CPU; +CPUALL=1 todas las tablas

logic [2:0]  bus_address = 0;
logic        bus_write = 0, bus_ioreq = 0, bus_valid = 0;
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

// ---------------- memoria: shim + latencia, o modelo perfecto ----------------
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
wire [31:0] s_rdata;
wire        s_rdata_en, s_stall;
wire [4:0]  s_rtag;
wire [31:0] dbg_miss, dbg_bka, dbg_park, dbg_bkb, dbg_drops;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid & ~PERFECT[0]), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(s_rdata), .vram_rdata_en(s_rdata_en), .vram_rtag(s_rtag),
    .vram_stall(s_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask), .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr), .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag),
    .dbg_miss(dbg_miss), .dbg_bka(dbg_bka), .dbg_park(dbg_park), .dbg_bkb(dbg_bkb), .dbg_drops(dbg_drops)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata; m_msk <= bk_wmask;
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
            bk_done_t <= ~bk_done_t; m_pend <= 0;
        end
    end
end
logic        m2_pend = 0;
logic [21:0] m2_addr;
integer      m2_cnt, m2_lat;
always @(posedge clk) begin
    if (bk2_req && !m2_pend) begin
        m2_pend <= 1; m2_addr <= bk2_addr; m2_cnt <= 0; m2_lat <= LATMIN + ({$random} % LATRND);
    end
    else if (m2_pend) begin
        m2_cnt <= m2_cnt + 1;
        if (m2_cnt == m2_lat) begin
            bk2_rword[7:0]  <= sdram[{m2_addr[21:1],1'b0}];
            bk2_rword[15:8] <= sdram[{m2_addr[21:1],1'b1}];
            bk2_done_t <= ~bk2_done_t; m2_pend <= 0;
        end
    end
end

// VRAM perfecta (siempre al dia; con PERFECT=1 tambien sirve las lecturas)
logic [31:0] vram_mem  [0:65535];
logic [31:0] vram_prev [0:65535];
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
logic [31:0] P_rdata = 0;
logic        P_rdata_en = 0;
logic [4:0]  P_rtag = 0;
always @(posedge clk) begin
    P_rdata_en <= 1'b0;
    if (vram_valid && vram_write) begin
        vram_prev[vram_address] <= vram_mem[vram_address];
        if (!vram_wdata_mask[0]) vram_mem[vram_address][ 7: 0] <= vram_wdata[ 7: 0];
        if (!vram_wdata_mask[1]) vram_mem[vram_address][15: 8] <= vram_wdata[15: 8];
        if (!vram_wdata_mask[2]) vram_mem[vram_address][23:16] <= vram_wdata[23:16];
        if (!vram_wdata_mask[3]) vram_mem[vram_address][31:24] <= vram_wdata[31:24];
    end
    else if (vram_valid && !vram_write && !p_pend) begin
        p_pend <= 1'b1; p_addr <= vram_address; p_tag <= vram_tag; p_cnt <= 0;
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == 6) begin
            P_rdata <= vram_mem[p_addr]; P_rtag <= p_tag; P_rdata_en <= 1'b1; p_pend <= 1'b0;
        end
    end
end
assign vram_rdata    = PERFECT[0] ? P_rdata    : s_rdata;
assign vram_rdata_en = PERFECT[0] ? P_rdata_en : s_rdata_en;
assign vram_rtag     = PERFECT[0] ? P_rtag     : s_rtag;
assign vram_stall    = PERFECT[0] ? 1'b0       : s_stall;

// ---------------- puerto CPU ----------------
// (asignaciones BLOQUEANTES tras el flanco +1ns: con '<=' dentro de una task
// llamada desde initial, Verilator --timing no publicaba el ciclo de bus y el
// VDP se quedaba sin registros — pantalla apagada, 0 peticiones de fondo)
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk); #1;
    bus_address = a; bus_wdata = d; bus_ioreq = 1; bus_write = 1; bus_valid = 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    #1; bus_ioreq = 0; bus_write = 0; bus_valid = 0;
    repeat (20) @(posedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask
task vdp_pal(input [3:0] idx, input [2:0] r, input [2:0] g, input [2:0] b);
begin vdp_reg(6'd16, {4'd0, idx}); bus_wr(3'd2, {1'b0, r, 1'b0, b}); bus_wr(3'd2, {5'd0, g}); end
endtask
task vram_set_wr(input [17:0] a);
begin vdp_reg(6'd14, {5'd0, a[16:14]}); bus_wr(3'd1, a[7:0]); bus_wr(3'd1, {2'b01, a[13:8]}); end
endtask
integer last_wr_t = 0, last_wr_addr = -1;
task vram_wr1(input [17:0] a, input [7:0] d);
begin vram_set_wr(a); bus_wr(3'd0, d); last_wr_t = $time; last_wr_addr = a; end
endtask

// ---------------- posicion ----------------
`define SM  u_vdp.u_timing_control.u_screen_mode
`define VI  u_vdp.u_vram_interface
integer vs_cnt = 0, line = 0, miss_prev = 0;
logic vs_d = 0, hs_d = 0;
always @(posedge clk) begin
    vs_d <= display_vs; hs_d <= display_hs;
    if (display_vs && !vs_d) begin vs_cnt <= vs_cnt + 1; line <= 0;
        if (capturing) $display("  cuadro %0d: misses del shim en el cuadro = %0d (S2 patrones erroneos acumulados %0d, S3 %0d)", vs_cnt, dbg_miss - miss_prev, s2_pat, s3);
        miss_prev <= dbg_miss; end
    else if (display_hs && !hs_d) line <= line + 1;
end

// ---------------- S1: peticiones de fondo perdidas ----------------
integer s1_busy = 0, s1_sprite = 0, s1_shown = 0, n_bgreq = 0, n_cpuwr = 0;
integer cpu_wr_t = 0;                      // ultimo ciclo en que el interface emitio una escritura CPU
integer cyc = 0;
always @(posedge clk) begin
    cyc <= cyc + 1;
    if (`VI.vram_valid && `VI.vram_write) begin n_cpuwr <= n_cpuwr + 1; cpu_wr_t <= cyc; end
    if (`VI.screen_mode_vram_valid) begin
        n_bgreq <= n_bgreq + 1;
        if (`VI.ff_vram_valid) begin
            s1_busy <= s1_busy + 1;
            if (s1_shown < 20) begin
                s1_shown <= s1_shown + 1;
                $display("S1 DROP(ocupado) t=%0t frame=%0d linea=%0d fase=%0d sub=%0d h_count=%0d  puerto ocupado por %s (emitido hace %0d ciclos)",
                         $time, vs_cnt, line, `SM.ff_phase, `SM.w_sub_phase, `VI.h_count,
                         `VI.ff_vram_write ? "ESCRITURA CPU" : "otra lectura", cyc - cpu_wr_t);
            end
        end
        else if (`VI.sprite_vram_valid) s1_sprite <= s1_sprite + 1;
    end
end

// ---------------- TRAZA del shim (+TRACE=1, solo con PERFECT=0) ----------------
// Lanzamientos del backend (kind 0=pf 1=rq 2=wq), misses de fondo con el estado de
// ventana/sc-cache, fills que aterrizan (sc-cache y ventana), fills descartados por
// pf_dirty y write-checks (tag-match en cache/ventana).
logic tr_bsy_d = 0;
always @(posedge clk) begin
    tr_bsy_d <= u_shim.bsy;
    if (TRACE && (capturing || TRACE == 2)) begin       // +TRACE=2: desde el reset
        if (u_shim.rf_p)
            $display("TR REFILL addr=%04h rq=%0d bgp_empty=%0d vb_p2=%0d t=%0t", u_shim.rf_addr, u_shim.rq_used, u_shim.bgp_empty, u_shim.vb_p2, $time);
        if (u_shim.bsy && !tr_bsy_d)
            $display("TR LANZA kind=%0d addr=%04h tag=%02h pfq=%0d wq=%0d rq=%0d t=%0t", u_shim.cur_kind, u_shim.cur_addrw,
                     u_shim.cur_tag, u_shim.pfq_wp - u_shim.pfq_rp, u_shim.wq_used, u_shim.rq_used, $time);
        if (u_shim.spr_p1 && u_shim.spr_tag1[4:2] == 3'd1
            && !(u_shim.pwq_v && u_shim.pwq[41:32] == u_shim.spr_addr1[15:6])
            && !(u_shim.scq_v && u_shim.scq_tag == u_shim.spr_addr1[15:12]))
            $display("TR BGMISS addr=%04h pwq_v=%0d pwq_tag=%03h scq_v=%0d scq_tag=%0h pfq=%0d rq=%0d t=%0t", u_shim.spr_addr1,
                     u_shim.pwq_v, u_shim.pwq[41:32], u_shim.scq_v, u_shim.scq_tag, u_shim.pfq_wp - u_shim.pfq_rp, u_shim.rq_used, $time);
        if (u_shim.vb_p2 && u_shim.vb_hit2) $display("TR VBHIT addr=%04h t=%0t", u_shim.vb_addr2, $time);
        if (u_shim.fill_now) $display("TR SCFILL addr=%04h word=%08h t=%0t", u_shim.fill_addr, u_shim.fill_word, $time);
        if (u_shim.pww_en) $display("TR WFILL idx=%02h tag=%03h data=%08h t=%0t", u_shim.pww_idx, u_shim.pww_tag, u_shim.pww_data, $time);
        if (u_shim.bsy && u_shim.cur_kind != 2'd2 && u_shim.pf_dirty
            && (u_shim.got_lo || (u_shim.bk_done_t != u_shim.done_d)) && (u_shim.got_hi || (u_shim.bk2_done_t != u_shim.done2_d)))
            $display("TR FILLDROP_dirty kind=%0d addr=%04h t=%0t", u_shim.cur_kind, u_shim.cur_addrw, $time);
        if (u_shim.wrk_p1) $display("TR WCHK addr=%04h mask=%b wrk_hit=%0d wu_hit=%0d t=%0t", u_shim.wrk_addr1, u_shim.wrk_mask1, u_shim.wrk_hit, u_shim.wu_hit, $time);
    end
end

// ---------------- S3: latch sin respuesta ----------------
integer bg_resp_since = 0, s3 = 0, s3_shown = 0;
always @(posedge clk) begin
    if (vram_rdata_en && vram_rtag[4:2] == 3'd1) bg_resp_since <= bg_resp_since + 1;
    if (`SM.w_screen_in_active && `SM.w_sub_phase == 4'd0) bg_resp_since <= 0;
    if (`SM.w_screen_in_active && `SM.w_sub_phase == 4'd12 && `SM.ff_phase <= 3'd3 && bg_resp_since == 0 && capturing) begin
        s3 <= s3 + 1;
        if (s3_shown < 20) begin
            s3_shown <= s3_shown + 1;
            $display("S3 LATCH SIN RESPUESTA t=%0t frame=%0d linea=%0d fase=%0d posx=%0d  ult.escritura hace %0d ns a %05h",
                     $time, vs_cnt, line, `SM.ff_phase, `SM.ff_pos_x, $time - last_wr_t, last_wr_addr);
        end
    end
end

// ---------------- S2: nombres y patrones por celda ----------------
localparam [17:0] NT  = 18'h00000;
localparam [17:0] BLK = 18'h00800;
localparam [17:0] PGT = 18'h01000;
localparam [21:0] VB  = 22'h280000;
function [7:0] mem8(input [17:0] a); mem8 = vram_mem[a[17:2]][8*a[1:0] +: 8]; endfunction
function [7:0] prev8(input [17:0] a); prev8 = vram_prev[a[17:2]][8*a[1:0] +: 8]; endfunction
integer capturing = 0;
integer s2_name = 0, s2_pat = 0, s2_shown = 0, s2_cells = 0;
integer hist_line [0:7];
integer ii;
initial for (ii = 0; ii < 8; ii = ii + 1) hist_line[ii] = 0;
always @(posedge clk) begin
    if (capturing && `SM.w_screen_in_active && `SM.ff_phase == 3'd5 && `SM.w_sub_phase == 4'd12
        && `SM.screen_pos_y[9:8] == 2'b00 && `SM.screen_pos_y[7:3] < 24) begin : s2
        integer r, c, ln; logic [7:0] n0, n1, p0, p1, e0, e1; logic [17:0] a0, a1;
        r = `SM.screen_pos_y[7:3]; ln = `SM.pixel_pos_y[2:0]; c = 2 * `SM.ff_pos_x;
        if (c < 79) begin
            s2_cells <= s2_cells + 1;
            n0 = `SM.ff_next_vram0; n1 = `SM.ff_next_vram4;
            p0 = `SM.ff_next_vram1; p1 = `SM.ff_next_vram5;
            a0 = NT + r*80 + c; a1 = a0 + 1;
            // nombres: actual o anterior
            if (n0 != mem8(a0) && n0 != prev8(a0)) begin
                s2_name <= s2_name + 1;
                if (s2_shown < 30) begin s2_shown <= s2_shown + 1;
                    $display("S2 NOMBRE t=%0t frame=%0d fila=%0d col=%0d linea=%0d core=%02h vram=%02h/%02h  ult.escr hace %0d ns a %05h",
                             $time, vs_cnt, r, c, ln, n0, mem8(a0), prev8(a0), $time - last_wr_t, last_wr_addr); end
            end
            if (n1 != mem8(a1) && n1 != prev8(a1)) begin
                s2_name <= s2_name + 1;
                if (s2_shown < 30) begin s2_shown <= s2_shown + 1;
                    $display("S2 NOMBRE t=%0t frame=%0d fila=%0d col=%0d linea=%0d core=%02h vram=%02h/%02h  ult.escr hace %0d ns a %05h",
                             $time, vs_cnt, r, c + 1, ln, n1, mem8(a1), prev8(a1), $time - last_wr_t, last_wr_addr); end
            end
            // patrones: el de SU nombre (segun el core) en esta linea
            e0 = mem8(PGT + n0*8 + ln); e1 = mem8(PGT + n1*8 + ln);
            if (p0 != e0) begin
                s2_pat <= s2_pat + 1; hist_line[ln] <= hist_line[ln] + 1;
                if (s2_shown < 30) begin s2_shown <= s2_shown + 1;
                    $display("S2 PATRON t=%0t frame=%0d fila=%0d col=%0d linea=%0d nombre=%02h patron=%02h esperado=%02h (B=%02h A=%02h)  ult.escr hace %0d ns a %05h",
                             $time, vs_cnt, r, c, ln, n0, p0, e0, mem8(PGT + 8'h42*8 + ln), mem8(PGT + 8'h41*8 + ln), $time - last_wr_t, last_wr_addr); end
            end
            if (p1 != e1) begin
                s2_pat <= s2_pat + 1; hist_line[ln] <= hist_line[ln] + 1;
                if (s2_shown < 30) begin s2_shown <= s2_shown + 1;
                    $display("S2 PATRON t=%0t frame=%0d fila=%0d col=%0d linea=%0d nombre=%02h patron=%02h esperado=%02h (B=%02h A=%02h)  ult.escr hace %0d ns a %05h",
                             $time, vs_cnt, r, c + 1, ln, n1, p1, e1, mem8(PGT + 8'h42*8 + ln), mem8(PGT + 8'h41*8 + ln), $time - last_wr_t, last_wr_addr); end
            end
        end
    end
end

// ---------------- precarga y estimulo ----------------
logic [7:0] fontA [0:7];
logic [7:0] fontB [0:7];
integer i, k, c, frames_done;
task preload_byte(input [17:0] a, input [7:0] d);
begin
    sdram[VB + a] = d;
    vram_mem[a[17:2]][8*a[1:0] +: 8] = d;
    vram_prev[a[17:2]][8*a[1:0] +: 8] = d;
end
endtask

initial begin
    if (!$value$plusargs("GAP=%d", GAP)) GAP = 250;
    if (!$value$plusargs("FRAMES=%d", FRAMES)) FRAMES = 4;
    if (!$value$plusargs("LATMIN=%d", LATMIN)) LATMIN = 26;
    if (!$value$plusargs("LATRND=%d", LATRND)) LATRND = 18;
    if (!$value$plusargs("SEED=%d", SEED)) SEED = 1;
    if (!$value$plusargs("PERFECT=%d", PERFECT)) PERFECT = 1;
    if (!$value$plusargs("WARM=%d", WARM)) WARM = 4;
    if (!$value$plusargs("NOWR=%d", NOWR)) NOWR = 0;
    if (!$value$plusargs("TRACE=%d", TRACE)) TRACE = 0;
    if (!$value$plusargs("CPUFONT=%d", CPUFONT)) CPUFONT = 0;
    if (!$value$plusargs("CPUALL=%d", CPUALL)) CPUALL = 0;
    i = $random(SEED);
    fontA[0]=8'h20; fontA[1]=8'h50; fontA[2]=8'h88; fontA[3]=8'h88; fontA[4]=8'hF8; fontA[5]=8'h88; fontA[6]=8'h88; fontA[7]=8'h00;
    fontB[0]=8'hF0; fontB[1]=8'h88; fontB[2]=8'h88; fontB[3]=8'hF0; fontB[4]=8'h88; fontB[5]=8'h88; fontB[6]=8'hF0; fontB[7]=8'h00;
    for (i = 0; i < 4194304; i = i + 1) sdram[i] = 8'h00;
    for (i = 0; i < 65536; i = i + 1) begin vram_mem[i] = 32'd0; vram_prev[i] = 32'd0; end
    for (i = 0; i < 8; i = i + 1) begin
        preload_byte(PGT + 8'h41*8 + i, fontA[i]);
        if (!CPUFONT) preload_byte(PGT + 8'h42*8 + i, fontB[i]);   // con CPUFONT la escribe la CPU mas abajo
    end
    for (i = 0; i < 24*80; i = i + 1) preload_byte(NT + i, 8'h41);
    for (i = 0; i < 270; i = i + 1) preload_byte(BLK + i, 8'h00);

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);
    vdp_pal(4'd4,  3'd0, 3'd0, 3'd7);
    vdp_pal(4'd15, 3'd7, 3'd7, 3'd7);
    vdp_reg(6'd0,  8'h04); vdp_reg(6'd1,  8'h70);
    vdp_reg(6'd2,  8'h03); vdp_reg(6'd3,  8'h27); vdp_reg(6'd4,  8'h02);
    vdp_reg(6'd7,  8'hF4); vdp_reg(6'd10, 8'h00); vdp_reg(6'd12, 8'h00);
    vdp_reg(6'd13, 8'h00); vdp_reg(6'd18, 8'h00); vdp_reg(6'd23, 8'h00);
    // como la BIOS al hacer SCREEN 0: la fuente entra por el puerto de CPU (98h).
    // Tras el barrido post-reset de la sc-cache (8192 ciclos ~ 95us, scv_ready):
    // durante el barrido los fills estan bloqueados y el write-allocate no cuaja
    // (artefacto del banco: la BIOS real escribe mucho despues del reset).
    if (CPUFONT) begin
        wait (vs_cnt >= 2);
        for (i = 0; i < 8; i = i + 1) vram_wr1(PGT + 8'h42*8 + i, fontB[i]);
    end
    // +CPUALL=1: TODAS las tablas entran por el puerto de CPU con autoincremento
    // (como LDIRVM/FILVRM de la BIOS): nombres, blink y las dos fuentes. Es el
    // escenario real de la placa: con el write-allocate (_187) todo queda
    // residente en la sc-cache y la ventana ya no decide nada en TEXT2.
    // Ritmo: ~100 ciclos por byte (~1.2us), como un OTIR a ~10 MHz; el bus_wr
    // a pelo (22 ciclos) es 20x mas rapido que cualquier Z80 y desborda wq.
    if (CPUALL) begin
        wait (vs_cnt >= 2);
        vram_set_wr(NT);  for (i = 0; i < 24*80; i = i + 1) begin bus_wr(3'd0, 8'h41); repeat (78) @(posedge clk); end
        vram_set_wr(BLK); for (i = 0; i < 270; i = i + 1) begin bus_wr(3'd0, 8'h00); repeat (78) @(posedge clk); end
        vram_set_wr(PGT + 8'h41*8);
        for (i = 0; i < 16; i = i + 1) begin bus_wr(3'd0, (i < 8) ? fontA[i] : fontB[i-8]); repeat (78) @(posedge clk); end
        last_wr_t = $time; last_wr_addr = PGT + 8'h42*8 + 7;
    end

    wait (vs_cnt >= WARM);
    @(posedge clk); capturing = 1;
    $display("=== tb_t2drop: PERFECT=%0d GAP=%0d FRAMES=%0d WARM=%0d NOWR=%0d LAT=%0d+rnd%0d SEED=%0d ===", PERFECT, GAP, FRAMES, WARM, NOWR, LATMIN, LATRND, SEED);
    $display("  misses del shim al acabar el calentamiento: %0d", dbg_miss);
    frames_done = vs_cnt; k = 0;
    while (vs_cnt < frames_done + FRAMES) begin
        for (c = 0; c < 80 && vs_cnt < frames_done + FRAMES; c = c + 1) begin
            if (NOWR) repeat (GAP + 120) @(posedge clk);
            else begin vram_wr1(NT + 10*80 + c, (k[0]) ? 8'h41 : 8'h42); repeat (GAP) @(posedge clk); end
        end
        k = k + 1;
    end
    @(posedge clk); capturing = 0;
    $display("");
    $display("================= RESULTADO =================");
    $display("  escrituras CPU emitidas: %0d   peticiones de fondo: %0d", n_cpuwr, n_bgreq);
    $display("  S1 peticiones de fondo PERDIDAS: por puerto ocupado=%0d  por sprite=%0d", s1_busy, s1_sprite);
    $display("  S3 latches sin respuesta: %0d", s3);
    $display("  S2 celdas muestreadas: %0d   nombres erroneos: %0d   patrones erroneos: %0d", s2_cells, s2_name, s2_pat);
    $display("     patrones erroneos por linea (0-7): %0d %0d %0d %0d %0d %0d %0d %0d",
             hist_line[0], hist_line[1], hist_line[2], hist_line[3], hist_line[4], hist_line[5], hist_line[6], hist_line[7]);
    if (!PERFECT[0]) $display("  shim: miss=%0d drops=%08h", dbg_miss, dbg_drops);
    $finish;
end
initial begin #(300_000_000); $display("TIMEOUT vs_cnt=%0d", vs_cnt); $finish; end
endmodule
