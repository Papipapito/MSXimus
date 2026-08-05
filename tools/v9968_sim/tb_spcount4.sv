// ============================================================================
// tb_spcol.sv — ¿FUNCIONA LA COLISION DE SPRITES DEL V9968? (la espinita)
//
// LA ULTIMA PUERTA SIN ABRIR (05/08): tras cinco curas reales, Fleet y DQ2
// siguen muriendo — y las tres flechas apuntan a los sprites de los modos
// clasicos: (1) el bucle de Fleet en pc=7a68 espera S#0.C=1 (probado en la
// traza openMSX: sale con s0=29); (2) el campo de numero de S#0 difiere del
// chip real (openMSX 0x9f=num31, placa 0x89=num9); (3) falla igual en el
// cartucho de HRA = RTL compartido = la maquinaria de sprites reescrita.
//
// Este banco (pila completa: glue + vdp + shim + SDRAM): dos sprites
// SOLAPADOS con patron solido y pantalla encendida ->
//   FASE A (VMODE=2, sprites MODO 1 — el mundo de DQ2):  ¿C=1? ¿num?
//   FASE B (5 sprites en la misma linea, modo 1):        ¿5S=1? ¿num=4?
//   (con VMODE=5: sprites MODO 2 — el mundo de Fleet; CC=0 en el color)
// Lectura de S#0 con R#15=0 tras >=2 frames de escaneo.
//
// Uso: vvp sim [+VMODE=2|5] [+VCD=1]
// RESULTADO (06/08) con +LAT=120 (DDR3 real con refresco y contienda,
// frente a los 26-44 del modelo de siempre): **VERDE — 3072 px, 100%**.
// La maquinaria del shim absorbe la latencia como fue diseñada, asi que
// el 'dato tardio' NO se reproduce en simulacion ni forzando el backend.
// El latch sin emparejar de vdp_vram_interface:320 sigue siendo un
// defecto de diseño REAL, pero NO esta demostrado que sea el que quita
// los sprites en placa: lo decide la medida de la s035.
// ============================================================================
`timescale 1ns/1ps

module tb_spcount4;

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

integer LAT_BASE = 26;
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
        m_cnt <= 0; m_lat <= LAT_BASE + ({$random} % 18);
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
        m2_cnt <= 0; m2_lat <= LAT_BASE + ({$random} % 18);
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

task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b01, a[13:8]});
end
endtask

task espera_frames(input integer n);
integer f;
begin
    for (f = 0; f < n; f = f + 1) begin
        @(posedge d_vs);
    end
    #100000;
end
endtask

// leer S#0 (con R#15=0 explicito, como un juego MSX1)
task lee_s0(output [7:0] v);
begin
    z80_out(2'd1, 8'h00); z80_out(2'd1, 8'h8F);
    z80_in (2'd1, v);
end
endtask


// ---------------------------------------------------------------------------
// tb_spcount2 — LA CONFIGURACION EXACTA DE DRAGON QUEST 2 (visor de openMSX):
// sprite mode 1, **16x16**, patron 0x3800, SAT 0x1B00, 192 lineas, color 0
// transparente. Sintoma de placa: SOLO SE VE EL PRIMER SPRITE.
// FASE 1 (control): 3 sprites, TODOS con patron 0  -> ¿salen los 3?
// FASE 2 (DQ2):     3 sprites con patrones 0, 4, 8 -> ¿solo el primero?
// Cada sprite 16x16 solido = 256 px; 3 sprites = 768.
integer i, j, blancos;
logic [7:0] v;

task pinta_sat(input [7:0] p1, input [7:0] p2);
begin
    vram_set_wr(18'h01B00);
    z80_out(2'd0, 8'd50);  z80_out(2'd0, 8'd20);  z80_out(2'd0, 8'd0); z80_out(2'd0, 8'd15);
    z80_out(2'd0, 8'd50);  z80_out(2'd0, 8'd60);  z80_out(2'd0, p1);   z80_out(2'd0, 8'd15);
    z80_out(2'd0, 8'd90);  z80_out(2'd0, 8'd100); z80_out(2'd0, p2);   z80_out(2'd0, 8'd15);
    z80_out(2'd0, 8'd208);
end
endtask

task cuenta(input integer fase);
integer k;
begin
    for (k = 0; k < 2; k = k + 1) begin
        blancos = 0;
        @(posedge d_vs);
        fork
            begin : cnt
                forever @(posedge clk)
                    if (d_en && d_r == 8'hFF && d_g == 8'hFF && d_b == 8'hFF)
                        blancos = blancos + 1;
            end
            begin @(posedge d_vs); disable cnt; end
        join
        $display("  FASE %0d frame %0d: pixeles = %0d  (3 sprites = 3072; SOLO EL PRIMERO = 1024)%s",
                 fase, k, blancos, (blancos > 0 && blancos <= 1200) ? "   *** SOLO EL PRIMERO — SINTOMA DE PLACA REPRODUCIDO ***" : "");
    end
end
endtask

initial begin
    repeat (48) @(posedge clk);
    reset_n = 1;
    repeat (48) @(posedge clk);
    if( !$value$plusargs("LAT=%d", LAT_BASE) ) LAT_BASE = 26;
    $display("=== tb_spcount4: DQ2 (modo 1, 16x16) con LATENCIA DE BACKEND = %0d ciclos ===", LAT_BASE);
    $display("    (26 = el modelo de siempre; 120 = DDR3 real con refresco y contienda)");

    vdp_reg(6'd0, 8'h02);
    vdp_reg(6'd2, 8'h06);
    vdp_reg(6'd3, 8'hFF);
    vdp_reg(6'd4, 8'h03);
    vdp_reg(6'd5, 8'h36);          // SAT 0x1B00
    vdp_reg(6'd6, 8'h07);          // patrones 0x3800
    vdp_reg(6'd7, 8'h00);
    vdp_reg(6'd1, 8'h42);          // pantalla ON + **SPRITES 16x16**

    // 3 grupos de patrones 16x16 solidos (32 bytes cada uno): patrones 0, 4, 8
    vram_set_wr(18'h03800);
    for (i = 0; i < 96; i = i + 1) z80_out(2'd0, 8'hFF);

    pinta_sat(8'd0, 8'd0);         // FASE 1: todos patron 0
    espera_frames(2);
    cuenta(1);

    pinta_sat(8'd4, 8'd8);         // FASE 2: patrones 0, 4, 8 (como DQ2)
    espera_frames(2);
    cuenta(2);

    $finish;
end

endmodule
