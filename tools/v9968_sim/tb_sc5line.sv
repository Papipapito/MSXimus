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

module tb_sc5line;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

// ---------------- bus compartido (escrituras a ambas pilas) ----------------
logic [2:0]  bus_address = 0;
logic        bus_ioreq = 0, bus_write = 0, bus_valid = 0;
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
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(A_ready),
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
wire [7:0]  bk_wdata;
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
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [7:0]  m_dat;
integer      m_cnt, m_lat;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
            if (m_we) sdram[m_addr] <= m_dat;
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
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(B_ready),
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

// ---------------- precarga: pagina 0 = 0x44, pagina 1 = 0x85 ----------------
// (el fill del ASM va por OTIR y esta validado en tb_screen5g; precargar
//  ahorra ~30 min de sim y deja el foco en LINE)
integer vi;
initial begin
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    for (vi = 0; vi < 65536; vi = vi + 1) vram_mem[vi] = 32'd0;
    for (vi = 0; vi < 8192; vi = vi + 1) begin          // pag0: words 0-8191
        vram_mem[vi] = 32'h44444444;
        sdram[22'h280000 + vi*4 + 0] = 8'h44;
        sdram[22'h280000 + vi*4 + 1] = 8'h44;
        sdram[22'h280000 + vi*4 + 2] = 8'h44;
        sdram[22'h280000 + vi*4 + 3] = 8'h44;
    end
    for (vi = 8192; vi < 16384; vi = vi + 1) begin      // pag1: words 8192-16383
        vram_mem[vi] = 32'h85858585;
        sdram[22'h280000 + vi*4 + 0] = 8'h85;
        sdram[22'h280000 + vi*4 + 1] = 8'h85;
        sdram[22'h280000 + vi*4 + 2] = 8'h85;
        sdram[22'h280000 + vi*4 + 3] = 8'h85;
    end
end

// ---------------- tareas de bus (esperan a AMBAS pilas) ----------------
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!(A_ready && B_ready)) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (20) @(posedge clk);
end
endtask
task bus_rd_A(input [2:0] a, output [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_ioreq <= 1; bus_write <= 0; bus_valid <= 1;
    @(posedge clk);
    while (!(A_ready && B_ready)) @(posedge clk);
    bus_ioreq <= 0; bus_valid <= 0;
    while (!A_rdata_en) @(posedge clk);
    d = A_rdata;
    repeat (20) @(posedge clk);
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

// ---------------- guion (calcado de sc5line.asm) ----------------
integer diffs, w, b8;
logic [7:0] a_byte, b_byte;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vsA >= 1);
    // screen5 (registros como el ASM; sprites ocultos)
    vdp_reg(6'd0, 8'h06);
    vdp_reg(6'd1, 8'h40);
    vdp_reg(6'd7, 8'h07);
    vdp_reg(6'd8, 8'h0A);
    vdp_reg(6'd9, 8'h80);
    vdp_reg(6'd2, 8'h1F);
    vdp_reg(6'd20, 8'h01);
    $display("SETUP OK vs=%0d", vsA);

    // t001: punto NX=NY=0
    line_cmd(16'd10, 16'd11, 16'd0, 16'd0, 8'd15, 8'h00, 8'h70, 1);
    // t017-t020: abanico corto en (40,40)
    line_cmd(16'd40, 16'd40, 16'd10, 16'd0,  8'd15, 8'h00, 8'h70, 17);
    line_cmd(16'd40, 16'd40, 16'd10, 16'd5,  8'd12, 8'h00, 8'h70, 18);
    line_cmd(16'd40, 16'd40, 16'd10, 16'd10, 8'd13, 8'h00, 8'h70, 19);
    line_cmd(16'd40, 16'd40, 16'd10, 16'd5,  8'd6,  8'h01, 8'h70, 20);
    $display("ABANICO OK (t=%0t)", $time);
    // t081-t084: borde a borde, 4 direcciones
    line_cmd(16'd0,   16'd80,  16'd255, 16'd19, 8'd15, 8'h00, 8'h70, 81);
    line_cmd(16'd0,   16'd120, 16'd255, 16'd19, 8'd12, 8'h08, 8'h70, 82);
    line_cmd(16'd255, 16'd80,  16'd255, 16'd19, 8'd13, 8'h04, 8'h70, 83);
    line_cmd(16'd255, 16'd120, 16'd255, 16'd19, 8'd6,  8'h0C, 8'h70, 84);
    $display("LARGAS OK (t=%0t)", $time);
    // t085: operaciones logicas sobre pagina 1 (fondo 0x85) — LECTURAS
    line_cmd(16'd0, 16'd10+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h71, 8501); // AND
    line_cmd(16'd0, 16'd13+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h72, 8502); // OR
    line_cmd(16'd0, 16'd16+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h73, 8503); // XOR
    line_cmd(16'd0, 16'd19+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h74, 8504); // NOT
    line_cmd(16'd0, 16'd21+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h78, 8505); // TIMP
    line_cmd(16'd0, 16'd24+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h79, 8506); // TAND
    line_cmd(16'd0, 16'd30+16'd256, 16'd255, 16'd0, 8'd4, 8'h00, 8'h7B, 8507); // TXOR
    $display("LOGICAS OK (t=%0t)", $time);
    // t086: clipping por la derecha y por la izquierda (pagina 1)
    line_cmd(16'd128, 16'd40+16'd256, 16'd234, 16'd0, 8'd3, 8'h00, 8'h70, 86);
    line_cmd(16'd127, 16'd45+16'd256, 16'd234, 16'd0, 8'd9, 8'h04, 8'h70, 8602);
    // t089: arranque fuera de rango (DX=300)
    line_cmd(16'd300, 16'd50, 16'd234, 16'd0, 8'd3, 8'h04, 8'h70, 89);
    $display("CLIPPING OK (t=%0t)", $time);

    // drenar colas del shim antes del diff
    repeat (20000) @(posedge clk);

    // ---------------- diff byte-exacto paginas 0-1 ----------------
    diffs = 0;
    for (w = 0; w < 16384; w = w + 1) begin
        for (b8 = 0; b8 < 4; b8 = b8 + 1) begin
            a_byte = sdram[22'h280000 + w*4 + b8];
            b_byte = vram_mem[w] >> (8*b8);
            if (a_byte !== b_byte) begin
                diffs = diffs + 1;
                if (diffs <= 30)
                    $display("DIFF w=%04x b=%0d A=%02x B=%02x  (x=%0d y=%0d)",
                             w, b8, a_byte, b_byte,
                             ((w % 32) * 4 + b8) * 2, w / 32);
            end
        end
    end
    $display("RESULTADO: ce_colgados=%0d diffs=%0d", ce_fails, diffs);
    if (ce_fails == 0 && diffs == 0) $display("*** LINE DISCRIMINADOR: OK ***");
    else                             $display("*** LINE DISCRIMINADOR: FALLO ***");
    #1000;
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT GLOBAL vs=%0d", vsA);
    $finish;
end

endmodule
