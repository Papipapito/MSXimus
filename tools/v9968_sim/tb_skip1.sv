// ============================================================================
// tb_skip1.sv — CAZA DEL "+1" DE VRAMSOK2: lecturas secuenciales de VRAM por
// el puerto 0x98 (SETRD previo, ~35+ T-states entre INs) a traves del
// ADAPTADOR REAL (v9968_cpu_glue) con TEXT2 (SCREEN 0 W80) DIBUJANDO, contra
// el shim + backend de LATENCIA CONFIGURABLE (+LATMIN/+LATRND, ciclos de 85.9).
//
// Bug medido en placa (DDR3 0,13% / SDRAM 0,34% de las lecturas): el puerto
// devuelve el byte de dir+1; releer recolocando el puntero SIEMPRE acierta.
//
// SOSPECHOSOS INSTRUMENTADOS (analisis estatico previo):
//  S1) vdp_vram_interface.v (router de respuestas por rtag, lineas 310-332):
//      ff_cpu_vram_rdata_en NO se limpia si el ciclo siguiente trae la
//      respuesta de OTRO consumidor (el `else` que limpia solo corre cuando
//      vram_rdata_en=0). Una respuesta CPU (late_v) seguida INMEDIATAMENTE de
//      una respuesta bg (pipe[6]) deja cpu_rdata_en ALTO 2 CICLOS:
//        -> el core ve dos rdata_en: doble autoincremento (salta 1 direccion)
//        -> y el 2o ciclo entra por `vram_rdata_en && !ff_pf_inflight`
//           (pf_inflight ya bajo con el 1o): el dato se re-publica al BUS y
//           machaca cdi_r del glue. Firma esperada: +1, nunca -1.
//      Sonda: en2 / leak_pre.
//  S2) re-captura del glue (bus_valid retenido en alto + latch con
//      ff_bus_ready interno): doble ejecucion del IN si llega con el puerto
//      bloqueado (ff_busy|ff_pf_inflight). Sonda: blocked_in / phantom.
//  S3) doble incremento del puntero en el core. Sonda: dbl_inc.
//
// LECCION de la campana: verificar ACTIVIDAD>0 de cada camino antes de creer
// un verde. Al final se imprime el bloque ACTIVIDAD.
// ============================================================================
`timescale 1ns/1ps

module tb_skip1;

localparam real CLK_HALF  = 5.8207;      // 85.909 MHz
localparam real NS_PER_CY = 11.6414;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

// --- bus del V9968, movido por el GLUE REAL ---
wire [2:0]  bus_address;
wire        bus_ioreq, bus_write, bus_valid;
wire [7:0]  bus_wdata;
wire [7:0]  bus_rdata;
wire        bus_rdata_en, bus_ready, int_n;

// --- lado Z80 ---
logic       csw_n = 1'b1, csr_n = 1'b1;
logic [1:0] z_mode = 2'd0;
logic [7:0] z_cdo  = 8'd0;
wire [7:0]  z_cdi;

v9968_cpu_glue u_glue (
    .clk_86(clk), .rst_n(reset_n),
    .csw_n(csw_n), .csr_n(csr_n), .mode(z_mode), .cdo(z_cdo), .cdi_r(z_cdi),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en)
);

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
wire [31:0] dbg_miss, dbg_bka, dbg_park, dbg_bkb, dbg_drops;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag), .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask), .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t), .diag(shim_diag),
    .dbg_miss(dbg_miss), .dbg_bka(dbg_bka), .dbg_park(dbg_park),
    .dbg_bkb(dbg_bkb), .dbg_drops(dbg_drops)
);

// ---------------------------------------------------------------------------
//  Backend de latencia CONFIGURABLE (canales A y B como el bridge real)
// ---------------------------------------------------------------------------
integer LATMIN, LATRND;                  // ciclos de 85.9 por op
logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat, vi;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask; m_cnt <= 0;
        m_lat <= LATMIN + ((LATRND > 0) ? ({$random} % LATRND) : 0);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt >= m_lat) begin
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
        m2_pend <= 1; m2_addr <= bk2_addr; m2_cnt <= 0;
        m2_lat <= LATMIN + ((LATRND > 0) ? ({$random} % LATRND) : 0);
    end
    else if (m2_pend) begin
        m2_cnt <= m2_cnt + 1;
        if (m2_cnt >= m2_lat) begin
            bk2_rword[7:0]  <= sdram[{m2_addr[21:1],1'b0}];
            bk2_rword[15:8] <= sdram[{m2_addr[21:1],1'b1}];
            bk2_done_t <= ~bk2_done_t; m2_pend <= 0;
        end
    end
end

// ---------------------------------------------------------------------------
//  Modelo del ciclo de I/O del Z80 (como tb_t2cpuread; sin /WAIT, como el HW)
// ---------------------------------------------------------------------------
real TSTATE = 279.33;                    // ns por estado T (3,579545 MHz)
integer FCPU_KHZ;

task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);                 // T1
    csw_n = 1'b0;
    #(3.0*TSTATE);             // T2 + TW + T3
    csw_n = 1'b1;
    #(8.0*TSTATE);             // resto de OUT (n),A = 12 T
end
endtask

task z80_in(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(TSTATE);                 // T1
    csr_n = 1'b0;
    #(2.5*TSTATE);             // el Z80 muestrea el bus de datos AQUI
    d = z_cdi;                 // <<< lo que el Z80 se lleva de verdad
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(8.0*TSTATE);             // resto de IN A,(n) = 12 T
end
endtask

task vdp_reg(input [5:0] r, input [7:0] d);
begin z80_out(2'd1, d); z80_out(2'd1, {2'b10, r}); end
endtask
task vram_set_rd(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b00, a[13:8]});
end
endtask

// patron VRAMSOK2: dir ^ (dir>>8) ^ A5h (+ bits de banco para desambiguar)
function [7:0] pat(input [17:0] a);
    pat = a[7:0] ^ a[15:8] ^ {6'd0, a[17:16]} ^ 8'hA5;
endfunction

// ---------------------------------------------------------------------------
//  SONDAS
// ---------------------------------------------------------------------------
integer vs_cnt = 0;
logic vs_d = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    if (display_vs && !vs_d) vs_cnt <= vs_cnt + 1;
end

// S1a: pulso de cpu_vram_rdata_en de 2+ ciclos en el router del interface
integer en2 = 0;
logic   cpu_en_d = 0;
time    t_last_leak = 0;
always @(posedge clk) begin
    cpu_en_d <= u_vdp.u_vram_interface.ff_cpu_vram_rdata_en;
    if (u_vdp.u_vram_interface.ff_cpu_vram_rdata_en && cpu_en_d) begin
        en2 <= en2 + 1;
        t_last_leak = $time;
        $display("LEAK_EN2 t=%0t  (cpu_rdata_en ALTO 2 ciclos) rtag_ahora=%b h=%0d",
                 $time, vram_rtag, u_vdp.u_vram_interface.h_count);
    end
end

// S1b: precursor en la SALIDA del shim — respuesta CPU seguida de OTRA
// respuesta en el ciclo inmediato (cualquier tag)
integer leak_pre = 0;
logic       ren_d = 0;
logic [4:0] rtag_d = 0;
always @(posedge clk) begin
    ren_d  <= vram_rdata_en;
    rtag_d <= vram_rtag;
    if (vram_rdata_en && ren_d && rtag_d[4:2] == 3'd3 && vram_rtag[4:2] != 3'd3) begin
        leak_pre <= leak_pre + 1;
        $display("LEAK_PRE t=%0t  resp CPU seguida de resp tag=%0d", $time, vram_rtag[4:2]);
    end
end

// S3: doble incremento del puntero del core
integer dbl_inc = 0;
logic   inc_d = 0;
always @(posedge clk) begin
    inc_d <= u_vdp.u_cpu_interface.ff_vram_address_inc;
    if (u_vdp.u_cpu_interface.ff_vram_address_inc && inc_d) begin
        dbl_inc <= dbl_inc + 1;
        $display("DBL_INC t=%0t  addr=%05h", $time,
                 u_vdp.u_cpu_interface.ff_vram_address);
    end
end

// S2: INs que llegan con el puerto bloqueado + ejecuciones w_read por IN
integer blocked_in = 0;
always @(posedge clk)
    if (u_glue.rd_start && (u_vdp.u_cpu_interface.ff_busy ||
                            u_vdp.u_cpu_interface.ff_pf_inflight))
        blocked_in <= blocked_in + 1;

integer n_wread = 0, n_hit = 0, n_missblk = 0;
always @(posedge clk) begin
    if (u_vdp.u_cpu_interface.w_read && u_vdp.u_cpu_interface.ff_port0) begin
        n_wread <= n_wread + 1;
        if (u_vdp.u_cpu_interface.ff_pf_valid) n_hit <= n_hit + 1;
        else                                   n_missblk <= n_missblk + 1;
    end
end
// fantasma: 2 ejecuciones w_read para el MISMO IN (entre flancos de csr)
integer phantom = 0;
integer wread_this_in = 0;
always @(posedge clk) begin
    if (u_glue.rd_start && z_mode == 2'd0) wread_this_in <= 0;
    else if (u_vdp.u_cpu_interface.w_read && u_vdp.u_cpu_interface.ff_port0) begin
        wread_this_in <= wread_this_in + 1;
        if (wread_this_in == 1) begin
            phantom <= phantom + 1;
            $display("PHANTOM_RD t=%0t  segunda ejecucion del mismo IN", $time);
        end
    end
end

// actividad de respuestas por tag
integer resp_cpu = 0, resp_bg = 0, resp_late_cpu = 0, req_cpu = 0;
logic late_d = 0;
always @(posedge clk) begin
    late_d <= u_shim.late_v;
    if (vram_rdata_en && vram_rtag[4:2] == 3'd3) resp_cpu <= resp_cpu + 1;
    if (vram_rdata_en && vram_rtag[4:2] == 3'd1) resp_bg  <= resp_bg + 1;
    // grant de late_v con tag cpu = respuesta CPU servida desde el BACKEND
    if (late_d && !u_shim.late_v && u_shim.late_tag[4:2] == 3'd3)
        resp_late_cpu <= resp_late_cpu + 1;
    if (vram_valid && !vram_write && vram_tag[4:2] == 3'd3) req_cpu <= req_cpu + 1;
end

// ---------------------------------------------------------------------------
localparam [17:0] NT    = 18'h00000;
localparam [17:0] BLKT  = 18'h00800;
localparam [17:0] PGT   = 18'h01000;
localparam [21:0] VB    = 22'h280000;
localparam [17:0] START = 18'h02000;     // por encima de las tablas T2
localparam [17:0] TOP   = 18'h20000;     // 128KB (modo no-256K)

integer NRD;
integer i, k, addr_i, gap_t;
integer err_total = 0, err_p1 = 0, err_m1 = 0, err_otro = 0, incid = 0, reheal_ok = 0, reheal_bad = 0;
integer lfsr = 32'hACE1;
integer seed_i, rnd_tmp;
logic [7:0] got, got2, exp_;

initial begin
    if (!$value$plusargs("FCPU=%d", FCPU_KHZ)) FCPU_KHZ = 3580;
    if (!$value$plusargs("NRD=%d",  NRD))      NRD = 6000;
    if (!$value$plusargs("LATMIN=%d", LATMIN)) LATMIN = 26;
    if (!$value$plusargs("LATRND=%d", LATRND)) LATRND = 18;
    if ($value$plusargs("SEED=%d", seed_i)) begin
        rnd_tmp = $random(seed_i);           // resiembra el generador global
        lfsr    = seed_i ^ 32'hACE1;
        if (lfsr == 0) lfsr = 32'hACE1;
    end
    TSTATE = 1000000.0 / FCPU_KHZ;

    // VRAM entera con el patron; tablas T2 encima
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    for (vi = 0; vi < 262144; vi = vi + 1) sdram[VB + vi] = pat(vi[17:0]);
    for (i = 0; i < 24*80; i = i + 1) sdram[VB + NT + i] = 8'h40 + (i & 8'h3F);
    for (i = 0; i < 240; i = i + 1)  sdram[VB + BLKT + i] = 8'hA5;

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);

    // TEXT2 (SCREEN 0 W80) con display ON — mismo setup que tb_t2cpuread
    vdp_reg(6'd0,  8'h04);  vdp_reg(6'd1,  8'h70);
    vdp_reg(6'd2,  8'h03);  vdp_reg(6'd3,  8'h27);
    vdp_reg(6'd4,  8'h02);  vdp_reg(6'd7,  8'hF4);
    vdp_reg(6'd10, 8'h00);  vdp_reg(6'd12, 8'h00);
    vdp_reg(6'd13, 8'h00);  vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd23, 8'h00);

    wait (vs_cnt >= 2);                  // calentar la cache un frame

    $display("=== VRAMSOK2-sim: %0d lecturas, Z80 %0d kHz, backend LAT=%0d+rnd%0d cy (%.0f-%.0f ns/op) ===",
             NRD, FCPU_KHZ, LATMIN, LATRND,
             LATMIN*NS_PER_CY, (LATMIN+LATRND)*NS_PER_CY);

    addr_i = START;
    vram_set_rd(addr_i[17:0]);
    for (i = 0; i < NRD; i = i + 1) begin
        z80_in(2'd0, got);
        exp_ = pat(addr_i[17:0]);
        if (got !== exp_) begin
            err_total = err_total + 1;
            if      (got === pat(addr_i[17:0] + 18'd1)) err_p1  = err_p1 + 1;
            else if (got === pat(addr_i[17:0] - 18'd1)) err_m1  = err_m1 + 1;
            else                                        err_otro = err_otro + 1;
            $display("ERROR #%0d t=%0t addr=%05h got=%02h exp=%02h [p(a+1)=%02h p(a-1)=%02h] dt_leak=%0t",
                     err_total, $time, addr_i, got, exp_,
                     pat(addr_i[17:0]+18'd1), pat(addr_i[17:0]-18'd1),
                     $time - t_last_leak);
            // VRAMSOK2: recolocar el puntero y RELEER la misma direccion
            incid = incid + 1;
            vram_set_rd(addr_i[17:0]);
            z80_in(2'd0, got2);
            if (got2 === exp_) reheal_ok = reheal_ok + 1;
            else begin
                reheal_bad = reheal_bad + 1;
                $display("  RELECTURA TAMBIEN MALA: got2=%02h (esto NO pasa en placa)", got2);
            end
            // y recolocar para continuar en addr+1
            vram_set_rd(addr_i[17:0] + 18'd1);
        end
        addr_i = addr_i + 1;
        if (addr_i >= TOP) begin
            addr_i = START;
            vram_set_rd(addr_i[17:0]);
        end
        // hueco entre INs: el IN consume 12T; +23..30T de lazo => 35..42 T
        lfsr = (lfsr >> 1) ^ (lfsr[0] ? 32'h8005 : 0);
        gap_t = 23 + (lfsr & 7);
        #(gap_t * TSTATE);
        if ((i % 1000) == 999)
            $display("... %0d lecturas t=%0t err=%0d (p1=%0d) en2=%0d leak_pre=%0d dbl_inc=%0d",
                     i+1, $time, err_total, err_p1, en2, leak_pre, dbl_inc);
    end

    $display("");
    $display("======================= RESULTADO =======================");
    $display("  lecturas: %0d   ERRORES: %0d (%.3f%%)", NRD, err_total, 100.0*err_total/NRD);
    $display("  firma: +1=%0d  -1=%0d  otro=%0d", err_p1, err_m1, err_otro);
    $display("  incidentes con relectura: %0d  (relectura OK=%0d, mala=%0d)", incid, reheal_ok, reheal_bad);
    $display("---------------------- SONDAS ---------------------------");
    $display("  S1 en2 (cpu_rdata_en 2 ciclos): %0d", en2);
    $display("  S1 leak_pre (resp CPU seguida de otra resp): %0d", leak_pre);
    $display("  S3 dbl_inc (doble autoincremento): %0d", dbl_inc);
    $display("  S2 blocked_in (IN con puerto bloqueado): %0d   phantom (2a ejecucion): %0d", blocked_in, phantom);
    $display("--------------------- ACTIVIDAD -------------------------");
    $display("  w_read=%0d (hit=%0d, miss_bloqueante=%0d)  req_cpu=%0d resp_cpu=%0d", n_wread, n_hit, n_missblk, req_cpu, resp_cpu);
    $display("  resp_cpu_desde_backend(late)=%0d   resp_bg=%0d", resp_late_cpu, resp_bg);
    $display("  shim dbg_drops={s1_pfq=%0d, wq_full=%0d}  bg_miss(c_miss)=%0d sp_miss=%0d",
             dbg_drops[31:16], dbg_drops[15:0], dbg_miss[15:0], dbg_miss[31:16]);
    if (n_wread == 0 || resp_cpu == 0 || resp_bg == 0)
        $display("  *** BANCO INVALIDO: algun camino con actividad CERO ***");
    else if (err_total > 0 && err_p1 == err_total && en2 > 0)
        $display("  => REPRODUCIDO: firma +1 pura y colision S1 detectada");
    else if (err_total > 0)
        $display("  => HAY ERRORES: revisar correlacion en el log");
    else
        $display("  => sin errores con esta latencia/cadencia");
    #1000;
    $finish;
end

initial begin
    #3000000000;                          // 3 s de sim
    $display("TIMEOUT vs_cnt=%0d", vs_cnt);
    $finish;
end

endmodule
