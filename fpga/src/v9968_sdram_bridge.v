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
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================

module v9968_sdram_bridge (
    // --- dominio del VDP (85.909 MHz) ---
    input  wire        clk_vdp,
    input  wire        rst_n,
    input  wire        bk_req,          // pulso 1 ciclo
    input  wire        bk_we,
    input  wire [21:0] bk_addr,         // direccion de BYTE
    input  wire [7:0]  bk_wdata,
    output reg  [15:0] bk_rword,
    output reg         bk_done_t,       // toggle

    // --- dominio SDRAM (108 MHz) ---
    input  wire        clk_108m,
    output reg         wv2_req,         // nivel
    output reg         wv2_we,
    output reg  [21:0] wv2_addr,
    output reg  [7:0]  wv2_wdata,
    input  wire [15:0] wv2_dout,        // palabra 16b latcheada por memory.v
    input  wire        wv2_done         // pulso 1 ciclo en clk_108m
);

    // ---- lado 85.9: captura de la peticion + toggle de salida ----
    reg        req_t = 0;
    reg        r_we = 0;
    reg [21:0] r_addr = 0;
    reg [7:0]  r_wdata = 0;

    always @( posedge clk_vdp ) begin
        if( !rst_n ) begin
            req_t <= 1'b0;
        end
        else if( bk_req ) begin
            r_we    <= bk_we;
            r_addr  <= bk_addr;
            r_wdata <= bk_wdata;
            req_t   <= ~req_t;
        end
    end

    // ---- 85.9→108: sync del toggle de peticion ----
    reg [2:0] req_s = 0;
    always @( posedge clk_108m ) req_s <= { req_s[1:0], req_t };
    wire new_req = req_s[2] ^ req_s[1];

    // ---- lado 108: nivel wv2_req + captura del done ----
    reg        ack_t = 0;
    reg [15:0] cap_word = 0;

    always @( posedge clk_108m ) begin
        if( new_req ) begin
            // datos ya estables ≥2 ciclos de 108 (cruzaron con el toggle)
            wv2_we    <= r_we;
            wv2_addr  <= r_addr;
            wv2_wdata <= r_wdata;
            wv2_req   <= 1'b1;
        end
        if( wv2_done ) begin
            cap_word <= wv2_dout;
            wv2_req  <= 1'b0;      // protocolo: bajar req tras el done
            ack_t    <= ~ack_t;
        end
    end

    // ---- 108→85.9: sync del toggle de respuesta ----
    reg [2:0] ack_s = 0;
    always @( posedge clk_vdp ) ack_s <= { ack_s[1:0], ack_t };
    wire new_ack = ack_s[2] ^ ack_s[1];

    always @( posedge clk_vdp ) begin
        if( !rst_n ) begin
            bk_done_t <= 1'b0;
        end
        else if( new_ack ) begin
            // cap_word estable desde su latch en 108 (≥2 ciclos de 85.9)
            bk_rword  <= cap_word;
            bk_done_t <= ~bk_done_t;
        end
    end

endmodule
