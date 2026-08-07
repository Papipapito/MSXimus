// ============================================================================
// opl4_pcm.v — pegamento del motor PCM/wavetable OPL4 (MSXimus _89)
//
// Une el YMF278B.sv de srg320 (24 slots PCM, fpga/opl4wave/) con el bus MSX
// y la DDR3 (wave_ddr3.v). Complementa a opl4fm.v (que lleva el FM OPL3):
// juntos son el MoonSound completo.
//
// ARQUITECTURA DE RELOJ (la clave de todo):
//  - El motor corre en clk_eng = clk_x1/2 = 37.125MHz (a 74.25MHz la cadena
//    de envolvente del YMF278B necesita ~19ns y el periodo es 13.5 — medido
//    en el primer build; a 37.125 tiene 27ns). CE FRACCIONARIO acumulador
//    6272/6875 = 33.8688MHz EXACTOS de media (la tecnica del turbo WSX)
//    -> fs = 44.1kHz exactos.
//  - El motor muestrea el dato de onda UNA ventana CYCLE1 (8 CE ~236ns)
//    despues de pedirlo, SIN señal de espera, y la DDR3 puede tardar mas.
//    Solucion: STALL del CE en el DEADLINE (el 7o CE tras el issue), no en
//    el issue — el fetch se solapa con la ejecucion y solo se congela el
//    exceso. El acumulador sigue acumulando credito durante el stall y
//    recupera en rafaga -> la fs MEDIA no se mueve (jitter sub-muestra,
//    inaudible). clk_eng es GENERADO de clk_x1: los cruces con la FSM DDR3
//    son paths sincronos normales, no CDC.
//
// BUS MSX -> MOTOR (CDC por toggles, como el resto del proyecto):
//  - Se le reenvian TODAS las escrituras OPL4 (C4-C7 y 7E/7F): el motor
//    rastrea NEW2 internamente viendo pasar las escrituras FM del bank1
//    (A=2 con 0x05 y A=3 con bit1). El FM real lo sigue llevando opl4fm.
//  - Las escrituras wave (A=5) se consumen en la siguiente CYCLE1_CE del
//    motor: la FSM de bus espacia peticiones 12 CE para no pisar REG_WR.
//  - Lecturas 7F: handshake disparado al INICIO del ciclo IN del Z80; el
//    resultado (~300-400ns) llega antes del muestreo del Z80 (~700ns a
//    3.58MHz). 7E devuelve el status {LD,BUSY} (como el chip real).
//  - Lecturas de status C4/C6 se reenvian como lectura A=0: el chip real
//    limpia LD2 en esa lectura (si no, LD se queda pegado y el software
//    que espera "LD=0" tras el init se cuelga).
// ============================================================================

module opl4_pcm (
    // ---- lado MSX (clk_host = clk_54m) ----
    input  wire        rst_n,          // bus_reset_n
    input  wire        clk_host,
    input  wire        iorq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    input  wire        m1_n,
    input  wire [7:0]  addr,
    input  wire [7:0]  din,

    output wire        wave_rd,        // lectura 7Eh/7Fh en curso (para el mux)
    output wire [7:0]  wave_dout,      // dato 7Eh/7Fh
    output wire        wave_wait_n,    // /WAIT al Z80 durante IN 7Fh (ver abajo)
    output wire [1:0]  wave_status,    // {LD,BUSY} sync a host (OR en status C4)
    output reg [5:0]  mix_fm,          // _110: F8 sincronizado a host
    output reg signed [15:0] pcm_l,    // OUT1 del motor, registrado en host
    output reg signed [15:0] pcm_r,

    // ---- dominio del motor (clk_eng = clk_x1/2 de la DDR3) ----
    input  wire        clk_eng,
    input  wire        eng_rst_n,      // calibrada + loader YRW801 done + reset

    // puerto de memoria hacia wave_ddr3 (su FSM va a clk_x1; relojes
    // relacionados /2 -> paths sincronos, la vuelta es un toggle)
    output reg         mem_req,        // pulso 1 ciclo clk_eng
    output reg         mem_we,
    output reg  [21:0] mem_addr,
    output reg  [7:0]  mem_wdata,
    input  wire [7:0]  mem_rdata,      // registrado en el shim, estable
    input  wire [15:0] mem_rword,      // _104: PALABRA entera (cache de palabra)
    input  wire        mem_done_t,     // TOGGLE = completada

    // ---- telemetria (_95): {ifw_hits[3:0], alive[3:0]} ----
    // alive avanza con cada CE del motor: dos lecturas seguidas con el
    // nibble bajo distinto = el dominio del motor esta VIVO. Muestreado en
    // crudo desde clk_host (diagnostico humano, el tearing da igual).
    output wire [7:0]  diag,
    output reg         dbg_tx,         // _111: telemetria UART TX (E22)
    input  wire [3:0]  vid_diag        // _114diag: estado del video (crudo, se
                                        // cruza a clk_eng aqui). {pll27_lock,
                                        // frame_cnt[2:0]} — lo mete en la trama.
);

// ===========================================================================
// LADO HOST: decodificacion + strobes + latches de peticion
// _91: bus REGISTRADO antes del decode (el T80 lanza en el flanco de bajada
// de clk_54m y aqui se consume en el de subida: el decode directo era un
// path de MEDIO ciclo que dependia de la loteria de placement; con el bus
// registrado hay ciclo entero y el retardo de 18.5ns es irrelevante frente
// al ciclo I/O del Z80).
// ===========================================================================
reg        iorq_r, rd_r, wr_r, m1_r;
reg [7:0]  addr_r, din_r;
always @(posedge clk_host) begin
    iorq_r <= iorq_n; rd_r <= rd_n; wr_r <= wr_n; m1_r <= m1_n;
    addr_r <= addr;   din_r <= din;
end

wire cs_fm = (iorq_r == 1'b0) && (m1_r == 1'b1) && (addr_r[7:2] == 6'b110001);
wire cs_wv = (iorq_r == 1'b0) && (m1_r == 1'b1) && (addr_r[7:1] == 7'b0111111);

assign wave_rd = cs_wv && (rd_r == 1'b0);

// mapeo puerto MSX -> pin A[2:0] del YMF278B:
//   C4->0 C5->1 C6->2 C7->3 (FM)   7E->4 7F->5 (wave)
wire [2:0] a3 = addr_r[7] ? {1'b0, addr_r[1:0]} : {2'b10, addr_r[0]};

wire wr_act = (cs_fm | cs_wv) && (wr_r == 1'b0);
wire rd_dat = cs_wv && (rd_r == 1'b0) && addr_r[0];          // IN 7Fh (dato)
wire rd_st  = cs_fm && (rd_r == 1'b0) && (addr_r[0] == 1'b0); // IN C4/C6 (status)

reg wr_act_d, rd_dat_d, rd_st_d;
reg        wr_t, rd_t, st_t;        // toggles de peticion (host -> x1)
reg [2:0]  req_a3;                  // direccion de la peticion (cuasi-estatica)
reg [7:0]  req_dat;

always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        wr_act_d <= 1'b0; rd_dat_d <= 1'b0; rd_st_d <= 1'b0;
        wr_t <= 1'b0; rd_t <= 1'b0; st_t <= 1'b0;
        req_a3 <= 3'd0; req_dat <= 8'd0;
    end
    else begin
        wr_act_d <= wr_act;
        rd_dat_d <= rd_dat;
        rd_st_d  <= rd_st;
        if (wr_act && !wr_act_d) begin
            req_a3  <= a3;
            req_dat <= din_r;
            wr_t    <= ~wr_t;
        end
        else if (rd_dat && !rd_dat_d)
            rd_t <= ~rd_t;          // lectura 7F: siempre A=5
        if (rd_st && !rd_st_d)
            st_t <= ~st_t;          // status C4/C6: lectura A=0 (limpia LD2)
    end
end

// vuelta: dato de lectura + status + PCM (todos cuasi-estaticos tras toggle)
// _91: los cruces host<->motor estan declarados ASINCRONOS en el .sdc
// (correcto para los 2FF), pero eso significa que el router NO vigila el
// retardo de los PAYLOADS (req_a3/req_dat/rd_data_x/pcm): si el payload
// llega mas tarde que el toggle sincronizado, se consume corrupto. Con
// place2 colaba de chiripa; con place1 el motor "desaparecio" (0000 en la
// deteccion). Fix: consumir el toggle UNA ETAPA MAS TARDE en ambos
// sentidos -> el payload gana ~2 ciclos extra de asentamiento y el
// funcionamiento deja de depender de la loteria de rutado.
reg rdd_h1, rdd_h2, rdd_h3, rdd_ack;   // toggle "lectura completada"
reg [7:0] rd_data_h;
reg pcm_h1, pcm_h2, pcm_h3, pcm_ack;
reg st_b1, st_b2, ld_b1, ld_b2;     // bits de status (nivel, 2FF)

// (señales del dominio x1 declaradas abajo)
reg        rd_done_t;               // x1: flip al completar lectura 7F
reg [7:0]  rd_data_x;
reg        pcm_t_x;                 // x1: flip a cada muestra nueva
reg signed [15:0] pcm_l_x, pcm_r_x; // x1: OUT1 retenido
reg [5:0] mixfm_s0, mixfm_s1;       // _110: F8 motor->host (cuasi-estatico)
always @(posedge clk_host) begin
    mixfm_s0 <= eng_mixfm;
    mixfm_s1 <= mixfm_s0;
end
reg        busy_x, ld_x;            // x1: status muestreado con bus en reposo

always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        rdd_h1 <= 1'b0; rdd_h2 <= 1'b0; rdd_h3 <= 1'b0; rdd_ack <= 1'b0; rd_data_h <= 8'd0;
        pcm_h1 <= 1'b0; pcm_h2 <= 1'b0; pcm_h3 <= 1'b0; pcm_ack <= 1'b0;
        pcm_l <= 16'sd0; pcm_r <= 16'sd0;
        st_b1 <= 1'b0; st_b2 <= 1'b0; ld_b1 <= 1'b0; ld_b2 <= 1'b0;
    end
    else begin
        rdd_h1 <= rd_done_t;  rdd_h2 <= rdd_h1;  rdd_h3 <= rdd_h2;
        if (rdd_h3 != rdd_ack) begin
            rdd_ack   <= rdd_h3;
            rd_data_h <= rd_data_x;   // estable: cambio hace >=3 ciclos host
        end
        pcm_h1 <= pcm_t_x;  pcm_h2 <= pcm_h1;  pcm_h3 <= pcm_h2;
        if (pcm_h3 != pcm_ack) begin
            pcm_ack <= pcm_h3;
            pcm_l   <= pcm_l_x;
            mix_fm  <= mixfm_s1;    // _110: cuasi-estatico, 2FF
            pcm_r   <= pcm_r_x;
        end
        st_b1 <= busy_x;  st_b2 <= st_b1;
        ld_b1 <= ld_x;    ld_b2 <= ld_b1;
    end
end

assign wave_status = {ld_b2, st_b2};
// 7E = status (como el chip: todo A!=5 lee status); 7F = ultimo dato leido
assign wave_dout = addr_r[0] ? rd_data_h : {6'b000000, ld_b2, st_b2};

// /WAIT durante IN 7Fh: el round-trip al motor son ~300-600ns (la lectura de
// reg6 dispara su propio fetch DDR3, que congela el CE del motor un rato) y
// un Z80 en turbo 5.37MHz muestrea a ~460ns -> loteria de fase. El WAIT
// estira el ciclo IN hasta tener el dato fresco (es el patron wait_uart del
// ESP). TIMEOUT de ~19us por si el motor esta en reset (DDR3 recalibrando):
// dato rancio pero el MSX no se cuelga.
reg        rd_served;
reg [10:0] wto;
always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        rd_served <= 1'b0;
        wto <= 11'd0;
    end
    else if (!rd_dat) begin
        rd_served <= 1'b0;
        wto <= 11'd0;
    end
    else begin
        if ((rdd_h2 != rdd_ack) || wto[10]) rd_served <= 1'b1;
        if (!rd_served) wto <= wto + 11'd1;
    end
end
assign wave_wait_n = ~(rd_dat & ~rd_served);

// ===========================================================================
// DOMINIO x1: CE fraccionario con stall + FSM de bus + puerto de memoria
// ===========================================================================

// liberacion de reset SINCRONA en clk_eng (asercion asincrona OK; soltar
// asincrono seria un riesgo de recovery en todo el dominio del motor)
reg [1:0] ers;
always @(posedge clk_eng or negedge eng_rst_n) begin
    if (!eng_rst_n) ers <= 2'b00;
    else            ers <= {ers[0], 1'b1};
end
wire erst_n = ers[1];

// --- sync de toggles host -> x1 ---
reg wr_s1, wr_s2, wr_s3, wr_ackx;
reg rd_s1, rd_s2, rd_s3, rd_ackx;
reg st_s1, st_s2, st_s3, st_ackx;
always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        wr_s1 <= 1'b0; wr_s2 <= 1'b0; wr_s3 <= 1'b0;
        rd_s1 <= 1'b0; rd_s2 <= 1'b0; rd_s3 <= 1'b0;
        st_s1 <= 1'b0; st_s2 <= 1'b0; st_s3 <= 1'b0;
    end
    else begin
        wr_s1 <= wr_t; wr_s2 <= wr_s1; wr_s3 <= wr_s2;
        rd_s1 <= rd_t; rd_s2 <= rd_s1; rd_s3 <= rd_s2;
        st_s1 <= st_t; st_s2 <= st_s1; st_s3 <= st_s2;
    end
end

// --- CE fraccionario 33.8688/37.5 = 14112/15625 exacto (_104: CLKOUT4) ---
// Durante un stall el acumulador SIGUE sumando (credito) y al soltar
// dispara CEs seguidos hasta recuperar: la fs media queda clavada.
// 24 bits = ~36us de credito acumulable (un fetch DDR3 son ~0.3us).
localparam [23:0] CE_INC = 24'd14112;
localparam [23:0] CE_MOD = 24'd15625;
reg [23:0] ce_acc;
reg        ce;
reg        mem_inflight;

// STALL EN EL DEADLINE, no en el issue: el motor pide el dato en MEM_START
// y lo muestrea/consume en la SIGUIENTE CYCLE1_CE. Se congela EXACTAMENTE
// esa CE (y solo esa) mientras el fetch DDR3 este en vuelo: el fetch se
// solapa con la ejecucion y el stall es solo el exceso de latencia.
// CYCLE1_NEXT viene DEL MOTOR (su divisor avanza con los mismos CE que
// esta decision lee -> alineacion exacta; contar CEs desde fuera iba
// siempre un ciclo por detras y el muestreo se colaba con dato rancio).
wire       e_cycle1_next;
wire       stall = mem_inflight && e_cycle1_next;

always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        ce_acc <= 24'd0;
        ce     <= 1'b0;
    end
    else begin
        ce <= 1'b0;
        if (!stall && (ce_acc + CE_INC >= CE_MOD)) begin
            ce_acc <= ce_acc + CE_INC - CE_MOD;
            ce     <= 1'b1;
        end
        else
            ce_acc <= ce_acc + CE_INC;
    end
end

// --- FSM de bus del motor (una peticion a la vez, espaciado 12 CE) ---
// El motor muestrea WR_N/RD_N bajo CE (flanco detectado): sostener 2 CE
// garantiza la deteccion; tras una escritura wave, esperar el resto de la
// ventana (REG_WR se consume en la siguiente CYCLE1_CE, <=8 CE).
localparam BF_IDLE = 3'd0, BF_WLOW = 3'd1, BF_WGAP = 3'd2,
           BF_RLOW = 3'd3, BF_RWAIT = 3'd4, BF_RLATCH = 3'd5;
reg [2:0] bf;
reg [3:0] bf_cnt;               // contador de pulsos CE
reg       bf_is_st;             // lectura de status (descartar dato)

reg       e_cs_n, e_wr_n, e_rd_n;
reg [2:0] e_a;
reg [7:0] e_di;
wire [7:0] e_do;

always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        wr_ackx <= 1'b0; rd_ackx <= 1'b0; st_ackx <= 1'b0;
        bf <= BF_IDLE; bf_cnt <= 4'd0; bf_is_st <= 1'b0;
        e_cs_n <= 1'b1; e_wr_n <= 1'b1; e_rd_n <= 1'b1;
        e_a <= 3'd0; e_di <= 8'd0;
        rd_done_t <= 1'b0; rd_data_x <= 8'd0;
        busy_x <= 1'b0; ld_x <= 1'b0;
    end
    else begin
        case (bf)
        BF_IDLE: begin
            e_cs_n <= 1'b1; e_wr_n <= 1'b1; e_rd_n <= 1'b1;
            e_a <= 3'd0;    // bus en reposo: DO = status del motor
            busy_x <= e_do[0];
            ld_x   <= e_do[1];
            bf_cnt <= 4'd0;
            if (wr_s3 != wr_ackx) begin
                wr_ackx <= wr_s3;
                e_a  <= req_a3;     // cuasi-estatico (toggle hace >=2 ciclos)
                e_di <= req_dat;
                e_cs_n <= 1'b0; e_wr_n <= 1'b0;
                bf <= BF_WLOW;
            end
            else if (rd_s3 != rd_ackx) begin
                rd_ackx <= rd_s3;
                e_a <= 3'd5;  bf_is_st <= 1'b0;
                e_cs_n <= 1'b0; e_rd_n <= 1'b0;
                bf <= BF_RLOW;
            end
            else if (st_s3 != st_ackx) begin
                st_ackx <= st_s3;
                e_a <= 3'd0;  bf_is_st <= 1'b1;
                e_cs_n <= 1'b0; e_rd_n <= 1'b0;
                bf <= BF_RLOW;
            end
        end
        BF_WLOW:                       // WR_N bajo durante 2 CE
            if (ce) begin
                bf_cnt <= bf_cnt + 4'd1;
                if (bf_cnt == 4'd1) begin
                    e_wr_n <= 1'b1; e_cs_n <= 1'b1;
                    bf_cnt <= 4'd0;
                    bf <= BF_WGAP;
                end
            end
        BF_WGAP:                       // hueco 12 CE (consumo de REG_WR)
            if (ce) begin
                bf_cnt <= bf_cnt + 4'd1;
                if (bf_cnt == 4'd11) bf <= BF_IDLE;
            end
        BF_RLOW:                       // RD_N bajo durante 2 CE
            if (ce) begin
                bf_cnt <= bf_cnt + 4'd1;
                if (bf_cnt == 4'd1) begin
                    e_rd_n <= 1'b1; e_cs_n <= 1'b1;   // A se mantiene
                    bf_cnt <= 4'd0;
                    bf <= BF_RWAIT;
                end
            end
        BF_RWAIT:                      // REG_Q valido ~3 CE tras el flanco
            if (ce) begin
                bf_cnt <= bf_cnt + 4'd1;
                if (bf_cnt == 4'd3) bf <= BF_RLATCH;
            end
        BF_RLATCH: begin
            if (!bf_is_st) begin
                rd_data_x <= e_do;     // A sigue en 5: DO = REG_Q
                rd_done_t <= ~rd_done_t;
            end
            bf <= BF_IDLE;
        end
        default: bf <= BF_IDLE;
        endcase
    end
end

// --- puerto de memoria: flanco de MRD/MWR -> peticion a wave_ddr3 ---
// _94: CACHE DE LINEA EN ESTE DOMINIO (clk_eng). La _92/_93 la tenian dentro
// de wave_ddr3 sirviendo hits a traves del cruce 37/74 y en la placa las
// escrituras del motor se perdian (la sim del sandwich exonero la logica:
// era fisica del cruce). Ahora wave_ddr3 vuelve al puerto PROBADO de la _91
// y la cache vive aqui: los hits alimentan MDI sin salir del dominio y sin
// transaccion DDR3 (el motor hace 4 fetches/slot/muestra que caen casi
// siempre en la misma linea de 16B: sin cache iba un 20% lento con 7 slots).
wire [20:0] e_ma;
wire [7:0]  e_mdo;
wire        e_mrd_n, e_mwr_n;
wire [9:0]  e_mcs_n;
// MA solo saca 21 bits; el bit21 (RAM de muestras en 0x200000+) viaja en
// los chip-selects: MCS_N[1]=0 <=> MEM_A[21]=1
wire [21:0] e_addr22 = {~e_mcs_n[1], e_ma};

// _107: cache de 64 PALABRAS + PREFETCH ENCADENADO (OBL etiquetado).
// La cache de 16 de la _105 se valido con 7 slots, pero el software real
// la desborda (Bombaman 22 slots, MoonDriver 16-24): 22 streams > 16
// entradas = thrash => 34 fetches/muestra, 48% de stalls => productor a
// 850/1200 = -505 cents = las "demos leeeentas" (tb_sandwich7 +nslots=22).
// El tamano solo NO basta: un stream toca cada palabra UNA vez (miss frio
// inevitable). La solucion es ESCONDER la latencia: cada miss trae su
// palabra Y ENCARGA la siguiente (bit pf de la entrada); cada hit sobre
// una entrada prefeteada encarga la proxima => los streams secuenciales
// van siempre servidos y la CE solo se congela en arranques de nota/loop.
// El prefetch usa el puerto en los huecos (op_is_pf, sin congelar la CE);
// un miss que llegue con prefetch en vuelo espera su turno (eng_pend,
// acotado por UNA op). pf_want es de 1 plaza (mejor esfuerzo): si dos
// hits lo pisan, el stream perdedor hara miss y su OBL lo recupera.
// _107c: PARTICIONADA POR SLOT — 32 slots x 4 palabras (indice
// {MEM_SLOT, addr[2:1]}). Los intentos compartidos (16/64/256 entradas
// direct-mapped) se ahogaban por DESALOJO CRUZADO: 22 streams x 3
// palabras calientes se pisan entre si (64 entradas: 62% hits; 256: 81%
// — nunca llega). Particionando, cada slot tiene sus 4 palabras
// (actual, vecina de interpolacion, +2 del prefetch) SIN colisiones
// por construccion: el hit rate ya no depende de la polifonia.
// _112: ventana de 8 PALABRAS por slot (antes 4) + PREFETCH POR STRIDE.
// La telemetria en placa (Bombaman seq 183-194) cazo tormentas de ~6
// misses/muestra correladas con la "vibracion": cada NOTE-ON carga una
// cabecera de 12 bytes = 6 palabras que NO CABIAN en la ventana de 4
// (la nota se trituraba su propia cache), y las notas agudas (paso >=2)
// dejaban atras el lookahead fijo de +2. Con 8 palabras caben cabecera
// y stream, y el stride por slot predice el salto real.
// ERA v3 (sin SSRAM): {tagA, word} viven en UNA BSRAM SDPB 256x34 con
// lectura SINCRONA. Gowin retiro el SSRAM del GW5AT-60B por un problema de
// silicio (soporte, 03/08/2026). lb_q corresponde a la direccion del ciclo
// ANTERIOR; como el motor registra MEM_A y MEM_RD en el MISMO flanco de CE
// y MRD_N dura >=2 CE, e_slot/e_addr22 son estables durante todo el lookup
// => la resolucion del hit se desplaza 1 ciclo (rd_edge_d1). El deadline del
// motor (CYCLE1_CE, >=4 CE tras MEM_START) tiene holgura de sobra: el hit
// sigue soltando la CE antes de que nadie la espere.
// Colision fill/lookup al mismo indice y flanco: SDPB lee el dato VIEJO =>
// tag rancio => miss => fetch redundante (correcto, solo mas lento; raro).
(* syn_ramstyle = "block_ram" *) reg [33:0] lb_mem [0:255];
reg [33:0] lb_q;
reg         rd_edge_d1;            // lookup en vuelo (lb_q valido al salir)
reg [255:0] lb_v;
reg [255:0] lb_pfb;                // entrada traida por prefetch (OBL tag)
// era v3: sl_last (ultima palabra pedida por slot) parte en BSRAM (18b) +
// 3b altos en FF — 576 FF y un mux 21b x 32:1 menos. La lectura sincrona
// vale porque e_slot es estable desde antes de rd_edge (MEM_A y MEM_RD se
// registran juntos) y el consumo va en rd_edge_d1; escritura y lectura en
// el mismo flanco del mismo slot = read-old = exactamente lo que hacia el
// original (dw se calculaba con el valor viejo ANTES de escribir el nuevo).
(* syn_ramstyle = "block_ram" *) reg [17:0] sl_mem [0:31];
reg [20:18] sl_hi [0:31];
reg [17:0]  sl_q;
reg [2:0]   sl_stride [0:31];      // stride en palabras (1..4; 0=sin entrenar)
wire [2:0]  eff_stride = (sl_stride[e_slot] == 3'd0) ? 3'd2 : sl_stride[e_slot];
wire [4:0]  e_slot;                // slot dueno del fetch (del motor)
wire [5:0]  eng_mixfm;             // _110: reg F8 (dominio motor)
reg         lb_hit;                // el ultimo fetch se sirvio de la cache
reg         lb_fast;               // hit en curso: completa al ciclo siguiente
reg [7:0]   lb_byte;

// MDI del motor: byte de la cache en hit, si no el del puerto
wire [7:0] mdi_eff = lb_hit ? lb_byte : mem_rdata;

// _95: watchdog de mem_inflight — ultima red por debajo de todo: si aun con
// el rescate de wave_ddr3 (0.9ms) el done no llega (toggle perdido en una
// colision, doble flip, lo que sea), a ~3.5ms se libera la CE a la fuerza.
// El motor muestrea UN dato rancio y sigue vivo; ifw_hits lo delata.
reg [17:0] ifw;
reg [3:0]  ifw_hits;
reg [3:0]  alive;                  // avanza con cada CE: latido visible
assign diag = {ifw_hits, alive};

reg mrd_d1, mwr_d1, done_d1;
reg        fill_pend;              // _96: fill de la cache diferido 1 ciclo
reg [20:0] fill_tag;
reg        fill_is_pf;             // _107: el fill viene de un prefetch
reg [4:0]  fill_slot;              // _107c: particion destino del fill
reg [4:0]  cur_op_slot;            // _107c: slot del op en el puerto
reg [4:0]  eng_pend_slot;
reg        port_busy;              // _107: UNA op (motor o pf) en el puerto
reg        op_is_pf;               // _107: la op en vuelo es un prefetch
reg        eng_pend;               // _107: op del motor esperando el puerto
reg        eng_pend_we;
reg [21:0] eng_pend_addr;
reg [7:0]  eng_pend_data;
// _107b: COLA de prefetch (8 plazas). Con 1 plaza el arranque no
// converge: 22 streams en regimen de miss pisotean el want y el pf
// nunca despega (medido: 799/1200, peor que sin pf). Con cola, cada
// hueco del puerto emite un pf pendiente -> avalancha al regimen bueno.
reg [25:0] pfq [0:7];              // {slot[4:0], palabra[20:0]}
reg [2:0]  pfq_wp, pfq_rp;
wire       pfq_empty = (pfq_wp == pfq_rp);
wire       pfq_full  = (pfq_wp + 3'd1 == pfq_rp);
reg        pf_kill;                // _107: el pf en vuelo quedo rancio
wire       rd_edge = ~e_mrd_n && !mrd_d1;
wire       wr_edge = ~e_mwr_n && !mwr_d1;

// era v3: retencion de UNA plaza para la escritura que colisiona con la
// resolucion de una lectura (ver la nota del bloque de escritura). El
// original no la necesitaba porque su exclusion era rd_edge/wr_edge, que
// el motor nunca solapa; al mover la resolucion a rd_edge_d1 el solape
// pasa a ser real con las escrituras de CPU a la RAM de ondas.
reg         wr_hold;
reg [21:0]  wrh_addr;
reg [7:0]   wrh_data;
reg [4:0]   wrh_slot;
// La escritura solo entra con la plaza del arbitro LIBRE: si entrase con
// un fallo de lectura ya encolado lo machacaria (eng_pend es de UNA plaza)
// y ese fetch no volveria nunca -> mem_inflight clavado -> CE congelada
// hasta el watchdog de 3,5 ms -> el status del motor se queda pegado.
wire        wre_free = !rd_edge_d1 && !eng_pend;
wire        wre_go   = wre_free && (wr_hold || wr_edge);
wire [21:0] wre_addr = wr_hold ? wrh_addr : e_addr22;
wire [7:0]  wre_data = wr_hold ? wrh_data : e_mdo;
wire [4:0]  wre_slot = wr_hold ? wrh_slot : e_slot;

// Puertos de la BSRAM de cache (era v3). Escritura = fill; lectura corre
// SIEMPRE (la direccion es cuasi-estatica alrededor de rd_edge). Sin reset:
// una BSRAM no lo tiene; la validez la gobierna lb_v (FF), como siempre.
always @(posedge clk_eng) begin
    if (fill_pend)
        lb_mem[{fill_slot,fill_tag[2:0]}] <= {fill_tag[20:3], mem_rword};
    lb_q <= lb_mem[{e_slot, e_addr22[3:1]}];
end

// puertos de la BSRAM de sl_last (era v3): escritura en el miss — la misma
// condicion del bloque strided del always principal — y lectura corriendo
// siempre sobre e_slot (cuasi-estatico alrededor del lookup)
wire lb_hit_now = lb_v[{e_slot,e_addr22[3:1]}] && (lb_q[33:16] == e_addr22[21:4]);
// if/else EXCLUYENTE (leccion _139): escritura y lectura comparten la
// direccion e_slot => Gowin infiere puerto UNICO, y leer durante we exige
// el WRITE_MODE 2'b10 que Arora-V no soporta (PA2122, v3b014). Con el
// else, el ciclo de escritura no refresca sl_q — irrelevante: su consumo
// (strided, en rd_edge_d1) usa el valor registrado el ciclo ANTERIOR.
always @(posedge clk_eng) begin
    if (rd_edge_d1 && !lb_hit_now)
        sl_mem[e_slot] <= e_addr22[18:1];
    else
        sl_q <= sl_mem[e_slot];
end
always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        mrd_d1 <= 1'b0; mwr_d1 <= 1'b0; done_d1 <= 1'b0;
        mem_req <= 1'b0; mem_we <= 1'b0;
        mem_addr <= 22'd0; mem_wdata <= 8'd0;
        mem_inflight <= 1'b0;
        lb_v <= 256'd0; lb_pfb <= 256'd0;
        lb_hit <= 1'b0; lb_fast <= 1'b0; lb_byte <= 8'd0;
        rd_edge_d1 <= 1'b0;
        wr_hold <= 1'b0; wrh_addr <= 22'd0; wrh_data <= 8'd0; wrh_slot <= 5'd0;
        ifw <= 18'd0; ifw_hits <= 4'd0; alive <= 4'd0;
        fill_pend <= 1'b0; fill_tag <= 21'd0; fill_is_pf <= 1'b0;
        fill_slot <= 5'd0; cur_op_slot <= 5'd0; eng_pend_slot <= 5'd0;
        port_busy <= 1'b0; op_is_pf <= 1'b0;
        eng_pend <= 1'b0; eng_pend_we <= 1'b0;
        eng_pend_addr <= 22'd0; eng_pend_data <= 8'd0;
        pfq_wp <= 3'd0; pfq_rp <= 3'd0; pf_kill <= 1'b0;
    end
    else begin
        mrd_d1 <= ~e_mrd_n;
        mwr_d1 <= ~e_mwr_n;
        done_d1 <= mem_done_t;
        mem_req <= 1'b0;
        if (ce) alive <= alive + 4'd1;
        // _95: el done se consume ANTES y en un if INDEPENDIENTE (historia:
        // un done coincidiendo con flanco nuevo se perdia y mem_inflight
        // quedaba clavado). _96: el fill va DIFERIDO 1 ciclo (fill_pend):
        // capturar mem_rword en el primer avistamiento del toggle es una
        // carrera de hold de picosegundos que en placa corrompia lineas.
        if (mem_done_t != done_d1) begin
            port_busy <= 1'b0;
            if (op_is_pf) begin
                op_is_pf <= 1'b0;
                if (!pf_kill) begin
                    fill_pend  <= 1'b1;
                    fill_tag   <= mem_addr[21:1];
                    fill_slot  <= cur_op_slot;
                    fill_is_pf <= 1'b1;
                end
                pf_kill <= 1'b0;
            end
            else begin
                mem_inflight <= 1'b0;
                if (!mem_we) begin
                    fill_pend  <= 1'b1;
                    fill_tag   <= mem_addr[21:1];
                    fill_slot  <= cur_op_slot;
                    fill_is_pf <= 1'b0;
                end
            end
        end
        if (fill_pend) begin
            fill_pend <= 1'b0;
            // el dato {tag,word} lo escribe el puerto BSRAM (arriba); aqui
            // solo la contabilidad FF — asentado (_96)
            lb_v[{fill_slot,fill_tag[2:0]}]    <= 1'b1;
            lb_pfb[{fill_slot,fill_tag[2:0]}]  <= fill_is_pf;
        end
        if (lb_fast) begin
            // hit del ciclo anterior: lb_byte ya es valido -> soltar el CE.
            // ¡OJO: el hit DEBE sujetar la CYCLE1 de muestreo como cualquier
            // fetch! (_94: sin esto el motor muestreaba MDI rancio.)
            lb_fast <= 1'b0;
            mem_inflight <= 1'b0;
        end
        // retencion de la escritura colisionada (una plaza; el motor no
        // emite dos escrituras en ciclos consecutivos)
        if (wr_edge && !wre_go) begin       // no puede entrar ya -> se retiene
            wr_hold  <= 1'b1;
            wrh_addr <= e_addr22;
            wrh_data <= e_mdo;
            wrh_slot <= e_slot;
        end
        else if (wr_hold && wre_go) wr_hold <= 1'b0;
        if (rd_edge) begin
            // era v3: la resolucion espera a lb_q (1 ciclo); la CYCLE1 se
            // sujeta desde YA para que el deadline no se cuele (_94)
            rd_edge_d1   <= 1'b1;
            mem_inflight <= 1'b1;
        end
        else
            rd_edge_d1 <= 1'b0;
        if (rd_edge_d1) begin
            if (lb_v[{e_slot,e_addr22[3:1]}] &&
                (lb_q[33:16] == e_addr22[21:4])) begin
                lb_hit  <= 1'b1;                   // HIT: sin transaccion
                lb_byte <= e_addr22[0] ? lb_q[15:8]
                                       : lb_q[7:0];
                lb_fast <= 1'b1;                   // completa en 1 ciclo
                if (lb_pfb[{e_slot,e_addr22[3:1]}]) begin  // OBL etiquetado
                    lb_pfb[{e_slot,e_addr22[3:1]}] <= 1'b0;
                    if (!pfq_full) begin
                        // _112: la proxima palabra segun el STRIDE del slot
                        pfq[pfq_wp] <= {e_slot, e_addr22[21:1]
                                        + {18'd0, eff_stride}};
                        pfq_wp <= pfq_wp + 3'd1;
                    end
                end
            end
            else begin
                lb_hit        <= 1'b0;
                eng_pend      <= 1'b1;             // _107: via arbitro
                eng_pend_we   <= 1'b0;
                eng_pend_addr <= e_addr22;
                eng_pend_slot <= e_slot;
                mem_inflight  <= 1'b1;  // congela la CYCLE1_CE hasta el done
                // _112: stride del slot = salto entre misses consecutivos
                // (clamp 1..4 palabras; saltos grandes = cambio de region
                //  -> vuelve a 2, el caso 12-bit paso 1)
                begin : strided
                    reg [20:0] dw;
                    // era v3: el valor viejo viene de {sl_hi (FF), sl_q
                    // (BSRAM, registrada)} — identico al async de antes
                    // porque e_slot lleva estable desde antes de rd_edge.
                    // La escritura nueva vive en su propio always (BSRAM).
                    dw = e_addr22[21:1] - {sl_hi[e_slot], sl_q};
                    if (dw != 21'd0 && dw <= 21'd4)
                        sl_stride[e_slot] <= dw[2:0];
                    else if (dw > 21'd8)
                        sl_stride[e_slot] <= 3'd2;
                    sl_hi[e_slot] <= e_addr22[21:19];
                end
                if (!pfq_full) begin    // pf al stride del slot
                    pfq[pfq_wp] <= {e_slot, e_addr22[21:1]
                                    + {18'd0, eff_stride}};
                    pfq_wp <= pfq_wp + 3'd1;
                end
            end
        end
        // ⚠️ era v3, DEFECTO PROPIO CORREGIDO: al desplazar la resolucion a
        // rd_edge_d1, este else-if paso a poder disparar de verdad. En el
        // original la exclusion era rd_edge/wr_edge, que NUNCA coinciden
        // (el motor conduce MRD_N y MWR_N excluyentes); con rd_edge_d1 SI
        // coinciden, porque las escrituras de la RAM de ondas las mete la
        // CPU (reg 06) de forma asincrona a los fetches del motor. Una
        // escritura que caia justo un ciclo despues de una lectura se
        // DESCARTABA EN SILENCIO. Ahora se retiene una plaza y entra al
        // ciclo siguiente.
        else if (wre_go) begin
            lb_hit <= 1'b0;
            if (wre_addr[21]) begin                // solo la RAM es escribible
                eng_pend      <= 1'b1;
                eng_pend_we   <= 1'b1;
                eng_pend_addr <= wre_addr;
                eng_pend_slot <= wre_slot;
                eng_pend_data <= wre_data;
                mem_inflight  <= 1'b1;             // tambien en escritura (_91)
                lb_v   <= 256'd0;                  // _107c: FLUSH total (una
                lb_pfb <= 256'd0;                  //  escritura CPU no tiene
                                                   //  slot; rancio = fuera)
                                                   // (_113: literal 128->256;
                                                   //  cero-extension = mismo
                                                   //  netlist, solo claridad)
                fill_pend <= 1'b0;                 // _96: cancelar fill pendiente
                pfq_rp <= pfq_wp;                  // _107b: vaciar wants rancios
                if (port_busy && op_is_pf && mem_addr[21:1] == wre_addr[21:1])
                    pf_kill <= 1'b1;               // pf en vuelo quedaria rancio
            end
            // _107: escritura con addr[21]==0 (region ROM) = NO-OP, como el
            // chip real. Sin esto la deteccion de RAM de MoonBlaster
            // "encontraba 4MB" y machacaba la YRW801 en SDRAM.
        end

        // _107: arbitro del puerto (una op en vuelo; motor > prefetch).
        // No emitir pf en el ciclo de un wr_edge (cerraria la ventana de
        // pf_kill: el flanco aun ve op_is_pf viejo).
        if (!port_busy && !fill_pend) begin
            if (eng_pend) begin
                eng_pend  <= 1'b0;
                mem_req   <= 1'b1;
                mem_we    <= eng_pend_we;
                mem_addr  <= eng_pend_addr;
                mem_wdata <= eng_pend_data;
                cur_op_slot <= eng_pend_slot;
                op_is_pf  <= 1'b0;
                port_busy <= 1'b1;
            end
            else if (!pfq_empty && !wr_edge && !rd_edge && !rd_edge_d1) begin
                // (!rd_edge_d1 era v3: un miss resuelve en N+1 y su eng_pend
                //  no es visible hasta N+2 — sin el guard un pf le robaria
                //  el puerto y el motor esperaria detras de un fetch ajeno)
                pfq_rp    <= pfq_rp + 3'd1;
                mem_req   <= 1'b1;
                mem_we    <= 1'b0;
                mem_addr  <= {pfq[pfq_rp][20:0], 1'b0};
                cur_op_slot <= pfq[pfq_rp][25:21];
                op_is_pf  <= 1'b1;
                port_busy <= 1'b1;
            end
        end

        // _95: watchdog de inflight (despues de todo: su liberacion forzada
        // solo gana si NADIE mas decidio sobre mem_inflight este ciclo).
        // _107: suelta tambien el arbitro para no dejarlo clavado.
        if (mem_inflight) begin
            ifw <= ifw + 18'd1;
            if (ifw[17]) begin
                mem_inflight <= 1'b0;
                lb_hit <= 1'b0;        // que muestree mem_rdata, no la cache
                ifw <= 18'd0;
                eng_pend <= 1'b0;
                port_busy <= 1'b0;
                op_is_pf <= 1'b0;
                if (ifw_hits != 4'd15) ifw_hits <= ifw_hits + 4'd1;
            end
        end
        else ifw <= 18'd0;
    end
end

// --- RECLOCK de salida (_98): FIFO 16 + consumidor a ritmo FIJO ---
// EL HALLAZGO de la saga _95-_97: los VALORES del motor eran perfectos
// (bit-exactos vs golden) pero sus TIEMPOS no — el stall del deadline
// congela la CE y el credito la recupera en rafagas: con 7 slots la sim
// midio periodos de 7.6 a 136us (nominal 22.676, sigma 6.9us) y el error
// de sample-and-hold en el DAC IGUALA la potencia de la señal (SNR -0.4dB)
// = el "ruido y crujidos" del HW, con el drone periodico de las rafagas.
// Las sims de valores/periodo-medio no lo veian; la telemetria tampoco
// (no hay nada roto: solo llega a destiempo).
//
// Fix: el productor escribe cada muestra en un FIFO de 16 cuando sale;
// el consumidor la saca con un acumulador IDENTICO (6272/6875, /768)
// pero SIN stall = metronomo exacto a 44.1kHz en el MISMO reloj ->
// tasas matematicamente clavadas, cero deriva. El credito CONSERVA el
// computo de muestras, asi que el nivel del FIFO vuelve solo a su punto
// tras cada excursion (max vista 136us = 6 muestras; arrancamos con 8).
// Subflujo: repetir la ultima (sin click). Sobreflujo: imposible con
// tasas clavadas (guardado igual). El lado host no cambia: pcm_t_x
// ahora simplemente late uniforme.
wire [15:0] o1_l, o1_r;
reg  [31:0] rf_mem [0:15];
reg  [3:0]  rf_wp, rf_rp;
reg         rf_run;                    // consumidor armado (nivel >= 8)
reg  [23:0] oacc;                      // acumulador del consumidor (sin stall)
reg  [9:0]  odiv;                      // /768 del consumidor
reg  [9:0]  pdiv;                      // /768 del PRODUCTOR (cuenta CEs)
always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        pcm_l_x <= 16'sd0; pcm_r_x <= 16'sd0; pcm_t_x <= 1'b0;
        rf_wp <= 4'd0; rf_rp <= 4'd0; rf_run <= 1'b0;
        oacc <= 24'd0; odiv <= 10'd0; pdiv <= 10'd0;
    end
    else begin
        // PRODUCTOR: una escritura por muestra del motor = cada 768 CE
        // (la CE es la que stalla; el o1 vigente en la frontera es la
        // muestra recien terminada — offset constante, inofensivo)
        if (ce) begin
            if (pdiv == 10'd767) begin
                pdiv <= 10'd0;
                if (rf_wp + 4'd1 != rf_rp) begin   // guardado (no deberia darse)
                    rf_mem[rf_wp] <= {o1_l, o1_r};
                    rf_wp <= rf_wp + 4'd1;
                end
            end
            else pdiv <= pdiv + 10'd1;
        end
        // CONSUMIDOR: mismo acumulador SIN stall = 44.1kHz de metronomo
        if (!rf_run) begin
            if ((rf_wp - rf_rp) >= 4'd8) rf_run <= 1'b1;   // nivel mod 16
            oacc <= 24'd0; odiv <= 10'd0;
        end
        else begin
            if (oacc + CE_INC >= CE_MOD) begin
                oacc <= oacc + CE_INC - CE_MOD;
                if (odiv == 10'd767) begin
                    odiv <= 10'd0;
                    if (rf_rp != rf_wp) begin
                        {pcm_l_x, pcm_r_x} <= rf_mem[rf_rp];
                        rf_rp <= rf_rp + 4'd1;
                    end                       // subflujo: repite la ultima
                    pcm_t_x <= ~pcm_t_x;      // late UNIFORME pase lo que pase
                end
                else odiv <= odiv + 10'd1;
            end
            else oacc <= oacc + CE_INC;
        end
    end
end

// ===========================================================================
// EL MOTOR (srg320, fpga/opl4wave/ymf278b_gowin.v)
// ===========================================================================
YMF278B u_engine (
    .CLK    (clk_eng),
    .RST_N  (erst_n),
    .EN     (1'b1),
    .CE     (ce),

    .A      (e_a),
    .DI     (e_di),
    .DO     (e_do),
    .RD_N   (e_rd_n),
    .WR_N   (e_wr_n),
    .CS_N   (e_cs_n),
    .IC_N   (erst_n),

    .IRQ_N  (),                 // el motor no genera IRQ (stub FM)

    .MA     (e_ma),
    .MDI    (mdi_eff),          // byte de cache en hit / puerto en miss
    .MDO    (e_mdo),
    .MRD_N  (e_mrd_n),
    .MWR_N  (e_mwr_n),
    .MCS_N  (e_mcs_n),
    .MEM_SLOT (e_slot),
    .MIX_FM   (eng_mixfm),

    .OUT0_L (), .OUT0_R (),     // FM del stub (siempre 0)
    // _110: OUT2 en vez de OUT1 — OUT2 = MixCalc(PCM, F9) + MixCalc(stub=0)
    // = el PCM CON la atenuacion del reg F9 aplicada, que hasta ahora se
    // ignoraba (VGMPlay/MBWave la usan para balancear; con F9=0 por reset
    // OUT2 == OUT1 bit a bit y toda la regresion se mantiene).
    .OUT1_L (), .OUT1_R (),
    .OUT2_L (o1_l), .OUT2_R (o1_r),

    .SND_EN (3'b111),

    .CYCLE1_NEXT (e_cycle1_next)
);

// ===========================================================================
// _111: TELEMETRIA UART (TX-only, 115200 8N1, dominio clk_eng = SIN CDC).
// El sim exonera todo lo que modelamos y la placa "vibra" con VGMPlay:
// esto emite cada ~250ms una trama binaria con los contadores que las sims
// no pueden ver en vivo. Pin: dbg_pmod1[4] = E22 (el del CH340 de la saga
// WiFi). Lector: tools/dbg_reader.py.
// Trama (16 bytes): A5 seq rep[2] drop[2] push[2] tick[2] miss[2] pf[2]
//                   {lvl_min,lvl} {ifw_hits,alive} sum
// (contadores libres de 16 bits: el lector calcula deltas por ventana;
//  lvl_min es ventana-local, se rearma en cada trama)
// ===========================================================================
parameter DBG_FRAME_CYC = 32'd9375000;   // ~250ms a 37.5MHz (el TB lo acorta)
parameter DBG_BAUD_DIV  = 9'd326;        // 37.5e6/115200 = 325.5

reg [15:0] c_rep, c_drop, c_push, c_tick, c_miss, c_pf;
reg [3:0]  lvl_min_w;
reg        t_x_d1;
reg [3:0]  rp_d1, wp_d1;
reg [9:0]  pdiv_d1;
wire [3:0] rf_lvl = rf_wp - rf_rp;

always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        c_rep <= 0; c_drop <= 0; c_push <= 0; c_tick <= 0; c_miss <= 0; c_pf <= 0;
        t_x_d1 <= 0; rp_d1 <= 0; wp_d1 <= 0; pdiv_d1 <= 0; lvl_min_w <= 4'hF;
    end
    else begin
        t_x_d1 <= pcm_t_x;
        rp_d1  <= rf_rp;
        wp_d1  <= rf_wp;
        pdiv_d1<= pdiv;
        if (pcm_t_x != t_x_d1) begin
            c_tick <= c_tick + 16'd1;
            if (rf_rp == rp_d1) c_rep <= c_rep + 16'd1;   // tick sin pull
        end
        if (rf_wp != wp_d1) c_push <= c_push + 16'd1;
        if (pdiv_d1 == 10'd767 && pdiv == 10'd0 && rf_wp == wp_d1
            && (wp_d1 + 4'd1) == rf_rp) c_drop <= c_drop + 16'd1;
        // _116: la replica usaba el indexado VIEJO de 4 palabras ({slot,
        // addr[2:1]}, tag[21:3]) desde la _112 -> d_miss MENTIA (contaba
        // "miss" en lecturas que la cache real de 8 palabras acertaba; los
        // "44100/6140 constantes" de la saga eran en parte este espejismo).
        // Ahora replica EXACTA del hit real: {slot, addr[3:1]}, tag[21:4].
        // era v3: la replica del hit se desplaza con el (rd_edge_d1 + lb_q)
        if (rd_edge_d1 && !(lb_v[{e_slot,e_addr22[3:1]}] &&
            (lb_q[33:16] == e_addr22[21:4]))) c_miss <= c_miss + 16'd1;
        if (mem_req && op_is_pf) c_pf <= c_pf + 16'd1;
        if (rf_lvl < lvl_min_w) lvl_min_w <= rf_lvl;
        if (dbg_snap) lvl_min_w <= 4'hF;                  // ventana nueva
    end
end

// --- emisor de tramas ---
reg [31:0] dbg_timer;
reg        dbg_snap;
reg [7:0]  fr [0:15];
reg [4:0]  fr_i;          // 0-15=trama, 16=sum, 17=reposo
reg [3:0]  bit_i;         // 0=start 1..8=datos 9=stop 10=fin
reg [8:0]  baud;
reg [7:0]  seq, sum;
integer fi;
reg [3:0]  vid_s0, vid_s1;   // _114diag: 2FF de vid_diag a clk_eng
always @(posedge clk_eng) begin vid_s0 <= vid_diag; vid_s1 <= vid_s0; end
always @(posedge clk_eng or negedge erst_n) begin
    if (!erst_n) begin
        dbg_timer <= 0; dbg_snap <= 0; fr_i <= 5'd17; bit_i <= 0; baud <= 0;
        seq <= 0; sum <= 0; dbg_tx <= 1'b1;
    end
    else begin
        dbg_snap <= 1'b0;
        if (dbg_timer == DBG_FRAME_CYC) begin
            dbg_timer <= 0;
            dbg_snap  <= 1'b1;
            fr[0] <= 8'hA5;         fr[1] <= seq;
            fr[2] <= c_rep[15:8];   fr[3] <= c_rep[7:0];
            fr[4] <= c_drop[15:8];  fr[5] <= c_drop[7:0];
            fr[6] <= c_push[15:8];  fr[7] <= c_push[7:0];
            fr[8] <= c_tick[15:8];  fr[9] <= c_tick[7:0];
            fr[10] <= c_miss[15:8]; fr[11] <= c_miss[7:0];
            fr[12] <= c_pf[15:8];   fr[13] <= c_pf[7:0];
            fr[14] <= {lvl_min_w, rf_lvl};
            // niquelado B: RESTAURADO a {ifw_hits, alive} — lo que documenta
            // la spec de la trama (:758) y espera tools/dbg_reader.py. El
            // diagnostico _114diag ({vid_s1, alive}) dejaba invisibles los
            // hits del watchdog, el centinela de la salud del motor.
            fr[15] <= {ifw_hits, alive};   // el sum va aparte como byte 16
            seq <= seq + 8'd1;
            fr_i <= 5'd0; bit_i <= 0; baud <= 0; sum <= 8'd0;
        end
        else dbg_timer <= dbg_timer + 32'd1;

        if (fr_i != 5'd17 || bit_i != 0) begin
            if (baud == DBG_BAUD_DIV - 1) begin
                baud <= 0;
                if (bit_i == 0) begin dbg_tx <= 1'b0; bit_i <= 4'd1; end        // start
                else if (bit_i <= 8) begin
                    dbg_tx <= (fr_i == 5'd16) ? sum[bit_i-1]
                                              : fr[fr_i][bit_i-1];
                    bit_i <= bit_i + 4'd1;
                end
                else begin                                                       // stop
                    dbg_tx <= 1'b1;
                    bit_i <= 0;
                    if (fr_i < 5'd16) begin
                        sum  <= sum + fr[fr_i];
                        fr_i <= fr_i + 5'd1;    // 15->16 = el byte sum
                    end
                    else fr_i <= 5'd17;         // sum enviado -> reposo
                end
            end
            else baud <= baud + 9'd1;
        end
        else dbg_tx <= 1'b1;
    end
end

endmodule
