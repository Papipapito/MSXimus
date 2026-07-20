// ============================================================================
// v9968_vram_shim.v — F1 del V9968 (MSXimus 60K): sirve la VRAM del V9968
// desde la SDRAM COMPARTIDA del dock cumpliendo el contrato medido en F0:
//
//   * PANTALLA (tag c_bg=1): respuesta a EXACTAMENTE 8 ciclos de clk_vdp
//     (85.909MHz) — el consumidor muestrea en fase fija (medido con la pila
//     ip_sdram+Micron: min=8 max=8). Se sirve desde una VENTANA DE PREFETCH
//     de 64 palabras de 32 bits (el fetch es LINEAL puro, verificado): cada
//     lectura bg dispara el prefetch OBL de las siguientes (saga wave _107).
//   * SPRITES (c_sprite=2): v1 via backend con eco (medir deadlines en sim;
//     si se corrompen -> v2 con particion propia de prefetch).
//   * CPU (3) / COMANDOS (4): latencia libre, fuera de orden, eco de tag
//     (el interface parcheado enruta por vram_rtag; ambos consumidores
//     ESPERAN su rdata_en — tolerantes por diseno).
//   * ESCRITURAS: cola de 4, byte a byte al backend (mascara 1-hot en
//     escrituras CPU; los comandos pueden empujar hasta 4 bytes/palabra).
//   * vram_refresh: IGNORADO (nuestra SDRAM ya refresca en memory.v).
//
// Backend (dominio clk_vdp; el CDC 85.9<->108 vive en el puerto wv2 de
// memory.v, patron wave port): peticiones de BYTE o PALABRA-16:
//   bk_req (pulso) + bk_we + bk_addr[21:0] (BYTE) + bk_wdata[7:0]
//   -> bk_done_t (toggle) + bk_rword[15:0] (palabra 16b alineada, como wv)
// Presupuesto medido (saga wave): ~300-500ns/op = 26-43 ciclos de 85.9.
// ============================================================================
module v9968_vram_shim #(
    parameter [21:0] VRAM_BASE = 22'h280000   // 256KB para el V9968 en SDRAM
                                              // (tras la sample RAM del OPL4)
)(
    input  wire        clk_vdp,          // 85.909 MHz
    input  wire        rst_n,

    // ---- lado V9968 (vdp.v parcheado) ----
    input  wire [17:2] vram_address,
    input  wire        vram_write,
    input  wire        vram_valid,       // PULSO
    input  wire [31:0] vram_wdata,
    input  wire [3:0]  vram_wdata_mask,
    input  wire [4:0]  vram_tag,         // {consumidor[2:0], byte_sel[1:0]}
    output reg  [31:0] vram_rdata,
    output reg         vram_rdata_en,
    output reg  [4:0]  vram_rtag,

    // ---- backend a memory.v (puerto estilo wave, mismo dominio) ----
    output reg         bk_req,           // pulso 1 ciclo
    output reg         bk_we,
    output reg  [21:0] bk_addr,          // direccion de BYTE en SDRAM
    output reg  [7:0]  bk_wdata,
    input  wire [15:0] bk_rword,         // palabra 16b (addr[0] ignorado)
    input  wire        bk_done_t,        // toggle

    // ---- backend canal B (_120, puerto wv3): SOLO lecturas — la mitad
    // ALTA de cada palabra sale en paralelo con la baja (SC7/8/12 piden
    // 1 palabra/730ns y un solo canal daba ~800ns) ----
    output reg         bk2_req,          // pulso 1 ciclo
    output reg  [21:0] bk2_addr,
    input  wire [15:0] bk2_rword,
    input  wire        bk2_done_t,       // toggle

    // ---- control de flujo (v3d): retiene los slots de CPU/COMANDO en el
    // interface cuando las colas van calientes — las escrituras de HMMV
    // desbordaban wq (4 plazas, backend byte-a-byte ~1.6us/palabra) y los
    // rectangulos salian RALLADOS. bg/sprite NO se frenan (ventana/cache).
    output wire        vram_stall,

    // ---- diagnostico ----
    output wire [7:0]  diag,
    // _121diag: contadores de telemetria (taps de solo lectura, cuasi-
    // estaticos — se muestrean desde dbg_uart en otro dominio)
    output wire [31:0] dbg_miss,
    output wire [31:0] dbg_bka,
    output wire [31:0] dbg_park,             // _124: {pisadas[15:0], drenajes[15:0]}
    output wire [31:0] dbg_bkb
);

localparam C_BG     = 3'd1;
localparam C_SPRITE = 3'd2;

// ============================================================================
// VENTANA DE PREFETCH de pantalla (v4: EN BSRAM — leccion _119: los conos
// asincronos fabric de pw_data/pw_tagA eran los peores caminos de TODA la
// matriz de rutados, hasta -2.8ns): 64 x {tag10, data32} direct-mapped
// (indice addr[7:2], tag addr[17:8]). Una linea SC5 = 32 palabras. El
// lookup pasa a la MISMA etapa 1 que la cache (hit -> pipe[1], total 8
// ciclos EXACTOS igual). Solo pw_v (64 FF) vive en fabric.
// Puerto de lectura unico muxeado: ciclo 0 = lookup del fetch/write-check;
// ciclo 2 = chequeo OBL (obl_w registrado; sin colision: vram_valid van
// separados >=8 ciclos).
// ============================================================================
reg [41:0] pw_mem [0:255];               // {tag[9:0], data[31:0]} (BSRAM)
reg [255:0] pw_v;                        // valid en fabric
reg [41:0] pwq;                          // lectura sincrona registrada
reg        pwq_v;                        // valid del indice leido

// escritura de la ventana (solo el backend): registros de fill
reg        pww_en;
reg [7:0]  pww_idx;
reg [9:0]  pww_tag;
reg [31:0] pww_data;

// ============================================================================
// CACHE DE TABLAS (v3): 4096 palabras de 32b (16KB) direct-mapped, indice
// addr[13:2], tag addr[17:14]. Sirve a DOS consumidores de fase fija:
//  * SPRITES (attr/color/pattern — v2, medido: sin cache se perdia el 51%)
//  * FONDO EN MODOS DE PATRONES (v3, leccion HW _117: la ventana OBL asume
//    fetch LINEAL — cierto SOLO en bitmap SC5+. En SCREEN 0/1/2 el fetch
//    salta NT->PGT->CT y la ventana fallaba casi todo -> basura animada en
//    todo texto, con el bitmap del logo perfecto. Las FOTOS lo clavaron.)
// 16KB cubre el espacio de tablas MSX1 ENTERO (SC2 usa 12.75KB): tras un
// frame de warm-up, SCREEN 0/1/2/3 quedan RESIDENTES.
// WRITE-THROUGH-UPDATE: una escritura que casa el tag ACTUALIZA la entrada
// (print/scroll/animar patrones no des-cachea); coherencia permanente.
//
// ⚠ INFERENCIA BSRAM OBLIGATORIA (leccion _117a: los arrays con lectura
// asincrona explotan en fabric): datos en 4 lanes 4096x8 con LECTURA
// SINCRONA (1 write-site por array). El lookup es de 2 ciclos e inyecta en
// pipe[1] -> el total sigue siendo 8 EXACTOS. Solo sc_v (4096 FF, con el
// mux registrado en scq_v) vive en fabric.
// ============================================================================
// lookup (fetch bg/sprite) y write-check (escritura) son mutuamente
// exclusivos (un solo vram_valid) -> UN puerto de lectura sirve a ambos:
// cada array queda 1R sincrono + 1W muxeado = BSRAM semi-dual limpia.
reg [7:0]  sc_d0 [0:4095];               // lane byte 0 (BSRAM)
reg [7:0]  sc_d1 [0:4095];
reg [7:0]  sc_d2 [0:4095];
reg [7:0]  sc_d3 [0:4095];
reg [3:0]  sc_tag [0:4095];              // addr[17:14] (BSRAM)
reg sc_v [0:4095];                       // _120d: valids EN BSRAM 4096x1 —
                                         // los 4096 FF con su mux 4096:1 y
                                         // el decode de CE eran el reincidente
                                         // de placement (r2/r9/_122). sc_v es
                                         // SET-ONLY salvo reset -> BSRAM con
                                         // BARRIDO de limpieza post-reset
                                         // (4096 ciclos ~48us, con miss
                                         // forzado mientras tanto).
reg [12:0] scv_swp;                      // contador del barrido
wire       scv_ready = scv_swp[12];

// lecturas sincronas registradas (salidas BSRAM + valid)
reg [7:0]  scq_d0, scq_d1, scq_d2, scq_d3;
reg [3:0]  scq_tag;
reg        scq_v;                        // salida del puerto BSRAM de sc_v

// etapa 1 del lookup (bg con miss de ventana, o sprite)
reg        spr_p1;
reg [15:0] spr_addr1;                    // addr[17:2]
reg [4:0]  spr_tag1;

// etapa 1 del write-check
reg        wrk_p1;
reg [15:0] wrk_addr1;
reg [31:0] wrk_data1;
reg [3:0]  wrk_mask1;                    // DQM (0 = escribir byte)

// OBL en dos fases (v4): obl_pend lanza la lectura BSRAM de la ventana
// (ciclo 2 del fetch), obl_chk consume pwq y encola (ciclo 3)
reg        obl_pend;
reg        obl_chk;
reg        obl_do;                       // _121b: fase 3 (comparador registrado)
reg [15:0] obl_w;
reg [15:0] obl_w_c, obl_w_d;             // _123: la direccion VIAJA con la
                                         // tuberia (un hit nuevo pisaba obl_w
                                         // con la fase 3 aun en vuelo: se
                                         // perdia una direccion y se duplicaba
                                         // otra = agujero en la cadena)
reg        pfB_pend;                     // _123b: semilla del fetch (miss +1 o
reg [15:0] pfB_wr;                       // rescate) REGISTRADA — el push desde
                                         // el ciclo del compare colgaba pfq del
                                         // DO del BSRAM (la familia critica
                                         // pw_mem DO -> pfq de _121b, resucito
                                         // a -25.8 en el roll r2 del park v1).
                                         // +1 ciclo en prefetch especulativo =
                                         // gratis, y en pares consecutivos el
                                         // esquema pipelinea sin perdidas.

// escritura muxeada de la cache (1 solo write-site por array): el FILL
// (completacion rq de sprite) espera en fill_* si el ciclo lo usa un update
reg        fill_pend;
reg [15:0] fill_addr;
reg [31:0] fill_word;

// cola de prefetch (_120c: 8 plazas — mas prefetch en vuelo para los
// modos de 256B/linea; tambien resiembra el placement, que con nombres
// no se inmuta: Gowin solo baraja con cambios ESTRUCTURALES)
reg [15:0] pfq [0:7];                    // addr[17:2]
reg [2:0]  pfq_wp, pfq_rp;
wire       pfq_empty = (pfq_wp == pfq_rp);
wire       pfq_full  = (pfq_wp + 3'd1 == pfq_rp);

// cola de escrituras (4 plazas: {mask,wdata,addr})
reg [51:0] wq [0:7];                     // {mask[3:0], wdata[31:0], addr[17:2]} (_120e: 8 plazas, umbral igual)
reg [2:0]  wq_wp, wq_rp;
reg [7:0]  wq_vld;                       // _126: bitmap de ocupacion (snoop)
wire       wq_empty = (wq_wp == wq_rp);
wire       wq_full  = (wq_wp + 3'd1 == wq_rp);

// cola de lecturas al backend (v3c: 8 plazas con RESERVA anti-drop — las
// lecturas de CPU/COMANDO no pueden perderse JAMAS: un drop deja al motor
// de comandos esperando su rdata_en para siempre = el cuelgue de SC5 en HW,
// y a la CPU con el buffer de prefetch rancio = el rastro del cursor.
// bg/sprite (tolerantes, se autocuran) solo encolan si quedan >=3 libres.)
reg [20:0] rq [0:15];                    // {tag[4:0], addr[17:2]} (_120e: 16 plazas, umbrales iguales)
reg [3:0]  rq_wp, rq_rp;
wire [3:0] rq_used  = rq_wp - rq_rp;
wire       rq_empty = (rq_wp == rq_rp);
wire       rq_full  = (rq_used == 4'd15);
wire       rq_room_soft = (rq_used <= 4'd12);  // hueco para bg/sprite (_121:
                                               // al ensanchar rq a 16 la
                                               // reserva quedo en 4 = cola
                                               // efectiva de 4 -> 265K
                                               // drops/s en SC8; CPU/cmd
                                               // conservan 3 plazas)
// _123: APARCAMIENTO con reintento para bg/sprite — el TB de placa cazo la
// correlacion 1:1 drop->miss (S3 t=51930893000 addr=403b == MISS ln=64
// addr=403b): con rq transitoriamente caliente (CPU+sprites+drenaje frenado
// por el refresh) la reserva DESCARTABA el miss de bg = un guion en pantalla
// una vez por batido (la "linea barredora" de HW _121/_122). Ahora se aparca
// en 1 plaza y se reencola al abrirse hueco (drena en <1us; si llegara otro
// mientras, gana el nuevo — el viejo ya perdio a su consumidor igualmente).
// _124: el park pasa a FIFO de 4 — en HW _123 el 1 miss/frame SEGUIA (+59/s
// exactos en COM11): la hipotesis es RAFAGA de misses bg en la misma ventana
// caliente (bg pisaba a bg en la plaza unica; el TB ya enseno S3b>0). Los
// contadores salen por COM11 (palabra 5) y responden la pregunta en placa:
// pisadas~59/s => era esto (y el FIFO de 4 ES el fix); pisadas=0 => el
// agujero esta mas arriba y toca radiografia de posicion.
reg [20:0] bgp [0:3];                          // {tag[4:0], addr[15:0]}
reg [1:0]  bgp_wp, bgp_rp;
wire       bgp_empty = (bgp_wp == bgp_rp);
wire       bgp_full  = (bgp_wp + 2'd1 == bgp_rp);
reg [15:0] c_park, c_pkov;                     // drenajes OK / pisadas (overflow)

// ============================================================================
// TUBERIA DE RESPUESTA A 8 CICLOS para bg: shift-register de 8 etapas con
// {valido, tag, dato}. Un hit de bg agenda su respuesta en la etapa 0 y
// emerge exactamente 8 flancos despues de vram_valid (la etapa se carga en
// el ciclo siguiente al pulso => 7 etapas de viaje + 1 de salida = 8).
// ============================================================================
reg [37:0] pipe [0:6];                   // {v, tag[4:0], dato[31:0]}
integer pi;

// miss de bg: contador (diagnostico — un miss = 1 palabra negra 1 frame)
reg [7:0] bg_miss;
assign diag = bg_miss;
reg [31:0] c_miss, c_bka, c_bkb;         // _121diag
assign dbg_miss = c_miss;
assign dbg_bka  = c_bka;
assign dbg_park = {c_pkov, c_park};
assign dbg_bkb  = c_bkb;

// control de flujo: con wq medio-lleno o rq caliente, el interface retiene
// los slots de CPU/COMANDO (ready=0) hasta que el backend drene
wire [2:0] wq_used = wq_wp - wq_rp;
assign vram_stall = (wq_used >= 3'd2) || (rq_used >= 4'd6);

// ============================================================================
// backend: una op en vuelo; prioridad _126: PREFETCH > escrituras >
// lecturas-demanda (la pantalla manda, como el VDP real — con wq primero
// un HMMV a chorro mataba de hambre a la ventana: 16k misses/frame =
// rectangulos SC8 despedazados; medido 73 con pfq primero). wq antes que
// rq = coherencia write->read global gratis; el unico que salta
// escrituras es el prefetch y pf_dirty descarta su fill si adelanto a
// una escritura pendiente del mismo word.
// Cada palabra-32 = 2 ops de 16 bits (addr byte par: +0 y +2).
// ============================================================================
reg        bsy;                          // op en vuelo (palabra o byte)
reg        done_d;
reg        done2_d;                      // _120: toggle-shadow del canal B
reg        got_lo, got_hi;               // _120: mitades recibidas (lecturas)
reg        pwv_set_p;                    // _120: set de pw_v retrasado 1 ciclo
reg [7:0]  pwv_set_i;                    //       (alineado con el dato negedge)
reg  [1:0] cur_kind;                     // 0=pf, 1=rq, 2=wq
reg        cur_half;                     // mitad baja(0)/alta(1) de la palabra
reg [15:0] cur_addrw;                    // addr[17:2] de la palabra en curso
reg [4:0]  cur_tag;                      // para rq
reg [31:0] cur_word;                     // acumulador de lectura / dato de escr.
reg [3:0]  cur_mask;
reg [1:0]  cur_wbyte;                    // byte en curso de la escritura
reg        word_pend;                    // palabra de 32b en construccion

// respuesta tardia (rq) esperando hueco de salida
reg        late_v;
reg [4:0]  late_tag;
reg [31:0] late_data;

// (_126: se evaluo una valvula anti-livelock para el fill dirty-dropped;
// innecesaria — la escritura culpable siempre drena en el primer hueco
// sin lecturas (hblank como muy tarde) y el rescate siguiente rellena
// limpio. El "cuelgue" que la motivo era un bug del TB sc5line.)

// _126: SNOOP anti-rancio de los fills. Con pfq por DELANTE de wq (y ya
// antes con rq: la escritura podia encolarse con la lectura EN VUELO), un
// fill que completa mientras una escritura al MISMO word espera en wq
// cachearia dato PRE-escritura marcado valido — la invalidacion del
// write-check ocurrio al ENCOLAR, cuando la entrada aun no existia. Si
// algun wq ocupado casa con la op en curso, el fill se DESCARTA (la
// entrada queda invalida y el siguiente fetch la rescata). La RESPUESTA
// al consumidor (late_v) NO se descarta: el unico lector que podria ver
// su propia escritura pendiente es la CPU, y no puede reordenarse asi.
wire pf_dirty = (wq_vld[0] && wq[0][15:0] == cur_addrw) ||
                (wq_vld[1] && wq[1][15:0] == cur_addrw) ||
                (wq_vld[2] && wq[2][15:0] == cur_addrw) ||
                (wq_vld[3] && wq[3][15:0] == cur_addrw) ||
                (wq_vld[4] && wq[4][15:0] == cur_addrw) ||
                (wq_vld[5] && wq[5][15:0] == cur_addrw) ||
                (wq_vld[6] && wq[6][15:0] == cur_addrw) ||
                (wq_vld[7] && wq[7][15:0] == cur_addrw);

// (_126c probo un snoop rq_dirty sobre la cabeza de rq para dejar pasar
// reads limpios por delante de las escrituras; el cono rq_rp -> mux 16:1
// -> 8 comparadores -> CE del lanzador violaba a -1.28ns en el GW5AT-60
// y el problema que resolvia era un FANTASMA (bug del TB sc5line). Con
// wq por delante de rq la coherencia write->read sale gratis, sin logica.)

// ---- pliegue del bit de mitad en los INDICES (_120, glitches SC7/8/12
// de HW _119): con el entrelazado del V9938 ({a[17],a[0],a[16:1]}) el bg
// y los sprites llegan como DOS streams fisicos que solo difieren en el
// bit 16 del byte (bit 14 del vector [17:2]); sin el pliegue colisionan
// en los mismos indices de ventana y cache y se desalojan mutuamente en
// CADA fetch (thrash total). El XOR con el bit 14 los separa; es
// biyectivo (ambos tags contienen el bit 14) y NEUTRO para streams
// lineales (bit constante) — sin señal de modo, sin flush al conmutar.
// _120b: ventana a 128 palabras (2 lineas SC7/8 completas) — el re-fetch
// de frontera del core (re-lee las primeras palabras de la linea) y el
// prefetch OBL de la linea siguiente PELEABAN por el mismo slot con 64
// (linea N+1 pisa exactamente los indices de la N): misses sistematicos
// en el arranque de lineas alternas. Con 128, lineas adyacentes conviven.
// _122: ventana a 256 palabras (8 medias-lineas SC7/8 por mitad) — el
// re-fetch de frontera aun pillaba el realineo de indices cada 4 lineas
// (~500 misses/s residuales en placa = guiones transitorios visibles).
function [7:0] w_idx(input [15:0] v);
    w_idx = v[7:0] ^ {v[14], 7'b0};
endfunction
function [11:0] c_idx(input [15:0] v);
    c_idx = v[11:0] ^ {v[14], 11'b0};
endfunction

// ---- write-mux de la cache de sprites (1 solo write-site por array):
// UPDATE (write-check con tag-match, byte a byte por mascara DQM) tiene
// prioridad; el FILL espera en fill_pend al primer ciclo libre.
wire wrk_hit  = wrk_p1 && scq_v && (scq_tag == wrk_addr1[15:12]);
// _121b (timing): el fill cede el puerto si hay write-check EN VUELO
// (wrk_p1, un FF), sin esperar al comparador de tags que lee de la BSRAM
// (sc_tag DO -> wrk_hit -> CE de los 4096 sc_v era la familia critica).
// Efecto: con write y fill simultaneos el fill espera 1 ciclo aunque el
// write no fuera a usar el puerto — bookkeeping, fuera del camino de 8.
wire fill_now = fill_pend && !wrk_p1 && scv_ready;
wire [11:0] scw_idx = wrk_hit ? c_idx(wrk_addr1) : c_idx(fill_addr);
wire scw_we0 = (wrk_hit && !wrk_mask1[0]) || fill_now;
wire scw_we1 = (wrk_hit && !wrk_mask1[1]) || fill_now;
wire scw_we2 = (wrk_hit && !wrk_mask1[2]) || fill_now;
wire scw_we3 = (wrk_hit && !wrk_mask1[3]) || fill_now;
wire [7:0] scw_b0 = wrk_hit ? wrk_data1[ 7: 0] : fill_word[ 7: 0];
wire [7:0] scw_b1 = wrk_hit ? wrk_data1[15: 8] : fill_word[15: 8];
wire [7:0] scw_b2 = wrk_hit ? wrk_data1[23:16] : fill_word[23:16];
wire [7:0] scw_b3 = wrk_hit ? wrk_data1[31:24] : fill_word[31:24];

// ---- BSRAMs de la cache: bloques DEDICADOS sin reset (inferencia limpia;
// leccion _117a — nada de lecturas asincronas de arrays grandes) ----
always @(posedge clk_vdp) begin
    if (scw_we0) sc_d0[scw_idx] <= scw_b0;
    scq_d0 <= sc_d0[c_idx(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we1) sc_d1[scw_idx] <= scw_b1;
    scq_d1 <= sc_d1[c_idx(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we2) sc_d2[scw_idx] <= scw_b2;
    scq_d2 <= sc_d2[c_idx(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we3) sc_d3[scw_idx] <= scw_b3;
    scq_d3 <= sc_d3[c_idx(vram_address)];
end
always @(posedge clk_vdp) begin
    if (fill_now) sc_tag[c_idx(fill_addr)] <= fill_addr[15:12];
    scq_tag <= sc_tag[c_idx(vram_address)];
end
// _120d: puerto BSRAM de los valids (write-site unico muxeado + lectura
// gated: durante el barrido post-reset todo se lee como invalido)
wire        scv_we = !scv_ready || fill_now;
wire [11:0] scv_wi = !scv_ready ? scv_swp[11:0] : c_idx(fill_addr);
always @(posedge clk_vdp) begin
    if (scv_we) sc_v[scv_wi] <= scv_ready;
    scq_v <= scv_ready ? sc_v[c_idx(vram_address)] : 1'b0;
end

// ---- BSRAM de la VENTANA (v4): 1R muxeado + 1W del backend ----
// _120c: el camino fisico pww_data->DI de la BSRAM era tan corto que
// violaba HOLD (-0.05ns por skew del arbol de reloj al macro), y todo
// buffer de paso (XOR+syn_keep, LUT1 explicitas) fue barrido por el
// optimizador. Fix estructural: recapturar el dato en FLANCO NEGATIVO.
// pww_tag/pww_data son registros estables el ciclo entero, la media
// etapa los recaptura a mitad de ciclo y la BSRAM (posedge) los ve
// estables ~5.8ns a cada lado de su flanco: hold y setup por
// construccion. pww_en/pww_idx no cambian (sus caminos no violaban).
reg [41:0] pww_word_n;
reg  [7:0] pww_idx_n;
reg        pww_en_n;
always @(negedge clk_vdp) begin
    pww_word_n <= {pww_tag, pww_data};
    pww_idx_n  <= pww_idx;
    pww_en_n   <= pww_en;
end
// _123: el OBL CEDIA el puerto de lectura a TODO vram_valid entrante (fix
// de la "linea barredora": antes obl_pend ganaba el mux y el fetch de ese
// ciclo leia el slot equivocado -> miss espurio / invalidacion perdida).
// _126: la cesion creo el hambre SIMETRICA — un chorro de comandos (HMMV
// SC8) no deja NINGUN ciclo libre, el OBL no resiembra la ventana y la
// linea siguiente nace fria (radiografia del TB sc8cmd_full: 16k misses
// con pfq=0 rq=0 y wv=1 = rectangulos despedazados de la foto 4297).
// Fix estructural: ESPEJO de TAGs pw_tagB solo-OBL con el MISMO write-site
// (cada array queda 1W+1R limpio) — el OBL lee SIEMPRE al ciclo siguiente
// y el fetch/write-check conserva pw_mem en exclusiva. Cero contencion en
// ambos sentidos, 256x42b extra de BSRAM.
wire       obl_read_now = obl_pend;
wire [7:0] pw_ridx = w_idx(vram_address);
always @(posedge clk_vdp) begin
    if (pww_en_n) pw_mem[pww_idx_n] <= pww_word_n;
    pwq <= pw_mem[pw_ridx];
end
// _126e: el espejo solo necesita el TAG (el obl_do compara pwqB[41:32] y
// el valid; el dato nunca se lee) — 256x10 en LUTRAM distribuida en vez
// de una BSRAM entera: las columnas BSRAM son escasas y el macro extra
// desplazaba el placement del motor de comandos (8 dados seguidos
// violando conos ff_command/ff_ny_b que en la _125 cerraban).
reg [9:0]  pw_tagB [0:255];              // espejo de TAGs — lector: solo OBL
reg [9:0]  pwqB_tag;
always @(posedge clk_vdp) begin
    if (pww_en_n) pw_tagB[pww_idx_n] <= pww_word_n[41:32];
    pwqB_tag <= pw_tagB[w_idx(obl_w)];
end
reg        pwqB_v;

wire [21:0] sd_base = VRAM_BASE + {4'd0, cur_addrw, 2'b00};
wire [15:0] nxt_w   = vram_address[17:2] + 16'd1;   // palabra siguiente (OBL)
// primer byte habilitado que queda en la mascara de la escritura en curso
wire [1:0]  nxt_byte = cur_mask[0] ? 2'd0 : cur_mask[1] ? 2'd1
                     : cur_mask[2] ? 2'd2 : 2'd3;

always @(posedge clk_vdp or negedge rst_n) begin
    if (!rst_n) begin
        pw_v <= 256'd0; scv_swp <= 13'd0; pfq_wp <= 0; pfq_rp <= 0;
        wq_wp <= 0; wq_rp <= 0; rq_wp <= 0; rq_rp <= 0; wq_vld <= 8'd0;
        bsy <= 0; done_d <= 0; done2_d <= 0; got_lo <= 0; got_hi <= 0;
        pwv_set_p <= 0; pwv_set_i <= 0;
        word_pend <= 0;
        cur_kind <= 0; cur_half <= 0; cur_addrw <= 0; cur_tag <= 0;
        bk2_req <= 0; bk2_addr <= 0;
        cur_word <= 0; cur_mask <= 0; cur_wbyte <= 0;
        late_v <= 0; late_tag <= 0; late_data <= 0;
        bk_req <= 0; bk_we <= 0; bk_addr <= 0; bk_wdata <= 0;
        vram_rdata <= 0; vram_rdata_en <= 0; vram_rtag <= 0;
        bg_miss <= 0;
        c_miss <= 0; c_bka <= 0; c_bkb <= 0;
        spr_p1 <= 0; spr_addr1 <= 0; spr_tag1 <= 0;
        wrk_p1 <= 0; wrk_addr1 <= 0; wrk_data1 <= 0; wrk_mask1 <= 4'hF;
        obl_pend <= 0; obl_chk <= 0; obl_do <= 0; obl_w <= 0;
        obl_w_c <= 0; obl_w_d <= 0;
        bgp_wp <= 0; bgp_rp <= 0; c_park <= 0; c_pkov <= 0;
        pfB_pend <= 0; pfB_wr <= 0;
        fill_pend <= 0; fill_addr <= 0; fill_word <= 0;
        pwq_v <= 0;
        pww_en <= 0; pww_idx <= 0; pww_tag <= 0; pww_data <= 0;
        for (pi = 0; pi < 7; pi = pi + 1) pipe[pi] <= 38'd0;
    end
    else begin
        bk_req  <= 1'b0;
        bk2_req <= 1'b0;
        done_d  <= bk_done_t;
        done2_d <= bk2_done_t;
        if (bk_done_t  != done_d)  c_bka <= c_bka + 32'd1;
        if (bk2_done_t != done2_d) c_bkb <= c_bkb + 32'd1;
        spr_p1 <= 1'b0;
        wrk_p1 <= 1'b0;
        pww_en <= 1'b0;
        pwq_v  <= pw_v[pw_ridx];
        pwqB_v <= pw_v[w_idx(obl_w)];    // _126: valid del espejo OBL
        if (!scv_ready) scv_swp <= scv_swp + 13'd1;
        // _120: el valid de la VENTANA se pone UN CICLO DESPUES de la
        // completacion — la media etapa negedge hace que el dato aterrice
        // en la BSRAM en T+1, y poner pw_v en T dejaba 1 ciclo de "valid
        // con dato viejo" (a ritmo SC8, con fetch pegado al fill, se
        // servia rancio). El set va ANTES del write-check: si ambos tocan
        // el mismo indice en el mismo ciclo, gana la INVALIDACION.
        pwv_set_p <= 1'b0;
        if (pwv_set_p) pw_v[pwv_set_i] <= 1'b1;
        if (fill_now) fill_pend <= 1'b0;

        // ---------- tuberia de 8 ciclos + salida ----------
        // salida: etapa 6 (si valida) gana el bus de respuesta; si no, una
        // respuesta tardia pendiente (rq) usa el hueco.
        if (pipe[6][37]) begin
            vram_rdata_en <= 1'b1;
            vram_rtag     <= pipe[6][36:32];
            vram_rdata    <= pipe[6][31:0];
        end
        else if (late_v) begin
            vram_rdata_en <= 1'b1;
            vram_rtag     <= late_tag;
            vram_rdata    <= late_data;
            late_v        <= 1'b0;
        end
        else vram_rdata_en <= 1'b0;
        for (pi = 6; pi > 0; pi = pi - 1) pipe[pi] <= pipe[pi-1];
        pipe[0] <= 38'd0;
        // (_126: el S6_hijack ya no existe — el OBL tiene su BSRAM espejo)

        // ---------- write-check de la VENTANA (v4, etapa 1): invalidacion
        // por coherencia si el tag leido de la BSRAM casa ----
        if (wrk_p1 && pwq_v && pwq[41:32] == wrk_addr1[15:6])
            pw_v[w_idx(wrk_addr1)] <= 1'b0;

        // ---------- OBL en TRES fases (_121b) — _126: con el ESPEJO pw_tagB
        // el OBL ya no cede puerto: dispara SIEMPRE al ciclo siguiente del
        // hit (obl_pend se consume solo). La direccion sigue viajando en
        // sombras (obl_w_c/_d) para que un hit nuevo pise obl_w sin
        // corromper la fase en vuelo.
        obl_pend <= 1'b0;                       // consumido (el hit lo re-arma)
        obl_chk  <= obl_read_now;
        obl_w_c  <= obl_w;
        obl_do   <= obl_chk && !(pwqB_v && pwqB_tag == obl_w_c[15:6]);
        obl_w_d  <= obl_w_c;
        pfB_pend <= 1'b0;                // default; las ramas de spr_p1 lo
                                         // suben (asignacion posterior gana)

        // ---------- etapa 1 UNIFICADA del lookup (v4): VENTANA + CACHE ----
        // Todo fetch (bg/sprite/CPU/comando) llega aqui con las lecturas
        // BSRAM ya en pwq/scq. Prioridad: ventana (solo bg, streaming) ->
        // cache (tablas residentes) -> backend. HIT -> pipe[1]: emerge a
        // 8 ciclos EXACTOS (fetch T, pipe[1] T+1, pipe[6] T+6, en T+7).
        if (spr_p1) begin
            if (spr_tag1[4:2] == C_BG && pwq_v &&
                pwq[41:32] == spr_addr1[15:6]) begin
                // HIT de VENTANA: dato + OBL (fase 2)
                // _122 probo prefetch +2 y ventana 256 contra la "linea
                // barredora" — NO ERA ESO (59 miss/s intactos en HW): el
                // culpable era el SECUESTRO del puerto pw_ridx por obl_pend
                // (ver _123 arriba). El +2 se queda: mas colchon gratis.
                pipe[1] <= {1'b1, spr_tag1, pwq[31:0]};
                if (obl_pend) begin
                    // _123: el OBL anterior cedio el puerto y aun no corrio;
                    // se rescata su direccion a pfq (via pfB_pend, registrado).
                    pfB_pend <= 1'b1;
                    pfB_wr   <= obl_w;
                end
                obl_pend <= 1'b1;
                obl_w    <= spr_addr1 + 16'd2;
            end
            else if (scq_v && scq_tag == spr_addr1[15:12])
                pipe[1] <= {1'b1, spr_tag1, {scq_d3, scq_d2, scq_d1, scq_d0}};
            else begin
                // MISS de cache: backend + fill al volver. bg/sprite encolan
                // con reserva (drop tolerable, se autocuran); CPU/COMANDO
                // encolan SIEMPRE (con 8 plazas, 1-en-vuelo cada uno y la
                // reserva de bg/sprite, nunca encuentran lleno).
                if (spr_tag1[4:2] == C_BG || spr_tag1[4:2] == C_SPRITE) begin
                    if (rq_room_soft) begin
                        rq[rq_wp] <= {spr_tag1, spr_addr1};
                        rq_wp <= rq_wp + 4'd1;
                    end
                    else begin
                        // _123/_124: APARCAR en vez de descartar (fix linea
                        // barredora); FIFO de 4 para las rafagas bg+bg.
                        if (!bgp_full) begin
                            bgp[bgp_wp] <= {spr_tag1, spr_addr1};
                            bgp_wp <= bgp_wp + 2'd1;
                        end
                        else begin
                            c_pkov <= c_pkov + 16'd1;
`ifdef SHIM_DBG_DROPS
                            $display("DROP S3b_park_lleno t=%0t addr=%h tag=%h", $time, spr_addr1, spr_tag1);
`endif
                        end
                    end
                end
                else if (!rq_full) begin
                    rq[rq_wp] <= {spr_tag1, spr_addr1};
                    rq_wp <= rq_wp + 4'd1;
                end
                if (spr_tag1[4:2] == C_BG) begin
                    // bg: cuenta el miss y arranca el stream OBL (bitmap).
                    // _122: siembra COMPLETA de la cadena +2 — el +1 va
                    // directo a pfq y el +2 via OBL (fase 2, un ciclo
                    // despues: sin colision en el puerto de pfq).
                    bg_miss <= bg_miss + 8'd1;
                    c_miss  <= c_miss + 32'd1;
                    pfB_pend <= 1'b1;            // semilla +1 (registrada; si
                    pfB_wr   <= spr_addr1 + 16'd1; // habia OBL retenido cede:
                                                 // el miss resiembra la cadena)
                    obl_pend <= 1'b1;
                    obl_w    <= spr_addr1 + 16'd2;
                    // _124: DEGRADACION ELEGANTE — el aparcamiento cura el
                    // fill posterior pero NO el guion del PRIMER miss (el
                    // consumidor muestrea a 8 ciclos fijos, pillara lo que
                    // haya). Si el slot de ventana es valido con tag ajeno,
                    // servir el dato RANCIO (contenido de ~4 lineas antes,
                    // casi siempre identico en bitmap) en vez de basura:
                    // el guion visible se vuelve imperceptible sea cual sea
                    // la causa del miss. El miss se sigue contando y el
                    // fill llega igual por detras (autocura real).
                    if (pwq_v)
                        pipe[1] <= {1'b1, spr_tag1, pwq[31:0]};
                end
            end
        end

        // ---------- drenaje del aparcamiento bg/sprite (_123) ----------
        if (!bgp_empty && rq_room_soft && !spr_p1) begin
            rq[rq_wp] <= bgp[bgp_rp];
            rq_wp <= rq_wp + 4'd1;
            bgp_rp <= bgp_rp + 2'd1;
            c_park <= c_park + 16'd1;
        end

        // ---------- push UNIFICADO de pfq (_123b): hasta 2 por ciclo, TODO
        // desde registros (obl_do/obl_w_d y pfB_pend/pfB_wr) — sin la familia
        // pw_mem DO -> pfq. Antes obl_do y la semilla del miss podian escribir
        // el MISMO slot en el mismo ciclo (pisada silenciosa). Con hueco para
        // uno solo gana la semilla (consumidor inminente).
        if (obl_do && pfB_pend && !pfq_full && (pfq_wp + 3'd2 != pfq_rp)) begin
            pfq[pfq_wp]        <= obl_w_d;
            pfq[pfq_wp + 3'd1] <= pfB_wr;
            pfq_wp <= pfq_wp + 3'd2;
        end
        else if (pfB_pend && !pfq_full) begin
            pfq[pfq_wp] <= pfB_wr;
            pfq_wp <= pfq_wp + 3'd1;
        end
        else if (obl_do && !pfq_full) begin
            pfq[pfq_wp] <= obl_w_d;
            pfq_wp <= pfq_wp + 3'd1;
        end
`ifdef SHIM_DBG_DROPS
        if ((obl_do || pfB_pend) && pfq_full)
            $display("DROP S1_pfq_full t=%0t A=%b:%h B=%b:%h", $time, obl_do, obl_w_d, pfB_pend, pfB_wr);
        else if (obl_do && pfB_pend && (pfq_wp + 3'd2 == pfq_rp))
            $display("DROP S1b_room1_pierde_A t=%0t A=%h", $time, obl_w_d);
`endif

        // ---------- aceptar peticion del VDP ----------
        if (vram_valid) begin
            if (vram_write) begin
                if (!wq_full) begin
                    // OJO: vram_wdata_mask es estilo DQM (1 = byte ENMASCARADO,
                    // no se escribe) — vdp_vram_interface pone 4'b1110 para el
                    // byte 0. En la cola se guarda INVERTIDA (1 = escribir).
                    wq[wq_wp] <= {~vram_wdata_mask, vram_wdata, vram_address};
                    wq_vld[wq_wp] <= 1'b1;
                    wq_wp <= wq_wp + 3'd1;
                end
`ifdef SHIM_DBG_DROPS
                else $display("DROP S5_wq_full t=%0t addr=%h", $time, vram_address);
`endif
                // write-check (etapa 1): compara los tags BSRAM y aplica el
                // update de cache byte a byte / la invalidacion de ventana
                wrk_p1    <= 1'b1;
                wrk_addr1 <= vram_address;
                wrk_data1 <= vram_wdata;
                wrk_mask1 <= vram_wdata_mask;
            end
            else begin
                // sprite / CPU / comando: lookup en la CACHE (v3c: la CPU
                // lee con PRE-FETCH del interface y el BIOS hace SETRD+IN
                // en ~2us — el backend a ~1us llegaba TARDE y el buffer
                // devolvia el dato ANTERIOR = el rastro del cursor en HW.
                // Con NT/PGT residentes, el hit responde en 8 ciclos.)
                spr_p1    <= 1'b1;
                spr_addr1 <= vram_address;
                spr_tag1  <= vram_tag;
            end
        end

        // ---------- backend: completar op en vuelo (_120: DOS CANALES —
        // los modos de 256B/linea (SC7/8/12) piden 1 palabra/730ns y UN
        // canal (2 ops seriales de 16b con su CDC) daba ~800ns: deficit
        // estructural. Las lecturas de palabra piden ahora las DOS mitades
        // EN PARALELO: bk=baja, bk2=alta (puerto wv3 + segundo bridge).
        // Las escrituras siguen byte a byte por bk.) ----------
        if (bsy && cur_kind == 2'd2 && (bk_done_t != done_d)) begin
            // escritura: byte hecho -> fuera de la mascara; si no queda
            // ninguno, palabra terminada (el lanzador coge el siguiente
            // habilitado via nxt_byte).
            bsy <= 1'b0;
            cur_mask[cur_wbyte] <= 1'b0;
            if ((cur_mask & ~(4'd1 << cur_wbyte)) == 4'd0)
                word_pend <= 1'b0;
        end
        if (bsy && cur_kind != 2'd2) begin : rd_complete
            reg lo_now, hi_now;
            reg [15:0] w_lo, w_hi;
            lo_now = (bk_done_t  != done_d);
            hi_now = (bk2_done_t != done2_d);
            w_lo = lo_now ? bk_rword  : cur_word[15:0];
            w_hi = hi_now ? bk2_rword : cur_word[31:16];
            if (lo_now) begin cur_word[15:0]  <= bk_rword;  got_lo <= 1'b1; end
            if (hi_now) begin cur_word[31:16] <= bk2_rword; got_hi <= 1'b1; end
            if ((got_lo || lo_now) && (got_hi || hi_now)) begin
                bsy <= 1'b0;
                if (cur_kind == 2'd0) begin
                    // fill de ventana via registros pww (write-site BSRAM)
                    // _126: descartado si hay escritura pendiente al word
                    if (!pf_dirty) begin
                        pww_en   <= 1'b1;
                        pww_idx  <= w_idx(cur_addrw);
                        pww_tag  <= cur_addrw[15:6];
                        pww_data <= {w_hi, w_lo};
                        pwv_set_p <= 1'b1;
                        pwv_set_i <= w_idx(cur_addrw);
                    end
                end
                else begin
                    late_v    <= 1'b1;
                    late_tag  <= cur_tag;
                    late_data <= {w_hi, w_lo};
                    // y de paso a la ventana si es bg (_126: mismo descarte)
                    if (cur_tag[4:2] == C_BG && !pf_dirty) begin
                        pww_en   <= 1'b1;
                        pww_idx  <= w_idx(cur_addrw);
                        pww_tag  <= cur_addrw[15:6];
                        pww_data <= {w_hi, w_lo};
                        pwv_set_p <= 1'b1;
                        pwv_set_i <= w_idx(cur_addrw);
                    end
                    // ...y a la CACHE (v3c: TODO consumidor de lectura
                    // rellena — bg/sprite/CPU/comando) — via fill_pend
                    // (_126: tambien descartado si el word esta sucio)
                    if (!pf_dirty) begin
                        fill_pend <= 1'b1;
                        fill_addr <= cur_addrw;
                        fill_word <= {w_hi, w_lo};
                    end
                end
            end
        end

        // ---------- backend: lanzar siguiente op ----------
        if (!bsy) begin
            if (word_pend) begin
                // solo ESCRITURAS (las lecturas ya no continúan: sus dos
                // mitades salieron juntas): siguiente byte HABILITADO de la
                // mascara (el completado ya se borro de cur_mask)
                bsy <= 1'b1; bk_req <= 1'b1;
                bk_we     <= 1'b1;
                cur_wbyte <= nxt_byte;
                bk_addr   <= sd_base | {20'd0, nxt_byte};
                bk_wdata  <= cur_word[8*nxt_byte +: 8];
            end
            // _126 (definitivo): PANTALLA > ESCRITURAS > LECTURAS-DEMANDA.
            //  1. pfq (streaming de ventana) — sagrado: el pipe de 8 ciclos
            //     no puede esperar a la SDRAM; cada miss de ventana es
            //     basura visible (16k/frame con wq primero = rectangulos
            //     SC8 despedazados; medido 73 con pfq primero).
            //  2. wq antes que rq: la coherencia write->read GLOBAL sale
            //     gratis (un read nunca adelanta a una escritura mas
            //     vieja). El unico que salta escrituras es el prefetch,
            //     y su hazard lo cubre pf_dirty descartando el fill.
            //  3. rq al final: CPU/sprite/dest-de-comando esperan lo que
            //     haya — wq esta acotada (stall del interface a 2) y pfq
            //     por el ritmo del display; el peor caso es ~us, igual
            //     que los slots de CPU del VDP real en linea activa.
            else if (!pfq_empty) begin
                cur_kind  <= 2'd0;
                cur_addrw <= pfq[pfq_rp];
                pfq_rp    <= pfq_rp + 3'd1;
                got_lo <= 1'b0; got_hi <= 1'b0;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b0;
                bk_addr  <= VRAM_BASE + {4'd0, pfq[pfq_rp], 2'b00};
                bk2_req  <= 1'b1;
                bk2_addr <= (VRAM_BASE + {4'd0, pfq[pfq_rp], 2'b00}) | 22'd2;
            end
            else if (!wq_empty) begin
                cur_kind  <= 2'd2;
                cur_addrw <= wq[wq_rp][15:0];
                cur_word  <= wq[wq_rp][47:16];
                cur_mask  <= wq[wq_rp][51:48];
                wq_vld[wq_rp] <= 1'b0;
                wq_rp     <= wq_rp + 3'd1;
                // primer byte habilitado de la mascara
                begin : first_byte
                    reg [1:0] fb;
                    fb = wq[wq_rp][48] ? 2'd0 : wq[wq_rp][49] ? 2'd1
                       : wq[wq_rp][50] ? 2'd2 : 2'd3;
                    cur_wbyte <= fb;
                    bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b1;
                    bk_addr  <= VRAM_BASE + {4'd0, wq[wq_rp][15:0], 2'b00}
                                | {20'd0, fb};
                    bk_wdata <= wq[wq_rp][16 + 8*fb +: 8];
                    word_pend <= |(wq[wq_rp][51:48] >> (fb + 1));
                end
            end
            else if (!rq_empty && !late_v) begin     // no pisar la tardia
                cur_kind  <= 2'd1;
                cur_tag   <= rq[rq_rp][20:16];
                cur_addrw <= rq[rq_rp][15:0];
                rq_rp     <= rq_rp + 4'd1;
                got_lo <= 1'b0; got_hi <= 1'b0;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b0;
                bk_addr  <= VRAM_BASE + {4'd0, rq[rq_rp][15:0], 2'b00};
                bk2_req  <= 1'b1;
                bk2_addr <= (VRAM_BASE + {4'd0, rq[rq_rp][15:0], 2'b00}) | 22'd2;
            end
        end
    end
end

endmodule
