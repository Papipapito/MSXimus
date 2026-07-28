// ============================================================================
// y8950_adpcm.v — seccion ADPCM-B del Y8950 (MSX-Audio) para MSXimus (_80)
//
// Glue con semantica calcada de openMSX Y8950Adpcm.cc (ground truth) sobre el
// decoder probado jt10_adpcmb (jotego/jt12, GPL3 — el mismo deltaT de Yamaha:
// step inicial 127, tablas 57..153, d2 con +0.5). El FM vive aparte (jtopl2).
// Auditado adversarialmente contra openMSX (2026-07-12): 29 hallazgos, los
// 11 relevantes aplicados; ver comentarios [AUDIT] en el codigo.
//
// - RAM de samples: _159 los 256KB COMPLETOS del Y8950 (unidad AMPLIADA),
//   FUERA del chip: el array de 32KB en BSRAM se retira (libera 16 bloques)
//   y las muestras viven en la SDRAM del dock a traves de adpcm_sdram.v
//   (puerto wv2 de memory.v, filas 5120+). Motivo: 256KB en BSRAM son 128
//   bloques y el GW5AT-60 tiene 118 EN TOTAL — no cabe ni con el chip vacio.
//   Con ROM-bank se sigue leyendo 0 e ignorando la escritura (HW real).
//   El camino de direcciones ya era de 256KB desde el _80 (ptr de 19 bits en
//   nibbles, mascara 0x3FFFF): lo unico que topaba era el array.
// - Registros: 07 control, 08 ROM/64K, 09/0A start, 0B/0C stop, 0F dato,
//   10/11 delta-N, 12 volumen. Punteros en NIBBLES (start = regL<<3 |
//   regH<<11, 19 bits); stop lleva SIEMPRE los bits [2:0] a 111 (|7, como el
//   chip real); mascara de BYTES 0x3FFFF (256K) o 0xFFFF (64K).
// - Modos (reg7 & 0xE0): 0x60 CPU->RAM (escritura), 0x20 RAM->CPU (lectura,
//   2 dummy reads), 0xA0 reproduccion desde RAM, 0x80 sintesis alimentada
//   por CPU (reg 0F). REC (b6) inhibe la reproduccion (sin ADC: no graba).
//   SP_OFF (b3) solo silencia. RESET (b0) borra reg7 (PCM_BSY queda).
// - Status visible = (raw & (0x87|mask)) | 0x06; mask del reg 4 (~din&0x78).
//   TODA escritura al reg 4 re-arma BUF_RDY si el modo es de memoria
//   (0x20/0x60) o la unidad esta ociosa — el detector del MSX-Audio BIOS
//   v1.3 depende de ello (bug openMSX [3533002]).
// - IRQ compuesta calculada pero SIN cablear al /INT (igual que el FM _79);
//   software que espere la interrupcion con HALT no funcionara aun.
//
// TIMING: eventos alineados con cen3m6; adv/nib combinacionales en el ciclo
// del tick (el decoder latchea data ahi; los bloques if(cen55) del
// interpolador exigen pulsos de 1 ciclo). El motor va gateado con !dec_clr
// para no leer ram_q rancio justo tras un START. El orden del always es
// reproduccion-ANTES-de-escrituras: en colisiones gana la CPU (mismo orden
// sync->write de openMSX). pcm_out registrado (cruce 54M->27M del mixer).
//
// _159 — POR QUE UNA CACHE DE PALABRA BASTA: el ADPCM-B consume un nibble
// por 'adv', y adv ocurre con probabilidad delta_n/65536 sobre un tick de
// 49.716 kHz. El PEOR CASO ABSOLUTO (delta_n=0xFFFF) son 24.858 B/s =
// 12.429 lecturas de palabra/s = una cada 80 us; el puerto wave de memory.v
// concede un turno cada ~148 ns => >270x de margen. Con una linea de palabra
// + una plaza de prefetch el motor JAMAS espera en regimen. Y si aun asi el
// dato no esta, el motor se GATEA (word_hit): se pierde un tick de 20 us en
// vez de decodificar basura — el deltaT es un decoder con estado y meterle un
// nibble inventado envenena toda la nota (la leccion del rail de la _158).
// ============================================================================

module y8950_adpcm(
    input             clk,        // clk_54m
    input             cen3m6,     // cen 3.58MHz (el mismo del jtopl2)
    input             rst_n,

    // snoop del bus (strobes de 1 ciclo de clk, generados en top.v)
    input             wr_c0,      // escritura a C0h (latch de registro)
    input             wr_c1,      // escritura a C1h (dato al registro sel)
    input             rd_c1,      // lectura de C1h (efectos si sel==0Fh)
    input      [7:0]  din,        // dato del Z80

    // flags de timers del jtopl (su dout[6:5]; ya gateados por SU mascara)
    input             ft1,
    input             ft2,

    output     [7:0]  status,     // byte de status compuesto (lectura C0)
    output reg [7:0]  data_dout,  // valor para lecturas de C1
    output            irq,        // IRQ compuesta (sin cablear en _80)
    output signed [15:0] pcm_out,

    // ---- _159: puerto de la RAM de muestras (256KB, via adpcm_sdram.v) ----
    // Contrato TOGGLE, el mismo del lado HOST de wave_sdram.v: mem_req_t
    // CAMBIA DE VALOR = nueva operacion, y el payload (we/addr/wdata) viaja
    // con el y no se toca hasta ver mem_done_t. La respuesta es la PALABRA
    // alineada que contiene el byte (memory.v ya devuelve 16 bits): es lo
    // que alimenta la cache de aqui abajo.
    output reg         mem_req_t,
    output reg         mem_we,
    output reg [17:0]  mem_addr,   // direccion de BYTE dentro de los 256KB
    output reg [7:0]   mem_wdata,
    input  wire [15:0] mem_rword,
    input  wire        mem_done_t,
    output wire [7:0]  mem_diag    // {wq_lost, wd_hits} — salud del camino
);

// ---------------------------------------------------------------------------
// registros / estado
// ---------------------------------------------------------------------------
reg [7:0]  reg_sel;
reg [7:0]  reg7;                  // START/REC/MEMDATA/REPEAT/SP_OFF/-/-/RESET
reg        rom_bank;              // reg8 b0
reg        is64k;                 // reg8 b1
reg [18:0] start_addr;            // en nibbles ([2:0] siempre 0)
reg [18:0] stop_addr;             // en nibbles ([2:0] SIEMPRE 111 — chip real)
reg [15:0] delta_n;
reg [7:0]  volume;
reg [7:0]  reg15;                 // ultimo dato CPU (reg 0F)
reg [3:0]  status_mask;           // visibilidad de {T1,T2,EOS,BUF} (reg4 b6:3)
reg        eos;
reg        buf_rdy;
reg        pcm_bsy;               // [AUDIT] latch: se escribe con reg7, el
                                  //  stop natural NO lo toca
reg [1:0]  read_delay;

reg [18:0] ptr;                   // puntero en nibbles (unico: modos exclusivos)
reg [16:0] now_step;              // acumulador de fase (STEP_BITS=16)
reg [7:0]  adpcm_byte;            // byte en curso (nibble alto ya consumido)

wire mode_mem   = reg7[5];
wire playing    = reg7[7] & ~reg7[6]; // [AUDIT] (reg7&0xC0)==0x80: REC inhibe
wire sp_off     = reg7[3];
wire rep_eat    = reg7[4];
wire [7:0] mode = reg7 & 8'hE0;

// ---------------------------------------------------------------------------
// puntero efectivo de ESCRITURA CPU: openMSX recarga memPtr=startAddr en la
// PRIMERA escritura tras entrar en modo (cubre "start escrito despues de
// reg7") -> la direccion fisica de esa primera escritura sale de aqui.
// ---------------------------------------------------------------------------
wire [18:0] wr_ptr = (read_delay != 2'd0) ? start_addr : ptr;

// ---------------------------------------------------------------------------
// direccionamiento de byte — _159: SIN la guarda de 32KB. La unica guarda
// que sobrevive es rom_bank (el HW real lee 0 e ignora escrituras con el
// banco de ROM seleccionado; openMSX Y8950Adpcm::readMemory hace lo mismo).
// La mascara is64k se queda TAL CUAL: es la del chip real (openMSX:
// addrMask = 64K ? (1<<16)-1 : (1<<18)-1) y con 256KB reales es correcta.
// ---------------------------------------------------------------------------
wire [17:0] rd_byte_addr = ptr[18:1]    & (is64k ? 18'h0FFFF : 18'h3FFFF);
wire [17:0] wr_byte_addr = wr_ptr[18:1] & (is64k ? 18'h0FFFF : 18'h3FFFF);
wire        rd_oob       = rom_bank;
wire        wr_oob       = rom_bank;

// NOTA _159: el HW real arranca la sample RAM a FF (openMSX clearRam). La
// SDRAM arranca INDETERMINADA (antes la BSRAM Gowin arrancaba a 0). Solo
// afecta a lecturas de zonas nunca escritas, que ya eran indefinidas para el
// software; todo replayer sube sus muestras antes de disparar el key-on.

// ---------------------------------------------------------------------------
// _159 — CACHE DE PALABRA (2 entradas, reemplazo round-robin)
//
// El puntero de reproduccion avanza MONOTONO de nibble en nibble: dos
// entradas (la palabra en curso + la que trae el prefetch) cubren el patron
// entero sin fallar una sola vez en regimen. El reemplazo round-robin es
// correcto justo POR esa monotonia: cuando el prefetch de T+1 aterriza en la
// entrada libre, la siguiente victima es la de T, que ya esta consumida.
//
// El tag es la DIRECCION FISICA de palabra ya enmascarada, asi que la cache
// es coherente por construccion frente a saltos (START/REPEAT), a is64k y a
// rom_bank: si la direccion cambia, el tag no casa y se hace un miss. Lo
// UNICO que hay que invalidar a mano son las escrituras de la CPU.
// ---------------------------------------------------------------------------
wire [16:0] rd_word   = rd_byte_addr[17:1];
wire [16:0] wr_word   = wr_byte_addr[17:1];
wire [16:0] word_mask = is64k ? 17'h07FFF : 17'h1FFFF;
wire [16:0] pf_word   = (rd_word + 17'd1) & word_mask;

reg  [15:0] cw0, cw1;
reg  [16:0] ctag0, ctag1;
reg         cv0, cv1;

wire hit0     = cv0 && (ctag0 == rd_word);
wire hit1     = cv1 && (ctag1 == rd_word);
wire word_hit = hit0 | hit1;
wire [15:0] hit_word = hit0 ? cw0 : cw1;
wire [7:0]  mem_byte = rd_oob ? 8'h00
                              : (rd_byte_addr[0] ? hit_word[15:8] : hit_word[7:0]);

wire pf_present = (cv0 && (ctag0 == pf_word)) || (cv1 && (ctag1 == pf_word));

// Modos que LEEN memoria: 0xA0 (reproduccion) y 0x20 (RAM->CPU por reg 0F).
// En 0x60 (subida CPU->RAM) el puerto es todo para las escrituras: emitir
// misses ahi seria trafico inutil que compite con la propia subida.
wire cache_rd_mode = (mode == 8'hA0) || (mode == 8'h20);
wire cache_active  = cache_rd_mode && !rom_bank;

wire ram_we = wr_c1 && (reg_sel == 8'h0F) && (mode == 8'h60) &&
              (wr_ptr <= stop_addr) && !wr_oob;

// ---------------------------------------------------------------------------
// _159 — FSM del puerto de memoria (UNA operacion en vuelo)
// Prioridad: escritura de la CPU > miss de lectura > prefetch. La escritura
// va primero porque es la unica con control de flujo visible (BUF_RDY) y la
// unica que puede perder informacion; el prefetch es especulativo y puede
// esperar todo lo que haga falta.
// ---------------------------------------------------------------------------
localparam OP_RD = 2'd0, OP_PF = 2'd1, OP_WR = 2'd2;

reg        busy;                  // op en vuelo
reg  [1:0] op_kind;
reg [16:0] op_tag;                // tag destino del fill
reg        fill_sel;              // round-robin de reemplazo
reg        done_seen;             // eco del toggle mem_done_t

// Cola de escritura de 4 plazas con FRENO ANTICIPADO a 2. La reserva de 2
// plazas NO es paranoia: entre que el software lee BUF_RDY y llega su OUT
// pasan ciclos, y en ese hueco puede haber colado otra escritura — sin
// reserva, un byte se perderia EN SILENCIO (medido en el banco). Con el
// freno a 2 y capacidad 4 caben las dos escrituras "en vuelo" del peor caso.
// Ritmos: VGMPlay sube un byte cada ~30 us (OUT + poll), un bucle 'outi' a
// pelo cada ~5 us, y el puerto sirve en ~1-2 us. wq_lost delata el imposible.
reg [25:0] wq [0:3];              // {addr[17:0], data[7:0]}
reg  [1:0] wq_wp, wq_rp;
reg  [2:0] wq_cnt;
wire       wq_full  = (wq_cnt >= 3'd2);   // lo que ve BUF_RDY (freno)
wire       wq_ovf   = (wq_cnt == 3'd4);   // desbordamiento real
wire       wq_empty = (wq_cnt == 3'd0);
wire       wq_push  = ram_we && !wq_ovf;
wire       wq_pop   = !busy && !wq_empty;
reg  [3:0] wq_lost;               // bytes perdidos (deberia quedarse en 0)

// _95 (leccion del OPL4): watchdog del handshake. Si un toggle se pierde,
// busy quedaria clavado y el ADPCM mudo PARA SIEMPRE. A ~150 us (2^13 ciclos
// de 54 MHz) se libera a la fuerza; wd_hits lo delata por telemetria.
reg [12:0] wd;
reg  [3:0] wd_hits;
assign mem_diag = {wq_lost, wd_hits};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_req_t <= 1'b0; mem_we <= 1'b0; mem_addr <= 18'd0; mem_wdata <= 8'd0;
        busy <= 1'b0; op_kind <= OP_RD; op_tag <= 17'd0; fill_sel <= 1'b0;
        done_seen <= 1'b0;
        cw0 <= 16'd0; cw1 <= 16'd0; ctag0 <= 17'd0; ctag1 <= 17'd0;
        cv0 <= 1'b0;  cv1 <= 1'b0;
        wq[0] <= 26'd0; wq[1] <= 26'd0; wq[2] <= 26'd0; wq[3] <= 26'd0;
        wq_wp <= 2'd0; wq_rp <= 2'd0; wq_cnt <= 3'd0; wq_lost <= 4'd0;
        wd <= 13'd0; wd_hits <= 4'd0;
    end
    else begin
        // ---- 1) aterrizaje de la operacion en vuelo ----
        if (mem_done_t != done_seen) begin
            done_seen <= mem_done_t;
            busy <= 1'b0;
            wd   <= 13'd0;
            if (op_kind != OP_WR) begin       // fill de la cache
                if (fill_sel) begin cw1 <= mem_rword; ctag1 <= op_tag; cv1 <= 1'b1; end
                else          begin cw0 <= mem_rword; ctag0 <= op_tag; cv0 <= 1'b1; end
                fill_sel <= ~fill_sel;
            end
        end
        else if (busy) begin                  // watchdog
            wd <= wd + 13'd1;
            if (wd == 13'h1FFF) begin
                busy    <= 1'b0;
                wd_hits <= wd_hits + 4'd1;
            end
        end

        // ---- 2) encolado de la escritura de la CPU + coherencia ----
        // (DESPUES del fill: si la CPU escribe la palabra que acaba de
        //  aterrizar, gana la invalidacion — el dato en vuelo es rancio)
        if (wq_push) begin
            wq[wq_wp] <= {wr_byte_addr, din};
            wq_wp     <= wq_wp + 2'd1;
            if (cv0 && (ctag0 == wr_word)) cv0 <= 1'b0;
            if (cv1 && (ctag1 == wr_word)) cv1 <= 1'b0;
        end
        else if (ram_we) wq_lost <= wq_lost + 4'd1;   // el imposible, contado
        case ({wq_push, wq_pop})
            2'b10:   wq_cnt <= wq_cnt + 3'd1;
            2'b01:   wq_cnt <= wq_cnt - 3'd1;
            default: ;
        endcase

        // ---- 3) emision (una op en vuelo; el toggle lleva el payload) ----
        if (!busy) begin
            if (!wq_empty) begin                          // escritura
                mem_we    <= 1'b1;
                mem_addr  <= wq[wq_rp][25:8];
                mem_wdata <= wq[wq_rp][7:0];
                op_kind   <= OP_WR;
                wq_rp     <= wq_rp + 2'd1;
                busy      <= 1'b1;
                wd        <= 13'd0;
                mem_req_t <= ~mem_req_t;
            end
            else if (cache_active && !word_hit) begin     // miss de lectura
                mem_we    <= 1'b0;
                mem_addr  <= {rd_word, 1'b0};
                op_kind   <= OP_RD;
                op_tag    <= rd_word;
                busy      <= 1'b1;
                wd        <= 13'd0;
                mem_req_t <= ~mem_req_t;
            end
            else if (cache_active && !pf_present) begin   // prefetch de +1
                mem_we    <= 1'b0;
                mem_addr  <= {pf_word, 1'b0};
                op_kind   <= OP_PF;
                op_tag    <= pf_word;
                busy      <= 1'b1;
                wd        <= 13'd0;
                mem_req_t <= ~mem_req_t;
            end
        end
    end
end

// ---------------------------------------------------------------------------
// cen de muestreo: fs = 3.58MHz/72 = 49.7kHz, ALINEADO con cen3m6
// ---------------------------------------------------------------------------
reg [6:0] fs_div;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) fs_div <= 7'd0;
    else if (cen3m6) fs_div <= (fs_div == 7'd71) ? 7'd0 : fs_div + 7'd1;
end
wire cen_fs = cen3m6 && (fs_div == 7'd71);

// ---------------------------------------------------------------------------
// motor: adv/nib COMBINACIONALES, alineados con cen_fs (el decoder latchea
// data en el ciclo cen del adv; los if(cen55) del interpolador exigen pulsos
// de 1 ciclo). !dec_clr evita leer ram_q rancio justo tras un START [AUDIT].
// ---------------------------------------------------------------------------
wire [16:0] step_sum = {1'b0, now_step[15:0]} + {1'b0, delta_n};
reg  dec_clr;
// _159: el motor va ADEMAS gateado por la cache. Sin el dato NO se avanza:
// perder un tick de 20 us es inaudible, meterle al deltaT un nibble
// inventado envenena el estado (step + acumulador) durante toda la nota.
// En los modos que no leen memoria (0x80 sintesis por CPU) y con rom_bank
// (que devuelve 0 por contrato) el gate es transparente.
wire mem_rdy = !mode_mem || rd_oob || word_hit;
wire engine  = cen_fs && playing && !dec_clr && mem_rdy;
wire adv     = engine && step_sum[16];
wire [3:0] nib = !ptr[0] ? (mode_mem ? mem_byte[7:4] : reg15[7:4])
                         : adpcm_byte[3:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_sel <= 8'd0; reg7 <= 8'd0; rom_bank <= 1'b0; is64k <= 1'b0;
        start_addr <= 19'd0;
        stop_addr  <= 19'd7;      // [AUDIT] bits [2:0] SIEMPRE a 1 (chip real)
        delta_n <= 16'd0;
        volume  <= 8'hFF;         // [AUDIT] reset del chip = volumen a tope
        reg15 <= 8'd0; status_mask <= 4'd0;
        eos <= 1'b0;
        buf_rdy <= 1'b1;          // [AUDIT] BUF_RDY=1 tras reset (deteccion BIOS)
        pcm_bsy <= 1'b0;
        read_delay <= 2'd0;
        ptr <= 19'd0; now_step <= 17'd0; adpcm_byte <= 8'd0;
        dec_clr <= 1'b1;
        data_dout <= 8'hFF;
    end
    else begin
        dec_clr <= 1'b0;

        // ================= reproduccion (PRIMERO: en colisiones gana la
        // CPU de abajo, mismo orden sync->write de openMSX) =================
        if (engine) begin
            if (step_sum[16]) begin
                now_step <= {1'b0, step_sum[15:0]};
                if (!ptr[0]) begin                   // nibble par: byte nuevo
                    adpcm_byte <= mode_mem ? mem_byte : reg15;
                    if (!mode_mem) buf_rdy <= 1'b1;  // consumido: pide otro
                end
                if (mode_mem && (ptr + 19'd1 > stop_addr)) begin
                    eos <= 1'b1;                     // EOS en cada fin (openMSX)
                    if (rep_eat) begin               // repeat: reinicio limpio
                        ptr      <= start_addr;
                        now_step <= 17'h10000 - {1'b0, delta_n};
                        dec_clr  <= 1'b1;
                    end
                    else reg7 <= 8'd0;               // stop total (PCM_BSY queda)
                end
                else ptr <= ptr + 19'd1;
            end
            else now_step <= step_sum;
        end

        // ================= bus CPU =================
        // ---- escritura C0: latch de registro ----
        if (wr_c0) reg_sel <= din;

        // ---- escritura C1: dato al registro seleccionado ----
        if (wr_c1) begin
            case (reg_sel)
            8'h04: begin
                if (din[7]) begin                    // IRQ RESET: borra flags
                    eos <= 1'b0; buf_rdy <= 1'b0;
                end
                else begin
                    status_mask <= ~din[6:3];        // 0x78
                    // [AUDIT] enmascarar BORRA el flag crudo (openMSX
                    // changeStatusMask: status &= 0x87|mask)
                    if (din[4]) eos     <= 1'b0;
                    if (din[3]) buf_rdy <= 1'b0;
                end
                // [AUDIT] resetStatus() de openMSX: TODA escritura al reg 4
                // re-arma BUF_RDY si hay modo de memoria o unidad ociosa
                // (ultima asignacion: gana sobre los clears de arriba)
                if (((reg7 & 8'hA0) == 8'h20) || ((reg7 & 8'hE0) == 8'h00))
                    buf_rdy <= 1'b1;
            end
            8'h07: begin
                pcm_bsy <= din[7];                   // [AUDIT] latch, pre-RESET
                if (din[0]) begin
                    reg7 <= 8'd0;                    // RESET
                    dec_clr <= 1'b1;
                end
                else begin
                    reg7 <= din;
                    if (din[7]) begin                // START: restart
                        ptr        <= start_addr;
                        now_step   <= 17'h10000 - {1'b0, delta_n};
                        adpcm_byte <= 8'd0;
                        dec_clr    <= 1'b1;
                    end
                    if (din[5]) begin                // MEMORY DATA
                        if (!din[7]) ptr <= start_addr;
                        read_delay <= 2'd2;
                        if ((din & 8'hA0) == 8'h20)  // lectura o escritura RAM
                            buf_rdy <= 1'b1;
                    end
                    else if (!din[7]) ptr <= 19'd0;  // acceso via CPU
                end
            end
            8'h08: begin rom_bank <= din[0]; is64k <= din[1]; end
            8'h09: start_addr[10:3]  <= din;
            8'h0A: start_addr[18:11] <= din;
            8'h0B: stop_addr[10:3]   <= din;         // [2:0] quedan a 111
            8'h0C: stop_addr[18:11]  <= din;
            8'h0F: begin
                reg15 <= din;
                if (mode == 8'h60) begin             // CPU -> RAM
                    read_delay <= 2'd0;              // primera escritura ancla
                    if (wr_ptr <= stop_addr) begin   // (ram_we escribe ahora)
                        buf_rdy <= 1'b1;             // "reset+set" en tiempo 0
                        if (wr_ptr + 19'd2 > stop_addr) begin
                            eos <= 1'b1;             // ultimo byte: EOS + wrap
                            ptr <= start_addr;
                        end
                        else ptr <= wr_ptr + 19'd2;
                    end
                end
                else if (mode == 8'h80)              // sintesis via CPU
                    buf_rdy <= 1'b0;                 // lleno: el tick la subira
            end
            8'h10: delta_n[7:0]  <= din;
            8'h11: delta_n[15:8] <= din;
            8'h12: volume <= din;
            default: ;
            endcase
        end

        // ---- lectura C1: efectos SOLO con el reg 0F seleccionado ----
        if (rd_c1) begin
            if (reg_sel == 8'h0F) begin
                // [AUDIT] peekData: dummies->reg15, pasado el fin->0x00,
                // modos no-lectura->0x00
                data_dout <= (mode != 8'h20)        ? 8'h00 :
                             (read_delay != 2'd0)   ? reg15 :
                             (ptr > stop_addr)      ? 8'h00 : mem_byte;
                if (mode == 8'h20) begin
                    if (read_delay != 2'd0) begin
                        read_delay <= read_delay - 2'd1;   // dummy read
                        ptr <= start_addr;
                        buf_rdy <= 1'b1;
                    end
                    else if (ptr > stop_addr) eos <= 1'b1;
                    else begin
                        ptr <= ptr + 19'd2;
                        buf_rdy <= 1'b1;                   // "reset+set" t=0
                    end
                end
            end
            else data_dout <= 8'hFF;
        end
    end
end

// ---------------------------------------------------------------------------
// cadena jt10: decoder deltaT + interpolacion lineal
// ---------------------------------------------------------------------------
wire signed [15:0] pcm_dec, pcm_inter;

jt10_adpcmb u_decoder(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .cen    ( cen3m6    ),
    .data   ( nib       ),
    .chon   ( playing   ),
    .adv    ( adv       ),
    .clr    ( dec_clr   ),
    .pcm    ( pcm_dec   )
);

jt10_adpcmb_interpol u_interpol(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .cen    ( cen3m6    ),
    .cen55  ( cen_fs    ),
    .adv    ( adv       ),
    .pcmdec ( pcm_dec   ),
    .pcmout ( pcm_inter )
);

// volumen lineal (reg 12): a tope (FF) ~ escala completa. Salida REGISTRADA
// ([AUDIT]: el mixer la muestrea en clk_27m; 1 ciclo de latencia es nada a
// 49.7kHz y corta el camino multiplicador->mux->arbol de sumas)
wire signed [24:0] pcm_scaled = pcm_inter * $signed({1'b0, volume});
reg  signed [15:0] pcm_r;
always @(posedge clk) pcm_r <= (playing && !sp_off) ? pcm_scaled[23:8] : 16'sd0;
assign pcm_out = pcm_r;

// ---------------------------------------------------------------------------
// status compuesto: (raw & (0x87|mask)) | 0x06 — flags enmascarados leen 0
//
// _159 — BUF_RDY EFECTIVO. El flag significa "puedo aceptar / ya tengo listo
// el byte". Con la RAM fuera del chip eso deja de ser instantaneo, asi que se
// le AÑADE la condicion real: en 0x60 (subida) que quede sitio en la cola de
// escritura, y en 0x20 (RAM->CPU) que el byte este ya en la cache. Es MAS
// fiel al chip real que darlo siempre listo (openMSX lo hace porque su RAM
// es un array de C++), y le da al bucle "in a,(C0)/and 8/jr z" de VGMPlay el
// control de flujo que ya esta esperando. El resto de modos, sin cambios.
// ---------------------------------------------------------------------------
wire rd_byte_rdy  = rd_oob | word_hit;
wire buf_rdy_eff  = (mode == 8'h60) ? (buf_rdy & ~wq_full)    :
                    (mode == 8'h20) ? (buf_rdy &  rd_byte_rdy) : buf_rdy;
wire [3:0] flags_masked = {ft1, ft2, eos, buf_rdy_eff} & status_mask;
assign irq    = |flags_masked;
assign status = {irq, flags_masked, 2'b11, pcm_bsy};

endmodule
