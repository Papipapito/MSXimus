// ============================================================================
// v9968_sdram_bridge.v — CDC entre el backend del shim VRAM del V9968
// (clk_vdp 85.909 MHz, bk_req pulso / bk_done_t toggle) y el puerto wave
// de memory.v (clk_108m, wv2_req NIVEL + wv2_done pulso; el peticionario
// debe BAJAR wv2_req tras ver su done — igual que el puerto wave del OPL4).
//
// CDC clasico por toggles: req_t (85.9→108) y ack_t (108→85.9), 2FF de
// sincronizacion en cada cruce. Los datos (addr/we/wdata) quedan ESTABLES
// desde el pulso bk_req hasta el done (el shim no emite otra peticion
// hasta recibir bk_done_t), asi que cruzan sin FIFO.
//
// _148 FIX B — ESCRITURAS DE PALABRA. El shim ya no trocea las escrituras en
// bytes: emite UNA peticion por palabra de 32 bits con bk_wmask[3:0]
// (1 = escribir ese byte). El bus de datos pasa de 8 a 32 bits y se anade
// wv2_wmask. El CDC NO cambia (toggle + captura estable): mismo numero de
// flip-flops de sincronizacion, misma latencia, solo mas bits de payload.
//
//   NARROW_BYTE = 0 (por defecto, camino DDR3): la palabra + mascara cruzan
//                    enteras -> UNA operacion en el lado far.
//   NARROW_BYTE = 1 (camino LEGACY de memory.v, puertos wv2/wv3): el lado far
//                    solo sabe escribir 1 byte por operacion (SdrDat =
//                    {wdata,wdata} con DQM de addr[0]). El bridge SERIALIZA la
//                    palabra en hasta 4 round-trips y solo entonces devuelve
//                    bk_done_t: el shim ve una escritura atomica de palabra y
//                    memory.v no se toca. Coste identico al esquema byte-a-byte
//                    de antes (que es lo que ese camino tenia igualmente).
//
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================

module v9968_sdram_bridge #(
    parameter NARROW_BYTE = 0,
    parameter FAR_DW      = 32   // ancho del bus de datos del lado far
                                 // (8 en el camino legacy de memory.v)
)(
    // --- dominio del VDP (85.909 MHz) ---
    input  wire        clk_vdp,
    input  wire        rst_n,
    input  wire        bk_req,          // pulso 1 ciclo
    input  wire        bk_we,
    input  wire [21:0] bk_addr,         // direccion de BYTE (escrituras: word-aligned)
    input  wire [31:0] bk_wdata,        // _148: palabra completa
    input  wire [3:0]  bk_wmask,        // _148: 1 = escribir ese byte
    output reg  [15:0] bk_rword,
    output reg         bk_done_t,       // toggle

    // --- dominio SDRAM (108 MHz) / DDR3 (74.25 MHz) ---
    input  wire        clk_108m,
    output reg         wv2_req,         // nivel
    output reg         wv2_we,
    output reg  [21:0] wv2_addr,
    output reg  [FAR_DW-1:0] wv2_wdata, // NARROW_BYTE=1 -> byte util en [7:0]
    output reg  [3:0]  wv2_wmask,       // NARROW_BYTE=1 -> sin uso (0)
    input  wire [15:0] wv2_dout,        // palabra 16b latcheada por memory.v
    input  wire        wv2_done         // pulso 1 ciclo en clk_108m
);

    // ---- lado 85.9: captura de la peticion + toggle de salida ----
    reg        req_t = 0;
    reg        r_we = 0;
    reg [21:0] r_addr = 0;
    reg [31:0] r_wdata = 0;
    reg [3:0]  r_wmask = 0;

    // _148: estado de la SERIALIZACION (solo vive con NARROW_BYTE=1; con 0 el
    // sintetizador lo elimina entero porque n_rem se queda constante a 0).
    reg [3:0]  n_rem = 0;            // bytes que AUN faltan por lanzar
    reg [31:0] n_word = 0;           // copia de la palabra
    reg [21:0] n_base = 0;           // direccion de la palabra (alineada)
    // primer byte habilitado de una mascara
    function [1:0] fbyte(input [3:0] m);
        fbyte = m[0] ? 2'd0 : m[1] ? 2'd1 : m[2] ? 2'd2 : 2'd3;
    endfunction

    // ---- 108→85.9: sync del toggle de respuesta (declarado antes de usarse) --
    reg [2:0] ack_s = 0;
    reg [15:0] cap_word = 0;
    wire new_ack = ack_s[2] ^ ack_s[1];

    always @( posedge clk_vdp ) begin
        if( !rst_n ) begin
            req_t     <= 1'b0;
            bk_done_t <= 1'b0;
            n_rem     <= 4'd0;
        end
        else begin
            if( bk_req ) begin
                // _148 SEGURIDAD: mascara VACIA. fbyte(0) devuelve 3 (no hay
                // bit puesto), asi que en modo serializado una escritura con
                // mascara 0 escribiria el byte 3 SIN que nadie lo pidiera. El
                // shim no deberia emitirla nunca (vram_wdata_mask = 4'b1111
                // significa "no escribas nada"), pero si llega se degrada a una
                // lectura inocua. En modo palabra la DM ya la neutraliza sola.
                r_we    <= bk_we && (!NARROW_BYTE || (bk_wmask != 4'd0));
                r_wmask <= bk_wmask;
                if( NARROW_BYTE && bk_we && (bk_wmask != 4'd0) ) begin
                    // lanzar el PRIMER byte habilitado; el resto queda en n_rem
                    r_addr  <= { bk_addr[21:2], fbyte(bk_wmask) };
                    r_wdata <= { 24'd0, bk_wdata[ 8*fbyte(bk_wmask) +: 8 ] };
                    n_rem   <= bk_wmask & ~(4'd1 << fbyte(bk_wmask));
                    n_word  <= bk_wdata;
                    n_base  <= bk_addr;
                end
                else begin
                    r_addr  <= bk_addr;
                    r_wdata <= bk_wdata;
                    n_rem   <= 4'd0;
                end
                req_t <= ~req_t;
            end
            else if( new_ack ) begin
                if( NARROW_BYTE && (n_rem != 4'd0) ) begin
                    // quedan bytes: relanzar SIN avisar al shim
                    r_addr  <= { n_base[21:2], fbyte(n_rem) };
                    r_wdata <= { 24'd0, n_word[ 8*fbyte(n_rem) +: 8 ] };
                    n_rem   <= n_rem & ~(4'd1 << fbyte(n_rem));
                    req_t   <= ~req_t;
                end
                else begin
                    // cap_word estable desde su latch en 108 (≥2 ciclos de 85.9)
                    bk_rword  <= cap_word;
                    bk_done_t <= ~bk_done_t;
                end
            end
        end
    end

    // ---- 85.9→108: sync del toggle de peticion ----
    reg [2:0] req_s = 0;
    always @( posedge clk_108m ) req_s <= { req_s[1:0], req_t };
    wire new_req = req_s[2] ^ req_s[1];

    // ---- lado 108: nivel wv2_req + captura del done ----
    reg        ack_t = 0;

    always @( posedge clk_108m ) begin
        if( new_req ) begin
            // datos ya estables ≥2 ciclos de 108 (cruzaron con el toggle)
            wv2_we    <= r_we;
            wv2_addr  <= r_addr;
            wv2_wdata <= r_wdata[FAR_DW-1:0];
            wv2_wmask <= NARROW_BYTE ? 4'd0 : r_wmask;
            wv2_req   <= 1'b1;
        end
        if( wv2_done ) begin
            cap_word <= wv2_dout;
            wv2_req  <= 1'b0;      // protocolo: bajar req tras el done
            ack_t    <= ~ack_t;
        end
    end

    always @( posedge clk_vdp ) ack_s <= { ack_s[1:0], ack_t };

endmodule
