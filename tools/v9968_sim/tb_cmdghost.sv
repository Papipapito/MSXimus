// ============================================================================
// tb_cmdghost.sv - el "rectangulo fantasma" del bug #2 del INFORME_NIQUELADO,
// a nivel de SISTEMA: R#46 de un comando nuevo cayendo DENTRO del flush (ya
// drenado) del comando anterior, que es de SOLO LECTURA.
//
// Pila: vdp (85.9 MHz) + v9968_vram_shim + modelo de SDRAM con latencia
// variable (calcada de la pila A de tb_sc5line).
//
// Guion, repetido con DESPLAZAMIENTO k = 0..K_MAX ciclos:
//   1) POINT (comando de SOLO LECTURA: deja la cache LIMPIA)
//   2) al ver el pulso interno ff_cache_flush_start del motor se esperan k
//      ciclos y se suelta el 2o byte del R#46 del comando siguiente (el
//      primero ya esta escrito): asi el start cae DENTRO de la ventana del
//      flush con precision de ciclo, sin depender del azar
//   3) el comando siguiente es un LMMV que rellena 16x1 pixeles de la fila
//      100+k con 0xFF
//   4) STOP + espera entre iteraciones para que un k que falle no contamine
//      al siguiente (y para medir si el motor y la cache quedan EN REPOSO)
// Al final se comprueba fila a fila si el rectangulo esta dibujado.
//
// Resultados medidos (Verilator, HEAD fc7f724):
//   RTL tal cual              12/15 - k=0,1,2 FANTASMA con la cache CLAVADA
//                             (ff_busy=1, ready=0) y no_reposo=15/15
//   + fix de la cache          12/15 - la cache queda sana (busy=0) pero el
//                             motor se congela: CE apagado por el flush_end
//                             RANCIO del comando abortado (bug #2b)
//   + fix de la cache y del motor  15/15 y no_reposo=0  -> *** OK ***
// ============================================================================
`timescale 1ns/1ps

module tb_cmdghost;

localparam real CLK_HALF = 5.8207;
localparam int  K_MAX    = 14;
`ifndef K_TRACE
`define K_TRACE 99
`endif
localparam int  K_TRACE  = `K_TRACE;

logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [2:0]  bus_address = 0;
logic        bus_write = 0;
logic        A_ioreq = 0, A_valid = 0;
logic [7:0]  bus_wdata = 0;

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
    for (vi = 0; vi < 32768; vi = vi + 1) sdram[22'h280000 + vi] = 8'h44;
end

// ---------------- tareas de bus (protocolo real) ----------------
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
        if (guard == 100000) $display("ATASCO op_A #%0d", op_n);
    end
    A_valid = 1;
    @(negedge clk);
    A_valid = 0; A_ioreq = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_wr(input [2:0] a, input [7:0] d);
begin op_A(a, 1'b1, d); bus_write = 0; end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

// R#46 con el SEGUNDO byte disparado k ciclos despues del flush del comando
// anterior (el primer byte, el dato, ya se ha escrito por separado)
integer trig_ok;
task r46_timed(input integer k);
    integer guard;
begin
    @(negedge clk);
    bus_address = 3'd1; bus_wdata = {2'b10, 6'd46}; bus_write = 1'b1;
    A_ioreq = 1; A_valid = 0;
    @(negedge clk);
    guard = 0;
    while (!A_ready) begin
        @(negedge clk);
        guard = guard + 1;
        if (guard > 100000) begin $display("ATASCO r46 ready"); guard = 0; end
    end
    // disparo: pulso interno de arranque del flush del comando anterior
    trig_ok = 0;
    guard = 0;
    while (!trig_ok && guard < 200000) begin
        if (u_vdpA.u_command.ff_cache_flush_start) trig_ok = 1;
        else begin @(negedge clk); guard = guard + 1; end
    end
    repeat (k) @(negedge clk);
    A_valid = 1;
    @(negedge clk);
    A_valid = 0; A_ioreq = 0; bus_write = 0;
    repeat (2) @(negedge clk);
end
endtask

// ---------------- traza ciclo a ciclo de una iteracion ----------------
integer trace_on = 0;
integer trace_n  = 0;
always @(posedge clk) begin
    if (trace_on && trace_n < 160) begin
        trace_n <= trace_n + 1;
        $display("T%03d fst=%0d busy=%b vval=%b vwr=%b aftrd=%b rden=%b | mot.st=%0d mot.valid=%b mot.wr=%b CE=%b start=%b flsh=%b | vram_rden=%b rdy=%b",
            trace_n,
            u_vdpA.u_command.u_cache.ff_flush_state,
            u_vdpA.u_command.u_cache.ff_busy,
            u_vdpA.u_command.u_cache.ff_vram_valid,
            u_vdpA.u_command.u_cache.ff_vram_write,
            u_vdpA.u_command.u_cache.ff_after_read,
            u_vdpA.u_command.u_cache.ff_cache_vram_rdata_en,
            u_vdpA.u_command.ff_state,
            u_vdpA.u_command.ff_cache_vram_valid,
            u_vdpA.u_command.ff_cache_vram_write,
            u_vdpA.u_command.ff_command_execute,
            u_vdpA.u_command.ff_start,
            u_vdpA.u_command.ff_cache_flush_start,
            u_vdpA.u_command.u_cache.command_vram_rdata_en,
            u_vdpA.u_command.u_cache.cache_vram_ready);
    end
end

integer vsA = 0;
logic vsA_d = 0;
always @(posedge clk) begin
    vsA_d <= A_vs;
    if (A_vs && !vsA_d) vsA <= vsA + 1;
end

// ---------------- guion ----------------
integer k, i, addr, pintados, trig_fails, no_reposo;
integer first_fail;
logic   fila_ok;
//	radiografia por iteracion (motor y cache tras dejar acabar el comando)
integer st_a   [0:K_MAX];
integer ce_a   [0:K_MAX];
integer busy_a [0:K_MAX];
integer fst_a  [0:K_MAX];
integer rdy_a  [0:K_MAX];
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vsA >= 1);
    vdp_reg(6'd0, 8'h06);
    vdp_reg(6'd1, 8'h40);
    vdp_reg(6'd7, 8'h07);
    vdp_reg(6'd8, 8'h0A);
    vdp_reg(6'd9, 8'h80);
    vdp_reg(6'd2, 8'h1F);
    vdp_reg(6'd20, 8'h01);
    $display("SETUP OK vs=%0d", vsA);

    trig_fails = 0;
    no_reposo  = 0;
    for (k = 0; k <= K_MAX; k = k + 1) begin
        // registros del LMMV que vendra DESPUES (asi el R#46 del comando
        // nuevo es la UNICA escritura que queda por hacer y se puede colocar
        // con precision de ciclo)
        vdp_reg(6'd36, 8'd0);            vdp_reg(6'd37, 8'd0);       // DX
        vdp_reg(6'd38, (100+k) & 8'hFF); vdp_reg(6'd39, 8'd0);       // DY
        vdp_reg(6'd40, 8'd16);           vdp_reg(6'd41, 8'd0);       // NX
        vdp_reg(6'd42, 8'd1);            vdp_reg(6'd43, 8'd0);       // NY
        vdp_reg(6'd44, 8'hFF);                                       // CLR
        vdp_reg(6'd45, 8'h00);                                       // ARG
        // POINT en (8, 8): comando de SOLO LECTURA -> cache LIMPIA
        vdp_reg(6'd32, 8'd8);  vdp_reg(6'd33, 8'd0);
        vdp_reg(6'd34, 8'd8);  vdp_reg(6'd35, 8'd0);
        vdp_reg(6'd46, 8'h40);
        // primer byte del R#46 siguiente (dato = LMMV IMP)
        bus_wr(3'd1, 8'h80);
        // segundo byte, k ciclos despues del arranque del flush del POINT
        if (k == K_TRACE) begin trace_on = 1; trace_n = 0; end
        r46_timed(k);
        if (!trig_ok) trig_fails = trig_fails + 1;
        repeat (6000) @(posedge clk);
        trace_on = 0;
        st_a[k]   = u_vdpA.u_command.ff_state;
        ce_a[k]   = u_vdpA.u_command.ff_command_execute;
        busy_a[k] = u_vdpA.u_command.u_cache.ff_busy;
        fst_a[k]  = u_vdpA.u_command.u_cache.ff_flush_state;
        rdy_a[k]  = u_vdpA.u_command.w_cache_vram_ready;
        //	SANEAMIENTO entre iteraciones: un STOP (R#46=0) mas la espera de
        //	rigor, para que un k que falle no contamine al siguiente (cada k
        //	tiene que medir SU ventana, no la resaca del anterior)
        vdp_reg(6'd46, 8'h00);
        repeat (4000) @(posedge clk);
        vdp_reg(6'd46, 8'h00);
        repeat (4000) @(posedge clk);
        if (u_vdpA.u_command.ff_state != 0 || u_vdpA.u_command.u_cache.ff_busy) begin
            $display("  AVISO k=%0d: no queda en reposo (state=%0d busy=%b)",
                     k, u_vdpA.u_command.ff_state,
                     u_vdpA.u_command.u_cache.ff_busy);
            no_reposo = no_reposo + 1;
        end
    end

    repeat (30000) @(posedge clk);

    pintados = 0;
    first_fail = -1;
    for (k = 0; k <= K_MAX; k = k + 1) begin
        fila_ok = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            addr = (100 + k) * 128 + i;
            if (sdram[22'h280000 + addr] !== 8'hFF) fila_ok = 1'b0;
        end
        if (fila_ok) begin
            pintados = pintados + 1;
            $display("  k=%0d fila=%0d  PINTADO   bytes=%02x%02x%02x%02x%02x%02x%02x%02x motor.state=%0d CE=%0d cache(busy=%0d fst=%0d rdy=%0d)",
                k, 100+k,
                sdram[22'h280000+(100+k)*128+0], sdram[22'h280000+(100+k)*128+1],
                sdram[22'h280000+(100+k)*128+2], sdram[22'h280000+(100+k)*128+3],
                sdram[22'h280000+(100+k)*128+4], sdram[22'h280000+(100+k)*128+5],
                sdram[22'h280000+(100+k)*128+6], sdram[22'h280000+(100+k)*128+7],
                st_a[k], ce_a[k], busy_a[k], fst_a[k], rdy_a[k]);
        end
        else begin
            if (first_fail < 0) first_fail = k;
            $display("  k=%0d fila=%0d  FANTASMA  bytes=%02x%02x%02x%02x%02x%02x%02x%02x motor.state=%0d CE=%0d cache(busy=%0d fst=%0d rdy=%0d)",
                k, 100+k,
                sdram[22'h280000+(100+k)*128+0], sdram[22'h280000+(100+k)*128+1],
                sdram[22'h280000+(100+k)*128+2], sdram[22'h280000+(100+k)*128+3],
                sdram[22'h280000+(100+k)*128+4], sdram[22'h280000+(100+k)*128+5],
                sdram[22'h280000+(100+k)*128+6], sdram[22'h280000+(100+k)*128+7],
                st_a[k], ce_a[k], busy_a[k], fst_a[k], rdy_a[k]);
        end
    end

    $display("--- ACTIVIDAD: comandos=%0d disparos_perdidos=%0d no_reposo=%0d ops_bus=%0d",
             (K_MAX+1)*4, trig_fails, no_reposo, op_n);
    $display("--- CACHE al final: ff_busy=%b ff_flush_state=%0d ff_vram_valid=%b motor.ff_state=%0d",
             u_vdpA.u_command.u_cache.ff_busy,
             u_vdpA.u_command.u_cache.ff_flush_state,
             u_vdpA.u_command.u_cache.ff_vram_valid,
             u_vdpA.u_command.ff_state);
    $display("RESULTADO: pintados=%0d/%0d primer_fantasma=%0d",
             pintados, K_MAX+1, first_fail);
    if (pintados == K_MAX+1 && trig_fails == 0)
        $display("*** CMD GHOST: OK ***");
    else
        $display("*** CMD GHOST: FALLO ***");
    #1000;
    $finish;
end

initial begin
    #600000000;
    $display("TIMEOUT GLOBAL vs=%0d op_n=%0d", vsA, op_n);
    $display("*** CMD GHOST: FALLO (timeout) ***");
    $finish;
end

endmodule
