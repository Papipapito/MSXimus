// ============================================================================
//  memory.v — Controlador SDR del MSXnano, PORTADO a bus de 16 bits para el
//  módulo Tang SDRAM (Winbond W9825G6KH, 16M×16, 32MB) de la Console 60K.
// ----------------------------------------------------------------------------
//  Cirugía 32→16 bits aplicada según docs/SDR_MEMORY_PORT.md. La FSM, el
//  arbitraje CPU/VDP por video_dhclk/dlclk, el fix MG2 (refresh nunca roba una
//  ESCRITURA VDP) y el contrato ram_*/vram_* NO cambian.
//
//  Cambios respecto al memory.v del TN20K (SDRAM embebida de 32 bits):
//   1. Bus de datos 32→16, DQM 4→2, byte-en-palabra = sdram_addr[0].
//   2. Dirección 11→13 bits (W9825: 8192 filas × 512 cols × 4 bancos).
//   3. MAPEO GEOMETRÍA-PRESERVANTE: el bit sdram_addr[1] (antes seleccionaba la
//      mitad alta/baja del word de 32b vía DQM HU/HL) pasa a ser el LSB de
//      COLUMNA. Así, cada word de 32b original = 2 columnas de 16b adyacentes,
//      y la geometría de colisión CPU↔VRAM del banco D queda IDÉNTICA al
//      diseño original (VRAM en cols pares de la región 3'b111; los bytes que
//      antes iban a las lanes HU/HL viven ahora en las cols impares).
//        CPU: bank=addr[22:21] · row={2'b00,addr[12:2]} · col={addr[20:13],addr[1]} · byte=addr[0]
//        VDP: bank=2'b11      · row={2'b00,vram[10:0]}  · col={3'b111,vram[15:11],1'b0} · byte=vram[16]
//   4. TRISTATE EXPLÍCITO (fix de portabilidad): el original hacía
//      `assign IO_sdram_dq = SdrDat` con SdrDat<=z en lecturas y luego LEÍA
//      SdrDat (el reg) para capturar el dato — un idioma que solo funciona
//      porque Gowin lo mapea al pad de la SDRAM EMBEBIDA. Con chip externo por
//      GPIO (GW5A) y en simulación eso lee 'z'. Ahora: dq_oe + dq_in explícitos.
//   5. El latch de lectura dispara en las fases 5 Y 6 (doble ventana): cubre
//      CL2 y CL2+registro-de-pad. En fase 6 el chip ya no conduce (BL=1, DQM):
//      el bus retiene el valor por capacidad (igual que hacía el TN20K). El
//      testbench lo modela; ver docs/SDR_MEMORY_PORT.md.
//
//  ✔ VERIFICADO EN SIMULACIÓN (Icarus): tools/sdr16_tb/ (modelo W9825 + auto-check).
//  ⚠ CKE: el módulo Tang SDRAM ata CKE a nivel alto en placa (el .cst de
//    C64Nano no tiene pin CKE) → O_sdram_cke queda sin constraint en el 60K.
// ============================================================================

module memory_ctrl #(
    // Console 60K: el chip SDR es EXTERNO (modulo por header). Con el reloj en
    // fase (como la SDRAM embebida del GW2AR) el viaje pad+traza+tAC+pad puede
    // dejar el dato de lectura fuera de la ventana del primer latch. Invertir
    // el reloj reenviado (180 grados) adelanta al chip media T y devuelve el
    // dato comodo en fase 5 (truco clasico de SDR externo; nand2mario igual).
    parameter SDCLK_INVERT = 1'b0
)(
    input wire clk_27m,          // OJO: top.v lo alimenta con clk_54m
	input wire clk_108m,
	input wire bus_reset_n,
	input wire video_dhclk,
	input wire video_dlclk,

	input wire [7:0] ram_din,
    input wire ram_req,
    input wire ram_write,
	input wire [22:0] ram_addr,
	input wire [7:0] vram_din,
	input wire vram_write,
	input wire [16:0] vram_addr,
    input wire bus_rfsh_n,

	output reg [7:0] ram_dout,
	output reg [15:0] vram_dout,
    output reg ram_busy,

    // ---- _104: puerto WAVE (OPL4) — roba SOLO los turnos de CPU ociosos ----
    // La YRW801+RAM de muestras (4MB) vive en las filas 4096+ del W9825,
    // FISICAMENTE inalcanzables por los mapeos CPU (filas 0-2047) y VDP
    // (banco D, filas 0-2047): aislamiento por construccion. El injerto
    // decide en ff_sdr_seq==001 y SOLO cuando el turno de CPU esta vacio
    // (enable_sdram==0): CPU, VDP, refresh y el invariante MG2 INTACTOS.
    // Handshake mismo-dominio (clk_108m): wv_req nivel + wv_done pulso.
    input  wire        wv_req,        // nivel: peticion pendiente
    input  wire        wv_we,
    input  wire [21:0] wv_addr,       // direccion de BYTE (4MB de wave)
    input  wire [7:0]  wv_wdata,
    output reg  [15:0] wv_dout,       // PALABRA leida (el shim elige byte)
    output reg         wv_done,       // pulso 1 ciclo = operacion completada

    // ---- V9968: puerto WV2 (VRAM del V9968 via v9968_sdram_bridge) ----
    // Mismo contrato y aislamiento que el puerto wave (filas 4096+); tambien
    // roba SOLO turnos de CPU vacios, con PRIORIDAD para la wave del OPL4
    // (audio, poco trafico) — wv2 toma los huecos restantes.
    input  wire        wv2_req,       // nivel: peticion pendiente
    input  wire        wv2_we,
    input  wire [21:0] wv2_addr,      // direccion de BYTE (ventana de 4MB wave)
    input  wire [7:0]  wv2_wdata,
    output reg  [15:0] wv2_dout,      // PALABRA leida (el shim elige byte)
    output reg         wv2_done,      // pulso 1 ciclo = operacion completada

    // ---- V9968 _120: puerto WV3 — SEGUNDO canal del shim (glitches SC7/8
    // de HW _119: esos modos piden 1 palabra de 32b cada ~730ns y UN canal
    // (2 ops seriales con su CDC) tarda ~800ns; con dos canales el shim pide
    // las DOS mitades EN PARALELO). Mismo contrato/aislamiento; prioridad
    // wave > wv2 > wv3 en los turnos de CPU vacios (sobran: 6.75M/s).
    input  wire        wv3_req,
    input  wire        wv3_we,
    input  wire [21:0] wv3_addr,
    input  wire [7:0]  wv3_wdata,
    output reg  [15:0] wv3_dout,
    output reg         wv3_done,

    // SDRAM externa (módulo Tang SDRAM, W9825G6KH 16M×16) por GPIO
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n, // chip select
    output wire O_sdram_cas_n, // columns address select
    output wire O_sdram_ras_n, // row address select
    output wire O_sdram_wen_n, // write enable
    inout wire [15:0] IO_sdram_dq, // 16 bit bidirectional data bus
    output wire [12:0] O_sdram_addr, // 13 bit multiplexed address bus
    output wire [1:0] O_sdram_ba, // four banks
    output wire [1:0] O_sdram_dqm // 16/2
);

	//`default_nettype none

    assign O_sdram_clk = SDCLK_INVERT ? ~clk_108m : clk_108m;
    assign O_sdram_cke = 1;
    assign O_sdram_cs_n = SdrCmd[3];
    assign O_sdram_ras_n = SdrCmd[2];
    assign O_sdram_cas_n = SdrCmd[1];
    assign O_sdram_wen_n = SdrCmd[0];

    assign O_sdram_dqm[1] = SdrUdq;
    assign O_sdram_dqm[0] = SdrLdq;
    assign O_sdram_ba[1] = SdrBa[1];
    assign O_sdram_ba[0] = SdrBa[0];

    assign O_sdram_addr = SdrAdr;

    // Tristate explícito del bus de datos (ver cabecera, cambio 4)
    assign IO_sdram_dq = dq_oe ? SdrDat : 16'hzzzz;
    wire [15:0] dq_in = IO_sdram_dq;


    reg [22:0] sdram_addr;
    wire sdram_read;
    reg sdram_write;
    wire sdram_dout;
    reg [2:0] sdram_seq;
    reg enable_sdram;

    always @ (posedge clk_27m) begin
        if ( bus_reset_n == 0) begin
            sdram_seq <= 3'd0;
            enable_sdram <= 0;
            sdram_addr <= 0;
            sdram_write <= 0;
            ram_busy <= 0;
        end
        else begin
            enable_sdram <= 0;
            case ( sdram_seq )
                3'd0 : begin
                    sdram_write <= 0;
                    if  ( ram_req == 1 && ( video_dlclk == 1 && video_dhclk == 1 ) ) begin
                    // iter.3-A RETIRADA (post-mortem _72/_73, 2026-07-12): se
                    // probo aceptar en TODO el slot dl (sin dh) para subir el
                    // turbo (TB T9: peor caso 250->213ns, 8/8 tests verdes)...
                    // y en HW NI ARRANCA (ni a 3.58). Causa probable: aceptando
                    // en el ultimo flanco 54M de la ventana, sdram_addr/write
                    // (seq1) llegan DESPUES de que el motor 108M muestree el
                    // slot -> escrituras tratadas como lecturas -> corrupcion.
                    // El TB no lo caza: su modelo de fases dl/dh no reproduce
                    // la fase real del VDP (vdp_ssg/DOTSTATE). La ventana dl&dh
                    // (primera mitad) garantiza 2+ ciclos de 54M de margen y es
                    // la UNICA validada. NO reabrir sin simular las fases
                    // reales del vdp_ssg contra el motor.
                        sdram_seq <= 3'd1;
                        ram_busy <= 1;
                    end
                end
                3'd1 : begin
                    enable_sdram <= 1;
                    sdram_addr <= ram_addr[22:0] ;
                    sdram_write <= ram_write;
                    sdram_seq <= 3'd2;
                end
                3'd2 : begin
                    enable_sdram <= 1;
                    if ( video_dlclk == 0 && video_dhclk == 0 ) begin
                        sdram_write <= 0;
                        sdram_seq <= 3'd3;
                    end
                end
                3'd3 : begin
                    enable_sdram <= 1;
                    sdram_write <= 0;
                    ram_dout <= RamDbi;
                    sdram_seq <= 3'd4;
                    ram_busy <= 0;
                end
                3'd4 : begin
                    if ( ram_req == 0 ) begin
                        sdram_seq <= 3'd0;
                    end
                end
                default: begin
                    sdram_seq <= 3'd0;
                end
            endcase
        end
    end

    // NOTA sim: initializers añadidos en el port (= power-up real de Gowin, 0).
    // Sin ellos, ff_mem_seq/ff_sdr_seq arrancan en X en simulación y el init
    // se bloquea (misma higiene que la auditoría pide para kanji.v).
    reg [2:0] ff_sdr_seq = 3'b000;
    // Guardia ANTI-INANICION del refresh (bug SCREEN 3 / multicolor): cuenta
    // oportunidades de refresh saltadas por vram_write; al llegar a 32 (~4us
    // de escritura VDP continua, imposible con escrituras reales) FUERZA el
    // refresh aunque vram_write siga activo. Ver comentario del slot abajo.
    reg [5:0] rfsh_skip_cnt = 6'd0;
    reg [4:0]  RstSeq = 0;
    // SDRAM control signals
    reg  [2:0] SdrSta = 3'b000;
    reg  [3:0] SdrCmd = 4'b1111;             //-- deselect en el arranque
    reg  [1:0] SdrBa = 2'b00;
    reg  SdrUdq = 1;
    reg  SdrLdq = 1;
    reg  [12:0] SdrAdr = 0;
    reg  [15:0] SdrDat = 0;
    reg  dq_oe = 0;
    reg  [1:0] SdrSize = 2'b11;

    localparam [3:0] SdrCmd_de = 4'b1111;            //-- deselect
    localparam [3:0] SdrCmd_pr = 4'b0010;            //-- precharge all
    localparam [3:0] SdrCmd_re = 4'b0001;            //-- refresh
    localparam [3:0] SdrCmd_ms = 4'b0000;            //-- mode register set

    localparam [3:0] SdrCmd_xx = 4'b0111;            //-- no operation
    localparam [3:0] SdrCmd_ac = 4'b0011;            //-- activate
    localparam [3:0] SdrCmd_rd = 4'b0101;            //-- read
    localparam [3:0] SdrCmd_wr = 4'b0100;            //-- write

    reg [7:0]  RamDbi = 0;
    reg [1:0] ff_mem_seq = 2'b00;
    reg [15:0] FreeCounter = 0;

//    ----------------------------------------------------------------
//    -- SDRAM access
//    ----------------------------------------------------------------
//    --   SdrSta = "000" => idle
//    --   SdrSta = "001" => precharge all
//    --   SdrSta = "010" => refresh
//    --   SdrSta = "011" => mode register set
//    --   SdrSta = "100" => read cpu
//    --   SdrSta = "101" => write cpu
//    --   SdrSta = "110" => read vdp
//    --   SdrSta = "111" => write vdp
//    ----------------------------------------------------------------

    always @ ( posedge clk_108m ) begin
        //-- 00 > 01 > 11 > 10
        ff_mem_seq <= { ff_mem_seq[0], (~ ff_mem_seq[1]) } ;
    end

    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            FreeCounter <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter <= FreeCounter + 1;
        end
    end

    reg [19:0] FreeCounter2;
    always @ ( posedge clk_108m ) begin
        if ( RstSeq < 5'b01000 ) begin
            FreeCounter2 <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter2 <= FreeCounter2 + 1;
        end
    end

    //-- RstSeq count
    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            RstSeq <= 0;
        end
        if( ff_mem_seq == 2'b00 && FreeCounter[15:0] == 16'hFFFF && RstSeq != 5'b11111 ) begin
            RstSeq <= RstSeq + 1;                                                   //-- 3ms (= 65536 / 21.48MHz)
        end
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b111 ) begin
            if( RstSeq[4:2] == 3'b000 ) begin
                SdrSta <= 3'b000;                                                //-- idle
            end
            else if( RstSeq[4:2] == 3'b001 ) begin
            //--  case RstSeq(1 downto 0) is
            //--      when "00"       => SdrSta <= "000";                         -- idle
            //--      when "01"       => SdrSta <= "001";                         -- precharge all
            //--      when "10"       => SdrSta <= "010";                         -- refresh (more than 8 cycles)
            //--      when others     => SdrSta <= "011";                         -- mode register set
            //--  end case;
                SdrSta <= { 1'b0, RstSeq[1:0] };
            end
            else if( bus_rfsh_n == 0 && video_dlclk == 1 && (vram_write == 0 || rfsh_skip_cnt[5] == 1) ) begin
                //-- refresh roba el slot VDP SOLO si el VDP va a LEER (display/
                //-- sprite, recuperable al siguiente frame). Si va a ESCRIBIR
                //-- (comando del blitter HMMV/HMMM o acceso CPU por puerto), NO:
                //-- el VDP da ACK incondicional y la escritura se perderia ->
                //-- agujeros permanentes en VRAM (glitch de MG2 al cambiar de
                //-- pantalla).
                //-- ⚠ GUARDIA (bug SCREEN 3): en multicolor el nivel vram_write
                //-- puede quedarse ACTIVO de forma sostenida -> el salto por
                //-- escritura mataba de hambre al refresh y la SDRAM se
                //-- descargaba en segundos (cuelgue total, MSXnano 20K y 60K;
                //-- goauld sin la condicion = inmune). rfsh_skip_cnt fuerza el
                //-- refresh tras 32 saltos (~4us): cadencia minima garantizada
                //-- (2x mejor que los 7.8us/fila del W9825) y las escrituras
                //-- reales (pulsos) siguen protegidas como pedia MG2.
                SdrSta <= 3'b010;                                                //-- refresh
                rfsh_skip_cnt <= 6'd0;
            end
            else begin
                //--  Normal memory access mode
                SdrSta[2] <= 1;                                               //-- read/write cpu/vdp
                if ( bus_rfsh_n == 0 && video_dlclk == 1 && rfsh_skip_cnt[5] == 0 )
                    rfsh_skip_cnt <= rfsh_skip_cnt + 6'd1;   //-- oportunidad saltada
            end
        end
        else if( ff_sdr_seq == 3'b001 && SdrSta[2] == 1 && RstSeq[4:3] == 2'b11 )begin
            SdrSta[1] <= video_dlclk;                                            //-- 0:cpu, 1:vdp
            if( video_dlclk == 0 ) begin
                // _104: si la fase 0 le dio el turno a la wave (SdrWav), el
                // flag de escritura es el suyo; si no, el del CPU.
                SdrSta[0] <= SdrWav ? wv_we : SdrWv2 ? wv2_we : SdrWv3 ? wv3_we : sdram_write;    //-- for cpu/wave/wv2/wv3
            end
            else begin
                SdrSta[0] <= vram_write;       //-- for vdp
            end
        end
    end

    // _104: CONCESION del turno a la wave — decidida en la fase 0 (el
    // ACTIVATE lleva la fila, hay que saberlo ahi). Solo turnos de CPU
    // VACIOS (enable_sdram==0, estable durante toda la mitad dlclk==0
    // porque FSM-A solo acepta con dlclk==1): CPU/VDP/refresh y el
    // invariante MG2 quedan INTACTOS por construccion.
    reg SdrWav = 0;
    reg wv_inflight = 0;
    wire wav_take = (enable_sdram == 0 && wv_req == 1 && wv_inflight == 0);
    // V9968: wv2 solo toma el hueco si la wave NO lo quiere este turno
    reg SdrWv2 = 0;
    reg wv2_inflight = 0;
    wire wv2_take = (enable_sdram == 0 && wv2_req == 1 && wv2_inflight == 0
                     && wav_take == 0);
    // V9968 _120: wv3 toma el hueco solo si ni wave ni wv2 lo quieren
    reg SdrWv3 = 0;
    reg wv3_inflight = 0;
    wire wv3_take = (enable_sdram == 0 && wv3_req == 1 && wv3_inflight == 0
                     && wav_take == 0 && wv2_take == 0);
    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b000 ) begin
            SdrWav <= (SdrSta[2] == 1) && (video_dlclk == 0) && wav_take
                      && (RstSeq[4:3] == 2'b11);
            if( (SdrSta[2] == 1) && (video_dlclk == 0) && wav_take
                && (RstSeq[4:3] == 2'b11) )
                wv_inflight <= 1'b1;
            SdrWv2 <= (SdrSta[2] == 1) && (video_dlclk == 0) && wv2_take
                      && (RstSeq[4:3] == 2'b11);
            if( (SdrSta[2] == 1) && (video_dlclk == 0) && wv2_take
                && (RstSeq[4:3] == 2'b11) )
                wv2_inflight <= 1'b1;
            SdrWv3 <= (SdrSta[2] == 1) && (video_dlclk == 0) && wv3_take
                      && (RstSeq[4:3] == 2'b11);
            if( (SdrSta[2] == 1) && (video_dlclk == 0) && wv3_take
                && (RstSeq[4:3] == 2'b11) )
                wv3_inflight <= 1'b1;
        end
        //-- 4 fases: inflight se suelta cuando el shim BAJA wv_req (tras ver
        //-- su wv_done) — sin esto, la siguiente fase 0 podia re-conceder la
        //-- MISMA operacion antes de que el shim retirase la peticion.
        if( wv_inflight == 1 && wv_req == 0 ) wv_inflight <= 1'b0;
        if( wv2_inflight == 1 && wv2_req == 0 ) wv2_inflight <= 1'b0;
        if( wv3_inflight == 1 && wv3_req == 0 ) wv3_inflight <= 1'b0;
    end

    // (_104: el latch de palabra wave va mas abajo, tras declarar
    //  ff_sdr_seq_5/6 — leccion Gowin de los implicitos)

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000:
                if( SdrSta[2] == 1 ) begin               //-- cpu/vdp read/write
                    SdrCmd <= SdrCmd_ac;
                end
                else if( SdrSta[1:0] == 2'b00 ) begin  //-- idle
                    SdrCmd <= SdrCmd_xx;
                end
                else if( SdrSta[1:0] == 2'b01 ) begin  //-- precharge all
                    SdrCmd <= SdrCmd_pr;
                end
                else if( SdrSta[1:0] == 2'b10 ) begin  //-- refresh
                    SdrCmd <= SdrCmd_re;
                end
                else begin                                   //-- mode register set
                    SdrCmd <= SdrCmd_ms;
                end
            3'b001:
                SdrCmd <= SdrCmd_xx;
            3'b010:
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        SdrCmd <= SdrCmd_rd;            //-- "100"(cpu read) / "110"(vdp read)
                    end
                    else begin
                        SdrCmd <= SdrCmd_wr;            //-- "101"(cpu write) / "111"(vdp write)
                    end
                end
            3'b011:
                SdrCmd <= SdrCmd_xx;
            default: ;
                //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
            end
            3'b010: begin
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        //-- lectura: habilitar los dos bytes; el latch elige
                        SdrUdq <= 0;
                        SdrLdq <= 0;
                    end
                    else begin
                        if( video_dlclk == 0 ) begin
                            //-- cpu/wave/wv2 write: lane por addr[0] (0=bajo, 1=alto)
                            SdrUdq <= ~( SdrWav ? wv_addr[0] : SdrWv2 ? wv2_addr[0] : SdrWv3 ? wv3_addr[0] : sdram_addr[0] );
                            SdrLdq <=  ( SdrWav ? wv_addr[0] : SdrWv2 ? wv2_addr[0] : SdrWv3 ? wv3_addr[0] : sdram_addr[0] );
                        end
                        else begin
                            //-- vdp write: lane por vram_addr[16]
                            SdrUdq <= ~vram_addr[16];
                            SdrLdq <=  vram_addr[16];
                        end
                    end
                end
            end
            3'b011: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( SdrSta[2] == 0 ) begin                                       //-- set [command mode]
                    //--           (A12:A11=00) WBL=single TM=off CL=2 WT=0(seq) BL=1
                    SdrAdr <= { 2'b00, 3'b010, 1'b0, 3'b010, 1'b0, 3'b000 };
                    SdrBa  <= 2'b00;                                             //-- bank A
                end
                else begin                                                           //-- set [row address]
                    if( video_dlclk == 0 ) begin
                        if( wav_take ) begin
                            //-- _104: wave = filas 4096+ (bit12 de fila a 1),
                            //-- INALCANZABLES por los mapeos CPU/VDP (fila
                            //-- {2'b00,...} siempre): aislamiento fisico.
                            SdrAdr <= { 1'b1, 2'b00, wv_addr[21:12] };
                            SdrBa  <= wv_addr[11:10];
                        end
                        else if( wv2_take ) begin
                            //-- V9968: misma ventana aislada de filas 4096+
                            SdrAdr <= { 1'b1, 2'b00, wv2_addr[21:12] };
                            SdrBa  <= wv2_addr[11:10];
                        end
                        else if( wv3_take ) begin
                            //-- V9968 _120: canal B, misma ventana aislada
                            SdrAdr <= { 1'b1, 2'b00, wv3_addr[21:12] };
                            SdrBa  <= wv3_addr[11:10];
                        end
                        else begin
                            SdrAdr <= { 2'b00, sdram_addr[12:2] };   //-- cpu read/write (fila = mismos bits que el original)
                            SdrBa  <= sdram_addr[22:21];                         //-- bank A+B+C+D
                        end
                    end
                    else begin
                        SdrAdr <= { 2'b00, vram_addr[10:0] };                   //-- vdp read/write
                        SdrBa  <= 2'b11;                                         //-- bank D
                    end
                end
            end
            3'b010: begin                                                                             //-- set [column address]
                SdrAdr[12:9] <= 4'b0010;                                                           //-- A10=1 => enable auto precharge
                //-- when A10=1, SdrBa is ignored and all banks are selected
                //-- be careful not to assign SdrBa during auto precharge, otherwise it will cause instability
                if( video_dlclk == 0 ) begin
                    if( SdrWav ) begin
                        //-- _104: wave col = wv[9:1] (9 bits)
                        SdrAdr[8:0] <= wv_addr[9:1];
                    end
                    else if( SdrWv2 ) begin
                        SdrAdr[8:0] <= wv2_addr[9:1];
                    end
                    else if( SdrWv3 ) begin
                        SdrAdr[8:0] <= wv3_addr[9:1];
                    end
                    else begin
                        //-- cpu: col = {addr[20:13], addr[1]} — el bit addr[1] (antes
                        //-- media palabra de 32b) es ahora el LSB de columna
                        SdrAdr[8:0] <= { sdram_addr[20:13], sdram_addr[1] };                          //-- cpu read/write
                    end
                end
                else begin
                    //-- vdp: misma región alta de columnas que el original, col par
                    SdrAdr[8:0] <= { 3'b111, vram_addr[15:11], 1'b0 };
                end
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b010 ) begin
            if( SdrSta[2] == 1 ) begin
                if( SdrSta[0] == 0 ) begin
                    dq_oe <= 0;                                                  //-- lectura: bus en Z
                end
                else begin
                    dq_oe <= 1;
                    if( video_dlclk == 0 ) begin
                        //-- "101"(cpu/wave/wv2 write): byte duplicado, DQM elige lane
                        SdrDat <= SdrWav ? { wv_wdata, wv_wdata } :
                                  SdrWv2 ? { wv2_wdata, wv2_wdata } :
                                  SdrWv3 ? { wv3_wdata, wv3_wdata } :
                                           { ram_din, ram_din };
                    end
                    else begin
                        SdrDat <= { vram_din, vram_din };          //-- "111"(vdp write)
                    end
                end
            end
        end
        else begin
            dq_oe <= 0;
        end
    end

    //-- Data read latch for CPU
    reg ff_sdr_seq_5 = 0;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_5 <= 0;
        if( ff_sdr_seq == 3'b100 ) begin
            ff_sdr_seq_5 <= 1;
        end
    end
    reg ff_sdr_seq_6 = 0;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_6 <= 0;
        if( ff_sdr_seq == 3'b101 ) begin
            ff_sdr_seq_6 <= 1;
        end
    end
    reg SdrSta_4 = 0;
    always @ ( posedge clk_108m ) begin
        SdrSta_4 <= 0;
        if( SdrSta[2:0] == 3'b100 ) begin
            SdrSta_4 <= 1;
        end
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
            //-- _104: un burst WAVE usa el encoding "read cpu" (100) — el
            //-- guardian !SdrWav/!SdrWv2 evita que pise RamDbi (contrato CPU intacto)
            if( SdrSta_4 == 1 && SdrWav == 0 && SdrWv2 == 0 && SdrWv3 == 0 ) begin         //-- read cpu
                if( sdram_addr[0] == 1'b0 )
                    RamDbi <= dq_in[7:0];
                else
                    RamDbi <= dq_in[15:8];
            end
        end
    end

    //-- _104: latch de PALABRA + pulso de completado del puerto wave.
    //-- Lecturas: mismas fases de dato que RamDbi; escrituras fire-and-forget.
    //-- El pulso wv_done va al final del burst en ambos casos.
    always @ ( posedge clk_108m ) begin
        wv_done <= 1'b0;
        if( (ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1) && SdrWav == 1 && SdrSta[0] == 0 )
            wv_dout <= dq_in;
        if( ff_sdr_seq == 3'b110 && SdrWav == 1 )
            wv_done <= 1'b1;
    end

    //-- V9968: latch de PALABRA + pulso de completado del puerto wv2
    always @ ( posedge clk_108m ) begin
        wv2_done <= 1'b0;
        if( (ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1) && SdrWv2 == 1 && SdrSta[0] == 0 )
            wv2_dout <= dq_in;
        if( ff_sdr_seq == 3'b110 && SdrWv2 == 1 )
            wv2_done <= 1'b1;
    end

    //-- V9968 _120: latch de PALABRA + pulso de completado del puerto wv3
    always @ ( posedge clk_108m ) begin
        wv3_done <= 1'b0;
        if( (ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1) && SdrWv3 == 1 && SdrSta[0] == 0 )
            wv3_dout <= dq_in;
        if( ff_sdr_seq == 3'b110 && SdrWv3 == 1 )
            wv3_done <= 1'b1;
    end


    //-- Data read latch for VDP
    always @ ( posedge clk_108m ) begin
            if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
                if( SdrSta == 3'b110 ) begin                        //-- read vdp
                    vram_dout <= dq_in;
                end
            end
    end

    //SDRAM controller state
    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( video_dhclk == 1 ) begin
                    ff_sdr_seq <= 3'b001;
                end
            end
            3'b111: begin
                if( video_dhclk == 0 ) begin
                    ff_sdr_seq <= 3'b000;
                end
            end
            default: begin
                ff_sdr_seq <= ff_sdr_seq + 1;
            end
        endcase
    end

endmodule
