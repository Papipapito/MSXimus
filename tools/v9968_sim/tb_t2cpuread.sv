// ============================================================================
// tb_t2cpuread.sv — REPRODUCCION EXTREMO A EXTREMO del "rastro del cursor":
// lecturas de VRAM del Z80 a traves del ADAPTADOR REAL (fpga/src/
// v9968_cpu_glue.v) con TEXT2 (SCREEN 0 W80) DIBUJANDO.
//
// GROUND TRUTH (medido en openMSX, V9938): el cursor de TEXT2 NO es el blink.
// La BIOS escribe el codigo 0xFF en la celda del cursor y reescribe el patron
// del caracter 255; para poder RESTAURAR la celda al mover el cursor tiene que
// haber LEIDO antes, por el puerto de datos del VDP, el codigo que habia
// debajo. Si esa lectura devuelve un byte EQUIVOCADO, la BIOS "restaura" un
// caracter equivocado y el glifo se queda en pantalla PARA SIEMPRE.
//
// v9968_cpu_glue.v NO frena al Z80 (no genera /WAIT): dispara la transaccion
// en el flanco de bajada de csr_n y confia en que bus_rdata_en llegue antes de
// que el T80 muestree cdi_r. Si no llega, cdi_r conserva el DATO DE LA LECTURA
// ANTERIOR (lo dice su propia cabecera, lineas 11-13).
//
// El banco modela el ciclo de I/O del Z80 (IN/OUT = /IORQ+/RD durante ~3 T,
// dato muestreado ~2,5 T tras el flanco) a la frecuencia +FCPU (kHz) y hace la
// secuencia de la BIOS: SETRD(celda) + IN, comparando con el valor real.
// ============================================================================
`timescale 1ns/1ps

module tb_t2cpuread;

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
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t), .diag(shim_diag)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat, vi;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask; m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
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
        m2_pend <= 1; m2_addr <= bk2_addr; m2_cnt <= 0; m2_lat <= 26 + ({$random} % 18);
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

// ---------------------------------------------------------------------------
//  Modelo del ciclo de I/O del Z80
// ---------------------------------------------------------------------------
real TSTATE = 279.33;                    // ns por estado T (3,579545 MHz)
integer FCPU_KHZ;

// IN/OUT: /IORQ+/RD (o /WR) bajan al empezar T2 y suben al acabar T3 (con el
// TW automatico de los ciclos de I/O). El Z80 muestrea el dato al final del TW.
task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);                 // T1
    csw_n = 1'b0;
    #(3.0*TSTATE);             // T2 + TW + T3
    csw_n = 1'b1;
    #(8.0*TSTATE);             // resto de la instruccion OUT (n),A = 11 T
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
    #(8.0*TSTATE);             // resto de IN A,(n) = 11 T
end
endtask

logic [7:0] dummy;
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

// ---------------------------------------------------------------------------
//  Sondas
// ---------------------------------------------------------------------------
integer vs_cnt = 0;
logic vs_d = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    if (display_vs && !vs_d) vs_cnt <= vs_cnt + 1;
end

// latencia interna: aceptacion de la peticion de lectura -> bus_rdata_en
integer cyc = 0;
always @(posedge clk) cyc <= cyc + 1;
integer rd_t0 = 0, rd_lat = 0, rd_n = 0, rd_max = 0, rd_sum = 0;
integer hist [0:127];
logic pend_rd = 0;
always @(posedge clk) begin
    if (bus_valid && !bus_write && bus_ioreq && bus_address == 3'd0 && !pend_rd) begin
        pend_rd <= 1; rd_t0 <= cyc;
    end
    else if (pend_rd && bus_rdata_en) begin
        pend_rd <= 0;
        rd_lat = cyc - rd_t0;
        rd_n = rd_n + 1; rd_sum = rd_sum + rd_lat;
        if (rd_lat > rd_max) rd_max = rd_lat;
        hist[(rd_lat < 127) ? rd_lat : 127] = hist[(rd_lat < 127) ? rd_lat : 127] + 1;
    end
end

// transacciones del Z80 PERDIDAS en el glue (llega un flanco con bus_valid aun alto)
integer dropped = 0;
always @(posedge clk)
    if (u_glue.bus_valid && (u_glue.wr_start || u_glue.rd_start)) dropped = dropped + 1;

// ---------------------------------------------------------------------------
localparam [17:0] NT   = 18'h00000;
localparam [17:0] BLKT = 18'h00800;
localparam [17:0] PGT  = 18'h01000;
localparam [21:0] VB   = 22'h280000;

integer NRD = 120;
integer i, bad, addr_i;
logic [7:0] got, exp_;
integer badlist [0:255];

initial begin
    for (i = 0; i < 128; i = i + 1) hist[i] = 0;
    if (!$value$plusargs("FCPU=%d", FCPU_KHZ)) FCPU_KHZ = 3580;
    TSTATE = 1000000.0 / FCPU_KHZ;       // ns por T

    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    for (i = 0; i < 8; i = i + 1) begin
        sdram[VB + PGT + 8'h4F*8 + i] = 8'hFC;
        sdram[VB + PGT + 8'hFF*8 + i] = 8'hFF;
    end
    // NT con un patron RECONOCIBLE por celda
    for (i = 0; i < 24*80; i = i + 1) sdram[VB + NT + i] = 8'h40 + (i & 8'h3F);
    for (i = 0; i < 240; i = i + 1) sdram[VB + BLKT + i] = 8'hA5;

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);

    vdp_reg(6'd0,  8'h04);  vdp_reg(6'd1,  8'h70);
    vdp_reg(6'd2,  8'h03);  vdp_reg(6'd3,  8'h27);
    vdp_reg(6'd4,  8'h02);  vdp_reg(6'd7,  8'hF4);
    vdp_reg(6'd10, 8'h00);  vdp_reg(6'd12, 8'h00);
    vdp_reg(6'd13, 8'h00);  vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd23, 8'h00);

    wait (vs_cnt >= 2);                  // calentar la cache un frame entero
    wait (display_en);

    rd_n = 0; rd_sum = 0; rd_max = 0;
    for (i = 0; i < 128; i = i + 1) hist[i] = 0;
    bad = 0;

    $display("=== Z80 a %0d kHz (T = %.1f ns), TEXT2 (SCREEN 0 W80) DIBUJANDO ===", FCPU_KHZ, TSTATE);
    for (i = 0; i < NRD; i = i + 1) begin
        addr_i = (i*137) % 1920;
        vram_set_rd(NT + addr_i);
        z80_in(2'd0, got);
        exp_ = 8'h40 + (addr_i & 8'h3F);
        if (got !== exp_) begin
            if (bad < 10)
                $display("  LECTURA MALA #%0d: celda %0d  el Z80 se lleva 0x%02h  (VRAM = 0x%02h)",
                         i, addr_i, got, exp_);
            bad = bad + 1;
        end
    end

    $display("");
    $display("======================= RESULTADO =======================");
    $display("  lecturas de VRAM del Z80 a traves de v9968_cpu_glue: %0d", NRD);
    $display("  *** BYTES EQUIVOCADOS QUE SE LLEVA EL Z80: %0d  (%.1f%%) ***", bad, 100.0*bad/NRD);
    $display("  transacciones de I/O PERDIDAS en el glue (flanco con bus_valid alto): %0d", dropped);
    $display("  latencia interna peticion->bus_rdata_en: n=%0d  media=%0d cy (%.0f ns)  MAX=%0d cy (%.0f ns)",
             rd_n, (rd_n>0)?rd_sum/rd_n:0, (rd_n>0)?(1.0*rd_sum/rd_n)*NS_PER_CY:0.0,
             rd_max, rd_max*NS_PER_CY);
    $display("  presupuesto del Z80 (flanco de csr_n -> muestreo) = %.0f ns = %0d ciclos de clk_86",
             2.5*TSTATE, $rtoi(2.5*TSTATE/NS_PER_CY));
    $write("  histograma de latencias (ciclos:cuenta):");
    for (i = 0; i < 128; i = i + 1) if (hist[i] > 0) $write(" %0d:%0d", i, hist[i]);
    $write("\n");
    if (bad == 0)
        $display("  => a esta frecuencia la lectura llega a tiempo SIEMPRE en este banco");
    else
        $display("  => REPRODUCIDO: el Z80 se lleva el dato de la lectura ANTERIOR");
    #1000;
    $finish;
end

initial begin
    #500000000;
    $display("TIMEOUT vs_cnt=%0d rd_n=%0d", vs_cnt, rd_n);
    $finish;
end

endmodule
