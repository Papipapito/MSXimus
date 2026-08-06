// ============================================================================
// tb_vramsoak_glue.sv — VRAMSOAK con el GLUE REAL contra la pila completa.
//
// LA PIEZA QUE FALTABA (05/08): con _185 puesto, Fleet vive ~107s y muere
// IGUAL que DQ2 — tras trafico pesado de 0x98, con la RAM/hooks del juego
// corruptos (PC hasta 0xFFFF). Queda UNA causa comun: alguna lectura del
// puerto 0x98 devuelve un byte MALO de vez en cuando y envenena el estado
// del juego. Sospechoso documentado (_163, tb_cpuif_dbl): la pre-lectura
// invalidada que aterriza y se sirve ("primera lectura mala, las
// siguientes buenas") — pero el banco viejo usa un MODELO de VRAM educado.
// Este banco: escritura de patrones CONOCIDOS + re-apuntados SETRD
// AGRESIVOS (con la pre-lectura aun en vuelo) + verificacion byte a byte,
// contra vdp COMPLETO + shim + SDRAM variable, con el protocolo Z80+WAIT
// del glue de verdad y la pantalla ENCENDIDA (slots peleados).
//
// Uso: vvp sim [+N=rondas] [+SPAN=bytes_por_ronda] [+SCROFF=1] [+VCD=1]
// Veredicto: fallos=0 => camino limpio en este escenario; fallos>0 =>
// clasificacion automatica (f(dir-1) / byte-previo / rancio-de-prefetch /
// basura) con las 8 primeras discrepancias detalladas.
// ============================================================================
`timescale 1ns/1ps

module tb_vramsoak_glue;

localparam real CLK_HALF = 5.8207;
localparam real TSTATE   = 279.33;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

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
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
end

// espejo del contenido esperado de la VRAM (lo que el TB ha escrito)
logic [7:0] vexp [0:262143];

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
    // OTIR real = 21T/byte (5,9us). +FAST: 8T (fisicamente imposible,
    // solo para medir el margen del colchon)
    #((FAST ? 4.0 : 17.0)*TSTATE);
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
    #((FAST ? 4.0 : 14.0)*TSTATE);   // INIR real ~21T; +FAST para margen
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

// lanzar un HMMV (relleno solido) a una zona ALTA (fuera de la de
// verificacion): motor royendo turnos de VRAM en paralelo al soak
task engine_hmmv(input [7:0] color);
begin
    vdp_reg(6'd36, 8'd0);   vdp_reg(6'd37, 8'd1);    // DX=256 -> 0x8000
    vdp_reg(6'd38, 8'd0);   vdp_reg(6'd39, 8'd1);    // DY=256
    vdp_reg(6'd40, 8'd0);   vdp_reg(6'd41, 8'd1);    // NX=256
    vdp_reg(6'd42, 8'd128); vdp_reg(6'd43, 8'd0);    // NY=128
    vdp_reg(6'd44, color);                            // CLR
    vdp_reg(6'd45, 8'd0);
    vdp_reg(6'd46, 8'hC0);                            // HMMV
end
endtask

// el tren de la BIOS (select S#2 / IN / restore) — el patron real
task bios_poll(output [7:0] v);
begin
    z80_out(2'd1, 8'h02); z80_out(2'd1, 8'h8F);
    z80_in (2'd1, v);
    z80_out(2'd1, 8'h00); z80_out(2'd1, 8'h8F);
end
endtask

// ---------------------------------------------------------------------------
integer N = 300;         // rondas
integer SPAN = 24;       // bytes leidos por ronda
integer SCROFF = 0;
integer BLTOG = 0;       // 1: conmutar la pantalla cada 8 rondas
integer ENGINE = 0;      // 1: HMMV del motor corriendo en paralelo
integer VMODE = 5;       // 5=SCREEN5 (G4) | 2=SCREEN2 (G2, el mundo de DQ2)
integer FAST = 0;        // 1: ritmo 8T fisicamente imposible (margen)
integer i, r, k;
integer lfsr;
logic [7:0] v, s0junk;
logic [17:0] base, wbase;
integer fallos, f_dm1, f_prev, f_pf, f_otros, mostrados;
logic [7:0] prev_rd;

initial begin
    if( !$value$plusargs("N=%d", N) ) N = 300;
    if( !$value$plusargs("SPAN=%d", SPAN) ) SPAN = 24;
    if( !$value$plusargs("SCROFF=%d", SCROFF) ) SCROFF = 0;
    if( !$value$plusargs("BLTOG=%d", BLTOG) ) BLTOG = 0;
    if( !$value$plusargs("ENGINE=%d", ENGINE) ) ENGINE = 0;
    if( !$value$plusargs("VMODE=%d", VMODE) ) VMODE = 5;
    if( $test$plusargs("FAST") ) FAST = 1;
    if( $test$plusargs("VCD") ) begin
        // quirurgico: glue + cpu_interface + señales del TB (el full-stack
        // entero seria gigante); profundidad 1 en el vdp
        $dumpfile("vramsoak.vcd");
        $dumpvars(0, u_glue);
        $dumpvars(0, u_vdp.u_cpu_interface);
        $dumpvars(1, tb_vramsoak_glue);
    end

    repeat (48) @(posedge clk);
    reset_n = 1;
    repeat (48) @(posedge clk);
    $display("=== tb_vramsoak_glue: N=%0d SPAN=%0d SCROFF=%0d ===", N, SPAN, SCROFF);

    // init: modo segun VMODE + pantalla segun SCROFF
    if (VMODE == 2) begin
        // SCREEN 2 (G2) — el mundo de DQ2: NT=1800 CT=2000 PGT=0000
        vdp_reg(6'd0, 8'h02);
        vdp_reg(6'd2, 8'h06);
        vdp_reg(6'd3, 8'hFF);
        vdp_reg(6'd4, 8'h03);
        vdp_reg(6'd5, 8'h36);
        vdp_reg(6'd6, 8'h07);
    end
    else begin
        vdp_reg(6'd0, 8'h06);
        vdp_reg(6'd2, 8'h1F);
    end
    vdp_reg(6'd1, SCROFF ? 8'h00 : 8'h40);
    vdp_reg(6'd15, 8'h00);

    // sembrar 4KB de patron conocido via el puerto (como un juego cargando)
    vram_set_wr(18'h00000);
    for (i = 0; i < 4096; i = i + 1) begin
        v = i[7:0] ^ (i[11:4]) ^ 8'h5A;
        z80_out(2'd0, v);
        vexp[i] = v;
    end
    $display("sembrado OK (4KB)");

    // el soak: re-apuntar SETRD a saco (a veces con la pre-lectura en
    // vuelo), leer SPAN bytes verificando, intercalar status/registros y
    // rafagas de escritura a otra zona (actualizando el espejo)
    fallos = 0; f_dm1 = 0; f_prev = 0; f_pf = 0; f_otros = 0; mostrados = 0;
    lfsr = 32'hACE1;
    prev_rd = 8'h00;
    for (r = 0; r < N; r = r + 1) begin
        lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
        base = {6'd0, lfsr[11:0]};              // 0..4095
        if (base > 4096 - SPAN) base = base % (4096 - SPAN);
        vram_set_rd(base);
        for (k = 0; k < SPAN; k = k + 1) begin
            z80_in(2'd0, v);
            if (v !== vexp[base + k]) begin
                fallos = fallos + 1;
                if (k > 0 && v === vexp[base + k - 1])      f_dm1  = f_dm1 + 1;
                else if (v === prev_rd)                      f_prev = f_prev + 1;
                else if (v === vexp[{6'd0, lfsr[11:0]} + 0]) f_pf   = f_pf + 1;
                else                                         f_otros = f_otros + 1;
                if (mostrados < 8) begin
                    mostrados = mostrados + 1;
                    $display("  !! ronda %0d k=%0d addr=%05x: esperado=%02x leido=%02x (prev_rd=%02x) t=%0t",
                             r, k, base + k, vexp[base + k], v, prev_rd, $time);
                end
                if ($test$plusargs("VCD") && fallos >= 2) begin
                    $display("VCD: parando tras el fallo %0d (t=%0t)", fallos, $time);
                    #100000;
                    $finish;
                end
            end
            prev_rd = v;
        end
        // intercalados: poll de BIOS, pantalla conmutando, motor en marcha
        bios_poll(s0junk);
        if (BLTOG && (r % 8) == 7)
            vdp_reg(6'd1, (r % 16) == 15 ? 8'h40 : 8'h00);   // BL off/on
        if (ENGINE && (r % 16) == 0)
            engine_hmmv(r[7:0]);                             // relanzar HMMV
        if ((r % 4) == 3) begin
            wbase = 18'h00800 | {8'd0, lfsr[9:0]};
            vram_set_wr(wbase);
            for (k = 0; k < 8; k = k + 1) begin
                v = lfsr[7:0] ^ k[7:0];
                z80_out(2'd0, v);
                if ((wbase + k) < 262144) vexp[wbase + k] = v;
            end
        end
        if ((r % 50) == 49)
            $display("  ronda %0d/%0d: fallos=%0d", r+1, N, fallos);
    end

    $display("RESULTADO: lecturas=%0d fallos=%0d  [f(dir-1)=%0d byte-previo=%0d pf-rancio=%0d otros=%0d]",
             N*SPAN, fallos, f_dm1, f_prev, f_pf, f_otros);
    if (fallos == 0) $display("*** SOAK LIMPIO en este escenario ***");
    else             $display("*** %0d LECTURAS MALAS: el veneno de Fleet/DQ2 REPRODUCIDO ***", fallos);
    $finish;
end

endmodule
