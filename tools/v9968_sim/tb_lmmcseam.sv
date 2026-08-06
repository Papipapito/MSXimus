// ============================================================================
// tb_lmmcseam.sv — reproduccion DETERMINISTA del byte perdido del LMMC.
//
// Guion (calcado del protocolo real del logo de arranque, trazado en openMSX):
//   R#36..45 (args, con R#44 = 1er byte PRECARGADO) -> R#46=B0 (LMMC 16x8)
//   -> R#17=AC -> 127 bytes por 0x9B a ritmo Z80 (PACE ciclos, ~6.5us OTIR)
//   -> poll de CE.
// En la K-esima lectura del backend de VRAM tras el lanzamiento se inyecta
// UNA latencia de B_LAT ciclos (simula un refresh/contencion del DDR3). Si el
// tiempo por byte del motor supera el hueco entre bytes de la CPU, la CPU
// escribe R#44 con TR=0 todavia y el paso del motor por c_state_lmmc_next
// hace TR<=1 pisando la entrega: motor 1 byte corto => CE=1 eterno.
// Barrido k=0..K_MAX. Con el RTL v2.1 (A) se espera CUELGUE en algun k; con
// el fix del latch ff_cpu_data_pending (B), OK en todos.
// Pila identica a tb_cmdghost: vdp 85.9MHz + v9968_vram_shim + SDRAM modelo.
// Display APAGADO para que las unicas lecturas de backend sean del motor
// (la latencia inyectada es el sustituto controlado de la contencion real).
// ============================================================================
`timescale 1ns/1ps

module tb_lmmcseam;

localparam real CLK_HALF = 5.8207;
localparam int  K_MAX    = 15;

integer PACE;
integer B_LAT;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic        bus_ioreq = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;

wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vaddr;
wire         vwrite, vvalid, vrefresh;
wire  [31:0] vwdata;
wire  [3:0]  vmask;
wire  [4:0]  vtag;
wire  [31:0] vrdata;
wire         vrdata_en;
wire  [4:0]  vrtag;
wire         vstall;
wire         d_hs, d_vs, d_en;
wire  [7:0]  d_r, d_g, d_b;

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

// ---- SDRAM con inyector de latencia: la lectura n-esima (rd_idx==boost_k
//      con boost_arm) espera B_LAT ciclos en vez de 26+rand%18 ----
integer boost_k = -1;
integer rd_idx = 0;
logic   boost_arm = 0;
integer boost_hits = 0;

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
        m_cnt <= 0;
        if (!bk_we && boost_arm && rd_idx == boost_k) begin
            m_lat <= B_LAT;
            boost_hits <= boost_hits + 1;
        end
        else begin
            m_lat <= 26 + ({$random} % 18);
        end
        if (!bk_we && boost_arm) rd_idx <= rd_idx + 1;
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

// ---- contadores del handshake ----
integer n_wr44 = 0;
integer n_consumo = 0;
logic [5:0] st_d = 0;
always @(posedge clk) begin
    st_d <= u_vdp.u_command.ff_state;
    if (u_vdp.u_command.register_write && u_vdp.u_command.register_num == 6'd44)
        n_wr44 <= n_wr44 + 1;
    if (u_vdp.u_command.ff_state == 6'd27 && st_d != 6'd27)
        n_consumo <= n_consumo + 1;
end

// ---- tareas de bus ----
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = 1;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);
    while (!bus_ready) @(negedge clk);
    bus_valid = 1;
    @(negedge clk);
    bus_valid = 0; bus_ioreq = 0; bus_write = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_rd(input [2:0] a, output [7:0] d);
begin
    @(negedge clk);
    bus_address = a; bus_write = 0;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);
    while (!bus_ready) @(negedge clk);
    bus_valid = 1;
    @(negedge clk);
    bus_valid = 0; bus_ioreq = 0;
    while (!bus_rdata_en) @(negedge clk);
    d = bus_rdata;
    repeat (2) @(negedge clk);
end
endtask
// cada OUT del Z80 real dista >= ~3.3us del siguiente (12-14 T-states):
// TODOS los writes de puerto van paceados, tambien los pares de registro
task outp(input [2:0] a, input [7:0] d);
begin bus_wr(a, d); repeat (280) @(negedge clk); end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin outp(3'd1, d); outp(3'd1, {2'b10, r}); end
endtask

// ---- guion ----
integer k, i, pr, w0, c0, sent, cons;
logic [7:0] rb;
integer fallos = 0;
initial begin
    if (!$value$plusargs("pace=%d", PACE))  PACE = 560;   // ~6.5us OTIR
    if (!$value$plusargs("blat=%d", B_LAT)) B_LAT = 900;  // ~10.5us de espiga

    repeat (50) @(posedge clk);
    reset_n = 1;
    repeat (5000) @(posedge clk);

    // SCREEN5, display APAGADO, S#2 seleccionado
    vdp_reg(6'd0, 8'h06);
    vdp_reg(6'd1, 8'h00);
    vdp_reg(6'd7, 8'h07);
    vdp_reg(6'd8, 8'h0A);
    vdp_reg(6'd9, 8'h80);
    vdp_reg(6'd2, 8'h1F);
    vdp_reg(6'd15, 8'h02);
    $display("SETUP OK pace=%0d blat=%0d", PACE, B_LAT);

    for (k = 0; k <= K_MAX; k = k + 1) begin
        // args del LMMC del logo: DX=208 DY=16+8k (banda nueva por iteracion
        // => cache fria => hay lecturas de fill y la espiga k SIEMPRE dispara)
        vdp_reg(6'd36, 8'hD0); vdp_reg(6'd37, 8'h00);
        vdp_reg(6'd38, 8'd16 + 8*k[7:0]); vdp_reg(6'd39, 8'h00);
        vdp_reg(6'd40, 8'h10); vdp_reg(6'd41, 8'h00);
        vdp_reg(6'd42, 8'h08); vdp_reg(6'd43, 8'h00);
        vdp_reg(6'd44, 8'h01);                          // PRECARGA (byte 1)
        vdp_reg(6'd45, 8'h00);
        w0 = n_wr44; c0 = n_consumo;
        rd_idx = 0; boost_k = k; boost_arm = 1;
        vdp_reg(6'd46, 8'hB0);                          // LMMC :GO
        vdp_reg(6'd17, 8'hAC);                          // R#17 -> R#44 fijo
        // 127 bytes a ciegas, ritmo Z80 (PACE ciclos entre bytes)
        for (i = 0; i < 127; i = i + 1) begin
            bus_wr(3'd3, i[7:0] + 8'd2);
            repeat (PACE) @(negedge clk);
        end
        // poll de CE (el juego real haria esto para siempre)
        pr = 0; rb = 8'hFF;
        while ((rb & 8'h01) != 0 && pr < 20000) begin
            bus_rd(3'd1, rb);
            pr = pr + 1;
        end
        boost_arm = 0;
        sent = n_wr44 - w0; cons = n_consumo - c0;
        if ((rb & 8'h01) != 0) begin
            fallos = fallos + 1;
            $display("k=%02d CUELGUE  S#2=%02x enviados=%0d consumidos=%0d descuadre=%0d lecturas_bk=%0d motor.state=%0d TR=%b",
                k, rb, sent, cons, sent - cons, rd_idx,
                u_vdp.u_command.ff_state, u_vdp.u_command.ff_transfer_ready);
            // rescate: STOP para poder seguir barriendo
            vdp_reg(6'd46, 8'h00);
            repeat (4000) @(posedge clk);
        end
        else begin
            $display("k=%02d ok       S#2=%02x enviados=%0d consumidos=%0d lecturas_bk=%0d polls=%0d",
                k, rb, sent, cons, rd_idx, pr);
        end
        repeat (4000) @(posedge clk);
    end

    $display("RESULTADO: fallos=%0d/%0d (boost_hits=%0d)", fallos, K_MAX+1, boost_hits);
    if (fallos == 0) $display("*** LMMC SEAM: OK ***");
    else             $display("*** LMMC SEAM: CUELGUE REPRODUCIDO ***");
    $finish;
end

initial begin
    repeat (2000) #1000000;
    $display("TIMEOUT GLOBAL");
    $finish;
end

endmodule
