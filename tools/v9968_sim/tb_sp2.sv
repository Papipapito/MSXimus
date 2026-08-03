// ============================================================================
// tb_sp2.sv — FRENTE 1: el scroll de DOS PAGINAS (R#25 bit0 = SP2) con
// SPRITES ENCENDIDOS. Es el escenario REAL del logo del MSX2+ y de la
// limitacion de SCREEN 7/8 del README, y NUNCA se habia simulado:
//
//   tb_scroll.sv (el banco que veniamos usando) NO escribe R#25 jamas
//   => SP2 = 0 => las dos paginas nunca se alternan. Y ademas pone
//   R#8 = 0x2A, cuyo bit 1 (SPD) APAGA los sprites. O sea que las dos
//   condiciones que definen el caso estaban las dos fuera del banco.
//
// POR QUE IMPORTAN LAS DOS:
//   * SP2: el V9968 conmuta de pagina UNA VEZ por linea activa. El OBL del
//     shim prefetchea +2 lineal (obl_la) y el CAMINANTE re-apunta a
//     addr+stride, las dos predicciones LINEALES. El salto de pagina en SC8
//     mueve vi[16], que con el entrelazado {a17,a0,a16:1} cae en
//     vram_address[15]: un salto de 8192 palabras. Ninguna de las dos
//     predicciones lo ve venir => 1 fallo por linea.
//   * SPRITES: el caminante SOLO corre en los slots OCIOSOS del OBL (correa
//     obl_walked). Los sprites compiten por esos mismos slots, asi que
//     medir con SPD=1 regala al shim un presupuesto que en la BIOS no tiene.
//
// ORACULO: dos pilas identicas en lockstep — A con el shim real + SDRAM de
// latencia variable, B con el modelo perfecto de 8 ciclos. Un solo pixel
// distinto = el shim sirvio un dato rancio o de otra direccion. El patron de
// precarga es unico por direccion, asi que el color delata QUE direccion.
//
// GUARDAS (la leccion de la medida anterior): el banco se declara INVALIDO
// si en la fase SP2 no hay conmutaciones de pagina o si los sprites no
// fetchean. Un banco que mide el caso equivocado en silencio es peor que no
// tener banco.
//
// Uso:  bash run_sp2.sh
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================
`timescale 1ns/1ps

module tb_sp2;

localparam real CLK_HALF = 5.8207;          // 85.909 MHz
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

localparam [2:0] C_BG     = 3'd1;
localparam [2:0] C_SPRITE = 3'd2;

// ---------------- bus compartido (escrituras a ambas pilas) ----------------
logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic        A_ioreq = 0, A_valid = 0;
logic        B_ioreq = 0, B_valid = 0;
logic [7:0]  bus_wdata = 0;

// ---------------- PILA A: shim real + backend con latencia ----------------
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

wire         bk_req, bk_we;
wire [21:0]  bk_addr;
wire [31:0]  bk_wdata;
wire [3:0]   bk_wmask;
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire [7:0]   shim_diag;
wire         bk2_req;
wire [21:0]  bk2_addr;
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

// modelo SDRAM: latencia 26+rnd(18) ciclos = 300-510 ns (la medida real)
integer LATMIN = 26, LATRND = 18, SEEDV = 1;
logic [7:0]  sdram [0:4194303];
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

// ---------------- PILA B: modelo perfecto F0 (8 ciclos) ----------------
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

// ---------------- precarga: patron unico por direccion (128KB) ------------
// Entrelazado del V9968: byte logico vi -> byte fisico {a17, a0, a16:1}.
// Con eso vi[16] (el bit de PAGINA de SC8) cae en vram_address[15].
integer vi;
logic [17:0] pa18;
logic [7:0]  v8;

// _163: escribe UN byte logico en las DOS memorias, aplicando el entrelazado.
task preload_byte(input [17:0] la, input [7:0] d);
    reg [17:0] pa;
begin
    pa = {la[17], la[0], la[16:1]};
    sdram[22'h280000 + pa] = d;
    vram_mem[pa[17:2]][8*pa[1:0] +: 8] = d;
end
endtask

integer ti;
logic [3:0] tcol;
initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    for (vi = 0; vi < 65536; vi = vi + 1) vram_mem[vi] = 32'd0;
    for (vi = 0; vi < 131072; vi = vi + 1) begin
        v8   = (vi & 8'hFF) ^ ((vi >> 8) & 8'hFF) ^ ((vi >> 16) ? 8'h55 : 8'h00);
        pa18 = {vi[17], vi[0], vi[16:1]};
        sdram[22'h280000 + pa18] = v8;
        vram_mem[pa18[17:2]][8*pa18[1:0] +: 8] = v8;
    end

    // ---- TABLAS DE SPRITE: PRECARGADAS, no escritas por el puerto de CPU ----
    // Escribirlas con 768 OUTs seguidos desbordaba la cola de 8 escrituras del
    // shim: wqdrop = 439 MEDIDO, o sea que 439 bytes no llegaban a la memoria
    // de la pila A y las tablas quedaban A MEDIAS. De ahi el pxdiff de base de
    // ~13000 pixeles (A pintaba negro donde B pintaba el sprite), que no tenia
    // NADA que ver con SP2. Ese ritmo de escritura es ademas imposible para un
    // Z80 real (~80x mas rapido), asi que no representa ningun caso de placa.
    // Patrones de 16x16 (4 patrones x 32 bytes) en 0x1C000
    for (ti = 0; ti < 128; ti = ti + 1)
        preload_byte(18'h1C000 + ti[17:0], 8'hFF - ti[7:0]);
    // Tabla de COLOR del modo 2: 32 sprites x 16 lineas en 0x1D000
    for (ti = 0; ti < 512; ti = ti + 1) begin
        tcol = ((ti / 16) % 15) + 1;
        preload_byte(18'h1D000 + ti[17:0], {4'd0, tcol});
    end
    // Tabla de ATRIBUTOS en 0x1D200: 32 sprites repartidos por toda la pantalla
    for (ti = 0; ti < 32; ti = ti + 1) begin
        preload_byte(18'h1D200 + ti[17:0]*4 + 0, ti[7:0] * 8'd8);          // Y
        preload_byte(18'h1D200 + ti[17:0]*4 + 1, (ti[7:0] * 8'd7) + 8'd8); // X
        preload_byte(18'h1D200 + ti[17:0]*4 + 2, {ti[1:0], 2'b00});        // patron
        preload_byte(18'h1D200 + ti[17:0]*4 + 3, 8'h00);
    end
end

// ---------------- tareas de bus (protocolo REAL, por pila) ----------------
integer op_n = 0;
task op_A(input [2:0] a, input wr, input [7:0] d);
    integer guard;
begin
    op_n = op_n + 1; guard = 0;
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = wr;
    A_ioreq = 1; A_valid = 0;
    @(negedge clk);
    while (!A_ready) begin
        @(negedge clk); guard = guard + 1;
        if (guard == 100000) $display("ATASCO op_A #%0d port=%0d t=%0t", op_n, a, $time);
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
    op_n = op_n + 1; guard = 0;
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = wr;
    B_ioreq = 1; B_valid = 0;
    @(negedge clk);
    while (!B_ready) begin
        @(negedge clk); guard = guard + 1;
        if (guard == 100000) $display("ATASCO op_B #%0d port=%0d t=%0t", op_n, a, $time);
    end
    B_valid = 1;
    @(negedge clk);
    B_valid = 0; B_ioreq = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_wr(input [2:0] a, input [7:0] d);
begin op_A(a, 1'b1, d); op_B(a, 1'b1, d); bus_write = 0; end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

// ---- escritura de VRAM por el puerto de la CPU (auto-incremento) ----
// Fijar direccion: R#14 = A16:A14, luego puerto 1 con A7:A0 y {01,A13:A8}.
task vram_addr_w(input [16:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b01, a[13:8]});
end
endtask
task vram_byte(input [7:0] d);          // escribe y auto-incrementa
begin bus_wr(3'd0, d); end
endtask

// _163 VERIFICACION DEL MONTAJE. Sin esto el banco puede estar midiendo con
// las tablas de sprite A MEDIAS en la pila A (768 escrituras seguidas por el
// puerto de CPU pasan por la cola de 8 del shim) y el pxdiff de base no
// tendria NADA que ver con SP2. Lee de la pila A por el puerto de CPU.
integer setup_bad = 0;
task vram_rd_A(input [16:0] a, output [7:0] d);
    integer guard;
begin
    // fijar direccion de LECTURA (bit7=0, bit6=0) en las DOS pilas
    vdp_reg(6'd14, {5'd0, a[16:14]});
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b00, a[13:8]});
    // el IN solo en A
    @(negedge clk);
    bus_address = 3'd0; bus_write = 0;
    A_ioreq = 1; A_valid = 0;
    @(negedge clk);
    while (!A_ready) @(negedge clk);
    A_valid = 1;
    @(negedge clk);
    A_valid = 0; A_ioreq = 0;
    guard = 0;
    while (!A_rdata_en && guard < 100000) begin @(negedge clk); guard = guard + 1; end
    d = A_rdata;
    repeat (2) @(negedge clk);
end
endtask
task check_byte(input [16:0] a, input [7:0] want, input [255:0] what);
    reg [7:0] got;
begin
    vram_rd_A(a, got);
    if (got !== want) begin
        setup_bad = setup_bad + 1;
        $display("SETUP MAL: %0s en 0x%05h -> lei %02h, escribi %02h", what, a, got, want);
    end
end
endtask

// ============================================================================
// MONITORES — lo que hace INVALIDO o VALIDO el experimento
// ============================================================================
// 1) Conmutaciones de PAGINA del stream de fondo. En SC8 la pagina es vi[16],
//    que tras el entrelazado es vram_address[15]. Si SP2 funciona de verdad
//    este contador sube ~1 por linea activa; si sale 0, el banco NO esta
//    midiendo el caso y hay que decirlo a gritos.
integer pg_flips = 0, pg_flips_frame = 0;
logic   pg_last = 0, pg_seen = 0;
always @(posedge clk) begin
    if (A_vvalid && !A_vwrite && A_vtag[4:2] == C_BG) begin
        if (pg_seen && (A_vaddr[15] != pg_last)) begin
            pg_flips       <= pg_flips + 1;
            pg_flips_frame <= pg_flips_frame + 1;
        end
        pg_last <= A_vaddr[15];
        pg_seen <= 1'b1;
    end
end

// 2) Fetches de SPRITE vistos en el bus (independiente de los contadores
//    internos del shim: si esto es 0, los sprites estan apagados).
integer sp_fetch = 0, sp_fetch_frame = 0;
always @(posedge clk)
    if (A_vvalid && !A_vwrite && A_vtag[4:2] == C_SPRITE) begin
        sp_fetch       <= sp_fetch + 1;
        sp_fetch_frame <= sp_fetch_frame + 1;
    end

// 3) Comparacion de PIXELES A vs B (el oraculo)
integer df = 0, den = 0, ftot = 0;
integer first_shown = 0;
always @(posedge clk) begin
    if (A_en && B_en && (A_r != B_r || A_g != B_g || A_b != B_b)) begin
        df <= df + 1;
        if (first_shown < 8) begin
            $display("PXDIFF vs=%0d A=%02x%02x%02x B=%02x%02x%02x pg=%b t=%0t",
                     vsA, A_r, A_g, A_b, B_r, B_g, B_b, pg_last, $time);
            first_shown <= first_shown + 1;
        end
    end
    if (A_en != B_en) den <= den + 1;
    // _163: contar los diffs que caen en cada mitad de pagina, para saber si el
    // dano se concentra en las fronteras (lo que acusaria a SP2) o esta
    // repartido (lo que acusaria al cambio de scroll en si).
    if (A_en && B_en && (A_r != B_r || A_g != B_g || A_b != B_b)) begin
        if (pg_last) df_pg1 <= df_pg1 + 1;
        else         df_pg0 <= df_pg0 + 1;
    end
end
integer df_pg0 = 0, df_pg1 = 0;

integer vsA = 0;
logic vsA_d = 0;
always @(posedge clk) begin
    vsA_d <= A_vs;
    if (A_vs && !vsA_d) vsA <= vsA + 1;
end

// contadores del shim al entrar/salir de cada fase
integer miss0, spmiss0, drop0;
`ifdef SHIM_DBG_SPLIT
integer wn0, sc0, f_wnhit, f_schit;      // _163: reparto ventana / sc-cache
`ifdef SHIM_SP2_PF
integer fd0, fp0, wk0;                   // _163: maquinaria del arreglo
`endif
`endif
task snap_shim;
begin
    miss0   = u_shim.c_miss;
    spmiss0 = u_shim.c_spmiss;
    drop0   = u_shim.c_s1drop;
`ifdef SHIM_DBG_SPLIT
    wn0     = u_shim.c_wnhit;
    sc0     = u_shim.c_schit;
`ifdef SHIM_SP2_PF
    fd0     = u_shim.c_flipdet;
    fp0     = u_shim.c_flippf;
    wk0     = u_shim.c_walk;
`endif
`endif
end
endtask

integer f_pxdiff, f_pgflips, f_spfetch, f_miss, f_spmiss, f_drop;
task frame_step(input [255:0] fase);
    integer v0;
begin
    v0 = vsA;
    pg_flips_frame = 0; sp_fetch_frame = 0;
    snap_shim();
    wait (vsA == v0 + 1);
    f_pxdiff  = df;
    f_pgflips = pg_flips_frame;
    f_spfetch = sp_fetch_frame;
    f_miss    = u_shim.c_miss   - miss0;
    f_spmiss  = u_shim.c_spmiss - spmiss0;
    f_drop    = u_shim.c_s1drop - drop0;
`ifdef SHIM_DBG_SPLIT
    f_wnhit = u_shim.c_wnhit - wn0;
    f_schit = u_shim.c_schit - sc0;
    $display("FRAME %0d [%0s] pxdiff=%0d (pg0=%0d pg1=%0d) | pgflips=%0d | FONDO: ventana=%0d sccache=%0d miss=%0d (total=%0d) | spmiss=%0d",
             vsA, fase, f_pxdiff, df_pg0, df_pg1, f_pgflips,
             f_wnhit, f_schit, f_miss, f_wnhit + f_schit + f_miss, f_spmiss);
`ifdef SHIM_SP2_PF
    // _163: ¿esta VIVA la maquinaria del arreglo? stride=0 => el caminante NO
    // dispara nunca y el arreglo, que vive dentro de su rama, tampoco.
    $display("        MAQUINARIA: stride=%0d | conmut.detectadas=%0d | caminante=%0d de las cuales precalentando frontera=%0d",
             u_shim.stride, u_shim.c_flipdet - fd0, u_shim.c_walk - wk0,
             u_shim.c_flippf - fp0);
`endif
`else
    $display("FRAME %0d [%0s] pxdiff=%0d (pg0=%0d pg1=%0d) endiff=%0d | pgflips=%0d spfetch=%0d | bgmiss=%0d spmiss=%0d pfqdrop=%0d wqdrop=%0d",
             vsA, fase, f_pxdiff, df_pg0, df_pg1, den, f_pgflips, f_spfetch,
             f_miss, f_spmiss, f_drop, u_shim.c_wqdrop);
`endif
    ftot = df;
    df = 0; den = 0;
    df_pg0 = 0; df_pg1 = 0;
    first_shown = 0;        // _163: 8 muestras POR FRAME, no 8 en todo el run
end
endtask

// ============================================================================
// GUION
// ============================================================================
integer k, s, got;
// _163: numero de pasos de cada barrido, para poder sacar el VEREDICTO con
// pocos frames. Con sprites encendidos cada frame cuesta ORDENES DE MAGNITUD
// mas de simular que el banco viejo (32 sprites de 16x16 activos en todas las
// lineas), asi que el barrido completo son horas. +HSN/+VSN lo acortan.
integer HSN = 32, VSN = 8, WARM = 3;
logic [3:0] spcol;                      // color del sprite (1..15), ancho explicito
integer d_ctrl = 0, d_sp2q = 0, d_sp2v = 0, d_sp2h = 0;
integer m_ctrl = 0, m_sp2q = 0, m_sp2v = 0, m_sp2h = 0;
integer pg_ctrl = 0, pg_sp2 = 0, sp_total = 0;

initial begin
    got = $value$plusargs("LATMIN=%d", LATMIN);
    got = $value$plusargs("LATRND=%d", LATRND);
    got = $value$plusargs("SEED=%d",   SEEDV);
    got = $value$plusargs("HSN=%d",    HSN);
    got = $value$plusargs("VSN=%d",    VSN);
    got = $value$plusargs("WARM=%d",   WARM);

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vsA >= 1);

    // ---- SCREEN 8, display APAGADO durante el volcado de tablas ----
    // El display se enciende DESPUES de escribir las tablas de sprite: si se
    // escribe con el display vivo, A y B ejecutan cada escritura en ciclos
    // distintos (cada uno espera SU ready) y ademas el display de A cachea las
    // tablas VIEJAS mientras se escriben. Las dos cosas ensucian la
    // comparacion sin tener nada que ver con SP2.
    vdp_reg(6'd0,  8'h0E);      // M5:M3 = SCREEN 8
    vdp_reg(6'd1,  8'h02);      // display OFF, sprites 16x16 (bit1)
    // R#2 = 0x3F: PAGINA 1. IMPRESCINDIBLE — el core solo activa SP2 si el bit
    // de pagina de la base esta a 1:
    //   w_scroll_page = (reg_scroll_planes && base[15]) ? w_pos_x[8] : base[15]
    // (vdp_timing_control_screen_mode.v:228). Con R#2 = 0x1F (base[15] = 0,
    // que es lo que ponia tb_scroll) el termino SP2 queda ANULADO y el modo de
    // dos paginas no existe por mucho que se escriba R#25.
    // Y ojo: la pagina la elige w_pos_x[8] = la posicion HORIZONTAL. El SP2 de
    // este core es un scroll de dos paginas HORIZONTAL, gobernado por
    // R#26/R#27, no por el scroll vertical R#23.
    vdp_reg(6'd2,  8'h3F);
    vdp_reg(6'd8,  8'h28);      // <<< SPD = 0: SPRITES ENCENDIDOS (tb_scroll ponia 0x2A)
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    // tablas de sprite (modo 2): color en 0x1D000, atributos en 0x1D200,
    // patrones en 0x1C000.
    vdp_reg(6'd5,  8'hA0);      // {R#11[1:0],R#5} << 7 = 0x1D000
    vdp_reg(6'd11, 8'h03);
    vdp_reg(6'd6,  8'h38);      // SPT = 0x1C000
    $display("SETUP SC8 + sprites ON vs=%0d", vsA);

    // (las tablas de sprite YA estan en las dos memorias: se precargan en el
    //  initial de arriba. No se escriben por el puerto de CPU a proposito.)

    // ---- VERIFICAR EL MONTAJE antes de medir nada ----
    // Muestras de las tres tablas, con lo que ESCRIBIMOS como referencia.
    check_byte(17'h1C000, 8'hFF,       "patron[0]");
    check_byte(17'h1C07F, 8'hFF - 8'd127, "patron[127]");
    check_byte(17'h1D000, 8'h01,       "color s0 l0");
    // s31 linea 15 = offset 511 => ((511/16) % 15) + 1 = (31 % 15) + 1 = 2
    check_byte(17'h1D1FF, 8'h02,       "color s31 l15");
    check_byte(17'h1D200, 8'h00,       "attr s0 Y");
    check_byte(17'h1D201, 8'h08,       "attr s0 X");
    check_byte(17'h1D204, 8'd8,        "attr s1 Y");
    check_byte(17'h1D27C, 8'd248,      "attr s31 Y");
    $display("SETUP CHECK: %0d bytes mal de 8   (wqdrop=%0d)",
             setup_bad, u_shim.c_wqdrop);
    if (setup_bad != 0) begin
        $display("*** LAS TABLAS NO ESTAN BIEN EN LA PILA A: el pxdiff de base NO");
        $display("*** mide SP2 sino escrituras perdidas. Arreglar el montaje primero.");
    end

    // ---- ahora si: display ON (tablas ya en VRAM, A y B en el mismo estado) --
    vdp_reg(6'd1, 8'h42);       // display ON + sprites 16x16
    $display("DISPLAY ON vs=%0d", vsA);

    // ---- calentamiento ----
    for (k = 0; k < WARM; k = k + 1) frame_step("warm");

    // ================= FASE 0: CONTROL, SP2 APAGADO =================
    // Es el caso que SI medimos hasta ahora (salvo por los sprites).
    // Referencia: si esto ya sale sucio, el problema no es SP2.
    vdp_reg(6'd25, 8'h00);
    frame_step("ctrl SP2=0");
    d_ctrl = d_ctrl + f_pxdiff; m_ctrl = m_ctrl + f_miss; pg_ctrl = pg_ctrl + f_pgflips;
    frame_step("ctrl SP2=0");
    d_ctrl = d_ctrl + f_pxdiff; m_ctrl = m_ctrl + f_miss; pg_ctrl = pg_ctrl + f_pgflips;

    // ===== FASE 0b: CONTROL QUE FALTABA — mover el H-SCROLL con SP2 APAGADO =
    // Sin esto no se puede atribuir el dano a SP2: podria ser el transitorio
    // del propio cambio de R#26/R#27 (la ventana entera queda desalineada un
    // frame), que ocurre con SP2 o sin el. Este control lo separa.
    for (k = 1; k <= HSN; k = k + 1) begin
        vdp_reg(6'd27, {5'd0, k[2:0]});
        vdp_reg(6'd26, k[7:0]);
        frame_step("ctrl SP2=0 + hscroll");
        d_ctrl = d_ctrl + f_pxdiff; m_ctrl = m_ctrl + f_miss;
        pg_ctrl = pg_ctrl + f_pgflips;
    end
    vdp_reg(6'd26, 8'd0); vdp_reg(6'd27, 8'd0);
    frame_step("ctrl recentrado");

    // ================= FASE 1: SP2 ON, QUIETO =================
    // R#25 = 0x03 = SP2 + MSK, exactamente lo que pone la BIOS en el logo.
    vdp_reg(6'd25, 8'h03);
    frame_step("SP2 quieto");
    d_sp2q = d_sp2q + f_pxdiff; m_sp2q = m_sp2q + f_miss; pg_sp2 = pg_sp2 + f_pgflips;
    frame_step("SP2 quieto");
    d_sp2q = d_sp2q + f_pxdiff; m_sp2q = m_sp2q + f_miss; pg_sp2 = pg_sp2 + f_pgflips;

    // ================= FASE 2: SP2 + H-SCROLL (LA FASE PRINCIPAL) =======
    // La pagina la elige w_pos_x[8] (posicion HORIZONTAL), asi que el motor
    // del caso es R#26/R#27, no R#23. Barrido COMPLETO de R#26 0..31 (el de
    // tb_scroll solo cubria 1..6) con el fino R#27 girando.
    // _163: arranca en k=1, IGUAL que el control de la fase 0b, para que los
    // dos barridos escriban los MISMOS valores de R#26/R#27 y sean comparables
    // frame a frame. (Antes empezaba en 0, que no mueve nada y desperdiciaba el
    // primer frame de la fase.)
    for (k = 1; k <= HSN; k = k + 1) begin
        vdp_reg(6'd27, {5'd0, k[2:0]});
        vdp_reg(6'd26, k[7:0]);
        frame_step("SP2 + hscroll");
        d_sp2h = d_sp2h + f_pxdiff; m_sp2h = m_sp2h + f_miss;
        pg_sp2 = pg_sp2 + f_pgflips;
    end
    vdp_reg(6'd26, 8'd0); vdp_reg(6'd27, 8'd0);
    frame_step("recentrado");

    // ================= FASE 3: SP2 + V-SCROLL (secundaria) =============
    // Con el scroll horizontal a la mitad de la ventana (R#26=16) para que la
    // conmutacion de pagina caiga DENTRO del area activa, se anade el
    // movimiento vertical: es la combinacion del logo del MSX2+.
    vdp_reg(6'd26, 8'd16);
    for (k = 1; k <= VSN; k = k + 1) begin
        vdp_reg(6'd23, k[7:0] * 8'd8);
        frame_step("SP2 + v+h scroll");
        d_sp2v = d_sp2v + f_pxdiff; m_sp2v = m_sp2v + f_miss;
        pg_sp2 = pg_sp2 + f_pgflips;
    end
    vdp_reg(6'd23, 8'd0);

    sp_total = sp_fetch;

    // ================= VEREDICTO =================
    $display("");
    $display("=========================== RESUMEN ===========================");
    $display("stride aprendida por el shim : %0d", u_shim.stride);
    $display("conmutaciones de pagina      : SP2=0 -> %0d   SP2=1 -> %0d", pg_ctrl, pg_sp2);
    $display("fetches de sprite (total)    : %0d", sp_total);
    $display("");
    $display("  fase              pxdiff    bgmiss");
    $display("  control (SP2=0)   %6d    %6d", d_ctrl, m_ctrl);
    $display("  SP2 quieto        %6d    %6d", d_sp2q, m_sp2q);
    $display("  SP2 + vscroll     %6d    %6d", d_sp2v, m_sp2v);
    $display("  SP2 + hscroll     %6d    %6d", d_sp2h, m_sp2h);
    $display("");

    // --- guardas: el experimento vale o no vale ---
    if (sp_total == 0) begin
        $display("*** BANCO INVALIDO: 0 fetches de sprite — los sprites NO estan");
        $display("*** encendidos (revisa R#1 bit1 y R#8 bit1). NO interpretar nada.");
    end
    else if (pg_sp2 == 0) begin
        $display("*** BANCO INVALIDO: con SP2=1 no hay NI UNA conmutacion de pagina.");
        $display("*** O R#25 no llega, o la pagina de SC8 no es vram_address[15].");
        $display("*** NO interpretar los pxdiff: no se esta midiendo el caso.");
    end
    else if (pg_ctrl != 0) begin
        $display("*** SOSPECHOSO: con SP2=0 ya hay %0d conmutaciones de pagina.", pg_ctrl);
        $display("*** El discriminador de pagina no aisla lo que creemos.");
    end
    // _163: el veredicto compara MAGNITUDES, no busca el cero. La version
    // anterior exigia d_ctrl == 0 y cantaba "sucio ya en el control" por los
    // 64 px/frame de la linea base (que son los 2 fallos residuales de la
    // ventana, NO un efecto de SP2): un veredicto que engañaba al leerlo.
    // El criterio bueno es la RAZON entre el daño con SP2 y el del control con
    // el MISMO movimiento de scroll.
    else begin : veredicto
        integer sp2_total, ctrl_per_frame;
        sp2_total      = d_sp2q + d_sp2v + d_sp2h;
        ctrl_per_frame = (d_ctrl > 0) ? (d_ctrl / (2 + HSN + 1)) : 0;
        $display("  linea base del control : %0d px/frame", ctrl_per_frame);
        $display("  total con SP2          : %0d px", sp2_total);
        if (sp2_total > 10 * d_ctrl && d_ctrl > 0) begin
            $display("*** REPRODUCIDO Y AISLADO: el dano con SP2 es >10x el del control");
            $display("*** con el MISMO movimiento de scroll. La causa es SP2.");
        end
        else if (sp2_total <= d_ctrl) begin
            $display("*** NO REPRODUCE: con SP2 no se ensucia mas que sin el.");
            $display("*** La hipotesis del prefetch SP2 queda REFUTADA por este banco.");
        end
        else begin
            $display("*** PARCIAL: hay mas dano con SP2 pero menos de 10x. Mirar");
            $display("*** frame a frame antes de concluir nada.");
        end
    end
    $finish;
end

initial begin
    #1800000000;
    $display("TIMEOUT GLOBAL vs=%0d", vsA);
    $display("SHIM: wq_used=%0d rq_used=%0d pfq w/r=%0d/%0d",
             u_shim.wq_used, u_shim.rq_used, u_shim.pfq_wp, u_shim.pfq_rp);
    $display("SHIM: obl_pend=%b obl_chk=%b obl_do=%b obl_walked=%b stride=%0d",
             u_shim.obl_pend, u_shim.obl_chk, u_shim.obl_do, u_shim.obl_walked,
             u_shim.stride);
    $display("MOTOR A: state=%0d A_ready=%b B_ready=%b op_n=%0d",
             u_vdpA.u_command.ff_state, A_ready, B_ready, op_n);
    $finish;
end

endmodule
