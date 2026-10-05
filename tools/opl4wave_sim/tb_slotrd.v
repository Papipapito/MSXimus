// ============================================================================
// tb_slotrd.v — RELECTURA DE REGISTROS DE SLOT POR 7Fh, A LA PRIMERA.
//
// POR QUE EXISTE: tb_regrd.sv guarda el readback del motor a solas y espera
// 120 clk antes de mirar DO; el pegamento opl4_pcm.v captura al 6o CE. Con
// esa captura, el motor de la era v3 devolvia en la PRIMERA lectura de un
// registro de slot el valor del registro leido antes ("una lectura por
// detras"), incluso respetando /WAIT. El chip real devuelve lo escrito
// (openMSX YMF278::readReg: default -> regs[reg]).
//
// QUE HACE (opl4_pcm + motor, bus de Z80 que respeta /WAIT, DDR3 falsa):
//  A. La secuencia del banco de placa de MoonTANG (RB_TEST=1): 12 valores en
//     50h..5Bh, una lectura de cada uno; despues cada uno leido dos veces.
//  B. Los nueve grupos de slot sin carga de cabecera (20h FNUM bajo, 38h FNUM
//     alto, 50h LEVEL, 68h PAN, 80h LFO, 98h/B0h/C8h RATE, E0h AM) x 24 slots,
//     UNA lectura por registro, en orden creciente y mezclando grupos, con la
//     fase del acceso barrida (retardo pseudoaleatorio con semilla).
//  C. WTN (08h..1Fh): dispara la carga de cabecera, que reescribe LFO/RATE/AM
//     con los bytes 7..11 de la cabecera; se relee todo contra ese modelo.
//  D. Lo mismo con el MOTOR SONANDO (6 slots con KEY ON: fetches a la DDR3 y
//     CE congelada en los fallos de cache).
//  E. Registros que no son de slot (02h, 03h..05h, F8h, F9h): no deben cambiar.
//
// SONDAS (dentro del motor): por cada lectura se anota k = cuantos CE pasan
// desde el flanco de RD hasta la CYCLE1 que borra REG_RD, y si hubo algun clk
// SIN CE entre T0 y T2. La tabla del final dice en que fases falla.
// Tambien mide cuanto dura /WAIT en cada IN 7Fh.
//
// Ejecutar: cd tools/opl4wave_sim && ./run_slotrd.sh   (+seed=N +pases=N +verb=1)
// +solo_b=1 se queda en las fases A y B (todos los registros con valores
// distintos): es la tabla limpia para ver en que fases falla un motor roto.
// ============================================================================
`timescale 1ns/1ps

module tb_slotrd;

// medio periodo de clk_eng: 13.333 = 37,5 MHz (60K y Zynq); el 138K va a 36 MHz
// (-Ptb_slotrd.ENG_HALF=13.889, lo pone su run_slotrd.sh)
parameter real ENG_HALF = 13.333;

reg clk_x1 = 0;
always #6.734 clk_x1 = ~clk_x1;        // 74.25 MHz (FSM de la memoria falsa)
reg clk_eng = 0;
always #(ENG_HALF) clk_eng = ~clk_eng; // motor
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

// ---- puerto de memoria falso (como tb_opl4pcm) ----
wire        mem_req, mem_we;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata;
reg  [7:0]  mem_rdata = 0;
reg  [15:0] mem_rword = 0;
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
    .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_rword(mem_rword), .mem_done_t(mem_done_t),
    .vid_diag(4'd0)
);

reg [7:0] wavemem [0:4194303];
reg        p_pend = 0, p_we;
reg [21:0] p_addr;
reg [7:0]  p_dat;
reg [5:0]  p_cnt, p_lat;
reg        mem_req_d = 0;
integer    n_fetch = 0;
always @(posedge clk_x1) begin
    mem_req_d <= mem_req;
    if (mem_req && !mem_req_d) begin
        p_pend <= 1; p_we <= mem_we; p_addr <= mem_addr; p_dat <= mem_wdata;
        p_cnt <= 0; p_lat <= 6'd20 + ({$random} % 5);
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == p_lat) begin
            if (p_we) wavemem[p_addr] <= p_dat;
            else begin
                mem_rdata <= wavemem[p_addr];
                mem_rword[7:0]  <= wavemem[{p_addr[21:1], 1'b0}];
                mem_rword[15:8] <= wavemem[{p_addr[21:1], 1'b1}];
                n_fetch = n_fetch + 1;
            end
            mem_done_t <= ~mem_done_t;
            p_pend <= 0;
        end
    end
end

// ---- plusargs ----
integer seed, PASES, VERB, SOLO_B;

// ---- tareas de Z80 (las de tb_opl4pcm) ----
real    t_rd;                 // instante en que el Z80 baja RD
reg     in7f = 0;
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
    t_rd = $realtime; in7f = (p == 8'h7F);
    #460;
    while (!wave_wait_n) @(posedge clk_host);   // el Z80 respeta /WAIT
    // El Z80 muestrea /WAIT en la bajada de TW y el dato en la de T3, un T
    // despues (186 ns a 5,37 MHz); aqui medio T. No vale mirar el dato en el
    // mismo instante: opl4_pcm suelta /WAIT un clk_host ANTES de presentarlo
    // (rd_served sale de rdd_h2 y rd_data_h de rdd_h3).
    #93;
    rdv = wave_dout;
    @(negedge clk_host); rd_n = 1; iorq_n = 1;
    in7f = 0;
    #1500;
end
endtask

// retardo pseudoaleatorio: barre la fase del acceso frente a la CYCLE1 del motor
task jitter;
    integer j;
begin
    j = {$random(seed)} % 700;
    #(j);
end
endtask

// ---- modelo: lo que debe devolver cada registro ----
reg [7:0] shadow [0:255];

task wreg(input [7:0] r, input [7:0] v);
begin
    outp(8'h7E, r); outp(8'h7F, v);
    shadow[r] = v;
end
endtask

// escritura de WTN: la carga de cabecera reescribe LFO, RATE0/1/2 y AM del slot
task wwtn(input integer s, input [7:0] v);
    integer h;
begin
    wreg(8'h08 + s, v);
    h = {shadow[8'h20 + s][0], v} * 12;
    shadow[8'h80 + s] = wavemem[h + 7];
    shadow[8'h98 + s] = wavemem[h + 8];
    shadow[8'hB0 + s] = wavemem[h + 9];
    shadow[8'hC8 + s] = wavemem[h + 10];
    shadow[8'hE0 + s] = wavemem[h + 11];
end
endtask

task espera_ld;
    integer n;
begin
    n = 0;
    inp(8'hC4); inp(8'h7E);
    while (rdv[1] && n < 400) begin #10000; inp(8'hC4); inp(8'h7E); n = n + 1; end
    if (rdv[1]) begin $display("FAIL: LD no se limpia"); errores = errores + 1; end
end
endtask

// ---- grupos ----
// 0: 08h WTN   1: 20h FNUM bajo  2: 38h FNUM alto  3: 50h LEVEL  4: 68h PAN
// 5: 80h LFO   6: 98h RATE0      7: B0h RATE1      8: C8h RATE2  9: E0h AM
// 10: el resto
function integer grp(input [7:0] r);
begin
    if      (r >= 8'h08 && r <= 8'h1F) grp = 0;
    else if (r >= 8'h20 && r <= 8'h37) grp = 1;
    else if (r >= 8'h38 && r <= 8'h4F) grp = 2;
    else if (r >= 8'h50 && r <= 8'h67) grp = 3;
    else if (r >= 8'h68 && r <= 8'h7F) grp = 4;
    else if (r >= 8'h80 && r <= 8'h97) grp = 5;
    else if (r >= 8'h98 && r <= 8'hAF) grp = 6;
    else if (r >= 8'hB0 && r <= 8'hC7) grp = 7;
    else if (r >= 8'hC8 && r <= 8'hDF) grp = 8;
    else if (r >= 8'hE0 && r <= 8'hF7) grp = 9;
    else grp = 10;
end
endfunction
function [7:0] gbase(input integer g);
begin
    case (g)
    0: gbase = 8'h08; 1: gbase = 8'h20; 2: gbase = 8'h38; 3: gbase = 8'h50;
    4: gbase = 8'h68; 5: gbase = 8'h80; 6: gbase = 8'h98; 7: gbase = 8'hB0;
    8: gbase = 8'hC8; default: gbase = 8'hE0;
    endcase
end
endfunction
// clase: 0 = BSRAM unica rt_mem (WTN, LEVEL, PAN, RATE, AM)
//        1 = RAM de registros (FNUM, LFO)        2 = el resto
function integer cls(input integer g);
begin
    if (g == 10) cls = 2;
    else if (g == 1 || g == 2 || g == 5) cls = 1;
    else cls = 0;
end
endfunction

// ---- sonda de causa raiz (dominio del motor) ----
// T0 = flanco de CE en que el motor ve bajar RD (REG_RD <= 1).
//   p_k  = n.o de CE desde T0 hasta la CYCLE1 que borra REG_RD (1..8)
//   p_t1 = clk en que cae el 1er CE tras T0; p_t2 = clk del 2o (carga de REG_Q)
reg     p_regrd_d = 0, p_act = 0;
integer p_nce = 0, p_nclk = 0, p_t1 = 0, p_t2 = 0, p_k = 0;
integer n_stall = 0;
always @(posedge clk_eng) begin
    p_regrd_d <= dut.u_engine.REG_RD;
    if (dut.stall) n_stall = n_stall + 1;
    if (dut.u_engine.REG_RD && !p_regrd_d) begin
        p_nce = 0; p_nclk = 0; p_t1 = 0; p_t2 = 0; p_k = 0; p_act = 1;
    end
    if (p_act) begin
        p_nclk = p_nclk + 1;
        if (dut.ce) begin
            p_nce = p_nce + 1;
            if (p_nce == 1) p_t1 = p_nclk;
            if (p_nce == 2) p_t2 = p_nclk;
            if (dut.u_engine.CYCLE1_CE && p_k == 0) p_k = p_nce;
        end
        if (p_k != 0 && p_nce >= 12) p_act = 0;
    end
end

// ---- medida de /WAIT en IN 7Fh ----
real    w_min = 1e9, w_max = 0, w_sum = 0, w;
integer w_n = 0, n_timeout = 0;
always @(posedge wave_wait_n) if (in7f) begin
    w = $realtime - t_rd;
    if (w < w_min) w_min = w;
    if (w > w_max) w_max = w;
    w_sum = w_sum + w; w_n = w_n + 1;
    if (dut.wto[10]) n_timeout = n_timeout + 1;
end

// ---- contabilidad ----
integer errores = 0;
integer g_n [0:10], g_bad [0:10], g_atras [0:10];
integer h_tot [0:63], h_bad [0:63];       // [clase(0/1)*32 + k*2 + hueco]
reg [7:0] ult_cls [0:2];                  // contenido del ultimo registro leido de cada clase
integer fase_bad;

task rchk(input [7:0] r);                 // UNA lectura de r, contra el modelo
    integer g, c, hu, ix;
    reg [7:0] e;
begin
    outp(8'h7E, r); jitter; inp(8'h7F);
    e = shadow[r];
    g = grp(r); c = cls(g);
    hu = (c == 1) ? ((p_t2 - p_t1) > 1) : (p_t2 > 2);
    ix = (c == 1 ? 32 : 0) + p_k * 2 + hu;
    g_n[g] = g_n[g] + 1;
    if (c != 2) h_tot[ix] = h_tot[ix] + 1;
    if (rdv !== e) begin
        errores = errores + 1; fase_bad = fase_bad + 1;
        g_bad[g] = g_bad[g] + 1;
        if (c != 2) h_bad[ix] = h_bad[ix] + 1;
        if (rdv === ult_cls[c]) g_atras[g] = g_atras[g] + 1;
        if (VERB) $display("    reg %02x: escrito %02x, leido %02x  (k=%0d hueco=%0d, /WAIT %0.0f ns)%0s",
                           r, e, rdv, p_k, hu, w, (rdv === ult_cls[c]) ? "  = el leido antes" : "");
    end
    ult_cls[c] = e;
end
endtask

function [7:0] pat(input [7:0] r, input integer sal);
begin
    pat = r * 8'd37 + sal * 101 + 8'h11;
    if (grp(r) == 4) pat = pat & 8'h7F;   // PAN: sin KEY ON
end
endfunction

// barrido de lectura unica: creciente por grupo y luego mezclando grupos
task barrido(input integer con_wtn);
    integer g, s, p;
begin
    for (p = 0; p < PASES; p = p + 1) begin
        for (g = (con_wtn ? 0 : 1); g < 10; g = g + 1)
            for (s = 0; s < 24; s = s + 1) rchk(gbase(g) + s);
        for (s = 0; s < 24; s = s + 1)
            for (g = (con_wtn ? 0 : 1); g < 10; g = g + 1) rchk(gbase(g) + ((s * 7 + p) % 24));
    end
end
endtask

integer i, s, g, k, malas, n_stall0, n_fetch0;
reg [7:0] e8;
initial begin
    if (!$value$plusargs("seed=%d", seed))   seed  = 1;
    if (!$value$plusargs("pases=%d", PASES)) PASES = 3;
    if (!$value$plusargs("verb=%d", VERB))   VERB  = 0;
    if (!$value$plusargs("solo_b=%d", SOLO_B)) SOLO_B = 0;
    for (i = 0; i <= 10; i = i + 1) begin g_n[i] = 0; g_bad[i] = 0; g_atras[i] = 0; end
    for (i = 0; i < 64; i = i + 1) begin h_tot[i] = 0; h_bad[i] = 0; end
    for (i = 0; i < 256; i = i + 1) shadow[i] = 8'h00;
    ult_cls[0] = 8'h00; ult_cls[1] = 8'h00; ult_cls[2] = 8'h00;

    // onda 0: cabecera en 0, cuadrada de 64 muestras en 0x100 (como tb_opl4pcm)
    for (i = 0; i < 4194304; i = i + 1) wavemem[i] = 8'h00;
    wavemem[1] = 8'h01; wavemem[5] = 8'hFF; wavemem[6] = 8'hC0;
    wavemem[8] = 8'hF0; wavemem[10] = 8'hFF;
    for (i = 0; i < 32; i = i + 1)  wavemem[22'h100 + i] = 8'h7F;
    for (i = 32; i < 64; i = i + 1) wavemem[22'h100 + i] = 8'h81;

    #500  rst_n = 1;
    #1000 eng_rst_n = 1;
    #100000;                              // limpieza interna de los 24 slots

    outp(8'hC6, 8'h05);
    outp(8'hC7, 8'h03);
    outp(8'h7E, 8'h02); inp(8'h7F);
    if (rdv !== 8'h20) begin $display("FAIL: reg 02h = %02x (esperado 20)", rdv); errores = errores + 1; end

    // ---------------------------------------------------------------- A
    $display("== A. la secuencia del banco de placa de MoonTANG (50h..5Bh) ==");
    for (i = 0; i < 12; i = i + 1) wreg(8'h50 + i, 8'h13 + 8'h14 * i);
    malas = 0;
    for (i = 0; i < 12; i = i + 1) begin
        outp(8'h7E, 8'h50 + i); inp(8'h7F);
        e8 = 8'h13 + 8'h14 * i;
        if (rdv !== e8) malas = malas + 1;
        $display("    registro %02x: escrito %02x, leido %02x %0s", 8'h50 + i, e8, rdv,
                 (rdv === e8) ? "" : "<-- distinto");
    end
    $display("  una lectura por registro: %0d de 12 distintas de lo escrito", malas);
    errores = errores + malas;
    malas = 0;
    for (i = 0; i < 12; i = i + 1) begin
        outp(8'h7E, 8'h50 + i); inp(8'h7F); inp(8'h7F);
        if (rdv !== (8'h13 + 8'h14 * i)) malas = malas + 1;
    end
    $display("  cada registro leido dos veces seguidas: %0d de 12 distintas", malas);
    errores = errores + malas;

    // ---------------------------------------------------------------- B
    $display("== B. nueve grupos x 24 slots, una lectura, motor en reposo ==");
    for (g = 1; g < 10; g = g + 1)
        for (s = 0; s < 24; s = s + 1) wreg(gbase(g) + s, pat(gbase(g) + s, 0));
    fase_bad = 0; n_stall0 = n_stall;
    barrido(0);
    $display("  %0d lecturas distintas de lo escrito (CE congelada %0d clk)", fase_bad, n_stall - n_stall0);

    if (!SOLO_B) begin
    // ---------------------------------------------------------------- C
    $display("== C. WTN (carga de cabecera) y relectura de todo ==");
    for (s = 0; s < 24; s = s + 1) begin
        wreg(8'h20 + s, pat(8'h20 + s, 1) & 8'hFE);     // WTN[8] = 0
        wwtn(s, 8'h01 + s);
        espera_ld;
    end
    fase_bad = 0;
    barrido(1);
    $display("  %0d lecturas distintas de lo esperado", fase_bad);

    // ---------------------------------------------------------------- D
    $display("== D. con el motor sonando (6 slots con KEY ON) ==");
    for (s = 0; s < 24; s = s + 1) begin
        if (s < 6) begin
            wreg(8'h20 + s, (s * 8'd32) & 8'hFE);       // F-num bajo, WTN[8] = 0
            wreg(8'h38 + s, 8'h10 + s);                 // octava 1
            wreg(8'h50 + s, (s << 1) | 8'h01);          // TL = s, LD directo
            wwtn(s, 8'h00);                             // onda 0: carga la cabecera
            espera_ld;
            wreg(8'h68 + s, 8'h80 + s);                 // KEY ON
        end
        else
            for (g = 1; g < 10; g = g + 1) wreg(gbase(g) + s, pat(gbase(g) + s, 2));
    end
    #200000;
    fase_bad = 0; n_stall0 = n_stall; n_fetch0 = n_fetch;
    barrido(1);
    $display("  %0d lecturas distintas de lo esperado (CE congelada %0d clk, %0d fetches)",
             fase_bad, n_stall - n_stall0, n_fetch - n_fetch0);
    if (n_stall == n_stall0) begin
        $display("FAIL: la fase D no congelo la CE ni una vez (no ejercita el stall)");
        errores = errores + 1;
    end
    for (s = 0; s < 6; s = s + 1) wreg(8'h68 + s, 8'h40 + s);   // KEY OFF + damp

    // ---------------------------------------------------------------- E
    $display("== E. registros que no son de slot ==");
    wreg(8'h03, 8'h2A); wreg(8'h04, 8'h5C);
    wreg(8'hF8, 8'h1B); wreg(8'hF9, 8'h24);
    shadow[8'h02] = 8'h20;
    fase_bad = 0;
    for (i = 0; i < 6; i = i + 1) begin
        rchk(8'hF8); rchk(8'h03); rchk(8'h02); rchk(8'hF9); rchk(8'h04);
        rchk(8'h50 + i); rchk(8'h38 + i);
    end
    $display("  %0d lecturas distintas de lo esperado", fase_bad);
    end

    // ---------------------------------------------------------------- resumen
    $display("== lecturas unicas por grupo (fases B, C, D y E) ==");
    $display("  grupo        lecturas  distintas  (= el registro leido antes)");
    for (g = 0; g <= 10; g = g + 1)
        $display("  %0s  %6d  %8d  %8d",
                 g == 0 ? "08h WTN   " : g == 1 ? "20h FNUM-L" : g == 2 ? "38h FNUM-H" :
                 g == 3 ? "50h LEVEL " : g == 4 ? "68h PAN   " : g == 5 ? "80h LFO   " :
                 g == 6 ? "98h RATE0 " : g == 7 ? "B0h RATE1 " : g == 8 ? "C8h RATE2 " :
                 g == 9 ? "E0h AM    " : "resto     ", g_n[g], g_bad[g], g_atras[g]);
    $display("== por fase: k = CE desde el flanco de RD hasta la CYCLE1 que borra REG_RD ==");
    $display("  BSRAM rt_mem (WTN, LEVEL, PAN, RATE, AM); hueco = algun clk sin CE entre T0 y T2");
    for (k = 1; k <= 8; k = k + 1)
        $display("    k=%0d   sin hueco: %4d distintas de %4d     con hueco: %4d de %4d",
                 k, h_bad[k*2], h_tot[k*2], h_bad[k*2+1], h_tot[k*2+1]);
    $display("  RAM de registros (FNUM, LFO); hueco = algun clk sin CE entre T1 y T2");
    for (k = 1; k <= 8; k = k + 1)
        $display("    k=%0d   sin hueco: %4d distintas de %4d     con hueco: %4d de %4d",
                 k, h_bad[32+k*2], h_tot[32+k*2], h_bad[32+k*2+1], h_tot[32+k*2+1]);
    $display("== /WAIT en IN 7Fh (desde que el Z80 baja RD hasta que se suelta) ==");
    $display("  %0d lecturas: min %0.0f ns, media %0.0f ns, max %0.0f ns; %0d por timeout",
             w_n, w_min, w_sum / w_n, w_max, n_timeout);
    if (n_timeout != 0) begin $display("FAIL: /WAIT soltado por timeout"); errores = errores + 1; end

    if (errores == 0) $display("*** TODOS LOS TESTS PASAN ***");
    else              $display("*** %0d ERRORES ***", errores);
    $finish;
end

initial begin
    #400000000;
    $display("FAIL: timeout global");
    $finish;
end

endmodule
