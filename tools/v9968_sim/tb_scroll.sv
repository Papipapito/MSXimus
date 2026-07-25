// ============================================================================
// tb_sc5line.sv — _124: DISCRIMINADOR del comando LINE (campana motor de
// comandos, HW _123: "la animacion no acaba de ir" en los tests de HRA).
// Dos pilas ejecutan la MISMA secuencia (calcada de sc5line.asm de HRA):
//   A = vdp + v9968_vram_shim + modelo SDRAM realista (latencia variable)
//   B = vdp + modelo perfecto F0 (respuesta 8 ciclos)
// Casos: punto (t001), abanico corto (t017-020), lineas borde a borde en las
// 4 direcciones (t081-084), operaciones logicas con LECTURA-modificacion-
// escritura (t085: AND/OR/XOR/NOT/TIMP/TAND/TXOR — el camino de lecturas del
// motor) y clipping fuera de rango (t086/t089).
// PASA si: todos los CE completan en ambas pilas y las dos VRAM (paginas 0-1
// de SC5) quedan BYTE-IDENTICAS. Un diff = corrupcion inducida por el
// shim/backend; un CE colgado = perdida de una lectura/escritura del motor.
// ============================================================================
`timescale 1ns/1ps

module tb_scroll;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

// ---------------- bus compartido (escrituras a ambas pilas) ----------------
// _126: ioreq/valid POR PILA — el protocolo real (leccion tb_cpu_bulk) exige
// valid = PULSO de 1 ciclo cuando SU ready esta alto, y los ready de A y B
// no tienen por que coincidir en fase (el viejo `while !(A_ready&&B_ready)`
// con valid mantenido colgaba en cuanto cualquier cambio del shim movia la
// fase de A: el cuelgue "TIMEOUT GLOBAL vs=54" con todo en reposo).
logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic        A_ioreq = 0, A_valid = 0;
logic        B_ioreq = 0, B_valid = 0;
logic [7:0]  bus_wdata = 0;

// ---------------- PILA A: shim + backend realista ----------------
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

// ---------------- PILA B: modelo perfecto F0 ----------------
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

logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
always @(posedge clk) begin
    B_vrdata_en_r <= 1'b0;
    if (B_vvalid && B_vwrite) begin
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

// ---------------- precarga: patron unico por direccion (2 paginas SC8) ----
// v8 = f(la) distinto en cada byte -> si la ventana sirve OTRA direccion
// (rancio o salto de scroll mal curado), el pixel delata la direccion.
integer vi;
logic [17:0] pa18;
logic [7:0]  v8;
initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    for (vi = 0; vi < 65536; vi = vi + 1) vram_mem[vi] = 32'd0;
    for (vi = 0; vi < 131072; vi = vi + 1) begin
        v8   = (vi & 8'hFF) ^ ((vi >> 8) & 8'hFF) ^ ((vi >> 16) ? 8'h55 : 8'h00);
        pa18 = {vi[17], vi[0], vi[16:1]};
        sdram[22'h280000 + pa18] = v8;
        vram_mem[pa18[17:2]][8*pa18[1:0] +: 8] = v8;
    end
end

// ---------------- tareas de bus (protocolo REAL, por pila) ----------------
// negedge + valid en PULSO de 1 ciclo cuando el ready de ESA pila esta alto
// (patron probado de tb_cpu_bulk/tb_sc8cmd_full); A y B en secuencia.
integer op_n = 0;
task op_A(input [2:0] a, input wr, input [7:0] d);
    integer guard;
begin
    op_n = op_n + 1;
    guard = 0;
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = wr;
    A_ioreq = 1; A_valid = 0;
    @(negedge clk);
    while (!A_ready) begin
        @(negedge clk);
        guard = guard + 1;
        if (guard == 100000)
            $display("ATASCO op_A #%0d port=%0d wr=%b d=%02x t=%0t", op_n, a, wr, d, $time);
    end
    A_valid = 1;
    @(negedge clk);
    A_valid = 0; A_ioreq = 0;
    repeat (2) @(negedge clk);
end
endtask
task op_B(input [2:0] a, input wr, input [7:0] d);
    integer guard;
begin
    op_n = op_n + 1;
    guard = 0;
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = wr;
    B_ioreq = 1; B_valid = 0;
    @(negedge clk);
    while (!B_ready) begin
        @(negedge clk);
        guard = guard + 1;
        if (guard == 100000)
            $display("ATASCO op_B #%0d port=%0d wr=%b d=%02x t=%0t", op_n, a, wr, d, $time);
    end
    B_valid = 1;
    @(negedge clk);
    B_valid = 0; B_ioreq = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_wr(input [2:0] a, input [7:0] d);
begin
    op_A(a, 1'b1, d);
    op_B(a, 1'b1, d);
    bus_write = 0;
end
endtask
task bus_rd_A(input [2:0] a, output [7:0] d);
    integer guard;
begin
    // OJO: NO reutilizar op_A — su repeat(2) final se COME el pulso de
    // rdata_en (llega ~2 ciclos tras el valid); hay que esperar el dato
    // INMEDIATAMENTE tras soltar valid (patron tb_sc8cmd_full).
    op_n = op_n + 1;
    @(negedge clk);
    bus_address = a; bus_write = 0;
    A_ioreq = 1; A_valid = 0;
    @(negedge clk);
    while (!A_ready) @(negedge clk);
    A_valid = 1;
    @(negedge clk);
    A_valid = 0; A_ioreq = 0;
    guard = 0;
    while (!A_rdata_en) begin
        @(negedge clk);
        guard = guard + 1;
        if (guard == 100000)
            $display("ATASCO rdata_en_A #%0d port=%0d t=%0t", op_n, a, $time);
    end
    d = A_rdata;
    op_B(a, 1'b0, 8'h00);       // B en lockstep (mismos efectos de lectura)
    repeat (2) @(negedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

// espera CE de la pila A (la B con memoria perfecta acaba antes seguro,
// pero se verifica tambien al final de cada linea)
integer ce_fails = 0;
task wait_ce(input [31:0] max_us, input integer tno);
    reg [7:0] st;
    integer t;
    reg ok;
begin
    ok = 0;
    for (t = 0; t < max_us; t = t + 1) begin
        vdp_reg(6'd15, 8'h02);
        bus_rd_A(3'd1, st);
        vdp_reg(6'd15, 8'h00);
        if (!st[0]) begin ok = 1; t = max_us; end
        else repeat (86) @(posedge clk);
    end
    if (!ok) begin
        ce_fails = ce_fails + 1;
        $display("CE COLGADO en test %0d (motor A) state=%0d wq=%0d rq=%0d",
                 tno, u_vdpA.u_command.ff_state, u_shim.wq_used, u_shim.rq_used);
    end
    // B debe estar tambien ocioso (comprobacion de coherencia del TB)
    if (u_vdpB.u_command.ff_state != 0)
        $display("AVISO: motor B aun activo en test %0d", tno);
end
endtask

// LINE: R#36..R#46 = DX DY NX NY CLR ARG CMD
task line_cmd(input [15:0] dx, input [15:0] dy, input [15:0] nx,
              input [15:0] ny, input [7:0] clr, input [7:0] arg,
              input [7:0] cmd, input integer tno);
begin
    vdp_reg(6'd36, dx[7:0]);  vdp_reg(6'd37, dx[15:8]);
    vdp_reg(6'd38, dy[7:0]);  vdp_reg(6'd39, dy[15:8]);
    vdp_reg(6'd40, nx[7:0]);  vdp_reg(6'd41, nx[15:8]);
    vdp_reg(6'd42, ny[7:0]);  vdp_reg(6'd43, ny[15:8]);
    vdp_reg(6'd44, clr);
    vdp_reg(6'd45, arg);
    vdp_reg(6'd46, cmd);
    wait_ce(32'd30000, tno);
end
endtask

integer vsA = 0;
logic vsA_d = 0;
always @(posedge clk) begin
    vsA_d <= A_vs;
    if (A_vs && !vsA_d) vsA <= vsA + 1;
end

// ---------------- comparacion de PIXELES A vs B (mismo RTL, lockstep) ----
integer df = 0, den = 0, ftot = 0;
integer diffs_v = 0, diffs_h = 0, diffs_quiet = 0;
always @(posedge clk) begin
    if (A_en && B_en && (A_r != B_r || A_g != B_g || A_b != B_b)) begin
        df <= df + 1;
        if (df < 6)
            $display("PXDIFF vs=%0d A=%02x%02x%02x B=%02x%02x%02x t=%0t",
                     vsA, A_r, A_g, A_b, B_r, B_g, B_b, $time);
    end
    if (A_en != B_en) den <= den + 1;
end

task frame_step(input integer tag);
    integer v0;
begin
    v0 = vsA;
    wait (vsA == v0 + 1);
    $display("FRAME %0d [fase %0d] pxdiff=%0d endiff=%0d", vsA, tag, df, den);
    ftot = df;
    df = 0; den = 0;
end
endtask

// ---------------- guion: SC8 + scroll churn ----------------
integer k;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vsA >= 1);
    // SCREEN 8 (como tb_sc8cmd_full)
    vdp_reg(6'd0,  8'h0E);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    $display("SETUP SC8 OK vs=%0d", vsA);

    // warm-up: 3 frames sin tocar nada (la ventana/cache se llenan)
    frame_step(0); frame_step(0); frame_step(0);

    // fase QUIETA de control: 2 frames, se esperan 0 diffs
    df = 0; den = 0;
    frame_step(1); diffs_quiet = diffs_quiet + ftot;
    frame_step(1); diffs_quiet = diffs_quiet + ftot;

    // fase V-SCROLL: R#23 avanza cada frame (como un juego)
    for (k = 1; k <= 6; k = k + 1) begin
        vdp_reg(6'd23, k[7:0] * 8'd8);
        frame_step(2); diffs_v = diffs_v + ftot;
    end
    vdp_reg(6'd23, 8'd0);
    frame_step(0);

    // fase H-SCROLL: R#26 (bruto 8px) + R#27 (fino) cada frame
    for (k = 1; k <= 6; k = k + 1) begin
        vdp_reg(6'd27, k[2:0] == 3'd0 ? 8'd1 : {5'd0, k[2:0]});
        vdp_reg(6'd26, k[7:0]);
        frame_step(3); diffs_h = diffs_h + ftot;
    end

    $display("STRIDE: stride=%0d", u_shim.stride);
    $display("RESULTADO: quiet=%0d vscroll=%0d hscroll=%0d", diffs_quiet, diffs_v, diffs_h);
    if (diffs_quiet == 0 && diffs_v == 0 && diffs_h == 0)
        $display("*** SCROLL: LIMPIO (no reproduce) ***");
    else
        $display("*** SCROLL: REPRODUCIDO (quiet=%0d v=%0d h=%0d) ***",
                 diffs_quiet, diffs_v, diffs_h);
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT GLOBAL vs=%0d", vsA);
    // radiografia del shim A en el momento del cuelgue
    $display("SHIM: wq_used=%0d rq_used=%0d pfq w/r=%0d/%0d wq_vld=%b",
             u_shim.wq_used, u_shim.rq_used, u_shim.pfq_wp, u_shim.pfq_rp,
             u_shim.wq_vld);
    // _148 FIX B: word_pend ya no existe (una op de backend por palabra)
    $display("SHIM: bsy=%b cur_kind=%0d bk_wmask=%b late_v=%b stall=%b",
             u_shim.bsy, u_shim.cur_kind, u_shim.bk_wmask, u_shim.late_v,
             u_shim.vram_stall);
    $display("SHIM: obl_pend=%b obl_chk=%b obl_do=%b pfB_pend=%b fill_pend=%b",
             u_shim.obl_pend, u_shim.obl_chk, u_shim.obl_do, u_shim.pfB_pend,
             u_shim.fill_pend);
    $display("MOTOR A: state=%0d | A_ready=%b B_ready=%b op_n=%0d", u_vdpA.u_command.ff_state, A_ready, B_ready, op_n);
    $finish;
end

endmodule
