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
//   * ESCRITURAS: cola de 8, UNA OP DE PALABRA por entrada (_148 FIX B: antes
//     byte a byte — hasta 4 ops de backend por palabra, 3.81 medidas, que
//     saturaban el canal A al 89% y mataban de hambre a los prefetch de
//     pantalla). La mascara de bytes viaja con el dato (bk_wmask).
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
    // _148 FIX B (COALESCING DE ESCRITURA): bk_wdata pasa de 8 a 32 bits y se
    // anade bk_wmask (1 = escribir ese byte, ya invertida respecto a la DQM del
    // VDP). UNA operacion de backend por PALABRA en vez de hasta 4 byte-ops.
    // En escrituras bk_addr queda alineada a palabra (addr[1:0] = 00).
    output reg  [31:0] bk_wdata,
    output reg  [3:0]  bk_wmask,
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
    // desbordaban wq (backend byte-a-byte ~1.6us/palabra; _148 FIX B: 1 op de
    // palabra ~0.4us, el stall salta MUCHO menos) y los
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
// _148 FIX A — LA CACHE PASA A 8192 LINEAS (32KB). El indice tenia 12 bits y
// NO contenia L[14] (=v[12]): dos direcciones separadas EXACTAMENTE 16KB caen
// SIEMPRE en la misma linea y se desalojan a muerte. En sprites mode 3 eso es
// mortal porque ese camino NO usa el entrelazado del V9938
// (vdp_timing_control_screen_mode.v:208 -> los sprites direccionan plano), asi
// que los patrones que difieren en 0x80 (p y p+8 con pattern = p*16, es decir
// p*2048 bytes) caen a 16KB EXACTOS: medido 32.19 miss/scanline en el modelo y
// 20.0% de miss de fetch de sprite en tb_sprite3. Con v[12] METIDO EN EL INDICE
// como bit ALTO el modelo baja a 0.38 miss/scanline (peor caso de 13 layouts).
// El TAG NO CAMBIA (sigue v[15:12], 4 bits): v[12] queda duplicado en indice y
// tag, lo cual es INOFENSIVO (un bit de tag redundante) y mantiene el
// comparador y el ancho de sc_tag intactos.
// BIYECTIVIDAD VERIFICADA por enumeracion de las 65536 palabras de L[17:2] con
// la funcion RTL EXACTA de abajo: 65536 claves (idx13,tag4) distintas, cero
// colisiones. Un indice no biyectivo daria FALSOS HIT = corrupcion silenciosa.
// COSTE: +9 bloques BSRAM de 18Kb (4 lanes de datos +2 c/u, sc_tag +1, sc_v +0).
//
// RESIDUO CONOCIDO (medido: 20.0% -> 0.33% de miss de sprite en tb_sprite3, NO
// 0%). Lo que queda es UN choque de indice concreto del layout del DEVCON:
//   SPT en 0x8000 -> palabra v = 0x2000 + p*512 + yl*32 + j  (v[14]=0, sin
//        pliegue) => idx13 = p*512 + yl*32 + j
//   SAT en 0x10000 -> palabra v = 0x4000 + p*2 + m  (v[14]=1 => el pliegue XOR
//        le suma 0x800) => idx13 = 0x800 + p*2 + m
//   El plano p=4 con linea fuente yl=0 cae en idx13 = 4*512 = 0x800..0x801,
//   EXACTAMENTE encima de la entrada de SAT del plano 0. Como la SAT se relee
//   en CADA scanline, esas dos lineas hacen ping-pong en las ~3 scanlines en
//   que el sprite 4 muestra su linea 0. Es el UNICO conflicto que sobrevive
//   (los 512 patrones son biyectivos entre si; la SAT ocupa 0x800..0x81F).
// Matarlo del todo pide ASOCIATIVIDAD, no mas lineas: el modelo (sc_bijective.py)
// da 0.00 miss/scanline con un victim buffer de 4 entradas sobre esta misma
// cache de 8192. Queda como trabajo futuro: 23 miss/frame no producen NINGUNA
// diferencia de pixel (ver el diff contra la referencia dorada), y un victim
// buffer es logica NUEVA en el camino de 8 ciclos = riesgo de timing.
//
// CACHE DE TABLAS (v3): 8192 palabras de 32b (32KB) direct-mapped, indice de 13
// bits (ver c_idx13), tag addr[17:14]. Sirve a DOS consumidores de fase fija:
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
reg [7:0]  sc_d0 [0:8191];               // lane byte 0 (BSRAM) — _148 FIX A: 8192
reg [7:0]  sc_d1 [0:8191];
reg [7:0]  sc_d2 [0:8191];
reg [7:0]  sc_d3 [0:8191];
reg [3:0]  sc_tag [0:8191];              // addr[17:14] (BSRAM)
reg sc_v [0:8191];                       // _120d: valids EN BSRAM 8192x1 —
                                         // los FF con su mux y el decode de CE
                                         // eran el reincidente de placement
                                         // (r2/r9/_122). sc_v es SET-ONLY salvo
                                         // reset -> BSRAM con BARRIDO de
                                         // limpieza post-reset (_148: 8192
                                         // ciclos ~95us, con miss forzado
                                         // mientras tanto; el doble que antes,
                                         // sigue siendo <2 frames de arranque).
reg [13:0] scv_swp;                      // contador del barrido (_148: 14 bits)
wire       scv_ready = scv_swp[13];

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
// _147 PROFUNDIDAD DE PREFETCH (lookahead OBL) — HIPOTESIS REFUTADA, se queda 2.
// Hipotesis: con el DDR3 real (191ns media, 757ns PICO = ~8 palabras a 93ns/
// palabra) el colchon de +2 llega TARDE en los picos -> subir el lookahead
// absorberia los 12 miss/frame de la rafaga de dibujo (menu/logo).
// BARRIDO en el modelo DDR3 REAL (tb_menu_ddr3, obl_la = 2/4/6/8, fallos_vram=0
// en todos): la RAFAGA EMPEORA monotona 12->13->16->18 miss/frame y el REPOSO
// sube EXACTO con obl_la (2/4/6/8). Los miss NO son inanicion mid-stream (mas
// profundidad no ayuda): son (a) coste de CALENTAMIENTO al rearrancar el stream
// (obl_la palabras hasta que el buffer profundo se llena tras cada corte de
// cadena: vblank / invalidacion) — CRECE con el lookahead; y (b) un suelo ~10
// miss/frame INDEPENDIENTE de la profundidad, inducido por las ESCRITURAS
// (colision fill<->escritura pendiente via pf_dirty; palabras recien escritas
// aun no residentes). El <3/frame NO se alcanza por profundidad de prefetch; el
// unico lever real es un write-allocate de PALABRA COMPLETA (riesgo: bytes no
// escritos quedarian rancios) — fuera del alcance de este cambio. obl_la=2 es
// identico al +2 historico; el knob deja el experimento documentado.
localparam [15:0] obl_la = 16'd2;
// _127: PREDICCION DE ZANCADA. El scroll H rompe el stream +1 DOS veces
// por linea (arranque y wrap del ring): ~28k px rancios/frame en
// tb_scroll (las franjas de la foto 4300). Parchear la oferta no vale
// (la rafaga tras miss EMPEORO: 506k, fetches duplicados); la solucion
// es PREDECIR: en bitmap el fetch de la linea N+1 es EXACTAMENTE el de
// la N desplazado UNA ZANCADA (32 palabras SC5/6, 64 SC7/8/12) —
// incluidos los dos saltos del scroll H. El OBL prefetchea addr+stride
// (la misma columna de la linea siguiente): prediccion perfecta, mismo
// trafico que el +2 de antes, cero duplicados.
// La zancada se aprende DEL PROPIO WRAP del ring, POR STREAM FISICO:
// con el entrelazado {a17,a0,a16:1} el bg llega como DOS streams (pares
// e impares, bit 14 del vector) en ping-pong ±16384 — radiografia del
// tb_scroll: cada stream avanza +1 y el wrap del scroll H aparece como
// delta -31 (SC8: ring de 32 palabras/stream) DENTRO de su stream,
// compuesto con el salto de stream si se mira el bus plano (por eso un
// aprendiz de stream unico es CIEGO). stride = 1 - delta_por_stream =
// palabras/linea/stream (16 SC5/6, 32 SC7/8/12), saneada a
// {8,16,32,64}; una vez aprendida vale tambien para el caso lineal (la
// linea N+1 del mismo stream sigue a +stride).
reg [15:0] bg_prev0, bg_prev1;           // ultimo fetch bg POR STREAM
reg [15:0] stride;                       // zancada aprendida (0 = no)
// _127J EL CAMINANTE: la radiografia (tb_scroll +SHIM_DBG_DROPS) enseno que
// CADA linea se fetchea DOS VECES (line-doubling): el 2o pase aparece como
// wrap -31 POR LINEA (6912 wraps, todos stride=32, ya en quiet) y durante
// ese pase el OBL esta OCIOSO (todos sus +2 ya residen -> espejo filtra).
// Los intentos de ANADIR trafico fracasaron TODOS (el presupuesto es ~1
// fetch por palabra consumida: dual-reseed = 48851 drops pfq_full y quiet
// 232->357004). El caminante NO anade: cuando el objetivo +2 YA RESIDE y
// hay zancada, re-apunta ese slot ocioso a la MISMA palabra de la LINEA
// SIGUIENTE (obl_w_c + stride - 2 = addr_hit + stride). Una sola vez por
// slot (correa obl_walked; sin ella el lazo de 3 fases se desboca +stride
// cada ~3 ciclos). Efecto: el 2o pase pre-calienta la linea N+1 ENTERA con
// su patron de wrap del scroll H incluido, a coste CERO de trafico.
reg        obl_walked;                   // correa: 1 walk por slot OBL
reg [15:0] wk_tgt;                       // objetivo del walk REGISTRADO (el
                                         // sumador +stride-2 fuera del cono
                                         // de obl_w: obl_w es estable desde
                                         // el hit hasta la fase 3, el valor
                                         // registrado es identico; 9 dados
                                         // seguidos violando las familias
                                         // cronicas con el sumador en linea)
// (_127J-c ECO DEL MISS: RETIRADO para la build — con el eco en el
// netlist las familias cronicas de placement violaron 24 dados
// seguidos (_127I sin el cerro a la primera). El eco vive en git
// (5825684) para reintentarlo tras entender la loteria.)
// (_127J-b, RETIRADO: un "pre-calentador de vblank" con detector de hueco
// resulto CODIGO MUERTO — la radiografia de deltas entre wraps demostro que
// el V9968 fetchea bg de forma CONTINUA tambien durante el blanking, solo
// que lineal y sin wraps: nunca hay hueco >8192 ciclos que detectar.)
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

// cola de escrituras (8 plazas: {mask,wdata,addr}; _148 FIX B: cada entrada
// es UNA op de backend, no hasta 4)
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
reg        pkov_p;                             // _127: pisada, registrada 1 ciclo

// _135 ECO DE ARRANQUE (residuo del hscroll, informe 23/07): el relevo +2
// es v-lineal y con el ring rotado por R#26 NADIE produce a tiempo las
// columnas s/s+1 del arranque de cada linea (miss autoperpetuante en las
// 191 lineas). Cura: el HUECO de hblank (silencio de bg > ~256 ciclos)
// arma 2 creditos por stream; los 2 primeros fetches bg de la linea (hit
// O miss — se tapea spr_p1 REGISTRADO, sin tocar el cono de pwq/pw_mem ni
// el mux de push de pfq, los dos puntos quemados por la loteria) encolan
// addr+stride en esta cola lateral, drenada SOLO con todo ocioso (4o
// brazo del lanzador). +4 palabras/linea ~ +6%, servidas en tiempo muerto
// (el hblank tiene ~16us sin BK RD; el deadline real es la linea, 63us).
reg [15:0] ecq [0:3];                          // addr[17:2] linea siguiente
reg [1:0]  ecq_wp, ecq_rp;
wire       ecq_empty = (ecq_wp == ecq_rp);
wire       ecq_full  = (ecq_wp + 2'd1 == ecq_rp);
reg [8:0]  bg_quiet;                           // silencio de bg (satura en 256)
reg [1:0]  ec_cred0, ec_cred1;                 // creditos por stream (bit14)

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
// _148 FIX C — TELEMETRIA DE SPRITE. c_miss solo cuenta miss de FONDO: en
// placa los sprites podian estar fallando el 20% de sus fetches y COM11 no
// decia NADA (el DEVCON con las cabezas rayadas paso por aqui invisible).
// c_spmiss/c_spfet son el par gemelo del camino de sprite (C_SPRITE=2):
//   c_spfet  = fetches de sprite que llegan a la etapa 1 del lookup
//   c_spmiss = los que fallan la sc-cache (van al backend)
// Sano tras el FIX A: c_spmiss/c_spfet < 0.1%.
reg [31:0] c_spmiss, c_spfet;
// PALABRA A DE COM11 (dbg_uart.cnt_a) REEMPAQUETADA:
//   bits [31:16] = c_spmiss[15:0]   (miss de SPRITE)
//   bits [15: 0] = c_miss[15:0]     (miss de FONDO, como siempre pero a 16b)
// A 60 fps y <=5 miss/frame un contador de 16 bits tarda ~3.6 min en dar la
// vuelta: de sobra para telemetria (el lector mira la DERIVADA, no el valor).
// dbg_audio_reader.py: word[0] -> spmiss = int(w,16)>>16, bgmiss = int(w,16)&0xFFFF.
assign dbg_miss = {c_spmiss[15:0], c_miss[15:0]};
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
reg [31:0] cur_word;                     // acumulador de lectura
// _148 FIX B — MAQUINARIA DE ESCRITURA BYTE-A-BYTE RETIRADA. Ya no existen:
//   cur_mask / cur_wbyte / nxt_byte  (byte en curso y mascara restante)
//   word_pend                        (palabra de 32b "en construccion")
//   wr_addrw / wr_word / sd_base     (estado de la escritura SUSPENDIDA)
// Con UNA op de backend por palabra, una escritura ya no puede quedarse a
// medias: se lanza con bsy=1 y termina en su unico done. Eso jubila TAMBIEN
// toda la maquinaria de PREEMPCION del _140 Punto B (el brazo `else if
// (word_pend)` del lanzador, la re-afirmacion de cur_kind=2 que evitaba el
// livelock, y el termino `word_pend && wr_addrw == cur_addrw` de pf_dirty):
// esas defensas existian PORQUE un prefetch podia colarse entre los bytes de
// una misma palabra. Ya no hay "entre". El orden de prioridades del lanzador
// se conserva intacto (pfq > wq > rq > eco), simplemente sin el escalon 2.

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
// _148 FIX B: el termino de la escritura SUSPENDIDA (word_pend && wr_addrw ==
// cur_addrw) DESAPARECE — con una op por palabra no existe escritura a medias
// que un prefetch pueda atravesar (bsy serializa: mientras la escritura vuela,
// nada mas se lanza). Quedan SOLO las 8 comparaciones contra la cola wq.
wire [7:0] pf_dm;                         // que entradas de wq casan el word
assign pf_dm[0] = wq_vld[0] && (wq[0][15:0] == cur_addrw);
assign pf_dm[1] = wq_vld[1] && (wq[1][15:0] == cur_addrw);
assign pf_dm[2] = wq_vld[2] && (wq[2][15:0] == cur_addrw);
assign pf_dm[3] = wq_vld[3] && (wq[3][15:0] == cur_addrw);
assign pf_dm[4] = wq_vld[4] && (wq[4][15:0] == cur_addrw);
assign pf_dm[5] = wq_vld[5] && (wq[5][15:0] == cur_addrw);
assign pf_dm[6] = wq_vld[6] && (wq[6][15:0] == cur_addrw);
assign pf_dm[7] = wq_vld[7] && (wq[7][15:0] == cur_addrw);
wire pf_dirty = |pf_dm;

// _148 FIX B (extra barato): FUSIONAR en vez de DESCARTAR. Hasta ahora un fill
// que chocaba con una escritura encolada se TIRABA y el word se recuperaba por
// el camino miss->rescate: la clasificacion del miss residual (MISSCLS 25/07)
// contaba filldrop_dirty=6 de 11 miss de rafaga, mas de la mitad de lo que
// queda. El dato leido de VRAM es valido para los bytes que la escritura NO
// toca; los que SI toca los conocemos (estan en la cola). Se fusionan igual
// que en wu_merged, con la mascara de la entrada de wq (1 = escribir).
// SEGURIDAD (por que solo UNA coincidencia): con dos o mas entradas al mismo
// word habria que aplicarlas EN ORDEN DE PROGRAMA — una cadena de 8 muxes de
// 32 bits en un shim con familias de placement cronicas, para un caso que no
// se da (cada comando escribe cada palabra una vez). Con >=2 se DESCARTA como
// siempre. pf_one/pf_drop son mutuamente excluyentes dentro de pf_dirty.
wire pf_one  = pf_dirty && ((pf_dm & (pf_dm - 8'd1)) == 8'd0);
wire pf_drop = pf_dirty && !pf_one;
// mux one-hot de {mascara[3:0], dato[31:0]} de la entrada que casa
wire [35:0] pf_ent = ({36{pf_dm[0]}} & wq[0][51:16]) |
                     ({36{pf_dm[1]}} & wq[1][51:16]) |
                     ({36{pf_dm[2]}} & wq[2][51:16]) |
                     ({36{pf_dm[3]}} & wq[3][51:16]) |
                     ({36{pf_dm[4]}} & wq[4][51:16]) |
                     ({36{pf_dm[5]}} & wq[5][51:16]) |
                     ({36{pf_dm[6]}} & wq[6][51:16]) |
                     ({36{pf_dm[7]}} & wq[7][51:16]);
wire [3:0]  pf_wm = pf_ent[35:32];       // 1 = ese byte lo pisa la escritura
wire [31:0] pf_wd = pf_ent[31:0];
function [31:0] pf_fuse(input [31:0] rd);
    pf_fuse = { pf_wm[3] ? pf_wd[31:24] : rd[31:24],
                pf_wm[2] ? pf_wd[23:16] : rd[23:16],
                pf_wm[1] ? pf_wd[15: 8] : rd[15: 8],
                pf_wm[0] ? pf_wd[ 7: 0] : rd[ 7: 0] };
endfunction

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
// _148 FIX A: indice de 13 bits. El pliegue XOR con v[14] (el bit de STREAM
// FISICO del entrelazado, ver arriba) se CONSERVA intacto en los 12 bits bajos;
// lo nuevo es v[12] (= L[14], el escalon de 16KB) como bit ALTO. Biyectivo con
// tag = v[15:12] (verificado por enumeracion de las 65536 palabras).
function [12:0] c_idx13(input [15:0] v);
    c_idx13 = { v[12], v[11:0] ^ {v[14], 11'b0} };
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
wire [12:0] scw_idx = wrk_hit ? c_idx13(wrk_addr1) : c_idx13(fill_addr);
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
    scq_d0 <= sc_d0[c_idx13(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we1) sc_d1[scw_idx] <= scw_b1;
    scq_d1 <= sc_d1[c_idx13(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we2) sc_d2[scw_idx] <= scw_b2;
    scq_d2 <= sc_d2[c_idx13(vram_address)];
end
always @(posedge clk_vdp) begin
    if (scw_we3) sc_d3[scw_idx] <= scw_b3;
    scq_d3 <= sc_d3[c_idx13(vram_address)];
end
always @(posedge clk_vdp) begin
    if (fill_now) sc_tag[c_idx13(fill_addr)] <= fill_addr[15:12];
    scq_tag <= sc_tag[c_idx13(vram_address)];
end
// _120d: puerto BSRAM de los valids (write-site unico muxeado + lectura
// gated: durante el barrido post-reset todo se lee como invalido)
wire        scv_we = !scv_ready || fill_now;
wire [12:0] scv_wi = !scv_ready ? scv_swp[12:0] : c_idx13(fill_addr);
always @(posedge clk_vdp) begin
    if (scv_we) sc_v[scv_wi] <= scv_ready;
    scq_v <= scv_ready ? sc_v[c_idx13(vram_address)] : 1'b0;
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

// (_148 FIX B: sd_base y nxt_byte RETIRADOS con la maquinaria byte-a-byte)
wire [15:0] nxt_w   = vram_address[17:2] + 16'd1;   // palabra siguiente (OBL)

// _140 WRITE-THROUGH-UPDATE de la VENTANA (raiz del miss-durante-escritura):
// una escritura de comando que CASA una entrada viva de la ventana (mismo
// tag) la ACTUALIZA EN SITIO en vez de invalidarla — asi el display no
// re-fetchea la palabra recien dibujada y se mata la tormenta de re-fetch
// (~2.7 miss/escritura medidos). wrk_addr1 comparte indice con pwq (leido
// en el ciclo previo desde el MISMO puerto pw_ridx), asi que pwq[31:0] es el
// contenido actual de esa entrada; se fusionan los bytes habilitados
// (wrk_mask1 = DQM, 0 = escribir) sobre el dato viejo. El puerto de escritura
// de pw_mem (pww) queda muxeado update-vs-fill: en colision GANA el update y
// el fill se DESCARTA (autocura via miss->rescate, igual que pf_dirty).
wire wu_hit = wrk_p1 && pwq_v && (pwq[41:32] == wrk_addr1[15:6]);
wire [31:0] wu_merged = {
    wrk_mask1[3] ? pwq[31:24] : wrk_data1[31:24],
    wrk_mask1[2] ? pwq[23:16] : wrk_data1[23:16],
    wrk_mask1[1] ? pwq[15:8]  : wrk_data1[15:8],
    wrk_mask1[0] ? pwq[7:0]   : wrk_data1[7:0]
};

always @(posedge clk_vdp or negedge rst_n) begin
    if (!rst_n) begin
        pw_v <= 256'd0; scv_swp <= 14'd0; pfq_wp <= 0; pfq_rp <= 0;
        wq_wp <= 0; wq_rp <= 0; rq_wp <= 0; rq_rp <= 0; wq_vld <= 8'd0;
        bsy <= 0; done_d <= 0; done2_d <= 0; got_lo <= 0; got_hi <= 0;
        pwv_set_p <= 0; pwv_set_i <= 0;
        cur_kind <= 0; cur_half <= 0; cur_addrw <= 0; cur_tag <= 0;
        bk2_req <= 0; bk2_addr <= 0;
        cur_word <= 0;
        late_v <= 0; late_tag <= 0; late_data <= 0;
        bk_req <= 0; bk_we <= 0; bk_addr <= 0; bk_wdata <= 0; bk_wmask <= 0;
        vram_rdata <= 0; vram_rdata_en <= 0; vram_rtag <= 0;
        bg_miss <= 0;
        c_miss <= 0; c_bka <= 0; c_bkb <= 0;
        c_spmiss <= 0; c_spfet <= 0;                  // _148 FIX C
        spr_p1 <= 0; spr_addr1 <= 0; spr_tag1 <= 0;
        wrk_p1 <= 0; wrk_addr1 <= 0; wrk_data1 <= 0; wrk_mask1 <= 4'hF;
        obl_pend <= 0; obl_chk <= 0; obl_do <= 0; obl_w <= 0;
        bg_prev0 <= 0; bg_prev1 <= 0; stride <= 0; obl_walked <= 0;
        obl_w_c <= 0; obl_w_d <= 0;
        bgp_wp <= 0; bgp_rp <= 0; c_park <= 0; c_pkov <= 0; pkov_p <= 0;
        ecq_wp <= 0; ecq_rp <= 0; bg_quiet <= 0;      // _135
        ec_cred0 <= 0; ec_cred1 <= 0;
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
        pkov_p <= 1'b0;                  // _127: pisada consumida al contador
        if (pkov_p) c_pkov <= c_pkov + 16'd1;
        if (!scv_ready) scv_swp <= scv_swp + 14'd1;
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

        // ---------- write-check de la VENTANA (v4, etapa 1) — _140:
        // WRITE-THROUGH-UPDATE (antes: invalidacion). Si el tag leido de la
        // BSRAM casa, se re-escribe la MISMA entrada con el dato fusionado y
        // pw_v se MANTIENE (no se toca) -> la palabra dibujada sigue caliente
        // y el display no la re-fetchea (mata el ~2.7 miss/escritura). El
        // update es el usuario PRIORITARIO del puerto pww este ciclo: los
        // fills del backend se auto-gatean con !wu_hit mas abajo. Un fill
        // descartado se autocura por el camino miss->rescate (como pf_dirty).
        if (wu_hit) begin
            pww_en   <= 1'b1;
            pww_idx  <= w_idx(wrk_addr1);
            pww_tag  <= wrk_addr1[15:6];
            pww_data <= wu_merged;
        end

        // ---------- OBL en TRES fases (_121b) — _126: con el ESPEJO pw_tagB
        // el OBL ya no cede puerto: dispara SIEMPRE al ciclo siguiente del
        // hit (obl_pend se consume solo). La direccion sigue viajando en
        // sombras (obl_w_c/_d) para que un hit nuevo pise obl_w sin
        // corromper la fase en vuelo.
        obl_pend <= 1'b0;                       // consumido (el hit lo re-arma)
        obl_chk  <= obl_read_now;
        obl_w_c  <= obl_w;
        wk_tgt   <= obl_w + stride - obl_la;  // = addr_hit + stride en fase 3 (_147: -obl_la casa con el lookahead)
        obl_do   <= obl_chk && !(pwqB_v && pwqB_tag == obl_w_c[15:6]);
        obl_w_d  <= obl_w_c;
        // _127J: caminante (ver arriba) — slot OBL ocioso + zancada => se
        // re-arma la maquinaria de 3 fases hacia la linea siguiente. Un hit
        // bg simultaneo PISA obl_pend/obl_w mas abajo (el hit vivo manda) y
        // eso es exactamente la prioridad deseada.
        if (obl_chk && pwqB_v && pwqB_tag == obl_w_c[15:6]
            && stride != 16'd0 && !obl_walked) begin
            obl_pend   <= 1'b1;
            obl_w      <= wk_tgt;                    // = addr_hit + stride
            obl_walked <= 1'b1;
        end
        pfB_pend <= 1'b0;                // default; las ramas de spr_p1 lo
                                         // suben (asignacion posterior gana)


        // ---------- _127: aprendizaje de la zancada (wrap POR STREAM) ----
        if (spr_p1 && spr_tag1[4:2] == C_BG) begin : stride_learn
            reg [15:0] d;
            d = spr_addr1 - (spr_addr1[14] ? bg_prev1 : bg_prev0);
            if (spr_addr1[14]) bg_prev1 <= spr_addr1;
            else               bg_prev0 <= spr_addr1;
            // salto negativo con magnitud <= 64 = wrap del ring por stream
            if (d[15] && (&d[14:6])) begin
                if ((16'd1 - d) == 16'd8  || (16'd1 - d) == 16'd16 ||
                    (16'd1 - d) == 16'd32 || (16'd1 - d) == 16'd64)
                    stride <= 16'd1 - d;
`ifdef SHIM_DBG_DROPS
                $display("WRAP addr=%h delta=%0d stride_n=%0d t=%0t",
                         spr_addr1, $signed(d), 16'd1 - d, $time);
`endif
            end
        end

        // ---------- etapa 1 UNIFICADA del lookup (v4): VENTANA + CACHE ----
        // Todo fetch (bg/sprite/CPU/comando) llega aqui con las lecturas
        // BSRAM ya en pwq/scq. Prioridad: ventana (solo bg, streaming) ->
        // cache (tablas residentes) -> backend. HIT -> pipe[1]: emerge a
        // 8 ciclos EXACTOS (fetch T, pipe[1] T+1, pipe[6] T+6, en T+7).
        if (spr_p1) begin
            // _148 FIX C: denominador de la tasa de miss de sprite
            if (spr_tag1[4:2] == C_SPRITE) c_spfet <= c_spfet + 32'd1;
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
                obl_pend  <= 1'b1;
                // _127J: el +2 lineal SE QUEDA como primario (la prediccion
                // sustitutiva fracaso: cualquier cambio de cadena abre
                // huecos). La linea siguiente la cubre el CAMINANTE en los
                // slots ociosos del 2o pase. Cada hit renueva su credito.
                obl_w      <= spr_addr1 + obl_la;   // _147: lookahead profundo
                obl_walked <= 1'b0;
            end
            else if (scq_v && scq_tag == spr_addr1[15:12])
                // _137: el re-armado del OBL en el CHIT (_135 micro-fix 2)
                // RETIRADO — en T2/80col (arranque del MSX-DOS) cada CHIT
                // disparaba un prefetch inutil: tormenta que saturaba pfq
                // (prioridad maxima) y mataba de hambre a wq/rq => CPU
                // congelada imprimiendo "detectando SD" (HW _136, 23/07).
                // La regla de oro por la puerta de atras. El eco de
                // arranque (drenaje solo-ocioso) hace el trabajo sin esto.
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
                            // _127: el incremento va REGISTRADO (pkov_p) — el
                            // CE de los 16 bits colgaba del DO de la BSRAM
                            // (pwq via el compare del hit) y era la unica
                            // familia violada del dado 337 (-13ps). Un ciclo
                            // tarde en un contador de telemetria es gratis.
                            pkov_p <= 1'b1;
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
                // _148 FIX C: gemelo de c_miss para el camino de SPRITE (en el
                // MISS de la sc-cache; los sprites no usan la ventana). Sale
                // por COM11 en dbg_miss[31:16].
                if (spr_tag1[4:2] == C_SPRITE) c_spmiss <= c_spmiss + 32'd1;
                if (spr_tag1[4:2] == C_BG) begin
                    // bg: cuenta el miss y arranca el stream OBL (bitmap).
                    // _122: siembra COMPLETA de la cadena +2 — el +1 va
                    // directo a pfq y el +2 via OBL (fase 2, un ciclo
                    // despues: sin colision en el puerto de pfq).
`ifdef SHIM_DBG_DROPS
                    $display("BGMISS addr=%h t=%0t", spr_addr1, $time);
`endif
                    bg_miss <= bg_miss + 8'd1;
                    c_miss  <= c_miss + 32'd1;
                    pfB_pend <= 1'b1;            // semilla +1 (registrada; si
                    pfB_wr   <= spr_addr1 + 16'd1; // habia OBL retenido cede:
                                                 // el miss resiembra la cadena)
                    obl_pend  <= 1'b1;
                    // _127: el MISS siempre recupera la linea ACTUAL (+2
                    // clasico; el +1 va por pfB) — la prediccion de zancada
                    // vive SOLO en los hits. Con zancada en el miss, la
                    // linea 0 tras cada vblank (cadena rota) no se
                    // recuperaba: quiet 232 -> 4852.
                    obl_w     <= spr_addr1 + obl_la;   // _147: lookahead profundo
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

        // ---------- _135 eco de arranque: silencio, creditos y encolado ----
        // (tap sobre spr_p1/spr_addr1/stride, todos REGISTRADOS: cero
        // contacto con el cono de pwq/pw_mem DO ni con el mux de pfq)
        if (spr_p1 && spr_tag1[4:2] == C_BG) begin
            bg_quiet <= 9'd0;
            if (stride != 16'd0 && !ecq_full) begin
                if (spr_addr1[14] ? (ec_cred1 != 2'd0) : (ec_cred0 != 2'd0)) begin
                    ecq[ecq_wp] <= spr_addr1 + stride;
                    ecq_wp      <= ecq_wp + 2'd1;
                    if (spr_addr1[14]) ec_cred1 <= ec_cred1 - 2'd1;
                    else               ec_cred0 <= ec_cred0 - 2'd1;
                end
            end
        end
        else begin
            if (!bg_quiet[8]) bg_quiet <= bg_quiet + 9'd1;
            if (bg_quiet == 9'd256) begin       // hueco: armar (se re-pina
                ec_cred0 <= 2'd2;               // durante todo el silencio,
                ec_cred1 <= 2'd2;               // inofensivo)
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
        // (_127J-c v2: el eco YA NO empuja aqui — el 4o brazo del mux de
        // pfq resucito las familias criticas de placement (15 dados
        // seguidos violando). Ahora monta en el registro pfB, mas abajo.)
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
        // Las escrituras van por bk, UNA op por palabra desde _148.) --------
        if (bsy && cur_kind == 2'd2 && (bk_done_t != done_d)) begin
            // _148 FIX B: una op = una PALABRA. El done cierra la escritura
            // entera (antes: un done por byte habilitado, hasta 4).
            bsy <= 1'b0;
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
                // _148 FIX B: el dato que se CACHEA lleva fusionados los bytes
                // de la escritura encolada al mismo word (pf_one). Solo se
                // descarta con >=2 escrituras pendientes (pf_drop).
                if (cur_kind == 2'd0) begin
                    // fill de ventana via registros pww (write-site BSRAM)
                    // _140: cede el puerto pww al write-through-update de
                    // este ciclo (!wu_hit); el fill descartado se re-siembra
                    // por el camino miss->rescate.
                    if (!pf_dirty && !wu_hit) begin
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
                    // la RESPUESTA al consumidor va SIN fusionar: la lectura
                    // se lanzo con wq vacia (rq va por debajo de wq), asi que
                    // una escritura llegada despues es POSTERIOR a este read.
                    late_data <= {w_hi, w_lo};
                    // y de paso a la ventana si es bg
                    // (_140: cede pww al write-through-update, !wu_hit)
                    if (cur_tag[4:2] == C_BG && !pf_dirty && !wu_hit) begin
                        pww_en   <= 1'b1;
                        pww_idx  <= w_idx(cur_addrw);
                        pww_tag  <= cur_addrw[15:6];
                        pww_data <= {w_hi, w_lo};
                        pwv_set_p <= 1'b1;
                        pwv_set_i <= w_idx(cur_addrw);
                    end
                    // ...y a la CACHE (v3c: TODO consumidor de lectura
                    // rellena — bg/sprite/CPU/comando) — via fill_pend
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
            // _126/_140: PANTALLA > (escritura en curso) > ESCRITURAS-NUEVAS >
            // LECTURAS-DEMANDA.
            //  1. pfq (streaming de ventana) — sagrado: el pipe de 8 ciclos no
            //     puede esperar a la SDRAM; cada miss = basura visible. _140
            //     Punto B lo puso por encima de la escritura en curso porque
            //     una escritura multibyte acaparaba canal-A hasta 4 byte-ops
            //     (44/63 miss del frame de rafaga estaban EN COLA, llegando
            //     tarde). _148 FIX B mata el problema en la raiz: la escritura
            //     dura UNA op, asi que ya no hay nada que preemptir — el brazo
            //     word_pend desaparece y con el todo el estado de suspension.
            //  2. wq antes que rq: coherencia write->read GLOBAL gratis (un
            //     read nunca adelanta a una escritura mas vieja).
            //  3. rq al final: CPU/sprite/dest-de-comando esperan. Como una
            //     escritura es atomica, un rq NUNCA lee una palabra a medio
            //     escribir (antes hacia falta el guardia word_pend=0).
            if (!pfq_empty) begin
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
                // _148 FIX B: UNA op de PALABRA. La direccion va alineada
                // (addr[1:0]=00) y la mascara de bytes viaja en bk_wmask
                // (1 = escribir, ya invertida respecto a la DQM del VDP al
                // encolar). El backend traduce a la DM de la DDR3.
                cur_kind  <= 2'd2;
                wq_vld[wq_rp] <= 1'b0;
                wq_rp     <= wq_rp + 3'd1;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b1;
                bk_addr  <= VRAM_BASE + {4'd0, wq[wq_rp][15:0], 2'b00};
                bk_wdata <= wq[wq_rp][47:16];
                bk_wmask <= wq[wq_rp][51:48];
            end
            // _135 micro-fix: !pfB_pend retiene el brazo rq UN ciclo cuando
            // hay siembra (+1 del miss / rescate OBL) aterrizando en pfq —
            // sin el reten, el rq del propio miss se colaba por delante de
            // su semilla (pfq aun vacia ese ciclo) y el +1 de la columna s
            // llegaba ~117ns tarde (regimen C del informe 23/07).
            else if (!rq_empty && !late_v && !pfB_pend) begin
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
            // _135: drenaje del eco de arranque — prioridad MINIMA, solo
            // con todas las colas vacias (tiempo muerto real). Es un fill
            // de ventana normal (cur_kind 0): tag-checked, inofensivo
            // incluso con stride rancio.
            else if (!ecq_empty && pfq_empty && wq_empty && rq_empty &&
                     bgp_empty && !late_v && !pfB_pend) begin
                cur_kind  <= 2'd0;
                cur_addrw <= ecq[ecq_rp];
                ecq_rp    <= ecq_rp + 2'd1;
                got_lo <= 1'b0; got_hi <= 1'b0;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b0;
                bk_addr  <= VRAM_BASE + {4'd0, ecq[ecq_rp], 2'b00};
                bk2_req  <= 1'b1;
                bk2_addr <= (VRAM_BASE + {4'd0, ecq[ecq_rp], 2'b00}) | 22'd2;
            end
        end
    end
end

endmodule
