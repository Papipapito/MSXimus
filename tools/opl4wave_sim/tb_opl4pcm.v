// ============================================================================
// tb_opl4pcm.v — testbench del motor PCM OPL4 + pegamento opl4_pcm (MSXimus _89)
//
// Valida ANTES de tocar la placa (leccion opl3_sim):
//  1. Deteccion: NEW2 via C6/C7 reenviados, lectura reg 02 = 0x20 (device ID).
//  2. Lectura de memoria de ondas via regs 3-6 (auto-incremento + prefetch).
//  3. ESCRITURA de RAM de muestras en 0x200000+ (bit21 via MCS_N) y relectura.
//  4. Carga de header de onda (12 bytes, flag LD) y KEY-ON -> PCM no-cero.
//  5. Todo bajo CE fraccionario con STALL y DDR3 falsa con latencia 20-24
//     ciclos + jitter; Z80 con muestreo a ~460ns (timing turbo 5.37MHz).
//
// Ejecutar: cd tools/opl4wave_sim && ./run_sim.sh
// ============================================================================
`timescale 1ns/1ps

module tb_opl4pcm;

reg clk_x1 = 0;
always #6.734 clk_x1 = ~clk_x1;        // 74.25 MHz (FSM DDR3)
reg clk_eng = 0;                        // 37.125 MHz (motor, /2 como en HW)
always #13.333 clk_eng = ~clk_eng;     // _104: 37.5MHz (CLKOUT4 del PLLA)
reg clk_host = 0;
always #9.26 clk_host = ~clk_host;     // 54 MHz

reg rst_n = 0, eng_rst_n = 0;

// ---- bus MSX ----
reg iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
reg [7:0] a = 0, din = 0;
wire wave_rd;
wire [7:0] wave_dout;
wire wave_wait_n;
wire [1:0] wave_status;
wire signed [15:0] pcm_l, pcm_r;

// ---- puerto DDR3 falso ----
wire        mem_req, mem_we;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata;
reg  [7:0]  mem_rdata = 0;
reg  [15:0]  mem_rword = 0;   // _104: palabra (cache de palabra)
reg         mem_done_t = 0;

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

// ---- memoria de ondas falsa: latencia DDR3 20-24 ciclos ----
reg [7:0] wavemem [0:4194303];         // 4MB (ROM 0-2MB, RAM 2-4MB)
reg        p_pend = 0, p_we;
reg [21:0] p_addr;
reg [7:0]  p_dat;
reg [5:0]  p_cnt, p_lat;
integer    n_reads = 0, n_writes = 0;
integer    li;
reg mem_req_d = 0;
always @(posedge clk_x1) begin
    mem_req_d <= mem_req;
    if (mem_req && !mem_req_d) begin      // flanco (el pulso eng dura 2 ciclos x1)
        p_pend <= 1; p_we <= mem_we; p_addr <= mem_addr; p_dat <= mem_wdata;
        p_cnt <= 0; p_lat <= 6'd20 + ({$random} % 5);
        if (p_pend) begin
            $display("FAIL: mem_req con operacion pendiente: en vuelo we=%b addr=%06x (cnt=%0d/%0d), nueva we=%b addr=%06x",
                     p_we, p_addr, p_cnt, p_lat, mem_we, mem_addr);
            $finish;
        end
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == p_lat) begin
            if (p_we) begin wavemem[p_addr] <= p_dat; n_writes = n_writes + 1; end
            else      begin
                mem_rdata <= wavemem[p_addr];
                mem_rword[7:0]  <= wavemem[{p_addr[21:1], 1'b0}];
                mem_rword[15:8] <= wavemem[{p_addr[21:1], 1'b1}];
                n_reads = n_reads + 1;
            end
            mem_done_t <= ~mem_done_t;    // toggle, como el wave_ddr3 real
            p_pend <= 0;
        end
    end
end

// ---- tareas Z80 (timing conservador estilo turbo) ----
task outp(input [7:0] p, input [7:0] v);
begin
    @(negedge clk_host); a = p; din = v; iorq_n = 0; wr_n = 0;
    #420; @(negedge clk_host); wr_n = 1; iorq_n = 1;
    #2500;                              // separacion entre OUTs (menor que OTIR real)
end
endtask

reg [7:0] rdv;
task inp(input [7:0] p);
begin
    @(negedge clk_host); a = p; iorq_n = 0; rd_n = 0;
    #460;                               // muestreo del Z80 a 5.37MHz (caso peor)
    while (!wave_wait_n) @(posedge clk_host);   // el Z80 respeta /WAIT
    #5;
    rdv = wave_dout;
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

// ---- monitor de PCM ----
integer pcm_max = 0, pcm_min = 0;
always @(posedge clk_host) begin
    if (pcm_l > pcm_max) pcm_max = pcm_l;
    if (pcm_l < pcm_min) pcm_min = pcm_l;
end

integer errors = 0;
task check(input [7:0] got, input [7:0] exp, input [127:0] what);
begin
    if (got !== exp) begin
        $display("FAIL %0s: leido %02x, esperado %02x", what, got, exp);
        errors = errors + 1;
    end
    else $display("  ok  %0s = %02x", what, got);
end
endtask

integer i;
initial begin
    // YRW801 sintetica: header de la onda 0 en 0x000000
    for (i = 0; i < 4194304; i = i + 1) wavemem[i] = 8'h00;
    wavemem[0]  = 8'h00;   // formato 8-bit, SA[21:16]=0
    wavemem[1]  = 8'h01;   // SA[15:8]  -> start = 0x000100
    wavemem[2]  = 8'h00;   // SA[7:0]
    wavemem[3]  = 8'h00;   // loop hi
    wavemem[4]  = 8'h00;   // loop lo = 0
    wavemem[5]  = 8'hFF;   // end (complemento a 2 de 64)
    wavemem[6]  = 8'hC0;
    wavemem[7]  = 8'h00;   // LFO/VIB
    wavemem[8]  = 8'hF0;   // AR=15 (instantaneo), D1R=0
    wavemem[9]  = 8'h00;   // DL=0, D2R=0
    wavemem[10] = 8'hFF;   // RC=15, RR=15
    wavemem[11] = 8'h00;   // AM
    // onda cuadrada de 64 muestras en 0x100
    for (i = 0; i < 32; i = i + 1) wavemem[22'h100 + i] = 8'h7F;
    for (i = 32; i < 64; i = i + 1) wavemem[22'h100 + i] = 8'h81;

    #500  rst_n = 1;
    #1000 eng_rst_n = 1;
    #2000;

    $display("== 1. init NEW/NEW2 (C6/C7 reenviados) y deteccion ==");
    outp(8'hC6, 8'h05);
    outp(8'hC7, 8'h03);
    rreg(8'h02);
    check(rdv, 8'h20, "reg02 (device ID)");

    $display("== 2. lectura YRW801 via regs 3-6 ==");
    wreg(8'h02, 8'h01);      // MEMMODE=1
    wreg(8'h03, 8'h00);
    wreg(8'h04, 8'h00);
    wreg(8'h05, 8'h00);      // MEMADDR=0 (dispara el prefetch)
    rreg(8'h06); check(rdv, 8'h00, "YRW801[0]");
    rreg(8'h06); check(rdv, 8'h01, "YRW801[1]");
    rreg(8'h06); check(rdv, 8'h00, "YRW801[2]");
    inp(8'h7F);  check(rdv, 8'h00, "YRW801[3] (IN directo)");

    $display("== 3. escritura RAM de muestras en 0x200000 ==");
    wreg(8'h03, 8'h20);      // MEMADDR = 0x200000
    wreg(8'h04, 8'h00);
    wreg(8'h05, 8'h00);
    wreg(8'h06, 8'hA5);
    wreg(8'h06, 8'h5A);      // auto-incremento
    wreg(8'h03, 8'h20);      // releer desde 0x200000
    wreg(8'h04, 8'h00);
    wreg(8'h05, 8'h00);
    rreg(8'h06); check(rdv, 8'hA5, "RAM[200000]");
    rreg(8'h06); check(rdv, 8'h5A, "RAM[200001]");
    wreg(8'h02, 8'h00);      // MEMMODE off

    $display("== 4. carga de header + KEY-ON ==");
    wreg(8'h20, 8'h00);      // F-num low / WTN[8]=0
    wreg(8'h38, 8'h00);      // octava 0 / F-num hi
    wreg(8'h50, 8'h01);      // TL=0 (max), LD=1 (directo)
    wreg(8'h08, 8'h00);      // wave 0 -> dispara la carga del header
    // poll del flag LD: leer C4 (A=0) limpia LD2 (chip real); LD real en bit1
    i = 0;
    inp(8'hC4);              // clear de LD2 (lectura de status A=0)
    inp(8'h7E);
    $display("  status tras WTN: %02x (LD=%b)", rdv, rdv[1]);
    while (rdv[1] && i < 100) begin
        #10000; inp(8'hC4); inp(8'h7E); i = i + 1;
    end
    if (rdv[1]) begin $display("FAIL: LD no se limpia"); errors = errors + 1; end
    else $display("  ok  LD limpio tras %0d polls", i);

    wreg(8'h68, 8'h80);      // KEY=1, pan centro
    pcm_max = 0; pcm_min = 0;

    #3000000;                // ~132 muestras: cubre la semionda negativa (paso 0.5)
    $display("== 5. resultado PCM: max=%0d min=%0d (fetches=%0d escrituras=%0d) ==",
             pcm_max, pcm_min, n_reads, n_writes);
    if (pcm_max < 2000)  begin $display("FAIL: PCM max demasiado bajo");  errors = errors + 1; end
    if (pcm_min > -2000) begin $display("FAIL: PCM min demasiado alto"); errors = errors + 1; end
    if (pcm_l === 16'hxxxx) begin $display("FAIL: PCM con X"); errors = errors + 1; end

    // key off + damp: debe apagarse (la release exponencial tarda ~1.5ms)
    wreg(8'h68, 8'h40);      // KEY=0, DAMP=1
    #2500000;
    pcm_max = 0; pcm_min = 0;
    #400000;
    $display("== 6. tras KEY-OFF+damp: max=%0d min=%0d ==", pcm_max, pcm_min);
    if (pcm_max > 200 || pcm_min < -200) begin
        $display("FAIL: no se apaga tras KEY-OFF"); errors = errors + 1;
    end

    if (errors == 0) $display("*** TODOS LOS TESTS PASAN ***");
    else             $display("*** %0d ERRORES ***", errors);
    $finish;
end

// guardia de tiempo
initial begin
    #60000000;  // 60ms
    $display("FAIL: timeout global");
    $finish;
end

endmodule
