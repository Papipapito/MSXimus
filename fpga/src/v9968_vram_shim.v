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
    output wire [31:0] dbg_bkb,
    output wire [31:0] dbg_drops             // _154: {s1_pfq[15:0], wq_full[15:0]} — drops REALES, sano=0
);

// ============================================================================
// _170 SC_FILL_POLICY — politica de relleno de la sc-cache, SELECCIONABLE.
// Existe para poder iterar EN PLACA en ciclos de 5 minutos (build ligera ~2 min
// + flasheo + arranque), porque el fallo que hay que cazar —un CUELGUE DE
// ARRANQUE— NO ES DETECTABLE EN SIMULACION: ningun banco arranca una BIOS, y por
// eso la rc5 paso TODAS las pruebas y colgo la maquina igual.
//
//   0 = TODOS rellenan (bg/sprite/CPU/comando).  <-- el de la rc3, el que
//       funciona. Es el estado seguro al que volver.
//   1 = todos MENOS el motor de comandos.  Curo el desalojo (c_spmiss/frame de
//       ~1300 a 1) y dejo el texto byte-identico y la bateria igual... pero
//       COLGO EL ARRANQUE en la build completa (rc5). Sin diagnosticar.
//   2 = SOLO sprites.  ⛔ ROMPE EL MODO TEXTO (rc4). No usar; esta aqui para que
//       quede constancia de que se probo.
//
// El detalle de los dos fracasos esta en el bloque grande del relleno, mas
// abajo. LEERLO antes de tocar esto.
// ============================================================================
localparam SC_FILL_POLICY = 3'd1;

localparam C_BG      = 3'd1;
localparam C_SPRITE  = 3'd2;
// _165b: faltaban las otras dos etiquetas del arbitro (vdp_vram_interface.v:115-118).
localparam C_CPU     = 3'd3;
localparam C_COMMAND = 3'd4;

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
// cache de 8192.
// ⚠ _151: TODO EL PARRAFO "RESIDUO CONOCIDO" DE AQUI ARRIBA DESCRIBE EL INDICE
// VIEJO. El choque SAT<->SPT ya no existe: c_idx13 mete v[13] en el indice y
// sube el pliegue de v[14] al bit 12 (ver el bloque _151 FIX en c_idx13). Se
// deja el texto porque explica COMO se llego hasta aqui y porque el analisis
// del pliegue sigue siendo la herramienta para razonar sobre esta cache.
// _150 — RESIDUO CERRADO: el VICTIM BUFFER esta IMPLEMENTADO (16 entradas
// asociativas en FF, ver el bloque "_150 VICTIM BUFFER" mas abajo). Va en la
// ETAPA LIBRE de la tuberia (pipe[2] en T+2, mismo instante de salida que
// pipe[1] en T+1), asi que no toca el contrato de 8 ciclos ni anade BSRAM.
// MEDIDO en tb_sprite3 (setup de PEOR CASO pattern=p*16): miss REAL de sprite
// 0.33%/frame -> 0.00%, y el frame pasa a ser IDENTICO a la referencia dorada
// (3168 lineas distintas -> 0).
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
// _176: refill de escrituras no-residentes (write-allocate diferido)

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
// ============================================================================
// _163 ARREGLO DEL SCROLL DE DOS PAGINAS (SP2, R#25 bit0) — ACTIVO EN LA BUILD.
// MEDIDO en tb_sp2.sv (dos pilas en lockstep, misma config y semilla), antes ->
// despues, con logs/sp2_split.log de referencia:
//   control sin SP2          :   64 px /   2 fallos  ->   64 px /   2  (igual)
//   SP2 estatico             :    0 px / 262 fallos  ->    0 px /   2
//   SP2 + scroll MOVIENDOSE  : 7312 px / 387 fallos  ->  144 px / 385   <<< 50x
//   recentrado               :   64 px / 262 fallos  ->   64 px /   2
// El caso del scroll en movimiento es el del logo del MSX2+ y el de SCREEN 7/8.
// ⚠️ HONESTIDAD: en ese caso los FALLOS no bajan (385 vs 387) pero el dano
// visible cae 50x. El desacople no esta explicado del todo: lo mas probable es
// que el prefetch ponga el dato en camino y la respuesta tardia llegue a tiempo
// para la pantalla aunque el contador ya haya apuntado el fallo, pero eso es
// hipotesis, NO medida.
// ⚠️ EFECTO SECUNDARIO REAL: el caminante pasa de ~6650 disparos/frame a ~385 y
// TODOS van a fronteras. Es un cambio de POLITICA (de "precalentar la linea
// siguiente en linea recta" a "precalentar fronteras"), no una simple adicion.
// Los frames de control salen identicos, asi que sin SP2 no se pierde nada.
// ============================================================================
// _163 SP2: fronteras de pagina predichas. Hay DOS por linea (ida y vuelta:
// A->B y B->A) y el caminante solo dispone de un slot por oportunidad, asi que
// se guardan por SEPARADO o se precalentaria solo la mitad. Se distinguen por
// el SIGNO del salto (ida = +~8192, vuelta = -~8192), no por un bit concreto:
// asi vale igual para SC7/8 (pagina en v[13]) que para SC5/6 (en v[12]).
// flip_tgt_* van REGISTRADOS por la misma razon que wk_tgt — meter ese sumador
// en linea hizo violar nueve dados seguidos (ver _127J arriba).
// _163 v2: ranuras POR STREAM. Medido: con SP2 el detector dispara 766 veces
// para 384 conmutaciones (= 2x), porque el entrelazado parte el fondo en DOS
// streams (bit 14) y el salto se ve en los dos. Con una sola ranura por
// direccion, la segunda deteccion sobrescribia a la primera y se perdia media
// frontera. Indice = spr_addr1[14].
reg [15:0] flip_dst_p [0:1];             // tras salto POSITIVO, por stream
reg [15:0] flip_tgt_p [0:1];
reg [15:0] flip_dst_n [0:1];             // tras salto NEGATIVO, por stream
reg [15:0] flip_tgt_n [0:1];
reg [1:0]  flip_pf_p, flip_pf_n;         // frontera pendiente, por stream
// Ventana de magnitud que cuenta como conmutacion de pagina. Cota inferior muy
// por encima del wrap del scroll H (<=64) y superior por debajo del retorno de
// campo (~13568), dejando margen ancho alrededor de 4096 y 8192.
localparam [15:0] FLIP_LO = 16'd2048;
localparam [15:0] FLIP_HI = 16'd12288;
// ⚠️ PENDIENTE (no bloqueante, medido): este detector discrimina por MAGNITUD y
// el retorno de campo (~6784 palabras/stream) esta a un 20% de la conmutacion
// (8192), asi que se cuela 1-2 veces por frame. NO cuesta fallos (2 en los dos
// casos), solo mueve 32 px de la huella residual entre frames. El criterio bueno
// seria la FORMA del salto (un bit alto contra muchos bits), no el tamano. Se
// deja para otra campana: no se toca lo que no se ha medido.
`ifdef SHIM_DBG_SPLIT
// _163 CONTADORES DE LA PROPIA MAQUINARIA — sin esto no se puede distinguir
// "el arreglo no sirve" de "el arreglo NO SE EJECUTA NUNCA", que es una
// posibilidad real: la rama del caminante exige stride != 0, y con SP2 las
// conmutaciones machacan bg_prev0/1, asi que la zancada podria no aprenderse
// nunca y el caminante estar MUERTO. Un arreglo que no corre no es una
// hipotesis refutada, es una hipotesis sin probar.
reg [31:0] c_flipdet;                    // conmutaciones DETECTADAS
reg [31:0] c_flippf;                     // veces que el caminante precalento
reg [31:0] c_walk;                       // veces que el caminante disparo (total)
`endif
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
reg        fill_sp;                      // _150: el fill viene de un fetch de
                                         // SPRITE (unico que alimenta el victim
                                         // buffer — ver el bloque _150)

// cola de prefetch (_120c: 8 plazas — mas prefetch en vuelo para los
// modos de 256B/linea; tambien resiembra el placement, que con nombres
// no se inmuta: Gowin solo baraja con cambios ESTRUCTURALES)
reg [15:0] pfq [0:7];                    // addr[17:2]
reg [2:0]  pfq_wp, pfq_rp;
wire       pfq_empty = (pfq_wp == pfq_rp);
wire       pfq_full  = (pfq_wp + 3'd1 == pfq_rp);

// cola de escrituras (8 plazas: {mask,wdata,addr}; _148 FIX B: cada entrada
// es UNA op de backend, no hasta 4)
reg [51:0] wq [0:15];                    // {mask[3:0], wdata[31:0], addr[17:2]} — _186b (caza del veneno MSX1,
                                         // 05/08): 8->16 plazas. En G1/G2 el fetch de display mata de hambre el
                                         // drenaje (~39us medidos en tb_vramsoak_glue) y una rafaga OTIR (5,9us/
                                         // byte) desbordaba las 8 => escrituras CPU PERDIDAS en silencio. 16 =
                                         // 94us de colchon a ritmo Z80 real (62us en turbo 5.37): imposible
                                         // desbordar. El umbral del stall del MOTOR no cambia (>=2). NOTA: NO
                                         // gatear cpu_vram_ready con el stall (probado en placa: rompe el HDMI
                                         // en el arranque — la advertencia v3d era cierta).
reg [3:0]  wq_wp, wq_rp;                 // _186b: punteros a 4 bits
reg [15:0] wq_vld;                       // _126: bitmap de ocupacion (snoop)
wire       wq_empty = (wq_wp == wq_rp);
wire       wq_full  = (wq_wp + 4'd1 == wq_rp);

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
reg [15:0] c_wqdrop, c_s1drop;           // _154: drops silenciosos (wq lleno / pfq lleno)
// _148 FIX C — TELEMETRIA DE SPRITE. c_miss solo cuenta miss de FONDO: en
// placa los sprites podian estar fallando el 20% de sus fetches y COM11 no
// decia NADA (el DEVCON con las cabezas rayadas paso por aqui invisible).
// c_spmiss/c_spfet son el par gemelo del camino de sprite (C_SPRITE=2):
//   c_spfet  = fetches de sprite que llegan a la etapa 1 del lookup
//   c_spmiss = los que fallan la sc-cache (van al backend)
// Sano tras el FIX A: c_spmiss/c_spfet < 0.1%.
reg [31:0] c_spmiss, c_spfet;
`ifdef SHIM_DBG_SPLIT
reg [31:0] c_wnhit, c_schit;             // _163: fondo servido por VENTANA / sc-cache
`endif
// PALABRA A DE COM11 (dbg_uart.cnt_a) REEMPAQUETADA:
//   bits [31:16] = c_spmiss[15:0]   (miss de SPRITE)
//   bits [15: 0] = c_miss[15:0]     (miss de FONDO, como siempre pero a 16b)
// A 60 fps y <=5 miss/frame un contador de 16 bits tarda ~3.6 min en dar la
// vuelta: de sobra para telemetria (el lector mira la DERIVADA, no el valor).
// dbg_audio_reader.py: word[0] -> spmiss = int(w,16)>>16, bgmiss = int(w,16)&0xFFFF.
assign dbg_miss = {c_spmiss[15:0], c_miss[15:0]};
assign dbg_bka  = c_bka;
assign dbg_drops = {c_s1drop, c_wqdrop};  // _154
assign dbg_park = {c_pkov, c_park};
assign dbg_bkb  = c_bkb;

// control de flujo: con wq medio-lleno o rq caliente, el interface retiene
// los slots de CPU/COMANDO (ready=0) hasta que el backend drene
wire [3:0] wq_used = wq_wp - wq_rp;
assign vram_stall = (wq_used >= 4'd2) || (rq_used >= 4'd6);

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
wire [15:0] pf_dm;                        // que entradas de wq casan el word (_186b: 16)
assign pf_dm[0] = wq_vld[0] && (wq[0][15:0] == cur_addrw);
assign pf_dm[1] = wq_vld[1] && (wq[1][15:0] == cur_addrw);
assign pf_dm[2] = wq_vld[2] && (wq[2][15:0] == cur_addrw);
assign pf_dm[3] = wq_vld[3] && (wq[3][15:0] == cur_addrw);
assign pf_dm[4] = wq_vld[4] && (wq[4][15:0] == cur_addrw);
assign pf_dm[5] = wq_vld[5] && (wq[5][15:0] == cur_addrw);
assign pf_dm[6] = wq_vld[6] && (wq[6][15:0] == cur_addrw);
assign pf_dm[7] = wq_vld[7] && (wq[7][15:0] == cur_addrw);
assign pf_dm[8] = wq_vld[8] && (wq[8][15:0] == cur_addrw);
assign pf_dm[9] = wq_vld[9] && (wq[9][15:0] == cur_addrw);
assign pf_dm[10] = wq_vld[10] && (wq[10][15:0] == cur_addrw);
assign pf_dm[11] = wq_vld[11] && (wq[11][15:0] == cur_addrw);
assign pf_dm[12] = wq_vld[12] && (wq[12][15:0] == cur_addrw);
assign pf_dm[13] = wq_vld[13] && (wq[13][15:0] == cur_addrw);
assign pf_dm[14] = wq_vld[14] && (wq[14][15:0] == cur_addrw);
assign pf_dm[15] = wq_vld[15] && (wq[15][15:0] == cur_addrw);
wire pf_dirty = |pf_dm;

// [niquelado B, bug #15 del informe] AQUI VIVIO el "_148 FIX B" (fusionar el
// fill con la escritura encolada al mismo word en vez de descartarlo — la
// clasificacion MISSCLS 25/07 lo justificaba: 6 de 11 miss de rafaga eran
// filldrop_dirty). Se descubrio que NUNCA SE CABLEO: pf_one/pf_fuse no tenian
// ni un consumidor y las guardas reales siguieron siendo `!pf_dirty` a secas,
// asi que el netlist jamas llevo la mejora. Se retira el codigo muerto; si
// algun dia se quiere DE VERDAD, la receta esta en el informe del niquelado
// (guardas `!pf_drop`, dato `pf_fuse({w_hi,w_lo})`, validar en tb_menu_ddr3 y
// tb_vbcoh). El comportamiento real de hoy: fill que choca con escritura
// pendiente se DESCARTA y el word se autocura por el camino miss->rescate.

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
// ============================================================================
// [_163 2026-07-30] EL SCROLL DE DOS PAGINAS (SP2, R#25 bit0) — MEDIDO Y CON
// UNA HIPOTESIS PROPIA REFUTADA. Banco: tools/v9968_sim/tb_sp2.sv
// (SC8 + sprites ON + R#2=0x3F, que es IMPRESCINDIBLE: el core solo activa SP2
//  si reg_pattern_name_table_base[15]=1 — ver vdp_timing_control_screen_mode.v
//  linea 228 — y la pagina la elige w_pos_x[8], o sea el scroll HORIZONTAL).
//
// MEDIDO (misma config y semilla, A=shim real / B=VRAM perfecta en lockstep):
//     SP2 apagado             : bgmiss =   2   pxdiff =    64
//     SP2 on, se enciende     : bgmiss = 384   pxdiff =   152   pgflips = 384
//     SP2 on, estatico        : bgmiss = 262   pxdiff =     0
//     SP2 on + R#26 CAMBIANDO : bgmiss = 387   pxdiff =  7336
//     SP2 on + scroll v+h     : bgmiss = 387   pxdiff = 13064
// El dano visible aparece cuando el scroll SE MUEVE. Y cuadra la aritmetica:
// la pantalla exige respuesta a 8 ciclos EXACTOS (contrato de la cabecera), asi
// que un miss NO llega a tiempo => 1 miss = 1 palabra mala = 4 px MSX x 3
// columnas del magnificador x 2 del doblado de linea ~= 19 px de pantalla;
// 7336/387 = 19.
//
// ⛔ HIPOTESIS REFUTADA (no repetirla): "las dos paginas alias-an en el mismo
// indice de la ventana y cada conmutacion desaloja lo que la otra necesita".
// Se probo plegando el bit de pagina en el indice:
//     w_idx = v[7:0] ^ {v[14],7'b0} ^ {1'b0, v[13]^v[12], 6'b0}
// (biyectivo, verificado por enumeracion de las 65536 palabras, 0 colisiones;
//  y exonerado del fallo preexistente de tb_sc8cmd_full por A/B). Resultado:
// BYTE-IDENTICO en todos los frames — bgmiss seguia siendo 384/262 clavado.
// CERO efecto. RETIRADO. Y ojo: BYTE-IDENTICO en los 5 frames comparados, ni
// un miss de diferencia — eso es MAS de lo que explicaria "el fix no ayuda", y
// deja abierta la posibilidad de que la ventana no sea quien sirve el grueso
// del fondo en este caso (la sc-cache de 8192 lineas, con su propio indice
// c_idx13 que NO se toco, podria estar absorbiendolo).
//
// LO QUE LOS DATOS SI DICEN, sin adornos:
//   flips=384 en las tres fases, pero misses = 384 (1,00 por flip) al encender
//   SP2, 262 (0,68) en estatico y 387 (1,01) con el scroll moviendose.
//   Que en estatico UN TERCIO de las conmutaciones acierte descarta un modelo
//   de fallo puramente EN FRIO: algo se retiene entre lineas. Y que al mover el
//   scroll suba a 1,01 encaja con que el desplazamiento invalida esa retencion.
//   O sea que hay las dos cosas: falta de prefetch a traves de la frontera Y
//   perdida de retencion. Cual pesa mas NO esta medido.
//
// SIGUIENTE PASO (campana aparte, no improvisar): instrumentar el shim para
// separar miss-de-ventana de miss-de-sc-cache antes de proponer nada mas. El
// candidato de arreglo sigue siendo predecir el salto y precalentar el bloque
// de la otra pagina — p.ej. retargetear el CAMINANTE del _127J a "ultima
// direccion vista en la OTRA pagina + zancada", que usa slots ociosos y por
// tanto no anade trafico (la unica clase de cambio que ha funcionado nunca
// aqui). Pero primero MEDIR quien falla.
// ============================================================================
function [7:0] w_idx(input [15:0] v);
    w_idx = v[7:0] ^ {v[14], 7'b0};
endfunction
// _148 FIX A: indice de 13 bits. El pliegue XOR con v[14] (el bit de STREAM
// FISICO del entrelazado, ver arriba) se CONSERVA intacto en los 12 bits bajos;
// lo nuevo es v[12] (= L[14], el escalon de 16KB) como bit ALTO. Biyectivo con
// tag = v[15:12] (verificado por enumeracion de las 65536 palabras).
//
// _151 FIX — LAS 3 RAYAS HORIZONTALES DE LA ru66 (SAT contra SPT).
// SINTOMA (HW _150): en la escena de los conejos de ru66-v9968-demo salen 3
// rayas horizontales de 1 px que cruzan a los DOS conejos a la MISMA Y (mitad
// de pantalla) y se prolongan sobre el fondo; el COM11 marcaba ~2.700 spMISS/s
// (~45/frame) SOSTENIDOS y vbhit = 0 (el victim buffer no rescataba NADA).
//
// CAUSA (medida, no supuesta). Con el indice de arriba:
//   SAT @0x10000 -> v = 0x4000 + P*2 + m ; v[14]=1 => idx13 = 2048 + P*2 + m
//   SPT @0x08000 -> v = 0x2000 + pat[7:4]*512 + yl*32 + pat[3:0]*2 + w
//                   v[14]=0, v[13] NO ENTRA EN EL INDICE => idx13 = (v & 0x1FFF)
//   La fila de patron 0 (pat[7:4]=0, o sea los patrones 0x00-0x0F, LOS PRIMEROS
//   QUE USA CUALQUIERA) cae en idx13 = yl*32 + ... => con yl = 64 y 65 aterriza
//   EXACTAMENTE encima de la SAT (idx13 2048..2095 = planos 0..23).
//   En la ru66 los conejos son SZ=3 (128 lineas fuente) con MGY=128 (1:1) y
//   arrancan en Y=31 => yl=64/65 se pintan en las LINEAS DE PANTALLA 95 y 96,
//   y el destrozo se arrastra a la 97. Los 8 planos de conejo re-leen su SAT
//   CADA scanline y sus patrones caen sobre ella: ping-pong puro. El VB de 16
//   entradas no puede: el conjunto en conflicto son ~32 palabras y la politica
//   round-robin lo recicla entero DENTRO de la misma linea.
//   Reproducido en tb_sprite3 -DRU66 con el layout REAL de la demo (SAT/SPT/
//   26 planos/patrones sacados de devcon.c): 41-42 miss/frame sostenidos, del
//   mismo orden que los ~45/frame del HW.
//   El indice viejo choca con las filas de patron 0,1,2,3,4 (las MAS usadas).
//
// FIX: meter v[13] en el indice y subir el pliegue de v[14] al bit 12.
//   idx13 = { v[12]^v[14], v[11]^v[13], v[10:0] }
//   * BIYECTIVO con tag = v[15:12] (enumeracion de las 65536 palabras: 65536
//     claves distintas; el tag da v[14] y v[13], asi que v[12] y v[11] se
//     recuperan). El TAG NO CAMBIA: mismo ancho, mismo comparador.
//   * COSTE: 1 XOR. Ni un FF, ni un bloque BSRAM, ni una etapa de tuberia.
//   * REGRESION CERO POR CONSTRUCCION en 0x0000-0x1FFF (v[13]=v[14]=0): las
//     tablas de SCREEN 0/1/2/3 y el bg de SC5 pagina 0 conservan idx13 = v[12:0]
//     BIT A BIT (verificado por enumeracion) -> la leccion _117 queda intacta.
//   * La SAT se muda a idx13 4096.., y el espacio de patrones que puede
//     chocar con ella pasa a ser el de las filas 5..15 (patrones >= 0x50) con
//     yl alto, en vez de las filas 0..4 con yl bajo. Es una MEJORA, no una
//     garantia: en una cache direct-mapped de 8192 palabras una pagina de
//     patrones de 8192 palabras cubre TODO el indice y siempre existe UN alias
//     posible. La red de seguridad general sigue siendo el victim buffer.
//   * Busqueda exhaustiva: de los 156 pliegues biyectivos de la familia
//     {v[14]->bit i, v[13]->bit j} que respetan 0x0000-0x1FFF, este par
//     (bits 12/11) es el UNICO que da 0 miss/frame en la escena ru66 en las
//     4 fases de animacion de los conejos (el siguiente mejor da 20).
// ===========================================================================
// _172 SEGUNDO PLIEGUE — ahora separa TAMBIEN la escena del V9968DM.
//
//   _151 (viejo): { v[12]^v[14], v[11]^v[13], v[10:0] }
//   _172 (este) : { v[12]^v[13], v[11]^v[14], v[10:0] }
// Solo cambia CON QUIEN se empareja cada bit alto. MISMO COSTE EXACTO: dos XOR
// de dos entradas. Mismo tag (v[15:12]), mismo comparador, ni un FF de mas.
//
// POR QUE. El pliegue del _151 se eligio para la ru66 y deja el caso del
// V9968DM sin cubrir: su SAT (0x7600) y la linea 44 de sus patrones (0xD600)
// caen en el MISMO indice 7552 con tags 1 y 3 -> se desalojan mutuamente cada
// scanline. Es la RAYA que quedaba en placa tras curar el desalojo por comandos.
//
// VERIFICADO POR ENUMERACION (tools/v9968_sim/alias_idx.py, con la geometria
// sacada del RTL y el SZ REAL de cada plano):
//                      colisiones vivas SAT<->SPT
//   funcion        ru66      V9968DM
//   _151 (vieja)      0           26     <- el defecto
//   _172 (esta)       0            0
// Los 26 son exactamente 13 patrones x 2 mitades, que cuadra con la cota de
// <=78 fallos/frame medida antes.
//
// ⚠️ EL MODELO SE VALIDA A SI MISMO, y esto importa: con la funcion VIEJA el
// script da 0 colisiones en la ru66 — que es justo lo que sabemos que pasa en
// placa. Si el modelo no reprodujera ese cero, no habria que creerle nada.
//
// ⚠️ Y CORRIGE UN ERROR DEL PRIMER ANALISIS, que se hizo con la huella MALA de
// la SAT de la ru66. Se supuso base[8:7]=0 en las dos escenas (SAT de 128 B),
// pero la ru66 programa R#5=0x03/R#11=0x02 -> base=0x10180 -> base[8:7]=0b11, y
// la mascara (base[8:7] & plane[5:4]) de
// vdp_sprite_select_visible_planes.v:136 NO anula plane[5:4]: su SAT ocupa el
// DOBLE. Con la huella mala la busqueda de candidatas no valia.
//
// SE CONSERVAN LAS DOS GARANTIAS DEL _151:
//   * BIYECTIVO con el tag (enumeracion de las 65536 palabras) -> cero falsos
//     aciertos.
//   * IDENTIDAD en 0x0000-0x1FFF (ahi v[13]=v[14]=0): las tablas de SCREEN
//     0/1/2/3 y el bg de SC5 pagina 0 conservan idx13 = v[12:0] bit a bit. La
//     leccion _117 queda intacta.
// Y sigue SIN SER una garantia universal: en una cache direct-mapped de 8192
// palabras, una pagina de patrones de 8192 cubre todo el indice y siempre puede
// existir UN alias. La red de seguridad general es el victim buffer.
//
// GUARDIAN: tb_sprite3 -DRU66 tiene que seguir dando DIFFS=0 contra la
// referencia. Es la prueba automatica de que el caso VALIDADO EN PLACA no se
// rompe — correrla SIEMPRE antes de sintetizar esto.
// ===========================================================================
function [12:0] c_idx13(input [15:0] v);
    c_idx13 = { v[12] ^ v[13], v[11] ^ v[14], v[10:0] };
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
// _150 FIX DE COHERENCIA nº2 (agujero PRE-EXISTENTE simetrico del anterior).
// scq_* se captura de `sc_*[c_idx13(vram_address)]` en el MISMO flanco en que un
// fill puede estar escribiendo esos arrays; la lectura no-bloqueante devuelve la
// foto ANTERIOR al fill. Si en ese flanco lo que hay en el bus es una ESCRITURA,
// su write-check de T+1 razona con un scq_* obsoleto y decide mal:
//   * mismo word: el fill acaba de instalar el tag, scq_tag es el viejo =>
//     wrk_hit=0 => la palabra recien escrita NO se aplica y la cache queda
//     RANCIA bajo el tag correcto;
//   * mismo indice, word distinto: scq_tag era el del word que se escribe =>
//     wrk_hit=1 => se pisan bytes ENCIMA de la linea que el fill acaba de meter.
// CURA: el fill CEDE el ciclo en que se acepta una escritura (se DIFIERE, no se
// pierde: fill_pend se mantiene). Asi el orden queda write-check-primero /
// fill-despues, que es sano en los dos casos.
// COSTE: un termino AND mas en el gate. vram_valid y vram_write son salidas de
// FF PLANAS de vdp_vram_interface (ff_vram_valid/ff_vram_write, lineas 345/346),
// asi que es FF -> 1 LUT -> WE de BSRAM: no reabre el riesgo 1 (ese es el cono
// del DO de sc_tag/sc_v hacia wrk_hit, que NO se toca).
wire wr_accept = vram_valid && vram_write;
wire fill_now = fill_pend && !wrk_p1 && !wr_accept && scv_ready;
wire [12:0] scw_idx = wrk_hit ? c_idx13(wrk_addr1) : c_idx13(fill_addr);
wire scw_we0 = (wrk_hit && !wrk_mask1[0]) || fill_now;
wire scw_we1 = (wrk_hit && !wrk_mask1[1]) || fill_now;
wire scw_we2 = (wrk_hit && !wrk_mask1[2]) || fill_now;
wire scw_we3 = (wrk_hit && !wrk_mask1[3]) || fill_now;
wire [7:0] scw_b0 = wrk_hit ? wrk_data1[ 7: 0] : fill_word[ 7: 0];
wire [7:0] scw_b1 = wrk_hit ? wrk_data1[15: 8] : fill_word[15: 8];
wire [7:0] scw_b2 = wrk_hit ? wrk_data1[23:16] : fill_word[23:16];
wire [7:0] scw_b3 = wrk_hit ? wrk_data1[31:24] : fill_word[31:24];

// ============================================================================
// _150 VICTIM BUFFER de la sc-cache — 16 entradas TOTALMENTE ASOCIATIVAS, en FF
// y LUT (CERO BSRAM nuevos: la cache ya se come 19 macros y la presion de
// columnas fue lo que descoloco el placement del motor de comandos en _126e).
//
// ⚠ _151 — LIMITE MEDIDO DE ESTE BLOQUE, LEER ANTES DE CONFIAR EN EL. El VB
// rescata un conflicto 2-a-1 AISLADO (el caso sintetico de tb_sprite3), pero NO
// un conflicto MASIVO: en la escena real de la ru66 (tb_sprite3 -DRU66) el
// conjunto en pugna en las lineas 95/96 son ~32 palabras sobre 16 lineas de
// indice, y la politica round-robin de 16 entradas se recicla ENTERA dentro de
// la misma scanline => vbhit = 0 y 41-42 miss/frame, exactamente lo que se veia
// en placa (~2.700 spMISS/s). Escalar el VB a 32 tampoco basta en todas las
// fases de animacion (el modelo da 64 miss/frame en dos de las cuatro). La cura
// real fue quitar el alias en el INDICE (ver _151 FIX en c_idx13); el VB se
// queda como red de seguridad GENERAL, no como el remedio de este caso.
//
// POR QUE. El FIX A (_148, 8192 lineas) bajo el miss de sprite del 20.0% al
// 0.33%, pero el residuo BASTA para destrozar el DEVCON: en placa (_149, COM11)
// la demo ru66 va a ~30 miss de sprite/s (99% bien) y DEVCON.COM a ~3050/s
// (bandas de basura). Ese residuo es UN choque de indice IRREDUCIBLE POR
// TAMANO — ver el bloque "RESIDUO CONOCIDO" de arriba: con SPT@0x8000 y
// SAT@0x10000 el plano p=4 linea fuente yl=0 cae EXACTAMENTE en idx13
// 0x800..0x801, encima de la entrada de SAT del plano 0, y la SAT se relee en
// CADA scanline => ping-pong perpetuo. Mas lineas NO lo arreglan (el conflicto
// es 2-a-1 sobre el mismo indice): pide ASOCIATIVIDAD.
//
// COMO. Cada FILL de la sc-cache se copia TAMBIEN aqui (round-robin). Cuando el
// siguiente fill al MISMO indice desaloja esa linea de la sc-cache, la copia
// SOBREVIVE en el VB. En el lookup, si falla la sc-cache pero acierta el VB se
// sirve desde aqui y NO se va al backend NI se toca la sc-cache: NO re-insertar
// es justo lo que ROMPE el ping-pong (re-insertar volveria a desalojar al otro
// y el lazo seguiria). Regimen permanente del caso DEVCON: la SAT vive en el VB,
// el patron en la sc-cache, cero trafico de backend.
//
// COHERENCIA (un dato rancio servido desde aqui = pantalla corrupta):
//  * INSERT: SOLO desde fill_word, que ya paso el guardia pf_dirty (ninguna
//    escritura al mismo word pendiente en wq). Hereda EXACTAMENTE la garantia
//    de la sc-cache, ni mas ni menos.
//  * INVALIDACION: TODA escritura borra las entradas que casan. wrk_p1 se arma
//    en CADA vram_write (incluso con wq llena, ver la aceptacion de peticion) y
//    la invalidacion cae en el MISMO flanco en que la escritura se registra.
//    Como lectura y escritura son MUTUAMENTE EXCLUYENTES (un solo vram_valid),
//    el lookup mas cercano posible a una escritura es su T+1, y para entonces
//    el valid ya esta borrado. Se invalida CASE EL TAG O NO en la sc-cache: el
//    VB es independiente.
//  * INSERT e INVALIDACION nunca coinciden: fill_now exige !wrk_p1.
//  * Duplicados (dos fills del mismo word sin escritura entre medias) son
//    posibles pero llevan dato IDENTICO — para que difirieran haria falta una
//    escritura entre ambos, y esa escritura habria invalidado las dos. Aun asi
//    el mux de salida es por PRIORIDAD (no OR), asi que el caso es inerte.
//  * Se invalida por DIRECCION COMPLETA (16 bits de addr[17:2]): asociativa
//    pura, sin aliasing de indice ni de tag.
//
// TIMING — LA ETAPA LIBRE (esto es lo que hace el cambio viable). spr_p1 (T+1)
// carga pipe[1] y llega a pipe[6] en T+7; cargar pipe[2] en T+2 llega a pipe[6]
// EL MISMO CICLO. El contrato de 8 ciclos del display NO se toca y el CAM + mux
// tiene un ciclo ENTERO para el, alimentado SOLO por FF (spr_addr1, vb_*) —
// cero contacto con el DO de las BSRAM.
// Ademas AFLOJA el riesgo 1 del gate: el encolado a rq (incremento de rq_wp +
// escritura de 21 bits) colgaba de scq_v/scq_tag, o sea del DO de sc_tag/sc_v en
// cascada de 2 bloques BSRAM; ahora cuelga de vb_p2/vb_hit2, dos FF planos, y
// scq_* solo alimenta el mux de pipe[1] y UN FF (vb_p2).
// ============================================================================
// syn_ramstyle="registers": el CAM lee TODAS las entradas EN PARALELO, asi que
// ninguna primitiva de RAM puede servirlas y la inferencia solo puede dar FF —
// pero el pragma lo deja EXPLICITO y blinda el "cero BSRAM nuevos" contra
// cualquier sorpresa del sintetizador (es un comentario para iverilog/verilator).
// TAMANO: knob de compilacion (`VB_ENTRIES`), potencia de 2. NO se puede razonar
// a priori (depende de cuantos fills ajenos pasan entre dos visitas al par en
// conflicto), asi que se BARRIO en tb_sprite3 con el setup de peor caso.
// Miss REAL de sprite por frame en regimen permanente, y diff del frame contra
// la referencia dorada s3r_frame.txt (737804 lineas):
//     sin VB (_149)  23/frame  0.33%   diff 3168
//     VB_N =  4      11/frame  0.16%   diff  960
//     VB_N =  8      11/frame  0.16%   diff 1440
//     VB_N = 16       0/frame  0.00%   diff    0   <-- RODILLA, es el elegido
//     VB_N = 32       0/frame  0.00%   diff    0
// 4 y 8 se quedan a medias porque el par en conflicto solo se visita ~3 veces
// por frame y entre visita y visita pasan mas de 8 fills: la entrada que hace
// falta ya se ha reciclado. 32 no aporta nada sobre 16 y cuesta el doble de FF.
`ifndef VB_ENTRIES
`define VB_ENTRIES 16
`endif
`ifndef VB_PTRW
`define VB_PTRW 4
`endif
localparam VB_N    = `VB_ENTRIES;
localparam VB_PW   = `VB_PTRW;
reg [15:0] vb_a [0:VB_N-1] /* synthesis syn_ramstyle = "registers" */; // clave = addr[17:2] COMPLETA
reg [31:0] vb_w [0:VB_N-1] /* synthesis syn_ramstyle = "registers" */; // dato de 32 bits
reg [VB_N-1:0] vb_val;                   // valids
reg [VB_PW-1:0] vb_rr;                   // puntero de reemplazo round-robin

// CAM de LECTURA (etapa 1, sobre spr_addr1 REGISTRADO) y de INVALIDACION
// (etapa 1 de ESCRITURA, sobre wrk_addr1). Comparadores explicitos, uno por
// entrada: la lectura es de las VB_N entradas EN PARALELO, asi que ninguna
// primitiva de memoria puede servirlas y la inferencia solo puede dar FF.
wire [VB_N-1:0] vb_rm;
wire [VB_N-1:0] vb_im;
genvar vg;
generate for (vg = 0; vg < VB_N; vg = vg + 1) begin : g_vbcam
    assign vb_rm[vg] = vb_val[vg] && (vb_a[vg] == spr_addr1);
    assign vb_im[vg] = vb_val[vg] && (vb_a[vg] == wrk_addr1);
end endgenerate
wire vb_rhit = |vb_rm;
// mux por PRIORIDAD (gana el indice mas bajo), no OR: inerte ante duplicados
integer vbi;
reg [31:0] vb_rd;
always @(*) begin
    vb_rd = vb_w[VB_N-1];
    for (vbi = VB_N-1; vbi >= 0; vbi = vbi - 1)
        if (vb_rm[vbi]) vb_rd = vb_w[vbi];
end

// ETAPA 2 del lookup (T+2): lo que fallo ventana + sc-cache en T+1 llega aqui
// con el veredicto del CAM y su dato ya REGISTRADOS.
reg        vb_p2;                        // hay un miss de etapa 1 en vuelo
reg [15:0] vb_addr2;
reg [4:0]  vb_tag2;
reg        vb_hit2;                      // acierto del victim buffer
reg [31:0] vb_dat2;
reg [31:0] c_vbhit;                      // telemetria de SIMULACION (sin
                                         // fanout: la sintesis lo poda, coste
                                         // HW = 0; se lee por jerarquia en TB)

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
        wq_wp <= 0; wq_rp <= 0; rq_wp <= 0; rq_rp <= 0; wq_vld <= 16'd0;

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
        c_wqdrop <= 0; c_s1drop <= 0;             // _154
        c_spmiss <= 0; c_spfet <= 0;                  // _148 FIX C
`ifdef SHIM_DBG_SPLIT
        c_wnhit <= 0; c_schit <= 0;                   // _163
`endif
        // _150 VICTIM BUFFER: se resetea SOLO el CONTROL (valids, puntero de
        // reemplazo y los dos FF de veredicto de la etapa 2). Las claves y los
        // datos (vb_a/vb_w = 384 FF) y vb_addr2/vb_tag2/vb_dat2 NO llevan reset
        // A PROPOSITO: van gateados por vb_val/vb_p2/vb_hit2, y colgar ~450
        // cargas mas de la red de reset asincrono es exactamente el tipo de
        // presion que ha estado moviendo el placement en esta saga. En
        // simulacion arrancan en X y NO propagan: vb_rm[k] es
        // `vb_val[k] && (...)` = 0 limpio con vb_val = 0.
        vb_val <= {VB_N{1'b0}}; vb_rr <= {VB_PW{1'b0}};
        vb_p2 <= 1'b0; vb_hit2 <= 1'b0; c_vbhit <= 0;
        spr_p1 <= 0; spr_addr1 <= 0; spr_tag1 <= 0;
        wrk_p1 <= 0; wrk_addr1 <= 0; wrk_data1 <= 0; wrk_mask1 <= 4'hF;
        obl_pend <= 0; obl_chk <= 0; obl_do <= 0; obl_w <= 0;
        bg_prev0 <= 0; bg_prev1 <= 0; stride <= 0; obl_walked <= 0;
        // _163 v2: reset de las ranuras de frontera. ⚠️ Esto NO puede ir bajo
        // ifdef: si no se resetean, flip_pf_* arranca indefinido en hardware y
        // el caminante puede desviarse a una direccion basura en el primer
        // frame. (Se colo asi al hacer el arreglo incondicional; Icarus compila
        // igual y no lo habria cantado.)
        flip_dst_p[0] <= 0; flip_dst_p[1] <= 0;
        flip_tgt_p[0] <= 0; flip_tgt_p[1] <= 0;
        flip_dst_n[0] <= 0; flip_dst_n[1] <= 0;
        flip_tgt_n[0] <= 0; flip_tgt_n[1] <= 0;
        flip_pf_p <= 2'b00; flip_pf_n <= 2'b00;
`ifdef SHIM_DBG_SPLIT
        c_flipdet <= 0; c_flippf <= 0; c_walk <= 0;
`endif
        obl_w_c <= 0; obl_w_d <= 0;
        bgp_wp <= 0; bgp_rp <= 0; c_park <= 0; c_pkov <= 0; pkov_p <= 0;
        ecq_wp <= 0; ecq_rp <= 0; bg_quiet <= 0;      // _135
        ec_cred0 <= 0; ec_cred1 <= 0;
        pfB_pend <= 0; pfB_wr <= 0;
        fill_pend <= 0; fill_addr <= 0; fill_word <= 0; fill_sp <= 0;
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
        vb_p2  <= 1'b0;                  // _150: etapa 2 del lookup
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

        // ---------- _150 FIX DE COHERENCIA (agujero PRE-EXISTENTE, cazado por
        // el banco tb_vbcoh). pf_dirty mira wq en el ciclo en que la lectura
        // COMPLETA, y wq se actualiza al FINAL de ese mismo ciclo => una
        // escritura aceptada EN ESE CICLO es INVISIBLE para pf_dirty. El fill
        // queda armado con dato PRE-escritura; el write-check aplica su update
        // correcto en T+1 (el fill esta bloqueado por !wrk_p1)... y el fill
        // aterriza en T+2 y LO PISA. Traza real del banco (palabra 0x4815):
        //   FILL 4815=cdfd8746 | WR dqm=1101 -> WCHK wrk_hit=1 (cache=cdfde046)
        //   | FILL 4815=cdfd8746 OTRA VEZ -> la lectura siguiente sirve RANCIO.
        // Y de regalo re-insertaba ese rancio en el VICTIM BUFFER un ciclo
        // DESPUES de haberlo invalidado, o sea que el VB heredaba el agujero.
        // CURA: si el write-check en vuelo apunta a la MISMA palabra que el fill
        // armado, se MATA el fill. Se autocura por el camino miss->rescate,
        // exactamente igual que un fill descartado por pf_dirty.
        // COSTE/RIESGO: un comparador de 16 bits entre DOS FF (wrk_addr1 vs
        // fill_addr) que solo llega al D de fill_pend — NO toca el cono del WE
        // de las BSRAM ni el de wrk_hit (riesgo 1 del gate).
        if (wrk_p1 && fill_pend && (wrk_addr1 == fill_addr)) fill_pend <= 1'b0;

        // ---------- _176 REFILL de escrituras no-residentes (write-allocate
        // diferido y DESCARTABLE). El suelo de ~10 miss/frame "inducido por
        // las escrituras" (nota del obl_la): una palabra escrita SIN tag-match
        // queda no-residente, y si es la SPT/SAT que el LRMM o la CPU
        // reescriben cada frame, el sprite la falla justo despues — y un miss
        // de sprite ES una raya: el colector latchea a fase fija (sub_phase
        // 14, vdp_sprite_info_collect.v:207) y el backend no llega. DEVCON.COM
        // en placa: rayas ligeras aleatorias (03/08).
        // CURA: tras un write-check de COMANDO o CPU sin tag-match se encola
        // una RELECTURA-prefetch con clase MUDA (tag 5'd0: el router del
        // interface no la entrega a nadie, no toca ventana ni VB, y pasa la
        // SC_FILL_POLICY). rq va por DEBAJO de wq => la relectura devuelve el
        // dato POST-escritura: fill coherente por construccion. DESCARTABLE
        // dos veces: (a) solo encola con rq_used<=10 (no toca ninguna
        // reserva); (b) este push va ANTES en el texto que el del vb y el del
        // aparcamiento — si coinciden en el ciclo, la asignacion posterior
        // GANA y el refill se pierde en silencio (= quedarse como hoy, el
        // miss se autocura). CONVERGE: al siguiente barrido la palabra es
        // residente y la escritura pasa a ser update puro — coste cero en
        // regimen. La decision va REGISTRADA (refill_p) para no colgar logica
        // nueva del cono DO->wrk_hit (leccion _121b). El tope rq_used<=4 va
        // POR DEBAJO del umbral de vram_stall (rq_used>=6): un refill jamas
        // provoca un stall del motor/CPU.
        // ⛔ EXPULSADO en la era V3 (cura #1 del expediente de la caza,
        // 4-6/08): el refill encolaba con tag mudo 5'd0, cuya clase [4:2]=0
        // NO es C_COMMAND, asi que SE SALTABA el filtro de SC_FILL_POLICY=1
        // — el que existe para que el trafico de destino del motor no inunde
        // la sc-cache. Cada escritura-miss del motor recreaba la inundacion
        // de la _164 (spMISS/s 25.000-55.000) => SAT/SPT desalojadas en pleno
        // scanline => el colector latchea basura a fase fija = la BANDA DE
        // RUIDO de la V9968DM2 donde debe ir el logo translucido.
        // Sentenciado por biseccion en placa (s011 BIEN / s012 MAL, una sola
        // variable) y confirmado en la s015. El suelo de ~10 miss/frame que
        // pretendia curar vuelve, y se acepta: es un coste de rendimiento,
        // no un artefacto visible.

        // ---------- _179 REINTENTO ANSIOSO del fill de ventana descartado ----
        // El suelo del bg en bitmap ("~10 miss/frame inducidos por las
        // ESCRITURAS", nota del obl_la): cuando el LMMM redibuja una zona, la
        // colision fill<->escritura pendiente (pf_dirty) DESCARTA el fill de
        // la ventana y el hueco se rescata TARDE al llegar el display = la
        // rayita en el bg animado (DEVCON v2 en placa, 04/08 — el _176 no la
        // toco porque el bg bitmap no usa la sc-cache). CURA: el descarte
        // re-encola la palabra como lectura-demanda con tag 5'b00001 (clase
        // muda: el interface la ignora) POR DEBAJO de wq => llega POST-
        // escritura y rellena la ventana ANTES de que el display la pida.
        // ⛔ EXPULSADO en la era V3 junto con el _176 (composicion de la
        // v2.1.2 del expediente: "la v2.1 completa MENOS _176 y _179").
        // Nunca se probo aislado en placa — la s015 que exonero al _177 ya
        // corria SIN el (no existia en la linea ligera). Se retira por la
        // misma familia de riesgo: inyecta lecturas con tag mudo en rq
        // durante el display. La rayita del bg animado que curaba vuelve a
        // quedar abierta y se anota como frente, no como regresion.

        // ---------- _150 VICTIM BUFFER: captura, insercion e invalidacion ----
        // (1) CAPTURA del veredicto del CAM en la etapa 1 del lookup. Solo hace
        //     falta el ciclo del fetch (CE = spr_p1, un FF plano).
        if (spr_p1) begin
            vb_hit2 <= vb_rhit;
            vb_dat2 <= vb_rd;
        end
        // (2) INVALIDACION por escritura — PRIMERO en el texto, pero es
        //     IMPOSIBLE que coincida con el insert (fill_now exige !wrk_p1), asi
        //     que no hay carrera entre el `vb_val <= ...` de aqui y el
        //     `vb_val[vb_rr] <= 1'b1` de abajo.
        if (wrk_p1) vb_val <= vb_val & ~vb_im;
        // (3) INSERT round-robin, SOLO en fills de SPRITE (fill_sp). Se copia el
        //     MISMO fill_word que entra en la sc-cache: misma garantia de
        //     coherencia, mismo instante, cero logica de "leer la victima" (que
        //     habria pedido un puerto de lectura extra de las BSRAM). El efecto
        //     victim-buffer sale igual: la copia sobrevive al fill SIGUIENTE
        //     sobre su mismo indice, que es el que la desaloja.
        //     POR QUE SOLO SPRITE. Honestidad sobre lo medido: en tb_sprite3
        //     este filtro NO cambia NADA (el fondo va por la ventana y solo
        //     genera 1 fill/frame; con y sin filtro salen los mismos numeros).
        //     Se deja como SEGURO para escenarios que el banco no cubre — el
        //     DEVCON corre bajo DOS, con lecturas de CPU y de motor de comandos
        //     que SI generan fills a chorro y podrian barrer las entradas justo
        //     antes de que el sprite las necesite. El fondo no pierde nada: en
        //     bitmap tiene su VENTANA de prefetch, y en modos de patrones las
        //     tablas MSX1 enteras (12.75KB) caben RESIDENTES en la sc-cache de
        //     32KB, asi que alli no hay conflicto que resolver. Y el choque que
        //     este bloque existe para matar (SAT vs SPT) es SPRITE contra
        //     SPRITE: los dos lados entran igual.
        if (fill_now && fill_sp) begin
            vb_rr  <= vb_rr + {{(VB_PW-1){1'b0}}, 1'b1};
            vb_val[vb_rr] <= 1'b1;
            vb_a[vb_rr] <= fill_addr;
            vb_w[vb_rr] <= fill_word;
        end

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
        // _163 v2 ⚠️ SIN el "- obl_la". El wk_tgt de arriba lo lleva para
        // CANCELAR el +obl_la que obl_w ya tiene dentro (se carga como
        // spr_addr1 + obl_la en el hit). flip_dst guarda la direccion CRUDA,
        // asi que restarlo dejaba el objetivo en frontera+30 en vez de
        // frontera+32: dos palabras corto, y el OBL prefetchea de una en una.
        // MEDIDO con ese error: 382 precalentamientos y los fallos INTACTOS
        // en 384. Los contadores de maquinaria son los que lo delataron.
        flip_tgt_p[0] <= flip_dst_p[0] + stride;
        flip_tgt_p[1] <= flip_dst_p[1] + stride;
        flip_tgt_n[0] <= flip_dst_n[0] + stride;
        flip_tgt_n[1] <= flip_dst_n[1] + stride;
        obl_do   <= obl_chk && !(pwqB_v && pwqB_tag == obl_w_c[15:6]);
        obl_w_d  <= obl_w_c;
        // _127J: caminante (ver arriba) — slot OBL ocioso + zancada => se
        // re-arma la maquinaria de 3 fases hacia la linea siguiente. Un hit
        // bg simultaneo PISA obl_pend/obl_w mas abajo (el hit vivo manda) y
        // eso es exactamente la prioridad deseada.
        // _163 SP2: el caminante atiende PRIMERO la frontera de pagina.
        // Medido: con SP2 el fondo falla EXACTAMENTE una vez por conmutacion y
        // es un fallo EN FRIO (la ventana acierta 12666/12672 sin SP2, o sea
        // que no hay conflicto de capacidad: el dato NUNCA SE PIDIO, porque
        // este OBL avanza +2 en linea recta y la frontera salta ~8192).
        // La frontera es PREDECIBLE: donde aterrizo el salto de la linea
        // anterior + una zancada. Se prefetchea en el MISMO slot ocioso que ya
        // usaba el caminante => CERO trafico nuevo, que es la unica clase de
        // cambio que ha funcionado nunca en este fichero.
        if (obl_chk && pwqB_v && pwqB_tag == obl_w_c[15:6]
            && stride != 16'd0 && !obl_walked) begin
            obl_pend   <= 1'b1;
            obl_walked <= 1'b1;
`ifdef SHIM_DBG_SPLIT
            c_walk     <= c_walk + 32'd1;
`endif
            // prioridad: fronteras pendientes primero (son las que fallan en
            // frio), y si no hay ninguna, el caminante de siempre.
            if (flip_pf_p[0]) begin
                obl_w        <= flip_tgt_p[0];
                flip_pf_p[0] <= 1'b0;       // una sola vez por conmutacion
`ifdef SHIM_DBG_SPLIT
                c_flippf     <= c_flippf + 32'd1;
`endif
            end
            else if (flip_pf_p[1]) begin
                obl_w        <= flip_tgt_p[1];
                flip_pf_p[1] <= 1'b0;
`ifdef SHIM_DBG_SPLIT
                c_flippf     <= c_flippf + 32'd1;
`endif
            end
            else if (flip_pf_n[0]) begin
                obl_w        <= flip_tgt_n[0];
                flip_pf_n[0] <= 1'b0;
`ifdef SHIM_DBG_SPLIT
                c_flippf     <= c_flippf + 32'd1;
`endif
            end
            else if (flip_pf_n[1]) begin
                obl_w        <= flip_tgt_n[1];
                flip_pf_n[1] <= 1'b0;
`ifdef SHIM_DBG_SPLIT
                c_flippf     <= c_flippf + 32'd1;
`endif
            end
            else obl_w <= wk_tgt;           // comportamiento de siempre
        end
        pfB_pend <= 1'b0;                // default; las ramas de spr_p1 lo
                                         // suben (asignacion posterior gana)


        // ---------- _127: aprendizaje de la zancada (wrap POR STREAM) ----
        if (spr_p1 && spr_tag1[4:2] == C_BG) begin : stride_learn
            reg [15:0] d;
            d = spr_addr1 - (spr_addr1[14] ? bg_prev1 : bg_prev0);
            if (spr_addr1[14]) bg_prev1 <= spr_addr1;
            else               bg_prev0 <= spr_addr1;
            // _163 SP2: DETECTAR LA CONMUTACION DE PAGINA. No se mira un bit
            // concreto a proposito (SC7/8 la pagina esta en v[13], SC5/6 en
            // v[12]): se detecta por la MAGNITUD del salto dentro del stream.
            //   avance normal        = +1
            //   wrap del scroll H    = -8..-64
            //   conmutacion de pagina= ~±4096 (SC5/6) o ~±8192 (SC7/8)
            //   retorno de CAMPO     = ~±13568  <-- NO es una conmutacion
            // ⚠️ MEDIDO: con un umbral suelto de 1024 el retorno de campo se
            // colaba como conmutacion y disparaba un prefetch inutil por frame.
            // No cambiaba el numero de fallos (los 2 residuales seguian siendo
            // 2) pero los movia de sitio, y con ellos su huella visible: 64 px
            // el frame anterior y 96 el siguiente. Ruido que no debe estar.
            // La cota SUPERIOR lo separa con margen ancho por los dos lados:
            // cubre 4096 y 8192 de sobra y excluye 13568.
            if (d[15]) begin
                if (~d >= FLIP_LO && ~d <= FLIP_HI) begin  // NEGATIVO (vuelta)
                    flip_dst_n[spr_addr1[14]] <= spr_addr1;
                    flip_pf_n[spr_addr1[14]]  <= 1'b1;
`ifdef SHIM_DBG_SPLIT
                    c_flipdet <= c_flipdet + 32'd1;
`endif
                end
            end
            else if (d >= FLIP_LO && d <= FLIP_HI) begin   // POSITIVO (ida)
                flip_dst_p[spr_addr1[14]] <= spr_addr1;
                flip_pf_p[spr_addr1[14]]  <= 1'b1;
`ifdef SHIM_DBG_SPLIT
                c_flipdet <= c_flipdet + 32'd1;
`endif
            end
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
`ifdef SHIM_DBG_SPLIT
            // _163: DE QUIEN vive el fondo. La campana de SP2 se quedo sin
            // saber si el grueso lo sirve la VENTANA o la sc-cache, y sin eso
            // no se puede proponer un arreglo con fundamento (el pliegue del
            // bit de pagina en w_idx salio BYTE-IDENTICO, que es justo lo que
            // pasaria si la ventana no fuese la que manda aqui).
            // Solo diagnostico: bajo ifdef, cero coste en la build real.
            if (spr_tag1[4:2] == C_BG) begin
                if (pwq_v && pwq[41:32] == spr_addr1[15:6])
                    c_wnhit <= c_wnhit + 32'd1;
                else if (scq_v && scq_tag == spr_addr1[15:12])
                    c_schit <= c_schit + 32'd1;
            end
`endif
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
                // _150: MISS de ventana + sc-cache. YA NO se encola aqui: se
                // DIFIERE UNA ETAPA (T+2) para consultar el VICTIM BUFFER, y el
                // encolado al backend vive alli. Cargar pipe[2] en T+2 emerge en
                // pipe[6] EL MISMO CICLO que cargar pipe[1] en T+1 => el
                // contrato de 8 ciclos queda INTACTO (etapa libre de la
                // tuberia). El brazo bg de abajo NO se mueve: depende de pwq
                // (ventana), que solo es valido en ESTE ciclo.
                vb_p2    <= 1'b1;
                vb_addr2 <= spr_addr1;
                vb_tag2  <= spr_tag1;
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

        // ---------- _150 ETAPA 2 del lookup: VICTIM BUFFER -------------------
        // Llega SOLO lo que fallo ventana + sc-cache en T+1, con el veredicto
        // del CAM ya registrado. TODO lo que hay aqui cuelga de FF planos
        // (vb_*): ni un comparador contra el DO de una BSRAM.
        // vb_p2 y spr_p1 NUNCA coinciden (vb_p2 es spr_p1 retrasado un ciclo y
        // los vram_valid van separados >=8 ciclos), asi que no hay carrera por
        // pipe[] ni por el puerto de escritura de rq.
        if (vb_p2) begin
            if (vb_hit2) begin
                // HIT del VICTIM BUFFER: se sirve por pipe[2] (mismo instante
                // de salida que pipe[1] en T+1: 8 ciclos EXACTOS) y NO se va al
                // backend. Al no haber fill, la sc-cache NO se toca: eso es
                // precisamente lo que rompe el ping-pong de indice.
                pipe[2] <= {1'b1, vb_tag2, vb_dat2};
                c_vbhit <= c_vbhit + 32'd1;
            end
            else begin
                // MISS REAL: backend + fill al volver (identico al de antes,
                // solo que un ciclo mas tarde y con los registros de la etapa
                // 2). bg/sprite encolan con reserva (drop tolerable, se
                // autocuran); CPU/COMANDO encolan SIEMPRE.
                if (vb_tag2[4:2] == C_BG || vb_tag2[4:2] == C_SPRITE) begin
                    if (rq_room_soft) begin
                        rq[rq_wp] <= {vb_tag2, vb_addr2};
                        rq_wp <= rq_wp + 4'd1;
                    end
                    else begin
                        // _123/_124: APARCAR en vez de descartar (fix linea
                        // barredora); FIFO de 4 para las rafagas bg+bg.
                        if (!bgp_full) begin
                            bgp[bgp_wp] <= {vb_tag2, vb_addr2};
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
                            $display("DROP S3b_park_lleno t=%0t addr=%h tag=%h", $time, vb_addr2, vb_tag2);
`endif
                        end
                    end
                end
                else if (!rq_full) begin
                    rq[rq_wp] <= {vb_tag2, vb_addr2};
                    rq_wp <= rq_wp + 4'd1;
                end
                // _148 FIX C / _150: gemelo de c_miss para el camino de SPRITE.
                // Ahora cuenta el miss REAL (post victim buffer), que es lo que
                // de verdad va al backend y lo que hay que mirar en COM11.
                if (vb_tag2[4:2] == C_SPRITE) c_spmiss <= c_spmiss + 32'd1;
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
        // _150: el encolado a rq se mudo de spr_p1 (T+1) a vb_p2 (T+2), asi que
        // el guardia anti-colision sobre rq[rq_wp]/rq_wp tiene que cubrir LOS
        // DOS ciclos (este bloque va DESPUES en el texto y ganaria la asignacion).
        if (!bgp_empty && rq_room_soft && !spr_p1 && !vb_p2) begin
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
        // _154: contador REAL del drop S1 (siempre compilado; el $display sigue bajo ifdef)
        if ((obl_do || pfB_pend) && pfq_full)
            c_s1drop <= c_s1drop + 16'd1;
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
                    wq_wp <= wq_wp + 4'd1;
                end
                else c_wqdrop <= c_wqdrop + 16'd1;    // _154: escritura PERDIDA (nunca llega a DDR3)
`ifdef SHIM_DBG_DROPS
                if (wq_full) $display("DROP S5_wq_full t=%0t addr=%h", $time, vram_address);
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
                // Colision fill<->escritura pendiente: el fill se DESCARTA
                // (guarda !pf_dirty de abajo) y el word se autocura por
                // miss->rescate. (La "fusion _148 FIX B" nunca se cableo —
                // ver la nota junto a pf_dirty.)
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
                    // (era V3: aqui vivia el productor del _179, expulsado —
                    // ver la nota del push retirado mas arriba. El descarte
                    // por pf_dirty vuelve a rescatarse tarde, al llegar el
                    // display, como en el mundo pre-_179.)
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
                    // (era V3: el `|| cur_tag == 5'b00001` era la puerta del
                    // reintento _179 — retirada con el; ya nadie emite ese
                    // tag mudo, asi que la condicion vuelve a ser solo bg.)
                    if (cur_tag[4:2] == C_BG
                        && !pf_dirty && !wu_hit) begin
                        pww_en   <= 1'b1;
                        pww_idx  <= w_idx(cur_addrw);
                        pww_tag  <= cur_addrw[15:6];
                        pww_data <= {w_hi, w_lo};
                        pwv_set_p <= 1'b1;
                        pwv_set_i <= w_idx(cur_addrw);
                    end
                    // ...y a la CACHE (v3c: TODO consumidor de lectura
                    // rellena — bg/sprite/CPU/comando) — via fill_pend
                    //
                    // _164 FIX — EL RELLENO SE FILTRA A LECTURAS DE SPRITE.
                    // La linea de arriba describe el comportamiento ANTERIOR
                    // (v3c: rellenaba TODO consumidor). Se deja escrita porque
                    // explica de donde venia el defecto.
                    //
                    // DEFECTO: cuando un comando LEE SU DESTINO —cosa que hace
                    // toda operacion logica distinta de IMP, y que el LRMM hace
                    // en CADA pixel— y ese destino es la tabla de patrones,
                    // inunda esta cache y desaloja los patrones que los sprites
                    // piden en el mismo scanline. La _150 ya habia visto la
                    // distincion y filtro el VICTIM BUFFER (fill_sp, justo
                    // debajo), pero dejo la cache abierta.
                    //
                    // MEDIDO (run_cmdthrash.sh, escena ru66, una sola variable):
                    //   c_spmiss/frame  vs1   vs2   vs3   vs4   vs5
                    //     base          2484   256    25     1     0  CONVERGE
                    //     +comandos     1414  1427  1133   617  1306  NUNCA
                    //     +comandos+fix 2627   135    10     0     0  CONVERGE
                    // En placa (V9968DM con su LRMM vivo): spMISS/s 25.000-55.000
                    // = ~667/frame; 1300x60 = 78.000/s en simulacion. Mismo orden.
                    //
                    // COSTE, medido con la bateria estandar corrida sin y con el
                    // filtro (run_battery_scfill.sh): los TRES bancos siguen OK
                    // (sc8cmd_full fallos_vram=0, sc5line diffs=0, cpu_bulk
                    // 0/8192); bkA 93264 -> 93363 (+0,11%), bg_miss 73 -> 79,
                    // TURNOS total IDENTICO. El motor de comandos y el puerto de
                    // CPU NO dependian de esta cache.
                    //
                    // ============================================================
                    // ⛔⛔ DOS INTENTOS DE FILTRAR ESTE RELLENO, DOS BUILDS ROTAS.
                    // NO VOLVER A TOCAR ESTA CONDICION SIN LEER ESTO ENTERO.
                    // ============================================================
                    // EL DEFECTO QUE SE INTENTABA CURAR (real y medido, sigue
                    // ABIERTO): cuando un comando LEE SU DESTINO —toda operacion
                    // logica != IMP, y el LRMM en CADA pixel— y ese destino cae en
                    // la tabla de patrones, inunda esta cache y desaloja los
                    // patrones que los sprites piden en el mismo scanline.
                    // Medido (run_cmdthrash.sh): con trafico de comandos el
                    // c_spmiss/frame se queda en ~1300 y NO CONVERGE, contra ~0 sin
                    // el. En placa, el V9968DM: spMISS/s 3.840 -> 25.000-55.000.
                    //
                    // INTENTO 1 (rc4): `&& (cur_tag[4:2] == C_SPRITE)`
                    //   ROMPIO EL MODO TEXTO. Razone "el fondo va por la VENTANA,
                    //   no por esta cache": cierto en BITMAP (barrido lineal), FALSO
                    //   en TEXTO, donde la tabla de patrones se accede INDEXADA POR
                    //   EL CODIGO DE CARACTER y el prefetch lineal no la cubre.
                    //   Reproducido despues en run_textgeom_roto.sh: el ancho de un
                    //   pixel MSX pasa de {2:239} uniforme a {2:150 4:15 8:14}, con
                    //   caracteres estirados hasta 14 px de pantalla.
                    //
                    // INTENTO 2 (rc5): `&& (cur_tag[4:2] != C_COMMAND)`
                    //   Paso TODO lo que se le puso delante —texto byte-identico,
                    //   bateria estandar con contadores CLAVADOS a la linea base,
                    //   desalojo curado (1300 -> 1 por frame)— y AUN ASI COLGO LA
                    //   MAQUINA EN PLACA: arranca, el menu se ve bien, pero al
                    //   pulsar ESC sale el logo y NO CONTINUA (ni BIOS ni MSX-DOS).
                    //   Identico en dos dados distintos. Sin diagnosticar.
                    //   Sospecha sin confirmar: al no rellenar, TODA lectura de
                    //   comando falla y va a rq; `vram_stall = (wq_used>=2) ||
                    //   (rq_used>=6)` (linea ~471) y el motor OBEDECE ese stall
                    //   (vdp_vram_interface.v:259/276) => posible realimentacion.
                    //
                    // LECCION: NINGUN banco de simulacion arranca una BIOS, asi que
                    // esta clase de fallo NO ES DETECTABLE con la infraestructura
                    // actual. Cualquier intento futuro necesita PRIMERO un banco que
                    // haga boot, o se prueba directamente en placa asumiendo el
                    // coste de una campana.
                    //
                    // ESTADO: se vuelve al comportamiento original (rellena TODO
                    // consumidor). El desalojo queda como DEFECTO CONOCIDO, con su
                    // coste acotado y sus bancos ya escritos para el dia que se
                    // retome.
                    // _170: la condicion la elige SC_FILL_POLICY (arriba del
                    // fichero). Con 0 es EXACTAMENTE `!pf_dirty`, o sea el
                    // comportamiento de la rc3 que funciona.
                    if (!pf_dirty &&
                        ( (SC_FILL_POLICY == 3'd0) ? 1'b1 :
                          (SC_FILL_POLICY == 3'd1) ? (cur_tag[4:2] != C_COMMAND) :
                                                     (cur_tag[4:2] == C_SPRITE) )) begin
                        fill_pend <= 1'b1;
                        fill_addr <= cur_addrw;
                        fill_word <= {w_hi, w_lo};
                        // _150: quien pidio esta palabra. Solo los SPRITES
                        // alimentan el victim buffer (ver abajo).
                        fill_sp   <= (cur_tag[4:2] == C_SPRITE);
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
                wq_rp     <= wq_rp + 4'd1;
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
