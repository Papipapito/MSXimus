//============================================================================
// fan_ctrl.v — Control del ventilador por temperatura del die (MSXimus 60K)
//
// El GW5AT-60 NO tiene sensor de temperatura on-die accesible (su SAR ADC,
// UG298, es solo de tensiones; el ADC delta-sigma con sensor termico es de
// los 25K/75K/138K, verificado empiricamente: RP0008). En su lugar se usa un
// TERMOMETRO DE OSCILADOR EN ANILLO (ro_osc.v): la frecuencia de un anillo
// de NANDs en fabric cae con la temperatura del die (~0.1%/grado). Se cuenta
// el anillo en ventanas de ~9.7ms contra clk (27MHz) y se compara con la
// BASELINE = maxima cuenta vista desde el encendido (el arranque en frio es
// el momento mas fresco del die):
//     ON  cuando la cuenta cae mas de K_ON/1024  (~3.1% = +~30 grados)
//     OFF cuando la cuenta sube de   K_OFF/1024  (~2.0% = +~20 grados)
// Fail-safe: cuenta a cero (anillo muerto u optimizado) -> ventilador ON.
//
// Limitacion documentada: si se reinicia con el die caliente, la baseline
// queda alta y el ventilador tarda mas en activarse (los umbrales son
// relativos al momento mas frio visto). Calibrable en HW via K_ON/K_OFF.
//============================================================================
module fan_ctrl #(
    parameter CLK_HZ   = 27_000_000,
    parameter [31:0] WIN_CYC = 32'd131072,  // ventana de cuenta (2^17 = ~4.85ms;
                                            // 20 bits no desbordan ni a 150MHz)
    parameter [9:0] K_ON  = 10'd32,   // caida para ON  (32/1024 = 3.1%)
    parameter [9:0] K_OFF = 10'd20,   // caida para OFF (20/1024 = 2.0%)
    // _124: umbrales ABSOLUTOS de cuenta (TH_ON != 0 los activa y anula el
    // modo relativo). Motivo: la pendiente REAL medida en placa (COM11,
    // 2026-07-20) es ~6x menor que la estimada (frio 386400 -> caliente
    // ~385400 con WIN 2^17 = -0.26%) y ademas la baseline relativa nace
    // ALTA si se flashea con el die caliente (el ventilador no arrancaba
    // nunca: HW _119/_122/_123). Con cuentas absolutas calibradas de la
    // telemetria real, el umbral es reproducible en esta placa.
    parameter [19:0] TH_ON  = 20'd0,  // ON  cuando meas < TH_ON  (0 = relativo)
    parameter [19:0] TH_OFF = 20'd0,  // OFF cuando meas > TH_OFF
    // _125: LECCION de HW _124 — los umbrales ABSOLUTOS no sobreviven a un
    // rebuild (la frecuencia del anillo depende del placement/rutado: _123
    // frio=386K con WIN 2^17, _124 leia 840K con WIN 2^18 = +8% de anillo,
    // el umbral quedo inalcanzable). Vuelta al modo RELATIVO con la K real
    // medida (el punto "ya deberia arrancar" de Albert = -0.26% del frio
    // => K_ON=2/1024 dispara a -0.195%) + GARANTIA POR TIEMPO: si tras
    // FORCE_ON_SEC segundos el termometro no ha disparado (die templado por
    // reflasheo en caliente, baseline envenenada, o pendiente rara), el
    // ventilador se enciende FIJO. El termometro adelanta; el reloj asegura.
    parameter [31:0] FORCE_ON_SEC = 32'd0   // 0 = sin garantia por tiempo
)(
    input  wire        clk,          // 27MHz
    input  wire        reset_n,
    // interfaz con ro_osc (anillo + contador en su dominio)
    output reg         ro_en,        // anillo corriendo
    output reg         ro_cnt_rst,   // limpia el contador (con el anillo parado)
    input  wire [19:0] ro_cnt,       // cuenta de flancos (estable con ro_en=0)
    // salida
    output reg         fan_en,
    output reg  [19:0] dbg_cnt       // ultima cuenta (para calibrar en HW)
);

    // Ventana de medida contra clk (27MHz); una medida por segundo
    localparam [31:0] C_MEAS  = CLK_HZ;         // periodo entre medidas
    localparam [31:0] C_WIN   = WIN_CYC;        // ciclos de ventana
    localparam [31:0] C_STL   = 32'd64;         // asentamiento tras parar/limpiar
    localparam [31:0] C_FIRST = CLK_HZ / 10;    // primera medida a los 100ms

    localparam S_IDLE = 3'd0;
    localparam S_CLR  = 3'd1;
    localparam S_RUN  = 3'd2;
    localparam S_STOP = 3'd3;
    localparam S_EVAL = 3'd4;

    reg [2:0]  state;
    reg [31:0] cnt;
    reg [19:0] base_max;          // maxima cuenta vista (referencia "frio")
    reg [19:0] meas;
    reg [29:0] prod_on, prod_off; // base_max * K (registrado, sin prisa)
    reg [19:0] th_on, th_off;
    reg [31:0] up_sec;            // _125: segundos de encendido (1 medida/s)
    reg        forced_on;         // _125: garantia por tiempo disparada

    always @(posedge clk) begin
        if (!reset_n) begin
            state      <= S_IDLE;
            cnt        <= C_MEAS - C_FIRST;
            ro_en      <= 1'b0;
            ro_cnt_rst <= 1'b0;
            fan_en     <= 1'b0;
            base_max   <= 20'd0;
            meas       <= 20'd0;
            dbg_cnt    <= 20'd0;
            prod_on    <= 30'd0;
            prod_off   <= 30'd0;
            th_on      <= 20'd0;
            th_off     <= 20'd0;
            up_sec     <= 32'd0;
            forced_on  <= 1'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    cnt <= cnt + 32'd1;
                    if (cnt >= C_MEAS) begin
                        cnt        <= 32'd0;
                        ro_cnt_rst <= 1'b1;      // limpiar con el anillo parado
                        state      <= S_CLR;
                    end
                end
                S_CLR: begin
                    cnt <= cnt + 32'd1;
                    if (cnt >= C_STL) begin
                        cnt        <= 32'd0;
                        ro_cnt_rst <= 1'b0;
                        ro_en      <= 1'b1;      // ventana abierta
                        state      <= S_RUN;
                    end
                end
                S_RUN: begin
                    cnt <= cnt + 32'd1;
                    if (cnt >= C_WIN) begin
                        cnt   <= 32'd0;
                        ro_en <= 1'b0;           // ventana cerrada
                        state <= S_STOP;
                    end
                end
                S_STOP: begin
                    cnt <= cnt + 32'd1;
                    if (cnt >= C_STL) begin      // contador ya estatico
                        meas  <= ro_cnt;
                        cnt   <= 32'd0;
                        state <= S_EVAL;
                    end
                end
                S_EVAL: begin
                    cnt <= cnt + 32'd1;
                    // pipeline relajado: productos y umbrales en ciclos sucesivos
                    prod_on  <= base_max * K_ON;
                    prod_off <= base_max * K_OFF;
                    th_on    <= base_max - prod_on[29:10];   // base*(1 - K_ON/1024)
                    th_off   <= base_max - prod_off[29:10];
                    if (cnt >= 32'd7) begin
                        dbg_cnt <= meas;
                        up_sec  <= up_sec + 32'd1;           // 1 medida ~ 1s
                        if (FORCE_ON_SEC != 32'd0 && up_sec >= FORCE_ON_SEC)
                            forced_on <= 1'b1;               // garantia por tiempo
                        if (forced_on || meas == 20'd0) begin
                            fan_en <= 1'b1;                  // garantia / anillo muerto
                        end
                        else begin
                            if (meas > base_max) base_max <= meas;
                            if (TH_ON != 20'd0) begin
                                // modo absoluto (solo calibraciones puntuales:
                                // NO sobrevive a un rebuild, ver cabecera)
                                if      (meas < TH_ON)  fan_en <= 1'b1;
                                else if (meas > TH_OFF) fan_en <= 1'b0;
                            end
                            else begin
                                if      (meas < th_on)  fan_en <= 1'b1;
                                else if (meas > th_off) fan_en <= 1'b0;
                            end
                            // entre umbrales: mantener (histeresis)
                        end
                        state <= S_IDLE;
                        cnt   <= 32'd0;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
