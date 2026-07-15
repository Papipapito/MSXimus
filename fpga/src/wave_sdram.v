// ============================================================================
// wave_sdram.v — memoria de ondas del OPL4 en la SDRAM del dock (MSXimus _104)
//
// SUSTITUYE a wave_ddr3.v: la DDR3 del SOM resulto ANALOGICAMENTE marginal
// en esta placa (ojo de calibracion con carril desplazado un beat, variable
// por arranque, saga _94-_103). La SDRAM W9825G6KH del dock lleva años
// sirviendo TODO el MSX (mapper/megaram/VRAM) sin corromper un byte: la
// wave (YRW801 2MB + RAM de muestras 2MB) se muda a sus filas 4096+,
// fisicamente inalcanzables por los mapeos CPU/VDP.
//
// El puerto wave de memory.v roba SOLO turnos de CPU vacios (patron
// refresh); este shim arbitra los dos clientes y habla su handshake de
// 4 fases (wv_req nivel / wv_done pulso, dominio clk_108m):
//  - HOST (clk_54m): loader wl + puerto debug 34-37h + verify. Toggle+3FF.
//  - MOTOR (clk_eng36 = 108/3): fetches del YMF278B. Toggle+3FF.
// TODOS los relojes son de la familia del PLLA -> paths sincronos, cero CDC
// de verdad (la leccion de toda la saga: 3FF igualmente, disciplina).
//
// El puerto devuelve PALABRAS (16 bits): el byte pedido + su pareja, para
// la cache de palabra de opl4_pcm (sustituye a la cache de linea DDR3).
// ============================================================================

module wave_sdram (
    // ---- lado MSX (clk_host = clk_54m) ----
    input  wire        clk_host,
    input  wire        rst_n,
    input  wire        req_toggle,    // flip = nueva operacion
    input  wire        we,            // 1=escritura (estable durante handshake)
    input  wire [21:0] addr,          // direccion de BYTE (4MB)
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,         // valido tras done_toggle
    output reg         done_toggle,   // flip = operacion completada
    output wire        ready,         // siempre 1 (la SDRAM inicializa en ms)

    // ---- puerto del motor PCM OPL4 (clk_eng36 = clk_108m/3) ----
    input  wire        clk_eng,
    input  wire        eng_req,       // pulso 1 ciclo eng = nueva operacion
    input  wire        eng_we,
    input  wire [21:0] eng_addr,
    input  wire [7:0]  eng_wdata,
    output reg  [7:0]  eng_rdata,
    output reg  [15:0] eng_rword,     // PALABRA (para la cache de palabra)
    output reg         eng_done_t,    // TOGGLE = completada

    // ---- telemetria (compatibilidad con el puerto diag del DDR3) ----
    output wire [7:0]  diag,

    // ---- puerto wave de memory.v (clk_108m) ----
    input  wire        clk_108m,
    output reg         wv_req,
    output reg         wv_we,
    output reg  [21:0] wv_addr,
    output reg  [7:0]  wv_wdata,
    input  wire [15:0] wv_dout,
    input  wire        wv_done        // pulso 1 ciclo
);

assign ready = 1'b1;
assign diag  = 8'h00;          // sin watchdogs: la SDRAM no tiene calibracion

// ---------------------------------------------------------------------------
// sincronizacion de peticiones al dominio 108 (3FF, disciplina de la casa:
// el payload viaja con el toggle y se consume 1 ciclo despues del aviso)
// ---------------------------------------------------------------------------
reg h_s1, h_s2, h_s3, h_ack;           // host toggle
reg e_s1, e_s2, e_s3, e_ack;           // eng toggle (el pulso eng dura 1 ciclo
reg eng_tgl;                            //  de 36M -> se convierte a toggle alli)
always @(posedge clk_eng or negedge rst_n) begin
    if (!rst_n) eng_tgl <= 1'b0;
    else if (eng_req) eng_tgl <= ~eng_tgl;
end

reg [1:0] st;
localparam ST_IDLE = 2'd0, ST_REQ = 2'd1, ST_DROP = 2'd2;
reg        op_eng;                      // cliente de la op en curso
reg [15:0] dout_h, dout_e;              // dato POR CLIENTE (sin sobrescrituras)
reg        done_h_t;                    // toggle de done hacia host (108)
reg        done_e_t;                    // toggle de done hacia eng  (108)

always @(posedge clk_108m or negedge rst_n) begin
    if (!rst_n) begin
        h_s1 <= 0; h_s2 <= 0; h_s3 <= 0; h_ack <= 0;
        e_s1 <= 0; e_s2 <= 0; e_s3 <= 0; e_ack <= 0;
        wv_req <= 0; wv_we <= 0; wv_addr <= 22'd0; wv_wdata <= 8'd0;
        st <= ST_IDLE; op_eng <= 0; dout_h <= 16'd0; dout_e <= 16'd0;
        done_h_t <= 0; done_e_t <= 0;
    end
    else begin
        h_s1 <= req_toggle; h_s2 <= h_s1; h_s3 <= h_s2;
        e_s1 <= eng_tgl;    e_s2 <= e_s1; e_s3 <= e_s2;
        case (st)
        ST_IDLE: begin
            if (e_s3 != e_ack) begin           // motor primero (deadline)
                e_ack   <= e_s3;
                op_eng  <= 1'b1;
                wv_we   <= eng_we;             // payload asentado (>=3 ciclos
                wv_addr <= eng_addr;           //  tras el toggle: regla _96)
                wv_wdata<= eng_wdata;
                wv_req  <= 1'b1;
                st <= ST_REQ;
            end
            else if (h_s3 != h_ack) begin
                h_ack   <= h_s3;
                op_eng  <= 1'b0;
                wv_we   <= we;
                wv_addr <= addr;
                wv_wdata<= wdata;
                wv_req  <= 1'b1;
                st <= ST_REQ;
            end
        end
        ST_REQ:
            if (wv_done) begin
                wv_req <= 1'b0;                // 4 fases: soltar la peticion
                if (op_eng) begin dout_e <= wv_dout; done_e_t <= ~done_e_t; end
                else        begin dout_h <= wv_dout; done_h_t <= ~done_h_t; end
                st <= ST_DROP;
            end
        ST_DROP:                                // 1 ciclo de guarda (inflight
            st <= ST_IDLE;                      //  de memory.v ve req=0)
        default: st <= ST_IDLE;
        endcase
    end
end

// ---------------------------------------------------------------------------
// vuelta al HOST (clk_54m): 3FF + payload byte
// ---------------------------------------------------------------------------
reg dh1, dh2, dh3;
always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        dh1 <= 0; dh2 <= 0; dh3 <= 0; done_toggle <= 0; rdata <= 8'd0;
    end
    else begin
        dh1 <= done_h_t; dh2 <= dh1; dh3 <= dh2;
        if (dh3 != done_toggle) begin
            done_toggle <= dh3;
            rdata <= addr[0] ? dout_h[15:8] : dout_h[7:0];
        end
    end
end

// ---------------------------------------------------------------------------
// vuelta al MOTOR (clk_eng36): 3FF + palabra entera (cache de palabra)
// ---------------------------------------------------------------------------
reg de1, de2, de3, done_e_seen;
always @(posedge clk_eng or negedge rst_n) begin
    if (!rst_n) begin
        de1 <= 0; de2 <= 0; de3 <= 0; done_e_seen <= 0;
        eng_rdata <= 8'd0; eng_rword <= 16'd0; eng_done_t <= 0;
    end
    else begin
        de1 <= done_e_t; de2 <= de1; de3 <= de2;
        if (de3 != done_e_seen) begin
            done_e_seen <= de3;
            eng_rword <= dout_e;
            eng_rdata <= eng_addr[0] ? dout_e[15:8] : dout_e[7:0];
            eng_done_t <= ~eng_done_t;
        end
    end
end

endmodule
