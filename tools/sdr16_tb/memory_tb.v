// ============================================================================
//  memory_tb.v — Testbench autochequeante del memory_ctrl de 16 bits (port 60K)
// ----------------------------------------------------------------------------
//  Verifica contra el modelo W9825G6KH:
//   T1  Init: secuencia real (precharge/refresh/MRS) acelerada con force sobre
//       FreeCounter; MRS validado por el modelo (CL2/BL1/single-write).
//   T2  CPU write/read-back dirigido: lanes par/impar, 4 bancos, bits de
//       fila/columna extremos, y bit addr[1] (LSB de columna nuevo).
//   T3  Aislamiento de byte (DQM): escribir un byte no toca el adyacente.
//   T4  CPU aleatorio: 300 escrituras + read-back (scoreboard).
//   T5  VDP write/read: word completo por lanes vram_addr[16], varias filas/cols.
//   T6  ALIASING geometría-preservante: el byte escrito por el VDP se lee por
//       CPU en la dirección de banco D construida (y viceversa); la col impar
//       adyacente NO colisiona.
//   T7  MG2/refresh: con bus_rfsh_n=0, una escritura VDP NUNCA se pierde;
//       con vram_write=0 el refresh sí ocurre (contador del modelo).
//
//  Relojes: clk108 y clk54 alineados (generadores independientes, flancos
//  coincidentes 1 de cada 2, como el CLKDIV real). video_dhclk/dlclk = ÷8/÷16
//  de 108 (13.5/6.75 MHz), la cadencia del diseño real.
// ============================================================================
`timescale 1ns/1ps

module memory_tb;

    // ---------------- relojes ----------------
    reg clk108 = 0;
    always #4.63 clk108 = ~clk108;

    reg clk54 = 0;
    initial begin
        #4.63;
        forever begin clk54 = ~clk54; #9.26; end
    end

    // strobes de fase de video (cadencia real: dh=13.5MHz, dl=6.75MHz)
    reg [3:0] phc = 0;
    always @(posedge clk108) phc <= phc + 1;
    wire video_dhclk = ~phc[2];   // alto en fases 0-3 de cada ventana de 8
    wire video_dlclk = ~phc[3];   // 1 = ventana VDP, 0 = ventana CPU

    // ---------------- señales DUT ----------------
    reg         bus_reset_n = 0;
    reg  [7:0]  ram_din  = 0;
    reg         ram_req  = 0;
    reg         ram_write = 0;
    reg  [22:0] ram_addr = 0;
    reg  [7:0]  vram_din = 0;
    reg         vram_write = 0;
    reg  [16:0] vram_addr = 0;
    reg         bus_rfsh_n = 1;
    wire [7:0]  ram_dout;
    wire [15:0] vram_dout;
    wire        ram_busy;

    wire        sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
    wire [15:0] sd_dq;
    wire [12:0] sd_addr;
    wire [1:0]  sd_ba;
    wire [1:0]  sd_dqm;

    memory_ctrl dut (
        .clk_27m     (clk54),        // ¡el puerto clk_27m recibe 54 MHz, como en top.v!
        .clk_108m    (clk108),
        .bus_reset_n (bus_reset_n),
        .video_dhclk (video_dhclk),
        .video_dlclk (video_dlclk),
        .ram_din     (ram_din),
        .ram_req     (ram_req),
        .ram_write   (ram_write),
        .ram_addr    (ram_addr),
        .vram_din    (vram_din),
        .vram_write  (vram_write),
        .vram_addr   (vram_addr),
        .bus_rfsh_n  (bus_rfsh_n),
        .ram_dout    (ram_dout),
        .vram_dout   (vram_dout),
        .ram_busy    (ram_busy),
        .O_sdram_clk   (sd_clk),
        .O_sdram_cke   (sd_cke),
        .O_sdram_cs_n  (sd_cs_n),
        .O_sdram_cas_n (sd_cas_n),
        .O_sdram_ras_n (sd_ras_n),
        .O_sdram_wen_n (sd_wen_n),
        .IO_sdram_dq   (sd_dq),
        .O_sdram_addr  (sd_addr),
        .O_sdram_ba    (sd_ba),
        .O_sdram_dqm   (sd_dqm)
    );

    w9825_model sdram (
        .clk   (sd_clk),
        .cke   (sd_cke),
        .cs_n  (sd_cs_n),
        .ras_n (sd_ras_n),
        .cas_n (sd_cas_n),
        .we_n  (sd_wen_n),
        .addr  (sd_addr),
        .ba    (sd_ba),
        .dqm   (sd_dqm),
        .dq    (sd_dq)
    );

    // ---------------- infra de test ----------------
    integer errors = 0;
    integer n;
    reg [7:0]  rb;
    reg [15:0] wb;
    integer refc0, refc1;

    task check8(input [7:0] got, input [7:0] exp, input [255:0] msg);
    begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL [%0t] %0s: got=%02x exp=%02x", $time, msg, got, exp);
        end
    end
    endtask

    task check16(input [15:0] got, input [15:0] exp, input [255:0] msg);
    begin
        if (got !== exp) begin
            errors = errors + 1;
            $display("FAIL [%0t] %0s: got=%04x exp=%04x", $time, msg, got, exp);
        end
    end
    endtask

    // -------- acceso CPU (protocolo de top.v: req -> busy sube -> busy baja) --------
    task cpu_op(input wr, input [22:0] a, input [7:0] wd, output [7:0] rd);
    begin
        @(negedge clk54);
        ram_addr  = a;
        ram_din   = wd;
        ram_write = wr;
        ram_req   = 1;
        @(posedge ram_busy);
        @(negedge ram_busy);
        @(negedge clk54);
        rd = ram_dout;
        ram_req = 0;
        @(negedge clk54);
    end
    endtask

    task cpu_write(input [22:0] a, input [7:0] d);
        reg [7:0] dummy;
        begin cpu_op(1'b1, a, d, dummy); end
    endtask

    task cpu_read_check(input [22:0] a, input [7:0] exp, input [255:0] msg);
        reg [7:0] r;
        begin cpu_op(1'b0, a, 8'h00, r); check8(r, exp, msg); end
    endtask

    // -------- acceso VDP (señales estables durante ventanas VDP completas) --------
    task vdp_write(input [16:0] a, input [7:0] d);
    begin
        @(negedge clk108);
        while (phc != 4'd14) @(negedge clk108);
        vram_addr  = a;
        vram_din   = d;
        vram_write = 1;
        repeat (48) @(posedge clk108);   // >= 2 ventanas VDP con write estable
        @(negedge clk108);
        vram_write = 0;
        repeat (16) @(posedge clk108);
    end
    endtask

    task vdp_read(input [16:0] a, output [15:0] w);
    begin
        @(negedge clk108);
        vram_write = 0;
        vram_addr  = a;
        repeat (48) @(posedge clk108);   // >= 2 ventanas VDP de lectura
        w = vram_dout;
    end
    endtask

    // -------- T9: medida de latencia del barrido de fase --------
    integer ph, rep, tries, hit, nlat;
    real t0, t1, lat, max_lat, min_lat, sum_lat;

    // -------- scoreboard del test aleatorio --------
    localparam NRAND = 300;
    reg [22:0] rnd_addr [0:NRAND-1];
    reg [7:0]  exp_mem  [0:8388607];     // 8 MB de espacio CPU
    integer ri;
    reg [22:0] ra;
    reg [7:0]  rd_;

    // -------- construcción de la dirección CPU que alias-a un byte VRAM --------
    //  (geometría preservada: row=addr[12:2]=vram[10:0], col={addr[20:13],addr[1]}
    //   = {3'b111, vram[15:11], 1'b0}, bank=11, byte=addr[0]=vram[16])
    function [22:0] vram_alias_cpu_addr(input [16:0] v, input odd_col);
    begin
        vram_alias_cpu_addr = { 2'b11,                       // [22:21] bank D
                                {3'b111, v[15:11]},          // [20:13] col alta
                                v[10:0],                     // [12:2]  fila
                                odd_col,                     // [1]     LSB de columna
                                v[16] };                     // [0]     lane/byte
    end
    endfunction

    // ---------------- watchdog ----------------
    initial begin
        #6_000_000;   // 6 ms de sim
        $display("TIMEOUT: el testbench no ha terminado");
        $finish;
    end

    // ---------------- secuencia principal ----------------
    initial begin
        $display("=== sdr16_tb: memory_ctrl 16-bit vs modelo W9825G6KH ===");

        // reset
        bus_reset_n = 0;
        repeat (40) @(posedge clk108);
        bus_reset_n = 1;

        // ---- T1: init acelerada (force sobre FreeCounter) ----
        while (dut.RstSeq !== 5'b11111) begin
            @(negedge clk108);
            force dut.FreeCounter = 16'hFFF0;
            @(negedge clk108);
            release dut.FreeCounter;
            repeat (90) @(posedge clk108);
        end
        repeat (64) @(posedge clk108);
        if (!sdram.mode_set) begin
            errors = errors + 1;
            $display("FAIL T1: la SDRAM no recibio MRS durante la init");
        end
        if (sdram.refresh_count == 0) begin
            errors = errors + 1;
            $display("FAIL T1: la init no emitio ningun refresh");
        end
        if (sdram.act_before_mrs != 0) begin
            errors = errors + 1;
            $display("FAIL T1: hubo %0d ACTIVATE antes del MRS", sdram.act_before_mrs);
        end
        $display("T1 init OK (refresh_init=%0d)", sdram.refresh_count);

        // ---- T2: CPU dirigido — lanes, bancos, extremos de fila/columna ----
        cpu_write(23'h000000, 8'h11);              // banco 0, byte par
        cpu_write(23'h000001, 8'h22);              // mismo word, byte impar
        cpu_write(23'h000002, 8'h33);              // addr[1]=1 -> columna impar
        cpu_write(23'h000003, 8'h44);
        cpu_write(23'h200000, 8'h55);              // banco 1
        cpu_write(23'h400000, 8'h66);              // banco 2
        cpu_write(23'h600000, 8'h77);              // banco 3 (D)
        cpu_write(23'h1FFC00, 8'h88);              // col alta banco 0
        cpu_write(23'h001FFC, 8'h99);              // fila alta
        cpu_read_check(23'h000000, 8'h11, "T2 b0 lane0");
        cpu_read_check(23'h000001, 8'h22, "T2 b0 lane1");
        cpu_read_check(23'h000002, 8'h33, "T2 col impar lane0");
        cpu_read_check(23'h000003, 8'h44, "T2 col impar lane1");
        cpu_read_check(23'h200000, 8'h55, "T2 banco1");
        cpu_read_check(23'h400000, 8'h66, "T2 banco2");
        cpu_read_check(23'h600000, 8'h77, "T2 banco3");
        cpu_read_check(23'h1FFC00, 8'h88, "T2 col alta");
        cpu_read_check(23'h001FFC, 8'h99, "T2 fila alta");
        $display("T2 CPU dirigido OK");

        // ---- T3: aislamiento de byte (DQM) ----
        cpu_write(23'h010100, 8'hAA);
        cpu_write(23'h010101, 8'hBB);
        cpu_write(23'h010100, 8'hCC);              // reescribir el par NO toca el impar
        cpu_read_check(23'h010101, 8'hBB, "T3 DQM byte impar intacto");
        cpu_read_check(23'h010100, 8'hCC, "T3 DQM byte par reescrito");
        $display("T3 aislamiento DQM OK");

        // ---- T4: CPU aleatorio con scoreboard ----
        for (ri = 0; ri < NRAND; ri = ri + 1) begin
            ra = $random;
            rnd_addr[ri] = ra;
            exp_mem[ra] = ra[7:0] ^ ra[15:8];
            cpu_write(ra, exp_mem[ra]);
        end
        for (ri = 0; ri < NRAND; ri = ri + 1) begin
            ra = rnd_addr[ri];
            cpu_op(1'b0, ra, 8'h00, rd_);
            check8(rd_, exp_mem[ra], "T4 random");
        end
        $display("T4 aleatorio (%0d accesos) OK", 2*NRAND);

        // ---- T5: VDP write/read por lanes ----
        vdp_write({1'b0, 16'h1234}, 8'h5A);        // byte bajo del word 0x1234
        vdp_write({1'b1, 16'h1234}, 8'hC3);        // byte alto
        vdp_read ({1'b0, 16'h1234}, wb);
        check16(wb, 16'hC35A, "T5 word 0x1234");
        vdp_write({1'b0, 16'h0000}, 8'h01);
        vdp_write({1'b1, 16'h0000}, 8'h02);
        vdp_write({1'b0, 16'hFFFF}, 8'h0E);        // fila/col extremas
        vdp_write({1'b1, 16'hFFFF}, 8'h0F);
        vdp_read ({1'b0, 16'h0000}, wb);
        check16(wb, 16'h0201, "T5 word 0x0000");
        vdp_read ({1'b0, 16'hFFFF}, wb);
        check16(wb, 16'h0F0E, "T5 word 0xFFFF");
        $display("T5 VDP lanes OK");

        // ---- T6: aliasing CPU<->VRAM con geometria preservada ----
        cpu_read_check(vram_alias_cpu_addr({1'b0,16'h1234}, 1'b0), 8'h5A, "T6 alias CPU lee byte bajo VRAM");
        cpu_read_check(vram_alias_cpu_addr({1'b1,16'h1234}, 1'b0), 8'hC3, "T6 alias CPU lee byte alto VRAM");
        // la columna IMPAR adyacente (donde antes vivian las lanes HU/HL) NO colisiona:
        cpu_write(vram_alias_cpu_addr({1'b0,16'h1234}, 1'b1), 8'hEE);
        cpu_write(vram_alias_cpu_addr({1'b1,16'h1234}, 1'b1), 8'hDD);
        vdp_read ({1'b0, 16'h1234}, wb);
        check16(wb, 16'hC35A, "T6 col impar no clobbera el word VRAM");
        // y viceversa: escribir por CPU en la col par SI se ve desde el VDP
        cpu_write(vram_alias_cpu_addr({1'b0,16'h1234}, 1'b0), 8'h78);
        vdp_read ({1'b0, 16'h1234}, wb);
        check16(wb, 16'hC378, "T6 escritura CPU visible por VDP");
        $display("T6 aliasing geometria OK");

        // ---- T7: MG2 / refresh ----
        // (a) con rfsh activo, la escritura VDP NUNCA se pierde
        bus_rfsh_n = 0;
        vdp_write({1'b0, 16'h2222}, 8'hA5);
        vdp_write({1'b1, 16'h2222}, 8'h96);
        bus_rfsh_n = 1;
        vdp_read ({1'b0, 16'h2222}, wb);
        check16(wb, 16'h96A5, "T7 MG2: escritura VDP con rfsh activo");
        // (b) con rfsh activo y SIN escritura, el refresh si ocurre
        refc0 = sdram.refresh_count;
        bus_rfsh_n = 0;
        vram_write = 0;
        repeat (160) @(posedge clk108);   // ~10 ventanas VDP
        bus_rfsh_n = 1;
        refc1 = sdram.refresh_count;
        if (refc1 <= refc0) begin
            errors = errors + 1;
            $display("FAIL T7: rfsh_n=0 sin escritura no genero refresh (%0d -> %0d)", refc0, refc1);
        end
        $display("T7 MG2/refresh OK (refresh en idle: +%0d)", refc1 - refc0);

        // ---- T8: GUARDIA anti-inanicion del refresh (bug SCREEN 3) ----
        // vram_write ATASCADO a nivel 1 sostenido (lo que hace el modo
        // multicolor): sin la guardia, el refresh se moria de hambre y la
        // SDRAM se descargaba en segundos. Con la guardia debe FORZARSE un
        // refresh cada <=32 ventanas saltadas.
        refc0 = sdram.refresh_count;
        bus_rfsh_n = 0;
        vram_write = 1;                       // nivel atascado (escenario MC)
        repeat (4096) @(posedge clk108);      // ~512 ventanas
        vram_write = 0;
        bus_rfsh_n = 1;
        refc1 = sdram.refresh_count;
        if (refc1 - refc0 < 4) begin
            errors = errors + 1;
            $display("FAIL T8: guardia no forzo refresh con vram_write atascado (%0d -> %0d)", refc0, refc1);
        end
        $display("T8 guardia anti-inanicion OK (+%0d refresh con vram_write atascado)", refc1 - refc0);

        // ---- T9: barrido de fase — latencia req->busy_baja de LECTURAS ----
        // Lanza lecturas en todos los offsets de fase alcanzables respecto a
        // la rejilla dl/dh y mide req->negedge(busy). Metrica de la iter.3:
        // a 5.37 la holgura del Z80 (RD activo->muestreo) es ~280ns; toda
        // latencia mayor = stall de 1 T-state entero via el handshake.
        cpu_write(23'h033333, 8'h3C);
        max_lat = 0; min_lat = 1000000; sum_lat = 0; nlat = 0;
        for (ph = 0; ph < 16; ph = ph + 1) begin
            for (rep = 0; rep < 4; rep = rep + 1) begin
                hit = 0;
                for (tries = 0; tries < 40; tries = tries + 1) begin
                    if (hit == 0) begin
                        @(negedge clk54);
                        if (phc == ph[3:0]) hit = 1;
                    end
                end
                if (hit == 1) begin
                    ram_addr  = 23'h033333;
                    ram_din   = 0;
                    ram_write = 0;
                    ram_req   = 1;
                    t0 = $realtime;
                    @(negedge ram_busy);
                    t1 = $realtime;
                    @(negedge clk54);
                    check8(ram_dout, 8'h3C, "T9 read-back del barrido");
                    ram_req = 0;
                    @(negedge clk54);
                    lat = t1 - t0;
                    if (lat > max_lat) max_lat = lat;
                    if (lat < min_lat) min_lat = lat;
                    sum_lat = sum_lat + lat;
                    nlat = nlat + 1;
                end
            end
        end
        $display("T9 barrido de fase: %0d lecturas, lat req->busy0  min=%0.0f  avg=%0.0f  MAX=%0.0f ns",
                 nlat, min_lat, sum_lat / nlat, max_lat);

        // ---- T9b: histograma respecto al T-state del turbo (186.3 ns @5.369) ----
        // Reutiliza el mismo barrido pero clasifica cada latencia en cubos de T.
        // Una lectura con lat<=186 CABE en 1 T-state (no stall); >186 fuerza
        // waits. La fraccion >186 * (coste medio) = el deficit del turbo.
        begin : hist
            integer h0, h1, h2, h3, k;
            real Tturbo;
            Tturbo = 1000.0 / 5.369318;   // 186.3 ns
            h0 = 0; h1 = 0; h2 = 0; h3 = 0;
            for (ph = 0; ph < 16; ph = ph + 1) begin
                for (rep = 0; rep < 6; rep = rep + 1) begin
                    hit = 0;
                    for (tries = 0; tries < 40; tries = tries + 1)
                        if (hit == 0) begin @(negedge clk54); if (phc == ph[3:0]) hit = 1; end
                    if (hit == 1) begin
                        ram_addr = 23'h033333; ram_din = 0; ram_write = 0; ram_req = 1;
                        t0 = $realtime; @(negedge ram_busy); t1 = $realtime;
                        @(negedge clk54); ram_req = 0; @(negedge clk54);
                        lat = t1 - t0;
                        if      (lat <= Tturbo)       h0 = h0 + 1;   // 0 waits
                        else if (lat <= 2.0*Tturbo)   h1 = h1 + 1;   // +1 T
                        else if (lat <= 3.0*Tturbo)   h2 = h2 + 1;   // +2 T
                        else                          h3 = h3 + 1;   // +3 T
                    end
                end
            end
            k = h0 + h1 + h2 + h3;
            $display("T9b histograma @5.369 (T=%0.0fns): cabe=%0d(%0d%%)  +1T=%0d  +2T=%0d  +3T=%0d",
                     Tturbo, h0, (100*h0)/k, h1, h2, h3);
            $display("     coste medio extra por lectura = %0.3f T-states",
                     (1.0*h1 + 2.0*h2 + 3.0*h3) / k);
        end

        // ---- T10: ritmo SOSTENIDO de servicio (techo del ancho de banda) ----
        // Fija req y NUNCA lo baja durante un burst; cuenta cuantas lecturas
        // completa el controlador por unidad de tiempo = maximo memory-bound.
        // Si el periodo de servicio < 186ns, la SDRAM NO es el techo de 5.37.
        begin : svc
            integer nsvc; real tA, tB, per;
            cpu_write(23'h044444, 8'h7E);
            nsvc = 400;
            @(negedge clk54); ram_addr = 23'h044444; ram_din = 0; ram_write = 0;
            ram_req = 1;
            @(posedge ram_busy);       // primera aceptacion
            tA = $realtime;
            for (n = 0; n < nsvc; n = n + 1) begin
                @(negedge ram_busy);   // dato listo
                @(negedge clk54); ram_req = 0;   // 1 ciclo de handshake (como el FSM real)
                @(negedge clk54); ram_req = 1;
                @(posedge ram_busy);
            end
            tB = $realtime;
            ram_req = 0;
            per = (tB - tA) / nsvc;
            $display("T10 servicio sostenido: %0d lecturas, periodo=%0.1f ns -> %0.3f MHz de lecturas back-to-back",
                     nsvc, per, 1000.0/per);
            $display("     (T-state turbo=186.3ns=5.369MHz ; normal=277.8ns=3.600MHz)");
        end

        // ---- resumen ----
        $display("---------------------------------------------");
        $display("stats modelo: writes=%0d reads=%0d refresh=%0d",
                 sdram.write_count, sdram.read_count, sdram.refresh_count);
        if (errors == 0)
            $display("*** ALL TESTS PASS ***");
        else
            $display("*** %0d ERRORES ***", errors);
        $finish;
    end

endmodule
