// ============================================================================
//  clk27_align.v — Alineador de fase del CLKDIV/5 (clk_27m) · Console 60K
// ----------------------------------------------------------------------------
//  PROBLEMA: en el TN20K, 27/54/108 salian ALINEADOS del mismo rPLL y todo el
//  core (PSG con bus a 27M, arbitro con DH/DL 27M->54M, VDP) se diseño con esa
//  disciplina de fase. En el 60K, clk_27m nace de un CLKDIV/5 de 135M cuyo
//  contador arranca al liberar la configuracion -> fase ARBITRARIA (1 de 5)
//  respecto a clk_54m. Victimas confirmadas: PSG mudo (escrituras de registro
//  muestreadas a 27M), y candidato principal del cuelgue de turbo/F11.
//
//  SOLUCION: medir la fase real y RE-LANZAR el CLKDIV hasta que caiga la
//  correcta (flanco de 27 coincidente con flanco de 54, como el TN20K).
//
//  MEDIDA (dominio 135M, todo del mismo VCO => fases deterministas):
//    - t54: FF toggle en 54M -> cuadrada de 27 MHz con flancos EN los flancos
//      de subida de 54M. Sus subidas caen cada 5 ciclos de 135.
//    - t27: FF toggle en 27M (CLKDIV) -> cuadrada de 13.5 MHz con flancos EN
//      las subidas de clk_27m. Subidas cada 10 ciclos de 135.
//    - k = ciclos de 135 entre subida de t27 y siguiente subida de t54
//      (0..4). Los retardos clk->q y de sincronizador son iguales para ambas
//      señales (mismos FFs, mismo destino) y se cancelan en la diferencia.
//    - k == TARGET_PHASE -> fase buena. Si no: pulso de RESETN al CLKDIV con
//      (5-k+TARGET) ciclos de retencion y re-medida (converge aunque el
//      arranque del divisor no sea deterministico: bucle de reintentos).
//
//  TARGET_PHASE por defecto 0 (flancos coincidentes). Si el HW demuestra un
//  offset fijo de rutado, se ajusta el parametro UNA vez (los LEDs de debug
//  muestran la k medida).
// ============================================================================
module clk27_align #(
    parameter [2:0] TARGET_PHASE = 3'd0,
    parameter       MAX_TRIES    = 5'd20
)(
    input  wire clk_135,
    input  wire clk_54m,
    input  wire clk_27m,        // salida del CLKDIV (via BUFG implicito)
    input  wire pll_lock,

    output reg  div5_rstn = 1'b0,   // -> RESETN del CLKDIV
    output reg  phase_ok  = 1'b0,   // fase correcta y estable
    output reg  gave_up   = 1'b0,   // agotados los reintentos (se queda como este)
    output reg  [2:0] phase_meas = 3'd7  // ultima k medida (debug/LEDs)
);

    // ---- toggles de referencia en cada dominio ----
    reg t54 = 1'b0;
    always @(posedge clk_54m) t54 <= ~t54;

    reg t27 = 1'b0;
    always @(posedge clk_27m) t27 <= ~t27;

    // ---- sincronizadores al dominio 135 (fases deterministas, mismo VCO) ----
    reg [1:0] s54 = 2'b00, s27 = 2'b00;
    always @(posedge clk_135) begin
        s54 <= {s54[0], t54};
        s27 <= {s27[0], t27};
    end
    wire e54 = (s54 == 2'b01);   // subida de t54 vista en 135
    wire e27 = (s27 == 2'b01);   // subida de t27 vista en 135

    // ---- lock sincronizado ----
    reg [1:0] lock_s = 2'b00;
    always @(posedge clk_135) lock_s <= {lock_s[0], pll_lock};
    wire locked = lock_s[1];

    // ---- FSM: soltar CLKDIV, medir k (mayoria de 8), reintentar ----
    localparam S_WAITLOCK = 3'd0;
    localparam S_RELEASE  = 3'd1;
    localparam S_SETTLE   = 3'd2;
    localparam S_MEASURE  = 3'd3;
    localparam S_JUDGE    = 3'd4;
    localparam S_RETRY    = 3'd5;
    localparam S_DONE     = 3'd6;

    reg [2:0]  st = S_WAITLOCK;
    reg [7:0]  timer = 8'd0;
    reg [2:0]  cnt135 = 3'd0;
    reg        armed = 1'b0;
    reg [2:0]  k = 3'd7;
    reg [2:0]  meas_n = 3'd0;
    reg [2:0]  agree_n = 3'd0;
    reg [2:0]  k_first = 3'd7;
    reg [4:0]  tries = 5'd0;
    reg [3:0]  hold_cycles = 4'd0;

    always @(posedge clk_135) begin
        // medidor continuo t27->t54 (solo se usa en S_MEASURE)
        if (e27) begin
            cnt135 <= 3'd0;
            armed  <= 1'b1;
        end
        else if (armed) begin
            if (e54) begin
                k     <= cnt135;
                armed <= 1'b0;
            end
            else if (cnt135 != 3'd6)
                cnt135 <= cnt135 + 3'd1;
            else
                armed <= 1'b0;   // fuera de rango (no deberia): descartar
        end

        case (st)
            S_WAITLOCK: begin
                div5_rstn <= 1'b0;
                if (locked) begin
                    timer <= 8'd0;
                    st    <= S_RELEASE;
                end
            end
            S_RELEASE: begin
                // retencion variable del RESETN = seleccion de fase si el
                // arranque es determinista (y reintento honesto si no lo es)
                if (timer[3:0] >= {1'b0, hold_cycles} + 4'd2) begin
                    div5_rstn <= 1'b1;
                    timer     <= 8'd0;
                    st        <= S_SETTLE;
                end
                else timer <= timer + 8'd1;
            end
            S_SETTLE: begin
                timer <= timer + 8'd1;
                if (timer == 8'hFF) begin   // ~1.9 us: CLKDIV+BUFG estables
                    meas_n  <= 3'd0;
                    agree_n <= 3'd0;
                    st      <= S_MEASURE;
                end
            end
            S_MEASURE: begin
                // recoger 8 medidas coherentes (una por flanco de t27 servido)
                if (!armed && k != 3'd7) begin
                    if (meas_n == 3'd0) begin
                        k_first <= k;
                        agree_n <= 3'd1;
                    end
                    else if (k == k_first)
                        agree_n <= agree_n + 3'd1;
                    meas_n <= meas_n + 3'd1;
                    k      <= 3'd7;
                    if (meas_n == 3'd7)
                        st <= S_JUDGE;
                end
            end
            S_JUDGE: begin
                phase_meas <= k_first;
                if (agree_n >= 3'd7 && k_first == TARGET_PHASE) begin
                    phase_ok <= 1'b1;
                    st       <= S_DONE;
                end
                else if (tries == MAX_TRIES) begin
                    gave_up <= 1'b1;    // seguir con lo que haya (no bloquear)
                    phase_ok <= 1'b1;
                    st      <= S_DONE;
                end
                else st <= S_RETRY;
            end
            S_RETRY: begin
                div5_rstn   <= 1'b0;
                tries       <= tries + 5'd1;
                // si el arranque del CLKDIV es determinista, esta retencion
                // corrige la fase de un golpe; si no, barre las 5 posiciones
                hold_cycles <= (k_first == 3'd7) ? 4'd1
                             : {1'b0, (TARGET_PHASE >= k_first) ? (TARGET_PHASE - k_first)
                                                                : (3'd5 + TARGET_PHASE - k_first)};
                timer       <= 8'd0;
                st          <= S_RELEASE;
            end
            S_DONE: begin
                // fase fijada hasta el proximo power-cycle
            end
            default: st <= S_WAITLOCK;
        endcase
    end

endmodule
