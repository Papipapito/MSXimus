// ============================================================================
// tb_s2fossil2.sv — el S#2 FOSIL de Fleet contra la PILA COMPLETA:
//   glue REAL (v9968_cpu_glue, protocolo valid->ready + /WAIT + fail-open)
//   + vdp COMPLETO (cpu_interface con sus slots/prefetch REALES, timing,
//     motor) + v9968_vram_shim + SDRAM con latencia variable.
//
// COBERTURA NUEVA: tb_bootreplay ataca el bus del vdp SIN glue y ademas
// espera bus_ready ANTES de levantar bus_valid (disciplina contraria al
// glue real); tb_cpuif_dbl lleva el glue pero con un MODELO de VRAM educado.
// Esta es la primera vez que el protocolo real del glue pelea contra los
// slots/stalls reales del interface+shim.
//
// GUION (radiografia s020 de Fleet, muerte en t~19.6s CON pantalla aun ON):
//   init SCREEN5 + pantalla ON -> trafico mixto: rafagas OTIR de escritura
//   al puerto 0 + polls de la BIOS (select S#2 / IN / restore) + lecturas
//   0x98 sueltas. El fosil real: todas las lecturas de 0x99 devuelven el
//   mismo byte mientras el S#2 interno cambia.
// DETECTORES:
//   - FOSIL: >=8 INs identicos con el VR REAL (jerarquico) conmutando >=2
//     veces entre medias.
//   - fail-opens del glue (wtmo_hit) — cada uno = un dato rancio servido.
//   - bus atascado: bus_valid alto > 4000 ciclos.
//   - divergencia TR: byte99[7] != TR interno en el momento de la entrega.
// Uso: vvp sim [+K=n] [+SCROFF=1] [+VCD=1]
// ============================================================================
`timescale 1ns/1ps

module tb_s2fossil2;

localparam real CLK_HALF = 5.8207;
localparam real TSTATE   = 279.33;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

// --- glue real ---
wire [2:0]  bus_address;
wire        bus_ioreq, bus_write, bus_valid;
wire [7:0]  bus_wdata;
wire [7:0]  bus_rdata;
wire        bus_rdata_en, bus_ready;

logic       csw_n = 1'b1, csr_n = 1'b1;
logic [1:0] z_mode = 2'd0;
logic [7:0] z_cdo  = 8'd0;
wire  [7:0] z_cdi;
wire        g_wait_n;

v9968_cpu_glue u_glue (
    .clk_86(clk), .rst_n(reset_n),
    .csw_n(csw_n), .csr_n(csr_n), .mode(z_mode), .cdo(z_cdo), .cdi_r(z_cdi),
    .wait_n(g_wait_n),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en)
);

// --- vdp completo + shim + SDRAM (calcado de tb_bootreplay) ---
wire        int_n;
wire [17:2] vaddr;
wire        vwrite, vvalid, vrefresh;
wire [31:0] vwdata;
wire [3:0]  vmask;
wire [4:0]  vtag;
wire [31:0] vrdata;
wire        vrdata_en;
wire [4:0]  vrtag;
wire        vstall;
wire        d_hs, d_vs, d_en;
wire [7:0]  d_r, d_g, d_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vaddr), .vram_write(vwrite),
    .vram_valid(vvalid), .vram_wdata(vwdata),
    .vram_wdata_mask(vmask),
    .vram_rdata(vrdata), .vram_rdata_en(vrdata_en),
    .vram_tag(vtag), .vram_rtag(vrtag),
    .vram_stall(vstall),
    .vram_refresh(vrefresh),
    .display_hs(d_hs), .display_vs(d_vs), .display_en(d_en),
    .display_r(d_r), .display_g(d_g), .display_b(d_b),
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
    .vram_address(vaddr), .vram_write(vwrite),
    .vram_valid(vvalid), .vram_wdata(vwdata),
    .vram_wdata_mask(vmask), .vram_tag(vtag),
    .vram_rdata(vrdata), .vram_rdata_en(vrdata_en),
    .vram_rtag(vrtag),
    .vram_stall(vstall),
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

integer vi;
initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = vi[7:0] ^ 8'h33;
end

// --- sondas ---
wire p_vr   = u_vdp.u_cpu_interface.status_vsync;      // VR REAL del timing
wire p_tr   = u_vdp.u_cpu_interface.status_transfer_ready;
wire p_F    = u_vdp.u_cpu_interface.ff_frame_interrupt;
wire p_infl = u_vdp.u_cpu_interface.ff_pf_inflight;
wire p_busy = u_vdp.u_cpu_interface.ff_busy;

integer n_glue = 0, n_tmo = 0, n_stuck = 0, vr_toggles = 0;
reg  tmo_d = 1'b0, vr_d = 1'b0;
integer bv_run = 0;
always @(posedge clk) if( reset_n ) begin
    if (bus_valid && bus_ready) n_glue = n_glue + 1;
    tmo_d <= u_glue.wtmo_hit;
    if (u_glue.wtmo_hit && !tmo_d) n_tmo = n_tmo + 1;
    vr_d <= p_vr;
    if (p_vr != vr_d) vr_toggles = vr_toggles + 1;
    if (bus_valid) begin
        bv_run = bv_run + 1;
        if (bv_run == 4000) begin
            n_stuck = n_stuck + 1;
            $display("!! BUS ATASCADO %0d: bus_valid lleva 4000 ciclos alto (t=%0t) busy=%b infl=%b",
                     n_stuck, $time, p_busy, p_infl);
        end
    end
    else bv_run = 0;
end

// --- ciclo Z80 con /WAIT ---
task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.5*TSTATE);
    csw_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task z80_out_otir(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.5*TSTATE);
    csw_n = 1'b1;
    #(4.0*TSTATE);
end
endtask

task z80_in(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(TSTATE);
    csr_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.0*TSTATE);
    d = z_cdi;
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(8.0*TSTATE);
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

task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b01, a[13:8]});
end
endtask

task bios_poll(output [7:0] v);
begin
    z80_out(2'd1, 8'h02); z80_out(2'd1, 8'h8F);
    z80_in (2'd1, v);
    z80_out(2'd1, 8'h00); z80_out(2'd1, 8'h8F);
end
endtask

// ---------------------------------------------------------------------------
integer K = 60;
integer SCROFF = 0;
integer i, j;
logic [7:0] v, v_prev, vjunk;
integer same_run, max_same_run, run_tgl, tgl_at_runstart;
integer n_trdiv = 0;
integer fossil;

initial begin
    if( !$value$plusargs("K=%d", K) ) K = 60;
    if( !$value$plusargs("SCROFF=%d", SCROFF) ) SCROFF = 0;
    if( $test$plusargs("VCD") ) begin
        $dumpfile("s2fossil2.vcd"); $dumpvars(0, tb_s2fossil2);
    end

    repeat (48) @(posedge clk);
    reset_n = 1;
    repeat (48) @(posedge clk);
    $display("=== tb_s2fossil2 (pila completa + glue): K=%0d SCROFF=%0d ===", K, SCROFF);

    // init: SCREEN 5 + pantalla ON (fetch de display vivo = slots peleados)
    vdp_reg(6'd0, 8'h06);      // G4 (SCREEN 5)
    vdp_reg(6'd2, 8'h1F);      // NT base
    vdp_reg(6'd1, 8'h40);      // BL=1 pantalla ON, IE0=0
    vdp_reg(6'd15, 8'h00);     // R#15=0
    // llenar un poco de VRAM por el puerto (el propio init estresa)
    vram_set_wr(18'h00000);
    for (i = 0; i < 64; i = i + 1) z80_out_otir(2'd0, i[7:0]);

    // FASE 1 — referencia: 12 polls con la pantalla ON (deben variar el VR)
    max_same_run = 0; same_run = 0; v_prev = 8'hXX;
    for (i = 0; i < 12; i = i + 1) begin
        bios_poll(v);
        if (i == 0 || v !== v_prev) same_run = 1; else same_run = same_run + 1;
        if (same_run > max_same_run) max_same_run = same_run;
        v_prev = v;
    end
    $display("FASE1: ultimo=%02x racha_max=%0d (VR real conmuta con el raster)",
             v_prev, max_same_run);

    // FASE 2 — prefetch caliente + el tren de la muerte
    vram_set_rd(18'h00100);
    for (i = 0; i < 4; i = i + 1) z80_in(2'd0, vjunk);
    vram_set_wr(18'h08000);

    if (SCROFF) vdp_reg(6'd1, 8'h00);   // variante: pantalla OFF antes del tren

    fossil = 0; max_same_run = 0; same_run = 0; run_tgl = 0;
    tgl_at_runstart = vr_toggles; v_prev = 8'hXX;
    for (i = 0; i < K; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) z80_out_otir(2'd0, 8'hA5 ^ i[7:0] ^ j[7:0]);
        bios_poll(v);
        if (v[7] != p_tr) n_trdiv = n_trdiv + 1;   // byte entregado vs TR real
        if (i == 0 || v !== v_prev) begin
            same_run = 1; tgl_at_runstart = vr_toggles;
        end
        else same_run = same_run + 1;
        if (same_run > max_same_run) begin
            max_same_run = same_run;
            run_tgl = vr_toggles - tgl_at_runstart;
        end
        if ((i % 3) == 2) begin
            z80_in(2'd0, vjunk); z80_in(2'd0, vjunk);
        end
        if ((i % 10) == 9)
            $display("  tren %0d/%0d: v=%02x  VRreal=%b TRreal=%b F=%b infl=%b  fail-opens=%0d atascos=%0d",
                     i+1, K, v, p_vr, p_tr, p_F, p_infl, n_tmo, n_stuck);
        v_prev = v;
    end

    $display("RESULTADO: racha_max=%0d (VR togg=%0d dentro)  fail-opens=%0d  atascos=%0d  div_TR=%0d  n_glue=%0d",
             max_same_run, run_tgl, n_tmo, n_stuck, n_trdiv, n_glue);
    if (max_same_run >= 8 && run_tgl >= 2) begin
        $display("*** FOSIL REPRODUCIDO: %0d lecturas identicas con el VR real moviendose ***", max_same_run);
        fossil = 1;
    end
    if (n_tmo > 0)
        $display("*** %0d FAIL-OPENS del glue = datos rancios servidos ***", n_tmo);
    if (n_stuck > 0)
        $display("*** BUS ATASCADO %0d veces ***", n_stuck);
    if (!fossil && n_tmo == 0 && n_stuck == 0)
        $display("*** SIN FOSIL en esta configuracion ***");
    $finish;
end

endmodule
