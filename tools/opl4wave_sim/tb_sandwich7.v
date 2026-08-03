// ============================================================================
// tb_sandwich7.v — EL EXPERIMENTO DEL DESAFINADO (_105): 7 slots sonando
// sobre la pila SDRAM REAL (memory_ctrl + W9825 + wave_sdram + opl4_pcm).
// Mide el periodo real de salida (ideal 22.676us) y la latencia de fetch
// vista por el motor. Si el periodo se estira => hambre de CE confirmada
// (la firma del "desafinado" de la _104 en placa).
// La YRW801 real se PRECARGA en el modelo W9825 con el mapeo wave de
// memory.v: row={1,00,A[21:12]}, bank=A[11:10], col=A[9:1], lane=A[0].
// ============================================================================
`timescale 1ns/1ps

module tb_sandwich7;

reg clk_108 = 0;
always #4.63 clk_108 = ~clk_108;           // 108 MHz
reg clk_host = 0;
initial begin #4.63; forever begin clk_host = ~clk_host; #9.26; end end
reg clk_eng = 0;
always #13.333 clk_eng = ~clk_eng;         // 37.5 MHz (CLKOUT4)

// fases de video (cadencia del TB de memory)
reg [3:0] phc = 0;
always @(posedge clk_108) phc <= phc + 1;
wire video_dhclk = ~phc[2];
wire video_dlclk = ~phc[3];

reg rst_n = 0;

// ---- puerto host del shim: OCIOSO (el loader no interviene) ----
reg         h_req = 0, h_we = 0;
reg  [21:0] h_addr = 0;
reg  [7:0]  h_wdata = 0;
wire [7:0]  h_rdata;
wire        h_done, h_ready;

// ---- motor ----
reg  eng_rst_n = 0;
wire mem_req, mem_we, mem_done_t;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata, mem_rdata;
wire [15:0] mem_rword;

reg iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
reg [7:0] a = 0, din = 0;
wire wave_rd, wave_wait_n;
wire [7:0] wave_dout;
wire [1:0] wave_status;
wire signed [15:0] pcm_l, pcm_r;

// ---- pila SDRAM real ----
wire        wv_req, wv_we, wv_done;
wire [21:0] wv_addr;
wire [7:0]  wv_wdata;
wire [15:0] wv_dout;
wire        sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
wire [15:0] sd_dq;
wire [12:0] sd_addr;
wire [1:0]  sd_ba, sd_dqm;
wire [15:0] nc_vram_dout; wire nc_ram_busy;

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

reg  [7:0]  ram_din = 0;
reg         ram_req = 0, ram_write = 0;
reg  [22:0] ram_addr = 0;
wire [7:0]  ram_dout;
wire        ram_busy;

memory_ctrl umem (
    .clk_27m(clk_host), .clk_108m(clk_108), .bus_reset_n(rst_n),
    .video_dhclk(video_dhclk), .video_dlclk(video_dlclk),
    .ram_din(ram_din), .ram_req(ram_req), .ram_write(ram_write), .ram_addr(ram_addr),
    .vram_din(8'h00), .vram_write(1'b0), .vram_addr(17'd0), .bus_rfsh_n(1'b1),
    .ram_dout(ram_dout), .vram_dout(nc_vram_dout), .ram_busy(ram_busy),
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

// init acelerada de la SDRAM
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

// ---- PRECARGA de la YRW801 real en el W9825 (mapeo wave de memory.v) ----
reg [7:0] rom [0:2097151];
integer pa;
reg [23:0] pidx;
initial begin
    $readmemh("yrw801_2m.hex", rom);
    wait (umem.RstSeq === 5'b11111);       // tras la init (no pisar el mode reg)
    for (pa = 0; pa < 2097152; pa = pa + 2) begin
        // index = {bank(2), row(13), col(9)}; row={1,00,A[21:12]}, col=A[9:1]
        pidx = {pa[11:10], 3'b100, pa[21:12], pa[9:1]};
        sdram.mem[pidx] = {rom[pa+1], rom[pa]};
    end
    $display("== YRW801 precargada en el W9825 ==");
end

// ---- tareas Z80 (identicas al sandwich) ----
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

// ---- _111 debug: patron ISR de VGMPlay (+isr=1): cada 885us el Z80 lee
// el status C4 (BUSY poll + flag del timer) y escribe el ack reg4=0x80.
// opl4_pcm reenvia TODO eso al motor wave (lectura C4 como A=0, escrituras
// C4/C5 como A=0/1): si cada evento perturba una muestra, el batido
// 1130Hz vs 44100Hz genera la "vibracion" lenta que se oye SOLO con
// VGMPlay/MBWave (los juegos no tocan C4 durante la musica).
integer ISRON = 0;
initial begin
    if (!$value$plusargs("isr=%d", ISRON)) ISRON = 0;
    if (ISRON) begin
        wait (umem.RstSeq === 5'b11111);
        #200000;
        forever begin
            inp(8'hC4);              // poll de status del ISR
            outp(8'hC4, 8'h04);      // select reg 4
            outp(8'hC5, 8'h80);      // ack
            inp(8'hC4);              // re-lectura tras ack
            #870000;                 // ~885us total
        end
    end
end

// ---- _113b: ARRANQUE DE MBWAVE 1.17 (+mbwave=1) — reproduce el CUELGUE.
// Del desensamblado de MBWAVE.COM: toda escritura/lectura wave gira en
// "IN A,(C4); RRA; JR c" = espera BUSY=0 SIN timeout (rutinas 32EB/32FE).
// El init (2B6E): 24 canales x { read 68+ch -> AND 7F -> write (keyoff),
// read 68+ch -> SET5 (LFORST!) -> write, write 80+ch (LFO/VIB!), write
// E0+ch (AM) } + volumen F9 read-modify-write. VGMPlay NUNCA lee regs
// wave ni escribe LFO directo: por eso solo MBWave muere. Si BUSY se
// queda a 1, el poll gira para siempre = el cuelgue total de la placa.
integer MBW = 0, mbch, mbpoll, mbhang;
task mb_poll_busy;   // el spin exacto de 32EB/32FE (con lectura C4 real:
begin                // cada IN C4 ademas limpia LD2 en el motor, como el HW)
    mbpoll = 0;
    inp(8'hC4);
    while (wave_status[0] && mbpoll < 3000) begin
        inp(8'hC4);
        mbpoll = mbpoll + 1;
    end
    if (mbpoll >= 3000) begin
        mbhang = 1;
        $display("*** CUELGUE REPRODUCIDO: BUSY clavado a 1 (canal %0d) ***", mbch);
    end
end
endtask
task mb_wr(input [7:0] r, input [7:0] v);   // 32EB
begin mb_poll_busy; outp(8'h7E, r); mb_poll_busy; outp(8'h7F, v); end
endtask
task mb_rd(input [7:0] r);                  // 32FE
begin mb_poll_busy; outp(8'h7E, r); mb_poll_busy; inp(8'h7F); end
endtask
initial begin
    if (!$value$plusargs("mbwave=%d", MBW)) MBW = 0;
    if (MBW) begin
        mbhang = 0;
        wait (umem.RstSeq === 5'b11111);
        #100000;                     // barrido de reset del motor
        mb_wr(8'h02, 8'h10);         // modo (2AE1)
        mb_rd(8'hF9);                // volumen: readback F9 (2CDB)
        mb_poll_busy;
        outp(8'h7F, 8'h00);          // write F9 directo (reg ya selecc., 2CEC)
        for (mbch = 0; mbch < 24 && !mbhang; mbch = mbch + 1) begin
            mb_rd(8'h68 + mbch[7:0]);                    // 2FC7: read
            mb_wr(8'h68 + mbch[7:0], rdv & 8'h7F);       //   keyoff
            mb_rd(8'h68 + mbch[7:0]);                    // 3147: read
            mb_wr(8'h68 + mbch[7:0], rdv | 8'h20);       //   SET LFORST
            mb_wr(8'h80 + mbch[7:0], 8'h07);             //   LFO/VIB a tope
            mb_wr(8'hE0 + mbch[7:0], 8'h07);             //   AM a tope
        end
        if (!mbhang) begin
            // veredicto: el motor debe seguir VIVO (BUSY limpiable) tras todo
            mb_wr(8'h02, 8'h10);
            $display("MBWAVE INIT: COMPLETO SIN CUELGUE (BUSY siempre bajo a 0)");
        end
        // ---- FASE 2: el note-on del replayer (overlay .004 +02E4): escribe
        // 0x38 (oct), 0x20 (fnum/WTN8), 0x08 (ONDA -> arranca carga de
        // cabecera, LD=1) y GIRA en "IN C4; BIT 1; JR nz" hasta LD==0.
        // SIN timeout: si la carga no termina, cuelgue total. 24 canales
        // seguidos (ondas de piano 300-306 y vecinas, como el kit real).
        for (mbch = 0; mbch < 24 && !mbhang; mbch = mbch + 1) begin
            mb_wr(8'h38 + mbch[7:0], 8'h10);                    // oct=1
            mb_wr(8'h20 + mbch[7:0], 8'h01);                    // fnum=0, WTN8=1
            mb_wr(8'h08 + mbch[7:0], 8'h2C + mbch[7:0]);        // ondas 300..
            mbpoll = 0;
            inp(8'hC4);                                          // spin LD (+0313)
            while (wave_status[1] && mbpoll < 3000) begin
                inp(8'hC4);
                mbpoll = mbpoll + 1;
            end
            if (mbpoll >= 3000) begin
                mbhang = 1;
                $display("*** CUELGUE REPRODUCIDO: LD clavado a 1 (canal %0d) ***", mbch);
            end
        end
        if (!mbhang)
            $display("MBWAVE NOTE-ON x24: COMPLETO SIN CUELGUE (LD siempre baja)");
        #2000000;
        $finish;
    end
end

// ---- _112: tormenta de RETRIGGERS (+retrig=1): cada ~1.2ms re-dispara
// la cabecera de un slot rotatorio (como percusion rapida / sonyc):
// cada note-on carga 12 bytes = 6 palabras — el patron que trituraba
// la ventana de 4 palabras en placa (telemetria seq 183-194).
integer RETRIG = 0, rslot = 0;
initial begin
    if (!$value$plusargs("retrig=%d", RETRIG)) RETRIG = 0;
    if (RETRIG) begin
        wait (umem.RstSeq === 5'b11111);
        #900000;
        forever begin
            wreg(8'h68 + rslot[7:0], 8'h00);              // key off
            wreg(8'h08 + rslot[7:0], 8'd44 + rslot[7:0]); // re-dispara header
            wreg(8'h68 + rslot[7:0], 8'h80);              // key on
            rslot = (rslot + 1) % NSLOTS;
            #1200000;
        end
    end
end

// ---- trafico Z80 de fondo (realista: 1 acceso cada ~0.4-0.9us) ----
integer CPUON = 0;
reg [7:0] cpu_rd;
task cpu_op(input wr, input [22:0] ca, input [7:0] wd);
begin
    @(negedge clk_host);
    ram_addr = ca; ram_din = wd; ram_write = wr; ram_req = 1;
    @(posedge ram_busy); @(negedge ram_busy);
    @(negedge clk_host);
    cpu_rd = ram_dout; ram_req = 0;
    @(negedge clk_host);
end
endtask
initial begin
    if (!$value$plusargs("cpu=%d", CPUON)) CPUON = 0;
    if (CPUON) begin
        wait (umem.RstSeq === 5'b11111);
        #70000;
        forever begin
            cpu_op({$random}%4 == 0, {$random}&23'h3FFFFF, {$random});
            #(400 + {$random}%500);
        end
    end
end

// ---- telemetria: latencia de fetch vista por el motor ----
real t_req, lat, lat_sum = 0, lat_max = 0;
integer lat_n = 0;
reg pend = 0, done_seen = 0;
always @(posedge clk_eng) begin
    if (mem_req) begin t_req = $realtime; pend <= 1; done_seen <= mem_done_t; end
    else if (pend && (mem_done_t !== done_seen)) begin
        lat = $realtime - t_req;
        lat_sum = lat_sum + lat;
        if (lat > lat_max) lat_max = lat;
        lat_n = lat_n + 1;
        pend <= 0;
    end
end

// ---- _107 debug: contadores de cache y traza de accesos ----
integer c_rd=0, c_hit=0, c_pf=0, tr_n=0;
integer ftr;
initial ftr=$fopen("trace_addr.txt","w");
always @(posedge clk_eng) begin
    if (dut.rd_edge) begin
        c_rd = c_rd + 1;
        if (tr_n < 600) begin
            // era v3: replica del hit real (BSRAM lb_mem, particion por slot)
            $fdisplay(ftr, "%0t R %h %b", $time, dut.e_addr22,
                      dut.lb_v[{dut.e_slot,dut.e_addr22[3:1]}] &&
                      (dut.lb_mem[{dut.e_slot,dut.e_addr22[3:1]}][33:16] == dut.e_addr22[21:4]));
            tr_n = tr_n + 1;
        end
    end
    if (dut.lb_fast) c_hit = c_hit + 1;
    if (dut.mem_req && dut.op_is_pf) c_pf = c_pf + 1;
end

// ---- _110 debug: FIFO del reclock — repeticiones, descartes, nivel ----
integer u_rep=0, p_drop=0, pfr=0;
integer lvl, lvl_min=99, lvl_max=-1;
reg t_x_d=0; reg [3:0] rp_d=0; reg [9:0] pdiv_d=0;
integer flvl; initial flvl=$fopen("fifo_level.txt","w");
always @(posedge clk_eng) begin
    t_x_d <= dut.pcm_t_x;
    rp_d  <= dut.rf_rp;
    pdiv_d<= dut.pdiv;
    if (dut.pcm_t_x !== t_x_d && dut.rf_rp === rp_d) u_rep = u_rep + 1;  // tick sin pull = repeticion
    if (pdiv_d == 10'd767 && dut.pdiv == 10'd0) pfr = pfr + 1;           // frame del productor
    lvl = (dut.rf_wp - dut.rf_rp) & 4'hF;
    if (ticks > 400) begin
        if (lvl < lvl_min) lvl_min = lvl;
        if (lvl > lvl_max) lvl_max = lvl;
    end
    if (dut.pcm_t_x !== t_x_d) $fdisplay(flvl, "%0d", lvl);
end

// ---- _111: receptor de la telemetria UART (valida tramas en sim) ----
defparam dut.DBG_FRAME_CYC = 32'd200000;   // trama cada ~5.3ms en sim
integer fdbg; initial fdbg=$fopen("dbg_bytes.txt","w");
reg [7:0] rxb; integer rxi;
initial begin
    forever begin
        @(negedge dut.dbg_tx);              // start
        repeat (489) @(posedge clk_eng);    // 1.5 bits (326*1.5)
        rxb = 0;
        for (rxi = 0; rxi < 8; rxi = rxi + 1) begin
            rxb[rxi] = dut.dbg_tx;
            repeat (326) @(posedge clk_eng);
        end
        $fdisplay(fdbg, "%02x", rxb);
    end
end

// ---- pushes del productor (la medida REAL del pitch) ----
integer pushes = 0, pushes0 = 0;
reg [3:0] rf_wp_d = 0;
always @(posedge clk_eng) begin
    rf_wp_d <= dut.rf_wp;
    if (dut.rf_wp !== rf_wp_d) pushes = pushes + 1;
end

// ---- medida del periodo de salida (ticks de muestra del reclock) ----
integer NSLOTS = 7, NSAMP = 1500;
integer fd, ticks = 0;
real t_start = 0, t_end = 0, per;
reg pcm_seen = 0;
real lat_sum0; integer lat_n0;
always @(posedge clk_host) begin
    pcm_seen <= dut.pcm_h3;
    if (dut.pcm_h3 !== pcm_seen) begin
        ticks = ticks + 1;
        if (ticks == 500) begin
            t_start = $realtime; lat_sum0 = lat_sum; lat_n0 = lat_n;
            pushes0 = pushes;
        end
        if (ticks >= 500 && ticks < 500 + NSAMP) $fdisplay(fd, "%0d", pcm_l);
        if (ticks == 500 + NSAMP) begin
            t_end = $realtime;
            per = (t_end - t_start) / NSAMP;
            $display("== RESULTADO %0d slots ==", NSLOTS);
            $display("periodo medio: %.4f us (ideal 22.6757; +%.2f%% = %.1f cents FLAT)",
                     per/1000.0, (per/22675.7-1.0)*100.0,
                     1731.2*(per/22675.7-1.0));   // ~1200/ln2*ln(x)≈1731*(x-1)
            $display("fetches en ventana: %0d (%.2f/muestra), lat media %.0f ns, max %.0f ns",
                     lat_n-lat_n0, (lat_n-lat_n0)*1.0/NSAMP,
                     (lat_sum-lat_sum0)/((lat_n-lat_n0)>0?(lat_n-lat_n0):1), lat_max);
            $display("carga de stall aprox: %.1f%% (margen CE 10.7%%)",
                     (lat_sum-lat_sum0)/(t_end-t_start)*100.0);
            $display("CACHE: reads=%0d hits=%0d (%.1f%%) pf_emitidos=%0d",
                     c_rd, c_hit, c_hit*100.0/(c_rd>0?c_rd:1), c_pf);
            $display("FIFO: repeticiones=%0d drops=%0d(frames %0d - pushes) nivel=[%0d..%0d]",
                     u_rep, pfr-pushes, pfr, lvl_min, lvl_max);
            $display("PRODUCTOR: %0d pushes / %0d ticks -> ratio %.5f = %.1f cents",
                     pushes-pushes0, NSAMP,
                     (pushes-pushes0)*1.0/NSAMP,
                     1731.2*((pushes-pushes0)*1.0/NSAMP-1.0));
            $finish;
        end
    end
end

// ---- test de SUBIDA a escala (+upload=N): streaming estilo VGMPlay/OTIR ----
integer UPLOAD = 0, uperr, ui;
reg [23:0] uidx;
task do_upload;
begin
    outp(8'h7E, 8'h02); outp(8'h7F, 8'h11);      // memmode=1, wavetblhdr=4
    outp(8'h7E, 8'h03); outp(8'h7F, 8'h20);      // MEMADDR = 0x200000
    outp(8'h7E, 8'h04); outp(8'h7F, 8'h00);
    outp(8'h7E, 8'h05); outp(8'h7F, 8'h00);
    outp(8'h7E, 8'h06);                          // selecciona reg 6 UNA vez
    for (ui = 0; ui < UPLOAD; ui = ui + 1)
        outp(8'h7F, (ui*7) & 8'hFF);             // stream tipo OTIR (~6us/byte)
    outp(8'h7E, 8'h02); outp(8'h7F, 8'h10);      // memmode off
    #20000;
    uperr = 0;
    for (ui = 0; ui < UPLOAD; ui = ui + 1) begin
        // mapeo wave de memory.v: index={A[11:10],100,A[21:12],A[9:1]}, lane=A[0]
        uidx = {ui[11:10]+2'b10, 3'b100, 10'h200 + ui[21:12], ui[9:1]};
        uidx = {(22'h200000+ui) >> 10 & 24'h3, 3'b100, (22'h200000+ui) >> 12 & 24'h3FF, (22'h200000+ui) >> 1 & 24'h1FF};
        if ((ui[0] ? sdram.mem[{ui[11:10], 3'b100, (10'h200 + ui[21:12]), ui[9:1]}][15:8]
                   : sdram.mem[{ui[11:10], 3'b100, (10'h200 + ui[21:12]), ui[9:1]}][7:0])
            !== ((ui*7) & 8'hFF)) begin
            if (uperr < 10)
                $display("  MAL byte %0d: mem=%02x esperado=%02x", ui,
                    ui[0] ? sdram.mem[{ui[11:10],3'b100,(10'h200+ui[21:12]),ui[9:1]}][15:8]
                          : sdram.mem[{ui[11:10],3'b100,(10'h200+ui[21:12]),ui[9:1]}][7:0],
                    (ui*7)&8'hFF);
            uperr = uperr + 1;
        end
    end
    $display("UPLOAD %0d bytes: %0d errores %s", UPLOAD, uperr, uperr==0 ? "*** LIMPIO ***" : "*** CORRUPTO ***");
    $finish;
end
endtask

integer i;
initial begin
    if (!$value$plusargs("nslots=%d", NSLOTS)) NSLOTS = 7;
    if (!$value$plusargs("nsamp=%d", NSAMP)) NSAMP = 1500;
    fd = $fopen("s7_dump.txt", "w");
    #500  rst_n = 1;
    wait (umem.RstSeq === 5'b11111);
    #2000;
    eng_rst_n = 1;
    #60000;                                   // barrido de reset del motor
    outp(8'hC6, 8'h05);
    outp(8'hC7, 8'h03);                       // NEW/NEW2
    if ($value$plusargs("upload=%d", UPLOAD)) do_upload;
    for (i = 0; i < NSLOTS; i = i + 1) begin
        // ondas DISTINTAS por slot (300+i) y fnum disperso: streams
        // independientes = el caso real de un tracker a polifonia alta
        wreg(8'h20 + i[7:0], (((i*89) % 128) << 1) | 8'h01);  // fnum bajo + WTN8
        wreg(8'h38 + i[7:0], 8'h10 | ((i%3)==0 ? 8'h00 : 8'h01)); // oct1, fn alto var
        wreg(8'h50 + i[7:0], 8'h01);          // TL=0, LD
        wreg(8'h08 + i[7:0], (8'd44 + i[7:0]));  // header: onda 300+i (0x12C+i)
        inp(8'hC4); inp(8'h7E);
        while (rdv[1]) begin #10000; inp(8'hC4); inp(8'h7E); end
    end
    $display("== %0d headers cargados ==", NSLOTS);
    for (i = 0; i < NSLOTS; i = i + 1)
        wreg(8'h68 + i[7:0], 8'h80);          // KEY on
    $display("== KEY on x%0d, midiendo... ==", NSLOTS);
end

initial begin
    #200000000;
    $display("TIMEOUT (ticks=%0d)", ticks);
    $finish;
end

endmodule
