// ============================================================================
// tb_sandwich.v — EL SANDWICH COMPLETO _104: memory_ctrl REAL + modelo W9825
// + wave_sdram (shim) + opl4_pcm + motor. La secuencia historica del fallo
// HW de la _93: loader -> lecturas host -> lecturas del motor -> RAM test.
// (La version DDR3 queda en tb_sandwich_ddr3.v.bak como referencia.)
// ============================================================================
`timescale 1ns/1ps

module tb_sandwich;

reg clk_108 = 0;
always #4.63 clk_108 = ~clk_108;           // 108 MHz
reg clk_host = 0;
initial begin #4.63; forever begin clk_host = ~clk_host; #9.26; end end
reg clk_eng = 0;
always #13.333 clk_eng = ~clk_eng;         // 37.5 MHz (CLKOUT4)

// fases de video (cadencia del TB de memory: dh=13.5MHz, dl=6.75MHz)
reg [3:0] phc = 0;
always @(posedge clk_108) phc <= phc + 1;
wire video_dhclk = ~phc[2];
wire video_dlclk = ~phc[3];

reg rst_n = 0;

// ---- puerto host de wave_ddr3 (protocolo del loader/wdbg: mismo flanco) ----
reg         h_req = 0, h_we = 0;
reg  [21:0] h_addr = 0;
reg  [7:0]  h_wdata = 0;
wire [7:0]  h_rdata;
wire        h_done;
wire        h_ready;

// ---- motor ----
reg  eng_rst_n = 0;
wire mem_req, mem_we, mem_done_t;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata, mem_rdata;
wire [15:0] mem_rword;

// bus MSX del motor
reg iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
reg [7:0] a = 0, din = 0;
wire wave_rd, wave_wait_n;
wire [7:0] wave_dout;
wire [1:0] wave_status;
wire signed [15:0] pcm_l, pcm_r;

// ---- pila SDRAM real: shim + memory_ctrl + modelo W9825 ----
wire        wv_req, wv_we, wv_done;
wire [21:0] wv_addr;
wire [7:0]  wv_wdata;
wire [15:0] wv_dout;
wire        sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
wire [15:0] sd_dq;
wire [12:0] sd_addr;
wire [1:0]  sd_ba, sd_dqm;
wire [7:0]  nc_ram_dout; wire [15:0] nc_vram_dout; wire nc_ram_busy;

wave_sdram uwsdram (
    .clk_host(clk_host), .rst_n(rst_n),
    .req_toggle(h_req), .we(h_we), .addr(h_addr), .wdata(h_wdata),
    .rdata(h_rdata), .done_toggle(h_done), .ready(h_ready),
    .clk_eng(clk_eng),
    .eng_req(mem_req), .eng_we(mem_we), .eng_addr(mem_addr),
    .eng_wdata(mem_wdata), .eng_rdata(mem_rdata), .eng_rword(mem_rword),
    .eng_done_t(mem_done_t),
    .diag(),
    .clk_108m(clk_108),
    .wv_req(wv_req), .wv_we(wv_we), .wv_addr(wv_addr), .wv_wdata(wv_wdata),
    .wv_dout(wv_dout), .wv_done(wv_done)
);

memory_ctrl umem (
    .clk_27m(clk_host), .clk_108m(clk_108), .bus_reset_n(rst_n),
    .video_dhclk(video_dhclk), .video_dlclk(video_dlclk),
    .ram_din(8'h00), .ram_req(1'b0), .ram_write(1'b0), .ram_addr(23'd0),
    .vram_din(8'h00), .vram_write(1'b0), .vram_addr(17'd0), .bus_rfsh_n(1'b1),
    .ram_dout(nc_ram_dout), .vram_dout(nc_vram_dout), .ram_busy(nc_ram_busy),
    .wv_req(wv_req), .wv_we(wv_we), .wv_addr(wv_addr), .wv_wdata(wv_wdata),
    .wv_dout(wv_dout), .wv_done(wv_done),
    .O_sdram_clk(sd_clk), .O_sdram_cke(sd_cke), .O_sdram_cs_n(sd_cs_n),
    .O_sdram_cas_n(sd_cas_n), .O_sdram_ras_n(sd_ras_n), .O_sdram_wen_n(sd_wen_n),
    .IO_sdram_dq(sd_dq), .O_sdram_addr(sd_addr), .O_sdram_ba(sd_ba),
    .O_sdram_dqm(sd_dqm)
);

w9825_model sdram (
    .clk(sd_clk), .cke(sd_cke), .cs_n(sd_cs_n), .ras_n(sd_ras_n),
    .cas_n(sd_cas_n), .we_n(sd_wen_n), .addr(sd_addr), .ba(sd_ba),
    .dqm(sd_dqm), .dq(sd_dq)
);

// init acelerada de la SDRAM (force sobre FreeCounter, como memory_tb)
initial begin
    wait (rst_n === 1'b1);
    while (umem.RstSeq !== 5'b11111) begin
        @(negedge clk_108);
        force umem.FreeCounter = 16'hFFF0;
        @(negedge clk_108);
        release umem.FreeCounter;
        repeat (90) @(posedge clk_108);
    end
end

opl4_pcm dut (
    .rst_n(rst_n), .clk_host(clk_host),
    .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
    .addr(a), .din(din),
    .wave_rd(wave_rd), .wave_dout(wave_dout), .wave_wait_n(wave_wait_n),
    .wave_status(wave_status),
    .pcm_l(pcm_l), .pcm_r(pcm_r),
    .clk_eng(clk_eng), .eng_rst_n(eng_rst_n),
    .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
    .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_rword(mem_rword), .mem_done_t(mem_done_t)
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
