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

    // ---- control de flujo (v3d): retiene los slots de CPU/COMANDO en el
    // interface cuando las colas van calientes — las escrituras de HMMV
    // desbordaban wq (4 plazas, backend byte-a-byte ~1.6us/palabra) y los
    // rectangulos salian RALLADOS. bg/sprite NO se frenan (ventana/cache).
    output wire        vram_stall,

    // ---- diagnostico ----
    output wire [7:0]  diag
);

localparam C_BG     = 3'd1;
localparam C_SPRITE = 3'd2;

// ============================================================================
// VENTANA DE PREFETCH de pantalla: 64 palabras de 32 bits, direct-mapped
// (indice addr[7:2] -> 6 bits, tag addr[17:8]). Una linea SC5 = 32 palabras,
// SC7/8 = 64: la ventana cubre la linea en curso + lookahead.
// ============================================================================
reg [31:0] pw_data [0:63];
reg [9:0]  pw_tagA [0:63];               // addr[17:8]
reg [63:0] pw_v;

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
reg [4095:0] sc_v;                       // valid en fabric (necesita reset)

// lecturas sincronas registradas (salidas BSRAM + valid)
reg [7:0]  scq_d0, scq_d1, scq_d2, scq_d3;
reg [3:0]  scq_tag;
reg        scq_v;

// etapa 1 del lookup (bg con miss de ventana, o sprite)
reg        spr_p1;
reg [15:0] spr_addr1;                    // addr[17:2]
reg [4:0]  spr_tag1;

// etapa 1 del write-check
reg        wrk_p1;
reg [15:0] wrk_addr1;
reg [31:0] wrk_data1;
reg [3:0]  wrk_mask1;                    // DQM (0 = escribir byte)

// OBL diferido (hit de ventana en ciclo 0 -> chequeo+encolado en ciclo 1)
reg        obl_pend;
reg [15:0] obl_w;

// escritura muxeada de la cache (1 solo write-site por array): el FILL
// (completacion rq de sprite) espera en fill_* si el ciclo lo usa un update
reg        fill_pend;
reg [15:0] fill_addr;
reg [31:0] fill_word;

// cola de prefetch (4 plazas de palabra-32 destino)
reg [15:0] pfq [0:3];                    // addr[17:2]
reg [1:0]  pfq_wp, pfq_rp;
wire       pfq_empty = (pfq_wp == pfq_rp);
wire       pfq_full  = (pfq_wp + 2'd1 == pfq_rp);

// cola de escrituras (4 plazas: {mask,wdata,addr})
reg [51:0] wq [0:3];                     // {mask[3:0], wdata[31:0], addr[17:2]}
reg [1:0]  wq_wp, wq_rp;
wire       wq_empty = (wq_wp == wq_rp);
wire       wq_full  = (wq_wp + 2'd1 == wq_rp);

// cola de lecturas al backend (v3c: 8 plazas con RESERVA anti-drop — las
// lecturas de CPU/COMANDO no pueden perderse JAMAS: un drop deja al motor
// de comandos esperando su rdata_en para siempre = el cuelgue de SC5 en HW,
// y a la CPU con el buffer de prefetch rancio = el rastro del cursor.
// bg/sprite (tolerantes, se autocuran) solo encolan si quedan >=3 libres.)
reg [20:0] rq [0:7];                     // {tag[4:0], addr[17:2]}
reg [2:0]  rq_wp, rq_rp;
wire [2:0] rq_used  = rq_wp - rq_rp;
wire       rq_empty = (rq_wp == rq_rp);
wire       rq_full  = (rq_used == 3'd7);
wire       rq_room_soft = (rq_used <= 3'd4);   // hueco para bg/sprite

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

// control de flujo: con wq medio-lleno o rq caliente, el interface retiene
// los slots de CPU/COMANDO (ready=0) hasta que el backend drene
wire [1:0] wq_used = wq_wp - wq_rp;
assign vram_stall = (wq_used >= 2'd2) || (rq_used >= 3'd6);

// ============================================================================
// backend: una op en vuelo; prioridad escrituras > lecturas no-bg > prefetch
// (las escrituras primero: coherencia lectura-tras-escritura del mismo dato;
//  la CPU del MSX no puede reordenar su propio write->read).
// Cada palabra-32 = 2 ops de 16 bits (addr byte par: +0 y +2).
// ============================================================================
reg        bsy;                          // op de 16b en vuelo
reg        done_d;
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

// ---- write-mux de la cache de sprites (1 solo write-site por array):
// UPDATE (write-check con tag-match, byte a byte por mascara DQM) tiene
// prioridad; el FILL espera en fill_pend al primer ciclo libre.
wire wrk_hit  = wrk_p1 && scq_v && (scq_tag == wrk_addr1[15:12]);
wire fill_now = fill_pend && !wrk_hit;
wire [11:0] scw_idx = wrk_hit ? wrk_addr1[11:0] : fill_addr[11:0];
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
    scq_d0 <= sc_d0[vram_address[13:2]];
end
always @(posedge clk_vdp) begin
    if (scw_we1) sc_d1[scw_idx] <= scw_b1;
    scq_d1 <= sc_d1[vram_address[13:2]];
end
always @(posedge clk_vdp) begin
    if (scw_we2) sc_d2[scw_idx] <= scw_b2;
    scq_d2 <= sc_d2[vram_address[13:2]];
end
always @(posedge clk_vdp) begin
    if (scw_we3) sc_d3[scw_idx] <= scw_b3;
    scq_d3 <= sc_d3[vram_address[13:2]];
end
always @(posedge clk_vdp) begin
    if (fill_now) sc_tag[fill_addr[11:0]] <= fill_addr[15:12];
    scq_tag <= sc_tag[vram_address[13:2]];
end

wire [21:0] sd_base = VRAM_BASE + {4'd0, cur_addrw, 2'b00};
wire [15:0] nxt_w   = vram_address[17:2] + 16'd1;   // palabra siguiente (OBL)
// primer byte habilitado que queda en la mascara de la escritura en curso
wire [1:0]  nxt_byte = cur_mask[0] ? 2'd0 : cur_mask[1] ? 2'd1
                     : cur_mask[2] ? 2'd2 : 2'd3;

always @(posedge clk_vdp or negedge rst_n) begin
    if (!rst_n) begin
        pw_v <= 64'd0; sc_v <= {4096{1'b0}}; pfq_wp <= 0; pfq_rp <= 0;
        wq_wp <= 0; wq_rp <= 0; rq_wp <= 0; rq_rp <= 0;
        bsy <= 0; done_d <= 0; word_pend <= 0;
        cur_kind <= 0; cur_half <= 0; cur_addrw <= 0; cur_tag <= 0;
        cur_word <= 0; cur_mask <= 0; cur_wbyte <= 0;
        late_v <= 0; late_tag <= 0; late_data <= 0;
        bk_req <= 0; bk_we <= 0; bk_addr <= 0; bk_wdata <= 0;
        vram_rdata <= 0; vram_rdata_en <= 0; vram_rtag <= 0;
        bg_miss <= 0;
        spr_p1 <= 0; spr_addr1 <= 0; spr_tag1 <= 0;
        wrk_p1 <= 0; wrk_addr1 <= 0; wrk_data1 <= 0; wrk_mask1 <= 4'hF;
        obl_pend <= 0; obl_w <= 0;
        fill_pend <= 0; fill_addr <= 0; fill_word <= 0;
        scq_v <= 0;
        for (pi = 0; pi < 7; pi = pi + 1) pipe[pi] <= 38'd0;
    end
    else begin
        bk_req <= 1'b0;
        done_d <= bk_done_t;
        spr_p1 <= 1'b0;
        wrk_p1 <= 1'b0;
        scq_v  <= sc_v[vram_address[13:2]];   // valid junto a las BSRAM
        if (fill_now) begin
            fill_pend <= 1'b0;
            sc_v[fill_addr[11:0]] <= 1'b1;
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

        // ---------- OBL diferido: chequeo de ventana + encolado (ciclo 1) ----
        obl_pend <= 1'b0;
        if (obl_pend && !pfq_full &&
            !(pw_v[obl_w[5:0]] && pw_tagA[obl_w[5:0]] == obl_w[15:6])) begin
            pfq[pfq_wp] <= obl_w;
            pfq_wp <= pfq_wp + 2'd1;
        end

        // ---------- etapa 1 del lookup en cache (dato BSRAM ya en scq_*) ----
        // Sirve a SPRITES y al FONDO con miss de ventana (v3). HIT: inyecta
        // en pipe[1] -> emerge en el MISMO ciclo 8 que un hit de ventana
        // (fetch en T, pipe[1] en T+1, pipe[6] en T+6, rdata_en en T+7).
        // Sin colision de etapas: los vram_valid van separados >=8 ciclos.
        if (spr_p1) begin
            if (scq_v && scq_tag == spr_addr1[15:12])
                pipe[1] <= {1'b1, spr_tag1, {scq_d3, scq_d2, scq_d1, scq_d0}};
            else begin
                // MISS de cache: backend + fill al volver. bg/sprite encolan
                // con reserva (drop tolerable, se autocuran); CPU/COMANDO
                // encolan SIEMPRE (con 8 plazas, 1-en-vuelo cada uno y la
                // reserva de bg/sprite, nunca encuentran lleno).
                if (spr_tag1[4:2] == C_BG || spr_tag1[4:2] == C_SPRITE) begin
                    if (rq_room_soft) begin
                        rq[rq_wp] <= {spr_tag1, spr_addr1};
                        rq_wp <= rq_wp + 3'd1;
                    end
                end
                else if (!rq_full) begin
                    rq[rq_wp] <= {spr_tag1, spr_addr1};
                    rq_wp <= rq_wp + 3'd1;
                end
                if (spr_tag1[4:2] == C_BG) begin
                    // bg: cuenta el miss y arranca el stream OBL (bitmap)
                    bg_miss <= bg_miss + 8'd1;
                    if (!pfq_full) begin
                        pfq[pfq_wp] <= spr_addr1 + 16'd1;
                        pfq_wp <= pfq_wp + 2'd1;
                    end
                end
            end
        end

        // ---------- aceptar peticion del VDP ----------
        if (vram_valid) begin
            if (vram_write) begin
                if (!wq_full) begin
                    // OJO: vram_wdata_mask es estilo DQM (1 = byte ENMASCARADO,
                    // no se escribe) — vdp_vram_interface pone 4'b1110 para el
                    // byte 0. En la cola se guarda INVERTIDA (1 = escribir).
                    wq[wq_wp] <= {~vram_wdata_mask, vram_wdata, vram_address};
                    wq_wp <= wq_wp + 2'd1;
                end
                // escritura invalida la palabra en ventana (coherencia)
                if (pw_v[vram_address[7:2]] &&
                    pw_tagA[vram_address[7:2]] == vram_address[17:8])
                    pw_v[vram_address[7:2]] <= 1'b0;
                // cache de sprites: arranca el WRITE-CHECK (etapa 1 compara
                // el tag BSRAM y aplica el update byte a byte si casa)
                wrk_p1    <= 1'b1;
                wrk_addr1 <= vram_address;
                wrk_data1 <= vram_wdata;
                wrk_mask1 <= vram_wdata_mask;
            end
            else if (vram_tag[4:2] == C_BG) begin
                if (pw_v[vram_address[7:2]] &&
                    pw_tagA[vram_address[7:2]] == vram_address[17:8]) begin
                    // HIT: agenda respuesta a 8 ciclos
                    pipe[0] <= {1'b1, vram_tag, pw_data[vram_address[7:2]]};
                    // OBL DIFERIDO al ciclo 1 (timing _118: sumador + chequeo
                    // de ventana 64:1 + escritura pfq en el ciclo 0 era el
                    // peor camino, -1.044; desde registro cierra). El fetch
                    // siguiente llega a >=8 ciclos: un ciclo de retardo del
                    // prefetch es invisible.
                    obl_pend <= 1'b1;
                    obl_w    <= nxt_w;
                end
                else begin
                    // MISS de ventana (v3): prueba la CACHE — en modos de
                    // patrones (SCREEN 0/1/2/3) las tablas NT/PGT/CT viven
                    // residentes ahi y responden a 8 ciclos igualmente. La
                    // etapa 1 (spr_p1) decide; el miss doble va al backend.
                    spr_p1    <= 1'b1;
                    spr_addr1 <= vram_address;
                    spr_tag1  <= vram_tag;
                end
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

        // ---------- backend: completar op en vuelo ----------
        if (bsy && (bk_done_t != done_d)) begin
            bsy <= 1'b0;
            if (cur_kind == 2'd2) begin
                // escritura: byte hecho -> fuera de la mascara; si no queda
                // ninguno, palabra terminada (el lanzador coge el siguiente
                // habilitado via nxt_byte).
                cur_mask[cur_wbyte] <= 1'b0;
                if ((cur_mask & ~(4'd1 << cur_wbyte)) == 4'd0)
                    word_pend <= 1'b0;
            end
            else begin
                if (!cur_half) begin
                    cur_word[15:0] <= bk_rword;
                    cur_half <= 1'b1;     // pedir mitad alta
                end
                else begin
                    // palabra completa
                    if (cur_kind == 2'd0) begin
                        pw_data[cur_addrw[5:0]] <= {bk_rword, cur_word[15:0]};
                        pw_tagA[cur_addrw[5:0]] <= cur_addrw[15:6];
                        pw_v[cur_addrw[5:0]]    <= 1'b1;
                    end
                    else begin
                        late_v    <= 1'b1;
                        late_tag  <= cur_tag;
                        late_data <= {bk_rword, cur_word[15:0]};
                        // y de paso a la ventana si es bg
                        if (cur_tag[4:2] == C_BG) begin
                            pw_data[cur_addrw[5:0]] <= {bk_rword, cur_word[15:0]};
                            pw_tagA[cur_addrw[5:0]] <= cur_addrw[15:6];
                            pw_v[cur_addrw[5:0]]    <= 1'b1;
                        end
                        // ...y a la CACHE (v3c: TODO consumidor de lectura
                        // rellena — bg/sprite/CPU/comando; localidad del
                        // cursor y de los VPEEKs) — via fill_pend
                        fill_pend <= 1'b1;
                        fill_addr <= cur_addrw;
                        fill_word <= {bk_rword, cur_word[15:0]};
                    end
                    word_pend <= 1'b0;
                end
            end
        end

        // ---------- backend: lanzar siguiente op ----------
        if (!bsy) begin
            if (word_pend) begin
                // continuar palabra en curso (2a mitad o siguiente byte)
                bsy <= 1'b1; bk_req <= 1'b1;
                if (cur_kind == 2'd2) begin
                    // siguiente byte HABILITADO de la mascara (el completado
                    // ya se borro de cur_mask) — no el cur_wbyte rancio
                    bk_we     <= 1'b1;
                    cur_wbyte <= nxt_byte;
                    bk_addr   <= sd_base | {20'd0, nxt_byte};
                    bk_wdata  <= cur_word[8*nxt_byte +: 8];
                end
                else begin
                    bk_we   <= 1'b0;
                    bk_addr <= sd_base | 22'd2;      // mitad alta
                end
            end
            else if (!wq_empty) begin
                cur_kind  <= 2'd2;
                cur_addrw <= wq[wq_rp][15:0];
                cur_word  <= wq[wq_rp][47:16];
                cur_mask  <= wq[wq_rp][51:48];
                wq_rp     <= wq_rp + 2'd1;
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
                rq_rp     <= rq_rp + 3'd1;
                cur_half  <= 1'b0; word_pend <= 1'b1;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b0;
                bk_addr <= VRAM_BASE + {4'd0, rq[rq_rp][15:0], 2'b00};
            end
            else if (!pfq_empty) begin
                cur_kind  <= 2'd0;
                cur_addrw <= pfq[pfq_rp];
                pfq_rp    <= pfq_rp + 2'd1;
                cur_half  <= 1'b0; word_pend <= 1'b1;
                bsy <= 1'b1; bk_req <= 1'b1; bk_we <= 1'b0;
                bk_addr <= VRAM_BASE + {4'd0, pfq[pfq_rp], 2'b00};
            end
        end
    end
end

endmodule
