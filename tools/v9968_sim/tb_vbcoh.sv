// ============================================================================
// tb_vbcoh.sv — BANCO DE COHERENCIA del victim buffer (_150).
//
// No renderiza nada: ataca el shim DIRECTAMENTE con trafico adversario de
// lecturas y escrituras sobre un POOL de direcciones construido para COLISIONAR
// en el indice de 13 bits de la sc-cache (la forma exacta del choque SPT/SAT del
// DEVCON), y comprueba UNA sola propiedad, la que importa:
//
//   *** TODO dato servido por el camino de FASE FIJA (pipe[6]) tiene que ser
//       EXACTAMENTE el contenido de la VRAM en el instante en que se pidio ***
//
// Un victim buffer que sirva rancio (o que no se invalide con una escritura)
// muere aqui. Se mira pipe[6] POR JERARQUIA con una tuberia espejo de 7 etapas
// alineada por construccion: tp[0] vale en T+1 (= spr_p1) ... tp[6] vale en T+7
// (= pipe[6]). Asi no hay ambiguedad con las respuestas TARDIAS (late_v), que
// salen por el mismo bus pero NO por la tuberia.
//
// Tags de SPRITE (3'd2) y CPU (3'd3): ninguno pasa por la ventana de prefetch,
// asi que no hay "degradacion elegante" (servir rancio A PROPOSITO) que pueda
// enmascarar un fallo real.
//
// El MISMO TB compila contra el shim BASE y contra el shim con VB.
// Uso: iverilog -g2012 -o x -s tb_vbcoh tb_vbcoh.sv <shim>.v && vvp x +iters=N
// ============================================================================
`timescale 1ns/1ps
module tb_vbcoh;

localparam [21:0] VBASE = 22'h280000;

logic clk = 0;
always #5.82 clk = ~clk;              // 85.909 MHz
logic reset_n = 0;

logic [17:2] vram_address = 0;
logic        vram_write   = 0;
logic        vram_valid   = 0;
logic [31:0] vram_wdata   = 0;
logic [3:0]  vram_wdata_mask = 4'hF;   // DQM: 1 = NO escribir
logic [4:0]  vram_tag     = 0;
wire  [31:0] vram_rdata;
wire         vram_rdata_en;
wire  [4:0]  vram_rtag;
wire         vram_stall;

wire        bk_req, bk_we;
wire [21:0] bk_addr;
wire [31:0] bk_wdata;
wire [3:0]  bk_wmask;
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire        bk2_req;
wire [21:0] bk2_addr;
logic [15:0] bk2_rword = 0;
logic        bk2_done_t = 0;

v9968_vram_shim #(.VRAM_BASE(VBASE)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag()
);

// ---- modelo de SDRAM/backend (identico al de tb_screen1) ----
logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
integer vi;
initial for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
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

// ============================================================================
// POOL con COLISION DE INDICE. c_idx13(v)={v[12], v[11:0]^{v[14],11'b0}},
// tag=v[15:12]  =>  A=0x2000+j (tag 2) y B=0x4000+(j^0x800) (tag 4) caen en el
// MISMO idx13={0,j}. Es la forma exacta del choque SPT/SAT del DEVCON.
// ============================================================================
localparam NP = 12;
localparam NPOOL = NP*2;
logic [15:0] pool [0:NPOOL-1];
integer pi_;
initial begin
    for (pi_ = 0; pi_ < NP; pi_ = pi_ + 1) begin
        pool[pi_*2  ] = 16'h2000 +  (pi_[15:0]*16'd7);
        pool[pi_*2+1] = 16'h4000 + ((pi_[15:0]*16'd7) ^ 16'h0800);
    end
end

// ============================================================================
// ESPEJO DORADO + TUBERIA ESPEJO, TODO en el MISMO always: cero carreras entre
// el commit de una escritura y el muestreo de una lectura (son mutuamente
// excluyentes: un solo vram_valid).
// tp[k] vale en T+1+k  =>  tp[6] vale en T+7 = el ciclo de pipe[6].
// ============================================================================
logic [31:0] gold [0:65535];
integer gi;
initial for (gi = 0; gi < 65536; gi = gi + 1) gold[gi] = 32'd0;

logic        tp_v [0:7];
logic [15:0] tp_a [0:7];
logic [31:0] tp_e [0:7];
logic [4:0]  tp_t [0:7];
logic [1:0]  tp_s [0:7];               // ORIGEN: 1 = etapa 1 (ventana/sc-cache)
                                       //         2 = etapa 2 (VICTIM BUFFER)
logic        tp_p [0:7];               // lo sirvio la TUBERIA (no una tardia)
integer k;
initial for (k = 0; k < 8; k = k + 1) begin tp_v[k]=0; tp_a[k]=0; tp_e[k]=0; tp_t[k]=0; tp_s[k]=0; tp_p[k]=0; end

integer n_rd = 0, n_wr = 0, n_serv = 0, n_bad = 0, n_tagbad = 0;
integer n_s1 = 0, n_s2 = 0, n_bad1 = 0, n_bad2 = 0;

// ---- SONDA DE LA CAUSA RAIZ (bug PRE-EXISTENTE de la sc-cache, nada que ver
// con el victim buffer): si un FILL escribe las BSRAM en el MISMO flanco en que
// se acepta una ESCRITURA, el scq_* que vera el write-check en T+1 es la foto
// ANTERIOR al fill => el write-through-update se salta (o se aplica al indice
// equivocado) y la linea queda RANCIA. Se cuentan las coincidencias.
function [12:0] c_idx13_tb(input [15:0] v);
    c_idx13_tb = { v[12], v[11:0] ^ {v[14], 11'b0} };
endfunction
integer n_hz = 0, n_hz_idx = 0, n_fill = 0;
always @(posedge clk) begin
    if (u_shim.fill_now) n_fill <= n_fill + 1;
    if (u_shim.fill_now && vram_valid && vram_write) begin
        n_hz <= n_hz + 1;
        if (c_idx13_tb(u_shim.fill_addr) == c_idx13_tb(vram_address))
            n_hz_idx <= n_hz_idx + 1;
    end
end

always @(posedge clk) begin
    for (k = 7; k > 0; k = k - 1) begin
        tp_v[k] <= tp_v[k-1]; tp_a[k] <= tp_a[k-1];
        tp_e[k] <= tp_e[k-1]; tp_t[k] <= tp_t[k-1]; tp_s[k] <= tp_s[k-1];
        tp_p[k] <= tp_p[k-1];
    end
    tp_p[7] <= u_shim.pipe[6][37];      // en T+7 la tuberia va a emitir
    // ORIGEN del servicio: en T+2 pipe[1] ya lleva el resultado de la etapa 1 y
    // (si existe) vb_p2/vb_hit2 llevan el de la etapa 2. tp_v[1] vale en T+2.
    if (tp_v[1]) begin
`ifdef HAS_VB
        tp_s[2] <= u_shim.pipe[1][37] ? 2'd1 :
                   (u_shim.vb_p2 && u_shim.vb_hit2) ? 2'd2 : 2'd0;
`else
        tp_s[2] <= u_shim.pipe[1][37] ? 2'd1 : 2'd0;
`endif
    end
    tp_v[0] <= 1'b0;
    if (vram_valid) begin
        if (vram_write) begin
            // commit al dorado en el MISMO flanco en que el shim ve la escritura
            n_wr <= n_wr + 1;
            if (!vram_wdata_mask[0]) gold[vram_address][ 7: 0] <= vram_wdata[ 7: 0];
            if (!vram_wdata_mask[1]) gold[vram_address][15: 8] <= vram_wdata[15: 8];
            if (!vram_wdata_mask[2]) gold[vram_address][23:16] <= vram_wdata[23:16];
            if (!vram_wdata_mask[3]) gold[vram_address][31:24] <= vram_wdata[31:24];
        end
        else begin
            n_rd    <= n_rd + 1;
            tp_v[0] <= 1'b1;
            tp_a[0] <= vram_address;
            tp_e[0] <= gold[vram_address];
            tp_t[0] <= vram_tag;
        end
    end
    // ---- COMPROBACION ----
    if (reset_n && tp_v[6] && u_shim.pipe[6][37]) begin
        n_serv <= n_serv + 1;
        if (tp_s[6] == 2'd1) n_s1 <= n_s1 + 1;
        if (tp_s[6] == 2'd2) n_s2 <= n_s2 + 1;
        if (u_shim.pipe[6][31:0] !== tp_e[6]) begin
            n_bad <= n_bad + 1;
            if (tp_s[6] == 2'd1) n_bad1 <= n_bad1 + 1;
            if (tp_s[6] == 2'd2) n_bad2 <= n_bad2 + 1;
            if (n_bad < 20)
                $display("*** RANCIO t=%0t addr=%04x sirvio=%08x esperado=%08x tag=%02x ORIGEN=%0d",
                         $time, tp_a[6], u_shim.pipe[6][31:0], tp_e[6], tp_t[6], tp_s[6]);
        end
        if (u_shim.pipe[6][36:32] !== tp_t[6]) begin
            n_tagbad <= n_tagbad + 1;
            if (n_tagbad < 10)
                $display("*** TAG MAL t=%0t got=%02x exp=%02x", $time,
                         u_shim.pipe[6][36:32], tp_t[6]);
        end
    end
    // ---- CONTRATO DE 8 CICLOS medido EN EL PUERTO DE SALIDA (no en pipe[6]):
    // 8 flancos exactos desde vram_valid, con el dato y el tag correctos. Es la
    // prueba de que servir desde la ETAPA 2 (victim buffer) no mueve la fase.
    if (reset_n && tp_v[7] && tp_p[7]) begin
        n_out <= n_out + 1;
        if (tp_s[7] == 2'd2) n_out2 <= n_out2 + 1;
        if (!vram_rdata_en || vram_rdata !== tp_e[7] || vram_rtag !== tp_t[7]) begin
            n_outbad <= n_outbad + 1;
            if (n_outbad < 20)
                $display("*** SALIDA MAL t=%0t addr=%04x en=%b rdata=%08x exp=%08x rtag=%02x exp=%02x ORIGEN=%0d",
                         $time, tp_a[7], vram_rdata_en, vram_rdata, tp_e[7],
                         vram_rtag, tp_t[7], tp_s[7]);
        end
    end
end
integer n_out = 0, n_out2 = 0, n_outbad = 0;

// ============================================================================
// TRAZA por direccion (+trace=<hex de la palabra>): imprime TODO lo que toca esa
// direccion o su indice de sc-cache. Para diseccionar un rancio concreto.
// ============================================================================
integer TRA; logic [15:0] TRW;
initial begin
    if (!$value$plusargs("trace=%h", TRA)) TRA = -1;
    TRW = TRA[15:0];
end
always @(posedge clk) begin
  if (TRA >= 0 && reset_n) begin
    if (vram_valid && vram_address == TRW)
        $display("T %0t  BUS %s addr=%04x wdata=%08x dqm=%b tag=%02x",
                 $time, vram_write?"WR":"RD", vram_address, vram_wdata, vram_wdata_mask, vram_tag);
    if (u_shim.wrk_p1 && u_shim.wrk_addr1 == TRW)
        $display("T %0t  WCHK addr=%04x scq_v=%b scq_tag=%x exp_tag=%x wrk_hit=%b data=%08x mask=%b",
                 $time, u_shim.wrk_addr1, u_shim.scq_v, u_shim.scq_tag,
                 u_shim.wrk_addr1[15:12], u_shim.wrk_hit, u_shim.wrk_data1, u_shim.wrk_mask1);
    if (u_shim.fill_now && c_idx13_tb(u_shim.fill_addr) == c_idx13_tb(TRW))
        $display("T %0t  FILL addr=%04x word=%08x (MISMO INDICE que %04x)",
                 $time, u_shim.fill_addr, u_shim.fill_word, TRW);
    if (u_shim.spr_p1 && u_shim.spr_addr1 == TRW)
        $display("T %0t  LOOK addr=%04x scq_v=%b scq_tag=%x exp=%x scdata=%02x%02x%02x%02x",
                 $time, u_shim.spr_addr1, u_shim.scq_v, u_shim.scq_tag,
                 u_shim.spr_addr1[15:12], u_shim.scq_d3, u_shim.scq_d2, u_shim.scq_d1, u_shim.scq_d0);
`ifdef HAS_VB
    if (u_shim.fill_now && u_shim.fill_addr == TRW)
        $display("T %0t  VBINS slot=%0d addr=%04x word=%08x", $time, u_shim.vb_rr, u_shim.fill_addr, u_shim.fill_word);
    if (u_shim.wrk_p1 && (|u_shim.vb_im) && u_shim.wrk_addr1 == TRW)
        $display("T %0t  VBINV mask=%b addr=%04x", $time, u_shim.vb_im, u_shim.wrk_addr1);
    if (u_shim.vb_p2 && u_shim.vb_addr2 == TRW)
        $display("T %0t  VBLK  addr=%04x hit=%b dat=%08x", $time, u_shim.vb_addr2, u_shim.vb_hit2, u_shim.vb_dat2);
`endif
    if (u_shim.bk_req && u_shim.bk_we &&
        u_shim.bk_addr == (VBASE + {4'd0, TRW, 2'b00}))
        $display("T %0t  BKWR addr=%06x data=%08x mask=%b", $time, u_shim.bk_addr, u_shim.bk_wdata, u_shim.bk_wmask);
  end
end

// ============================================================================
// GENERADOR
// ============================================================================
task issue(input [17:2] a, input wr, input [31:0] d, input [3:0] dqm, input [4:0] tg);
begin
    @(posedge clk);
    vram_address <= a; vram_write <= wr; vram_valid <= 1'b1;
    vram_wdata <= d; vram_wdata_mask <= dqm; vram_tag <= tg;
    @(posedge clk);
    vram_valid <= 1'b0;
end
endtask

integer it, gap, r;
logic [15:0] a;
logic [3:0]  dqm;
integer NITER, NOWR, SEED, sd;
integer dummy;
initial begin
    if (!$value$plusargs("iters=%d", NITER)) NITER = 40000;
    if (!$value$plusargs("seed=%d", SEED))  SEED  = 0;
    NOWR = $test$plusargs("nowr");         // +nowr = SOLO lecturas
    for (sd = 0; sd < SEED; sd = sd + 1) dummy = $random;   // desfasa la secuencia
    repeat (40) @(posedge clk);
    reset_n = 1;
    repeat (9000) @(posedge clk);          // barrido de limpieza de sc_v (8192)

    for (it = 0; it < NITER; it = it + 1) begin
        gap = 8 + ({$random} % 12);        // contrato: vram_valid >= 8 ciclos
        repeat (gap) @(posedge clk);
        // respetar el control de flujo: sin esto wq desborda, el shim PIERDE
        // escrituras y el dorado divergiria por culpa del TB, no del DUT
        while (vram_stall) @(posedge clk);

        r = {$random} % 100;
        if (NOWR && r < 30) r = 30 + (r % 70);   // +nowr: sin escrituras
        if (r < 25) begin                  // escritura sobre el pool
            a   = pool[{$random} % NPOOL];
            dqm = {$random} % 15;          // 0..14: al menos un byte vivo
            issue(a, 1'b1, {$random}, dqm, 5'd0);
        end
        else if (r < 30) begin             // escritura de ruido (fills ajenos)
            a = {$random} % 16'hFFFF;
            issue(a, 1'b1, {$random}, 4'b0000, 5'd0);
        end
        else if (r < 85) begin             // lectura de SPRITE sobre el pool
            a = pool[{$random} % NPOOL];
            issue(a, 1'b0, 32'd0, 4'hF, {3'd2, 2'b00});
        end
        else if (r < 95) begin             // lectura de CPU sobre el pool
            a = pool[{$random} % NPOOL];
            issue(a, 1'b0, 32'd0, 4'hF, {3'd3, 2'b00});
        end
        else begin                         // lectura de ruido
            a = {$random} % 16'hFFFF;
            issue(a, 1'b0, 32'd0, 4'hF, {3'd2, 2'b00});
        end

        if (it % 10000 == 0)
            $display("PROG it=%0d rd=%0d wr=%0d servidos=%0d RANCIOS=%0d tagmal=%0d",
                     it, n_rd, n_wr, n_serv, n_bad, n_tagbad);
    end

    repeat (500) @(posedge clk);
    $display("--------------------------------------------------------------");
    $display("VBCOH FIN | lecturas=%0d escrituras=%0d | servidos_por_tuberia=%0d (%0d%% de las lecturas)",
             n_rd, n_wr, n_serv, (n_rd>0)? (n_serv*100)/n_rd : 0);
    $display("VBCOH ORIGEN | etapa1(ventana/sc-cache)=%0d (rancios=%0d)  etapa2(VICTIM BUFFER)=%0d (rancios=%0d)",
             n_s1, n_bad1, n_s2, n_bad2);
    $display("VBCOH SONDA  | fills=%0d  fill_vs_escritura=%0d  con_MISMO_indice=%0d",
             n_fill, n_hz, n_hz_idx);
    $display("VBCOH 8CICLOS| respuestas en el PUERTO a 8 flancos=%0d (de ellas por VICTIM BUFFER=%0d) fallos=%0d",
             n_out, n_out2, n_outbad);
    if (n_bad == 0 && n_tagbad == 0 && n_outbad == 0)
        $display("*** VBCOH: COHERENCIA OK (0 rancios en %0d servicios de fase fija, 0 fallos de contrato en %0d respuestas) ***", n_serv, n_out);
    else
        $display("*** VBCOH: FALLO — %0d RANCIOS, %0d tags malos, %0d fallos de contrato ***", n_bad, n_tagbad, n_outbad);
    $finish;
end

initial begin
    #4000000000;
    $display("VBCOH TIMEOUT rd=%0d wr=%0d servidos=%0d RANCIOS=%0d", n_rd, n_wr, n_serv, n_bad);
    $finish;
end

endmodule
