// ============================================================================
// tb_ddr3_backend.sv — banco del camino bk/bk2 -> bridges -> backend DDR3 ->
// modelo de IP. Verifica el contrato que el shim espera del backend:
//   T1  lecturas sueltas canal A (patron conocido escrito antes)
//   T2  lecturas sueltas canal B
//   T3  COMBO: A y B pedidos el mismo ciclo, misma palabra de 32b
//   T4  escrituras byte + readback (mascara DM)
//   T5  rafaga tipo prefetch: 32 palabras seguidas por A+B
//   T6  watchdog _95: el modelo deja de responder -> dones FF y el sistema
//       NO se cuelga (siguiente op normal responde)
// ============================================================================
`timescale 1ns/1ps
module tb_ddr3_backend;

    // relojes: clk_vdp 85.909, clk_27 y clk_g50 solo formales para el modelo
    logic clk_vdp = 0;  always #5.820 clk_vdp = ~clk_vdp;
    logic clk_27  = 0;  always #18.518 clk_27 = ~clk_27;
    logic clk_g50 = 0;  always #10.000 clk_g50 = ~clk_g50;
    logic rst_n = 0;

    // ---- lado shim (bk/bk2) ----
    logic        bk_req = 0, bk_we = 0;
    logic [21:0] bk_addr = 0;
    logic [7:0]  bk_wdata = 0;
    wire  [15:0] bk_rword;
    wire         bk_done_t;

    logic        bk2_req = 0;
    logic [21:0] bk2_addr = 0;
    wire  [15:0] bk2_rword;
    wire         bk2_done_t;

    // ---- backend + bridges ----
    wire clk_x1;
    wire a_req_w, a_we_w, b_req_w;
    wire [21:0] a_addr_w, b_addr_w;
    wire [7:0]  a_wdata_w;
    wire [15:0] a_dout_w, b_dout_w;
    wire a_done_w, b_done_w;
    wire ready_w;
    wire [7:0] diag_w;

    v9968_sdram_bridge u_brA (
        .clk_vdp(clk_vdp), .rst_n(rst_n),
        .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
        .bk_rword(bk_rword), .bk_done_t(bk_done_t),
        .clk_108m(clk_x1),
        .wv2_req(a_req_w), .wv2_we(a_we_w), .wv2_addr(a_addr_w),
        .wv2_wdata(a_wdata_w), .wv2_dout(a_dout_w), .wv2_done(a_done_w)
    );
    v9968_sdram_bridge u_brB (
        .clk_vdp(clk_vdp), .rst_n(rst_n),
        .bk_req(bk2_req), .bk_we(1'b0), .bk_addr(bk2_addr), .bk_wdata(8'd0),
        .bk_rword(bk2_rword), .bk_done_t(bk2_done_t),
        .clk_108m(clk_x1),
        .wv2_req(b_req_w), .wv2_we(), .wv2_addr(b_addr_w),
        .wv2_wdata(), .wv2_dout(b_dout_w), .wv2_done(b_done_w)
    );

    wire [14:0] ddr_addr; wire [2:0] ddr_bank;
    wire ddr_cs, ddr_ras, ddr_cas, ddr_we_p, ddr_ck, ddr_ck_n, ddr_cke, ddr_odt, ddr_reset_n;
    wire [1:0] ddr_dm; wire [15:0] ddr_dq; wire [1:0] ddr_dqs, ddr_dqs_n;

    v9968_ddr3_backend dut (
        .a_req(a_req_w), .a_we(a_we_w), .a_addr(a_addr_w), .a_wdata(a_wdata_w),
        .a_dout(a_dout_w), .a_done(a_done_w),
        .b_req(b_req_w), .b_addr(b_addr_w), .b_dout(b_dout_w), .b_done(b_done_w),
        .clk_x1_out(clk_x1), .ready(ready_w), .diag(diag_w), .dbg_ops(),
        .recal_req(1'b0),
        .clk_27(clk_27), .clk_g50(clk_g50), .pll27_lock(1'b1),
        .ddr_addr(ddr_addr), .ddr_bank(ddr_bank), .ddr_cs(ddr_cs),
        .ddr_ras(ddr_ras), .ddr_cas(ddr_cas), .ddr_we(ddr_we_p),
        .ddr_ck(ddr_ck), .ddr_ck_n(ddr_ck_n), .ddr_cke(ddr_cke),
        .ddr_odt(ddr_odt), .ddr_reset_n(ddr_reset_n), .ddr_dm(ddr_dm),
        .ddr_dq(ddr_dq), .ddr_dqs(ddr_dqs), .ddr_dqs_n(ddr_dqs_n)
    );

    // pll_ddr3 / pll_mDRP_intf: stubs abajo; la IP es el modelo conductual

    // ---- helpers lado shim ----
    integer errores = 0;

    task automatic op_a(input bit we, input [21:0] ad, input [7:0] wd,
                        output [15:0] rw);
        @(posedge clk_vdp);
        bk_we <= we; bk_addr <= ad; bk_wdata <= wd; bk_req <= 1'b1;
        @(posedge clk_vdp);
        bk_req <= 1'b0;
        begin : espera
            automatic bit d0 = bk_done_t;
            automatic int guard = 0;
            while (bk_done_t == d0) begin
                @(posedge clk_vdp);
                guard++;
                if (guard > 400000) begin
                    $display("FALLO: op_a timeout addr=%h", ad);
                    errores++; disable espera;
                end
            end
        end
        rw = bk_rword;
    endtask

    task automatic op_b_rd(input [21:0] ad, output [15:0] rw);
        @(posedge clk_vdp);
        bk2_addr <= ad; bk2_req <= 1'b1;
        @(posedge clk_vdp);
        bk2_req <= 1'b0;
        begin : espera
            automatic bit d0 = bk2_done_t;
            automatic int guard = 0;
            while (bk2_done_t == d0) begin
                @(posedge clk_vdp);
                guard++;
                if (guard > 400000) begin
                    $display("FALLO: op_b timeout addr=%h", ad);
                    errores++; disable espera;
                end
            end
        end
        rw = bk2_rword;
    endtask

    // combo: A y B lanzados el MISMO ciclo (como hace el shim)
    task automatic op_ab(input [21:0] adA, input [21:0] adB,
                         output [15:0] rwA, output [15:0] rwB);
        @(posedge clk_vdp);
        bk_we <= 0; bk_addr <= adA; bk_req <= 1'b1;
        bk2_addr <= adB; bk2_req <= 1'b1;
        @(posedge clk_vdp);
        bk_req <= 1'b0; bk2_req <= 1'b0;
        begin : espera
            automatic bit dA = bk_done_t, dB = bk2_done_t;
            automatic int guard = 0;
            while (bk_done_t == dA || bk2_done_t == dB) begin
                @(posedge clk_vdp);
                guard++;
                if (guard > 400000) begin
                    $display("FALLO: op_ab timeout");
                    errores++; disable espera;
                end
            end
        end
        rwA = bk_rword; rwB = bk2_rword;
    endtask

    // referencia
    logic [7:0] ref_mem [int unsigned];
    function automatic [15:0] ref_word(input [21:0] ad);
        automatic logic [21:0] base = {ad[21:1], 1'b0};
        ref_word = { (ref_mem.exists(base+1) ? ref_mem[base+1] : 8'h00),
                     (ref_mem.exists(base)   ? ref_mem[base]   : 8'h00) };
    endfunction

    logic [15:0] rw, rw2;
    integer i;
    localparam [21:0] BASE = 22'h280000;

    initial begin
        repeat (20) @(posedge clk_vdp);
        rst_n = 1;
        wait (ready_w);
        $display("CALIB OK t=%0t diag=%h", $time, diag_w);

        // T4 primero: poblar 64 bytes con escrituras (tambien es el test DM)
        for (i = 0; i < 64; i++) begin
            op_a(1'b1, BASE + i[21:0], 8'hA0 ^ i[7:0], rw);
            ref_mem[BASE + i[21:0]] = 8'hA0 ^ i[7:0];
        end
        $display("T4a escrituras OK");

        // T1: lecturas sueltas A
        for (i = 0; i < 32; i += 2) begin
            op_a(1'b0, BASE + i[21:0], 8'h00, rw);
            if (rw !== ref_word(BASE + i[21:0])) begin
                $display("FALLO T1 addr=%h leido=%h esp=%h", BASE+i, rw, ref_word(BASE+i[21:0]));
                errores++;
            end
        end
        $display("T1 lecturas A OK");

        // T2: lecturas sueltas B
        for (i = 32; i < 64; i += 2) begin
            op_b_rd(BASE + i[21:0], rw);
            if (rw !== ref_word(BASE + i[21:0])) begin
                $display("FALLO T2 addr=%h leido=%h esp=%h", BASE+i, rw, ref_word(BASE+i[21:0]));
                errores++;
            end
        end
        $display("T2 lecturas B OK");

        // T3: COMBO — mitades baja (A) y alta (B) de la misma palabra de 32b
        for (i = 0; i < 64; i += 4) begin
            op_ab(BASE + i[21:0], BASE + i[21:0] + 22'd2, rw, rw2);
            if (rw !== ref_word(BASE + i[21:0]) ||
                rw2 !== ref_word(BASE + i[21:0] + 22'd2)) begin
                $display("FALLO T3 addr=%h A=%h/%h B=%h/%h", BASE+i,
                         rw, ref_word(BASE+i[21:0]), rw2, ref_word(BASE+i[21:0]+22'd2));
                errores++;
            end
        end
        $display("T3 combo OK");

        // T5: rafaga tipo prefetch (64 palabras alternando A/B)
        for (i = 0; i < 128; i += 2) begin
            if (i[2]) op_b_rd(BASE + 22'h100 + i[21:0], rw);
            else      op_a(1'b0, BASE + 22'h100 + i[21:0], 8'h00, rw);
        end
        $display("T5 rafaga OK (sin cuelgue)");

        // T7 (_130): COHERENCIA DE LA CACHE DE LINEA — leer palabra (llena
        // la cache), escribir un byte de ESA linea, releer: debe verse el
        // byte nuevo (la escritura actualiza la linea cacheada, no solo la
        // DDR3). Por los DOS canales.
        op_a(1'b0, BASE + 22'h20, 8'h00, rw);          // llena clA
        op_b_rd(BASE + 22'h24, rw);                    // llena clB (misma linea? 0x24>>4==0x2 si, misma)
        op_a(1'b1, BASE + 22'h21, 8'h5A, rw);          // escribe byte impar
        ref_mem[BASE + 22'h21] = 8'h5A;
        op_a(1'b0, BASE + 22'h20, 8'h00, rw);          // hit clA: ¿byte nuevo?
        if (rw !== ref_word(BASE + 22'h20)) begin
            $display("FALLO T7a coherencia clA: leido=%h esp=%h", rw, ref_word(BASE + 22'h20));
            errores++;
        end
        op_b_rd(BASE + 22'h20, rw);                    // hit clB de la misma linea
        if (rw !== ref_word(BASE + 22'h20)) begin
            $display("FALLO T7b coherencia clB: leido=%h esp=%h", rw, ref_word(BASE + 22'h20));
            errores++;
        end
        $display("T7 coherencia cache OK");

        // T8 (_132): MARTILLEO bajo readys cayendo — reproduce la corrupcion
        // del 23/07. El modelo ya tumba cmd_ready/wr_data_rdy periodicamente
        // (glitch_rdy=1 por defecto, tambien durante T1-T7); con el patron
        // racy viejo esto pierde operaciones y desincroniza las FIFOs de la
        // IP (franjas + glifos repetidos); con el handshake retenido debe
        // salir PERFECTO. Fase 1: blit secuencial (el patron del logo).
        // Fase 2: mezcla pseudo-aleatoria de escrituras/lecturas A/B/combo.
        begin
            automatic int lfsr = 32'sd12345;
            automatic logic [21:0] ad;
            automatic logic [7:0]  wv;
            for (i = 0; i < 256; i++) begin           // fase 1: blit secuencial
                op_a(1'b1, BASE + 22'h200 + i[21:0], 8'h30 ^ i[7:0], rw);
                ref_mem[BASE + 22'h200 + i[21:0]] = 8'h30 ^ i[7:0];
            end
            for (i = 0; i < 256; i += 2) begin
                op_a(1'b0, BASE + 22'h200 + i[21:0], 8'h00, rw);
                if (rw !== ref_word(BASE + 22'h200 + i[21:0])) begin
                    if (errores < 20)
                        $display("FALLO T8-blit addr=%h leido=%h esp=%h",
                                 BASE+22'h200+i[21:0], rw, ref_word(BASE+22'h200+i[21:0]));
                    errores++;
                end
            end
            for (i = 0; i < 500; i++) begin           // fase 2: mezcla
                lfsr = (lfsr * 1103515245 + 12345) & 32'h7FFFFFFF;
                ad = BASE + 22'h200 + ((lfsr >> 8) % 256);
                wv = lfsr[23:16];
                case (lfsr % 4)
                2'd0: begin
                    op_a(1'b1, ad, wv, rw);
                    ref_mem[ad] = wv;
                end
                2'd1: begin
                    op_a(1'b0, ad, 8'h00, rw);
                    if (rw !== ref_word(ad)) begin
                        if (errores < 20)
                            $display("FALLO T8-rdA addr=%h leido=%h esp=%h",
                                     ad, rw, ref_word(ad));
                        errores++;
                    end
                end
                2'd2: begin
                    op_b_rd(ad, rw);
                    if (rw !== ref_word(ad)) begin
                        if (errores < 20)
                            $display("FALLO T8-rdB addr=%h leido=%h esp=%h",
                                     ad, rw, ref_word(ad));
                        errores++;
                    end
                end
                default: begin
                    op_ab({ad[21:2], 2'b00}, {ad[21:2], 2'b10}, rw, rw2);
                    if (rw  !== ref_word({ad[21:2], 2'b00}) ||
                        rw2 !== ref_word({ad[21:2], 2'b10})) begin
                        if (errores < 20)
                            $display("FALLO T8-combo addr=%h A=%h/%h B=%h/%h",
                                     {ad[21:2], 2'b00},
                                     rw,  ref_word({ad[21:2], 2'b00}),
                                     rw2, ref_word({ad[21:2], 2'b10}));
                        errores++;
                    end
                end
                endcase
            end
        end
        $display("T8 martilleo con readys cayendo OK");

        // T6: watchdog _95 — el modelo deja de responder lecturas
        dut.u_ddr3.fail_mode = 1;
        op_a(1'b0, BASE, 8'h00, rw);
        if (rw !== 16'hFFFF) begin
            $display("FALLO T6: esperaba rescate FFFF, leido=%h", rw);
            errores++;
        end
        dut.u_ddr3.fail_mode = 0;
        // _132: tras el rescate, el dato rancio de la lectura abandonada
        // llega tarde — la siguiente lectura NO debe tomarlo como suyo
        // (anti-desincronizacion rd_pend). Leemos direcciones ESCRITAS en
        // T4 cuyas lineas seguro NO estan en cache tras el T8 (0x28001) y
        // comprobamos el VALOR, no solo la vida.
        op_a(1'b0, BASE + 22'h12, 8'h00, rw);
        if (rw !== ref_word(BASE + 22'h12)) begin
            $display("FALLO T6b desinc post-rescate: leido=%h esp=%h",
                     rw, ref_word(BASE + 22'h12));
            errores++;
        end
        op_b_rd(BASE + 22'h14, rw);
        if (rw !== ref_word(BASE + 22'h14)) begin
            $display("FALLO T6c desinc post-rescate B: leido=%h esp=%h",
                     rw, ref_word(BASE + 22'h14));
            errores++;
        end
        $display("T6 watchdog + anti-desincronizacion OK (diag=%h)", diag_w);

        if (errores == 0) $display("*** DDR3 BACKEND: TODO OK ***");
        else              $display("*** DDR3 BACKEND: %0d FALLOS ***", errores);
        $finish;
    end

endmodule

// ---- stubs de PLL para el TB (la IP-modelo autogenera clk_out) ----
module pll_ddr3 (
    output wire lock, output wire clkout0, output wire clkout2,
    input wire clkin, input wire reset, input wire mdclk,
    input wire [1:0] mdopc, input wire mdainc, input wire [7:0] mdwdi,
    output wire [7:0] mdrdo
);
    assign lock = 1'b1; assign clkout0 = 1'b0; assign clkout2 = 1'b0;
    assign mdrdo = 8'd0;
endmodule

module pll_mDRP_intf (
    input wire clk, input wire rst_n, input wire pll_lock, input wire wr,
    output wire mdrp_inc, output wire [1:0] mdrp_op, output wire [7:0] mdrp_wdata,
    input wire [7:0] mdrp_rdata
);
    assign mdrp_inc = 1'b0; assign mdrp_op = 2'd0; assign mdrp_wdata = 8'd0;
endmodule
