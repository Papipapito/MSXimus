// ============================================================================
// tb_sandwich.v — EL SANDWICH COMPLETO: wave_ddr3 REAL + opl4_pcm + motor,
// con un modelo conductual de la IP DDR3 de Gowin (stubs abajo).
//
// Cierra el punto ciego de todas las sims anteriores: wave_ddr3 nunca habia
// entrado en simulacion (se sustituia por una memoria falsa). Reproduce la
// secuencia del fallo HW de la _93: loader -> lecturas host (test 3) ->
// lecturas del motor (test 4) -> re-lectura host -> test de RAM del motor,
// TODO con la "tormenta" de fetches de los slots barridos de fondo.
// ============================================================================
`timescale 1ns/1ps

module tb_sandwich;

reg clk_x1_src = 0;
always #6.734 clk_x1_src = ~clk_x1_src;    // 74.25 MHz (la "IP" lo devuelve)
reg clk_host = 0;
always #9.26 clk_host = ~clk_host;         // 54 MHz
reg clk_g50 = 0;
always #10 clk_g50 = ~clk_g50;             // 50 MHz (POR/watchdog)

reg rst_n = 0;

// ---- puerto host de wave_ddr3 (protocolo del loader/wdbg: mismo flanco) ----
reg         h_req = 0, h_we = 0;
reg  [21:0] h_addr = 0;
reg  [7:0]  h_wdata = 0;
wire [7:0]  h_rdata;
wire        h_done;
wire        h_ready;

// ---- motor ----
wire        eng_clk_x1;
reg         opl4_clk37 = 0;
always @(posedge eng_clk_x1) opl4_clk37 <= ~opl4_clk37;   // divisor como top.v

reg  eng_rst_n = 0;
wire mem_req, mem_we, mem_done_t;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata, mem_rdata;
wire [127:0] mem_rline;

// bus MSX del motor
reg iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
reg [7:0] a = 0, din = 0;
wire wave_rd, wave_wait_n;
wire [7:0] wave_dout;
wire [1:0] wave_status;
wire signed [15:0] pcm_l, pcm_r;

wire [14:0] ddr_addr; wire [2:0] ddr_bank;
wire ddr_cs, ddr_ras, ddr_cas, ddr_we_w, ddr_ck, ddr_ck_n, ddr_cke, ddr_odt, ddr_reset_n;
wire [1:0] ddr_dm; wire [15:0] ddr_dq; wire [1:0] ddr_dqs, ddr_dqs_n;

wave_ddr3 uwave (
    .clk_host   (clk_host),
    .rst_n      (rst_n),
    .req_toggle (h_req),
    .we         (h_we),
    .addr       (h_addr),
    .wdata      (h_wdata),
    .rdata      (h_rdata),
    .done_toggle(h_done),
    .ready      (h_ready),
    .clk_x1_out (eng_clk_x1),
    .eng_req    (mem_req),
    .eng_we     (mem_we),
    .eng_addr   (mem_addr),
    .eng_wdata  (mem_wdata),
    .eng_rdata  (mem_rdata),
    .eng_rline  (mem_rline),
    .eng_done_t (mem_done_t),
    .recal_req  (1'b0),          // _100: sin recal forzada en el TB
    .clk_27     (1'b0),
    .clk_g50    (clk_g50),
    .pll27_lock (1'b1),
    .ddr_addr(ddr_addr), .ddr_bank(ddr_bank), .ddr_cs(ddr_cs), .ddr_ras(ddr_ras),
    .ddr_cas(ddr_cas), .ddr_we(ddr_we_w), .ddr_ck(ddr_ck), .ddr_ck_n(ddr_ck_n),
    .ddr_cke(ddr_cke), .ddr_odt(ddr_odt), .ddr_reset_n(ddr_reset_n),
    .ddr_dm(ddr_dm), .ddr_dq(ddr_dq), .ddr_dqs(ddr_dqs), .ddr_dqs_n(ddr_dqs_n)
);

opl4_pcm dut (
    .rst_n(rst_n), .clk_host(clk_host),
    .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
    .addr(a), .din(din),
    .wave_rd(wave_rd), .wave_dout(wave_dout), .wave_wait_n(wave_wait_n),
    .wave_status(wave_status),
    .pcm_l(pcm_l), .pcm_r(pcm_r),
    .clk_eng(opl4_clk37), .eng_rst_n(eng_rst_n),
    .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
    .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_rline(mem_rline), .mem_done_t(mem_done_t)
);

// ---- tareas host (protocolo EXACTO del loader/wdbg: payload y toggle en el
//      MISMO flanco de clk_host; espera del toggle done) ----
reg h_done_seen;
task host_op(input we_i, input [21:0] ad, input [7:0] dat);
begin
    @(posedge clk_host);
    h_we <= we_i; h_addr <= ad; h_wdata <= dat;
    h_req <= ~h_req;              // mismo flanco, como wl/wdbg
    h_done_seen = h_done;
    @(posedge clk_host);
    while (h_done == h_done_seen) @(posedge clk_host);
end
endtask

reg [7:0] h_out;
task host_read(input [21:0] ad);
begin
    host_op(1'b0, ad, 8'h00);
    h_out = h_rdata;
end
endtask

// ---- tareas Z80 ----
task outp(input [7:0] p, input [7:0] v);
begin
    @(negedge clk_host); a = p; din = v; iorq_n = 0; wr_n = 0;
    #420; @(negedge clk_host); wr_n = 1; iorq_n = 1;
    #2500;
end
endtask

reg [7:0] rdv;
task inp(input [7:0] p);
begin
    @(negedge clk_host); a = p; iorq_n = 0; rd_n = 0;
    #460;
    while (!wave_wait_n) @(posedge clk_host);
    #5; rdv = wave_dout;
    #80; @(negedge clk_host); rd_n = 1; iorq_n = 1;
    #1500;
end
endtask

task wreg(input [7:0] r, input [7:0] v);
begin outp(8'h7E, r); outp(8'h7F, v); end
endtask

task rreg(input [7:0] r);
begin outp(8'h7E, r); inp(8'h7F); end
endtask

// ---- referencia y verificacion ----
reg [7:0] ref0 [0:15];   // primeros bytes de la "YRW801"
integer errors = 0;
task check(input [7:0] got, input [7:0] exp, input [127:0] what);
begin
    if (got !== exp) begin
        $display("FAIL %0s: leido %02x esperado %02x", what, got, exp);
        errors = errors + 1;
    end
    else $display("  ok  %0s = %02x", what, got);
end
endtask

integer i;
initial begin
    // patron reconocible (cabecera real de la YRW801)
    ref0[0]=8'h40; ref0[1]=8'h18; ref0[2]=8'h00; ref0[3]=8'h00;
    ref0[4]=8'h00; ref0[5]=8'hFF; ref0[6]=8'hD6; ref0[7]=8'h00;
    ref0[8]=8'hF0; ref0[9]=8'h00; ref0[10]=8'h0F; ref0[11]=8'h00;
    ref0[12]=8'h40; ref0[13]=8'h18; ref0[14]=8'h3F; ref0[15]=8'h00;

    #200 rst_n = 1;
    // esperar calibracion
    while (!h_ready) @(posedge clk_host);
    $display("== calibrada ==");

    // 1. LOADER: escribir 64 bytes como el wl (payload+toggle mismo flanco)
    for (i = 0; i < 64; i = i + 1)
        host_op(1'b1, i[21:0], (i < 16) ? ref0[i] : (i[7:0] ^ 8'h5A));
    $display("== loader: 64 bytes escritos ==");

    // 2. motor FUERA de reset -> arranca la TORMENTA de fetches
    eng_rst_n = 1;
    #30000;   // dejar la tormenta en marcha (y el barrido)
    $display("== motor vivo (tormenta activa) ==");

    // 3. lecturas host tipo test 3 (con tormenta de fondo)
    for (i = 0; i < 8; i = i + 1) begin
        host_read(i[21:0]);
        check(h_out, ref0[i], "host[i] con tormenta");
    end

    // 4. secuencia del motor (test 4): NEW2 + lectura de 0..7 por regs
    #30000;  // margen post-barrido para las escrituras (leccion del TB)
    outp(8'hC6, 8'h05);
    outp(8'hC7, 8'h03);
    wreg(8'h02, 8'h01);
    wreg(8'h03, 8'h00); wreg(8'h04, 8'h00); wreg(8'h05, 8'h00);
    for (i = 0; i < 8; i = i + 1) begin
        rreg(8'h06);
        check(rdv, ref0[i], "motor[i]");
    end

    // 5. re-lectura host DESPUES de la actividad del motor (el FALLO de la _93)
    for (i = 0; i < 8; i = i + 1) begin
        host_read(i[21:0]);
        check(h_out, ref0[i], "host[i] tras motor");
    end

    // 6. test de RAM del motor en 0x200000 (el ERR F95AFF de la _93)
    wreg(8'h03, 8'h20); wreg(8'h04, 8'h00); wreg(8'h05, 8'h00);
    wreg(8'h06, 8'hA5); wreg(8'h06, 8'h5A); wreg(8'h06, 8'hC3);
    wreg(8'h03, 8'h20); wreg(8'h04, 8'h00); wreg(8'h05, 8'h00);
    rreg(8'h06); check(rdv, 8'hA5, "RAM[0]");
    rreg(8'h06); check(rdv, 8'h5A, "RAM[1]");
    rreg(8'h06); check(rdv, 8'hC3, "RAM[2]");
    wreg(8'h02, 8'h00);

    if (errors == 0) $display("*** SANDWICH: TODOS LOS TESTS PASAN ***");
    else             $display("*** SANDWICH: %0d ERRORES ***", errors);
    $finish;
end

initial begin
    #80000000;
    $display("TIMEOUT (errores=%0d)", errors);
    $finish;
end

endmodule

// ============================================================================
// STUBS de la IP de Gowin (conductuales)
// ============================================================================
module pll_ddr3 (
    output lock, output clkout0, output clkout2,
    input clkin, input reset, input mdclk,
    input [1:0] mdopc, input mdainc, input [7:0] mdwdi, output [7:0] mdrdo
);
    assign lock = 1'b1;
    assign clkout0 = 1'b0;
    assign clkout2 = 1'b0;    // memory_clk (no usado por el modelo)
    assign mdrdo = 8'h00;
endmodule

module pll_mDRP_intf (
    input clk, input rst_n, input pll_lock, input wr,
    output mdrp_inc, output [1:0] mdrp_op, output [7:0] mdrp_wdata, input [7:0] mdrp_rdata
);
    assign mdrp_inc = 1'b0;
    assign mdrp_op = 2'b00;
    assign mdrp_wdata = 8'h00;
endmodule

// modelo conductual de la IP DDR3: comandos EN ORDEN, latencia de lectura
// ~20 ciclos, escritura enmascarada por DM (1=no escribir), rafagas de 16B.
// app_rdy cae ~200ns cada ~7.8us (refresh) para realismo.
module DDR3_Memory_Interface_Top (
    input memory_clk, output pll_stop, input clk, input rst_n,
    output cmd_ready, input [2:0] cmd, input cmd_en, input [27:0] addr,
    output wr_data_rdy, input [127:0] wr_data, input wr_data_en, input wr_data_end,
    input [15:0] wr_data_mask,
    output reg [127:0] rd_data, output reg rd_data_valid, output rd_data_end,
    input sr_req, input ref_req, output sr_ack, output ref_ack,
    output reg init_calib_complete, output clk_out, input pll_lock, input burst,
    output ddr_rst,
    output [14:0] O_ddr_addr, output [2:0] O_ddr_ba, output O_ddr_cs_n,
    output O_ddr_ras_n, output O_ddr_cas_n, output O_ddr_we_n,
    output O_ddr_clk, output O_ddr_clk_n, output O_ddr_cke, output O_ddr_odt,
    output O_ddr_reset_n, output [1:0] O_ddr_dqm,
    inout [15:0] IO_ddr_dq, inout [1:0] IO_ddr_dqs, inout [1:0] IO_ddr_dqs_n
);
    assign pll_stop = 1'b0;
    assign rd_data_end = 1'b1;
    assign sr_ack = 1'b0; assign ref_ack = 1'b0;
    assign ddr_rst = ~rst_n_sync;
    assign O_ddr_addr = 0; assign O_ddr_ba = 0; assign O_ddr_cs_n = 1;
    assign O_ddr_ras_n = 1; assign O_ddr_cas_n = 1; assign O_ddr_we_n = 1;
    assign O_ddr_clk = 0; assign O_ddr_clk_n = 1; assign O_ddr_cke = 0;
    assign O_ddr_odt = 0; assign O_ddr_reset_n = 1; assign O_ddr_dqm = 0;

    // clk_out = el reloj x1 lo pone el testbench (jerarquico)
    assign clk_out = tb_sandwich.clk_x1_src;

    reg rst_n_sync = 0;
    always @(posedge clk_out) rst_n_sync <= 1'b1;

    // memoria de 4MB en lineas de 16B
    reg [7:0] mem [0:4194303];
    integer k;
    initial begin
        for (k = 0; k < 4194304; k = k + 1) mem[k] = 8'hFF;   // flash virgen
        init_calib_complete = 0;
        rd_data_valid = 0;
    end

    // calibracion a los ~300 ciclos
    integer calcnt = 0;
    always @(posedge clk_out) begin
        if (calcnt < 300) calcnt <= calcnt + 1;
        else init_calib_complete <= 1;
    end

    // refresh: app_rdy cae 15 ciclos cada ~580 (7.8us)
    integer refcnt = 0;
    reg in_ref = 0;
    always @(posedge clk_out) begin
        refcnt <= refcnt + 1;
        if (refcnt % 580 == 0) in_ref <= 1;
        else if (refcnt % 580 == 15) in_ref <= 0;
    end
    assign cmd_ready = init_calib_complete && !in_ref;
    assign wr_data_rdy = init_calib_complete && !in_ref;

    // cola de UN comando en vuelo (la FSM del cliente es de a-uno) + latencia
    reg [27:0] q_addr;
    reg        q_rd_pend = 0;
    reg [127:0] q_wdata;
    reg [15:0]  q_mask;
    integer     q_lat = 0;
    integer     bidx;
    // _95: inyeccion de fallo — +drop_read=N hace que la N-esima lectura NO
    // devuelva rd_data_valid JAMAS (la IP "se la come"): valida el watchdog
    // de operacion de wave_ddr3 (done falso FF a ~0.9ms, motor sigue vivo)
    integer     drop_read = 0, rd_seq = 0;
    initial if (!$value$plusargs("drop_read=%d", drop_read)) drop_read = 0;
    always @(posedge clk_out) begin
        rd_data_valid <= 0;
        if (cmd_en && cmd_ready) begin
            if (cmd == 3'b001) begin
                rd_seq <= rd_seq + 1;
                if (drop_read != 0 && (rd_seq + 1) == drop_read) begin
                    q_rd_pend <= 0;    // tragada: ni valid ni datos
                    $display("[stub] lectura %0d TRAGADA (inyeccion de fallo)", rd_seq + 1);
                end
                else begin
                    q_addr <= addr; q_rd_pend <= 1;
                    q_lat <= 18 + ({$random} % 6);
                end
            end
            else begin
                // escritura: data llega por wr_data_en este mismo ciclo o proximo
                q_addr <= addr;
            end
        end
        if (wr_data_en) begin
            // aplicar de inmediato (en orden): addr en PALABRAS de 16 bits
            for (bidx = 0; bidx < 16; bidx = bidx + 1)
                if (!wr_data_mask[bidx])
                    mem[{q_addr_active(), 4'b0000} + bidx] <= wr_data[bidx*8 +: 8];
        end
        if (q_rd_pend) begin
            q_lat <= q_lat - 1;
            if (q_lat <= 0) begin
                for (bidx = 0; bidx < 16; bidx = bidx + 1)
                    rd_data[bidx*8 +: 8] <= mem[{q_addr[20:3], 4'b0000} + bidx];
                rd_data_valid <= 1;
                q_rd_pend <= 0;
            end
        end
    end
    // direccion activa para la escritura: cmd y wr_data_en llegan juntos
    // (el cliente los pone el mismo ciclo) -> usar addr directo si cmd_en
    function [17:0] q_addr_active;
        begin
            q_addr_active = (cmd_en && cmd == 3'b000) ? addr[20:3] : q_addr[20:3];
        end
    endfunction
endmodule
