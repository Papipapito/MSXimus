// ============================================================================
// adpcm_sdram.v — RAM de muestras del ADPCM-B (Y8950) en la SDRAM (_159)
//
// El Y8950 real direcciona 256KB de sample RAM (el NMS-1205 trae 32KB "de
// serie" y la wiki documenta la ampliacion a 256KB). El MSXimus tenia esos
// 32KB en BSRAM; los 256KB serian 128 bloques y el GW5AT-60 tiene 118 EN
// TOTAL, asi que la ampliacion NO CABE en BSRAM ni con el chip vacio. La
// unica memoria con sitio es la SDRAM W9825G6KH del dock, que ademas tiene
// DOS CLIENTES LIBRES ya cableados y validados en placa: wv2 y wv3 quedaron
// atados a 0 cuando la VRAM del V9968 se mudo a la DDR3.
//
// Este shim es una copia deliberada del lado HOST de wave_sdram.v (mismo
// protocolo req/ack por TOGGLE + 3FF, misma FSM ST_IDLE/ST_REQ/ST_DROP de 4
// fases, mismo "el payload viaja con el toggle y se consume >=3 ciclos
// despues"). No se inventa nada: ese handshake lleva validado desde la _104.
//
// MAPA: wv_addr = {4'd0, addr[17:0]} y memory.v mapea la familia wv2/wv3 a
// row = {1'b1, 2'b01, addr[21:12]} => filas 5120..5183 del W9825. Quedan
// FISICAMENTE fuera del alcance de la CPU (filas 0-2047), del VDP (banco D,
// filas 0-2047) y de la wave del OPL4 (filas 4096-5119): aislamiento por
// construccion, igual que el resto de la familia.
//
// El puerto devuelve PALABRAS de 16 bits (memory.v ya lo hace): es lo que
// alimenta la cache de palabra de y8950_adpcm.v. Las escrituras son de BYTE
// (memory.v elige la lane con DQM segun wv_addr[0]).
//
// FALLBACK_BSRAM=1 — LINEA DE RESPALDO (_137, VRAM del V9968 en SDRAM): ahi
// wv2/wv3 los conduce el bridge del V9968 y no hay puerto libre, asi que
// esta rama reimplementa los 32KB de siempre en BSRAM detras de la MISMA
// interfaz. El y8950_adpcm.v queda con UN SOLO camino de datos (la variante
// vive aqui, aislada); top.v elige el parametro con un `ifdef que NO puede
// producir la combinacion mala.
// ============================================================================

module adpcm_sdram #(
    parameter FALLBACK_BSRAM = 0
)(
    // ---- lado ADPCM (clk_host = clk_54m, el del y8950_adpcm) ----
    input  wire        clk_host,
    input  wire        rst_n,
    input  wire        req_toggle,    // flip = nueva operacion
    input  wire        we,            // 1=escritura de byte
    input  wire [17:0] addr,          // direccion de BYTE (256KB)
    input  wire [7:0]  wdata,
    output wire [15:0] rword,         // PALABRA alineada, valida tras done
    output wire        done_toggle,   // flip = operacion completada

    // ---- puerto wv2 de memory.v (clk_108m) ----
    input  wire        clk_108m,
    output wire        wv_req,        // nivel: peticion pendiente
    output wire        wv_we,
    output wire [21:0] wv_addr,
    output wire [7:0]  wv_wdata,
    input  wire [15:0] wv_dout,
    input  wire        wv_done        // pulso de 1 ciclo
);

generate
if (FALLBACK_BSRAM == 0) begin : g_sdram

    // -----------------------------------------------------------------------
    // ida: clk_54m -> clk_108m (3FF; los dos relojes son del PLLA, pero la
    // disciplina de la casa es 3FF igualmente — leccion de toda la saga)
    // -----------------------------------------------------------------------
    localparam ST_IDLE = 2'd0, ST_REQ = 2'd1, ST_DROP = 2'd2;

    reg        s1, s2, s3, ack;
    reg [1:0]  st;
    reg        r_req, r_we;
    reg [21:0] r_addr;
    reg [7:0]  r_wdata;
    reg [15:0] dout_l;
    reg        done_t;

    always @(posedge clk_108m or negedge rst_n) begin
        if (!rst_n) begin
            s1 <= 1'b0; s2 <= 1'b0; s3 <= 1'b0; ack <= 1'b0;
            st <= ST_IDLE;
            r_req <= 1'b0; r_we <= 1'b0; r_addr <= 22'd0; r_wdata <= 8'd0;
            dout_l <= 16'd0; done_t <= 1'b0;
        end
        else begin
            s1 <= req_toggle; s2 <= s1; s3 <= s2;
            case (st)
            ST_IDLE:
                if (s3 != ack) begin
                    ack     <= s3;
                    r_we    <= we;               // payload asentado (>=3
                    r_addr  <= {4'd0, addr};     //  ciclos tras el toggle:
                    r_wdata <= wdata;            //  regla _96)
                    r_req   <= 1'b1;
                    st      <= ST_REQ;
                end
            ST_REQ:
                if (wv_done) begin
                    r_req  <= 1'b0;              // 4 fases: soltar la peticion
                    dout_l <= wv_dout;
                    done_t <= ~done_t;
                    st     <= ST_DROP;
                end
            ST_DROP:                             // 1 ciclo de guarda (el
                st <= ST_IDLE;                   //  inflight de memory.v ve
            default:                             //  req=0 antes de reconceder)
                st <= ST_IDLE;
            endcase
        end
    end

    assign wv_req   = r_req;
    assign wv_we    = r_we;
    assign wv_addr  = r_addr;
    assign wv_wdata = r_wdata;

    // -----------------------------------------------------------------------
    // vuelta: clk_108m -> clk_54m (3FF + payload)
    // -----------------------------------------------------------------------
    reg        d1, d2, d3, dseen;
    reg [15:0] rw;

    always @(posedge clk_host or negedge rst_n) begin
        if (!rst_n) begin
            d1 <= 1'b0; d2 <= 1'b0; d3 <= 1'b0; dseen <= 1'b0; rw <= 16'd0;
        end
        else begin
            d1 <= done_t; d2 <= d1; d3 <= d2;
            if (d3 != dseen) begin
                dseen <= d3;
                rw    <= dout_l;                 // asentado: el 108 lo dejo
            end                                  //  3 ciclos antes de avisar
        end
    end

    assign rword       = rw;
    assign done_toggle = dseen;

end
else begin : g_bsram

    // -----------------------------------------------------------------------
    // RESPALDO: los 32KB de siempre en BSRAM, con la MISMA interfaz. Dos
    // bancos de 16Kx8 (bytes pares / impares) para poder escribir de byte y
    // leer de palabra sin byte-enables — inferencia limpia en Gowin.
    // Fuera de 32KB: lee 0 e ignora la escritura (comportamiento _80).
    // -----------------------------------------------------------------------
    reg [7:0] ram_lo [0:16383];
    reg [7:0] ram_hi [0:16383];

    reg        s1, new_d;
    reg [15:0] rw;
    reg        dtog;

    wire       new_op = (req_toggle != s1);
    wire       oob    = (addr[17:15] != 3'b000);
    wire [13:0] widx  = addr[14:1];

    always @(posedge clk_host) begin
        if (new_op && we && !oob) begin
            if (addr[0]) ram_hi[widx] <= wdata;
            else         ram_lo[widx] <= wdata;
        end
    end

    always @(posedge clk_host)                   // lectura continua
        rw <= oob ? 16'h0000 : {ram_hi[widx], ram_lo[widx]};

    always @(posedge clk_host or negedge rst_n) begin
        if (!rst_n) begin
            s1 <= 1'b0; new_d <= 1'b0; dtog <= 1'b0;
        end
        else begin
            s1    <= req_toggle;
            new_d <= new_op;
            if (new_d) dtog <= ~dtog;            // rw ya esta asentado
        end
    end

    assign rword       = rw;
    assign done_toggle = dtog;
    assign wv_req      = 1'b0;
    assign wv_we       = 1'b0;
    assign wv_addr     = 22'd0;
    assign wv_wdata    = 8'd0;

end
endgenerate

endmodule
