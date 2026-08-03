// Implementation of HDMI Spec v1.4a Section 5.4: Encoding, Section 5.2.2.1: Video Guard Band, Section 5.2.3.3: Data Island Guard Bands.
// By Sameer Puri https://github.com/sameer

module tmds_channel
#(
    // TMDS Channel number.
    // There are only 3 possible channel numbers in HDMI 1.4a: 0, 1, 2.
    parameter int CN = 0,
    // _169 MSXimus: 1 = registra q_m/N1q_m07/N0q_m07 para partir el cono
    // combinacional del 8b/10b. Ver el bloque grande de mas abajo. Por defecto 0
    // => netlist IDENTICO al original de hdl-util (este fichero es de terceros y
    // lo comparte la linea del V9958 clasico, que esta publicada).
    parameter bit PIPELINE_QM = 1'b0
)
(
    input logic clk_pixel,
    input logic [7:0] video_data,
    input logic [3:0] data_island_data,
    input logic [1:0] control_data,
    input logic [2:0] mode,  // Mode select (0 = control, 1 = video, 2 = video guard, 3 = island, 4 = island guard)
    output logic [9:0] tmds = 10'b1101010100
);

// See Section 5.4.4.1
// Below is a direct implementation of Figure 5-7, using the same variable names.

logic signed [4:0] acc = 5'sd0;

logic [8:0] q_m;
logic [9:0] q_out;
logic [9:0] video_coding;
assign video_coding = q_out;

logic [3:0] N1D;
logic signed [4:0] N1q_m07;
logic signed [4:0] N0q_m07;
always_comb
begin
    N1D = video_data[0] + video_data[1] + video_data[2] + video_data[3] + video_data[4] + video_data[5] + video_data[6] + video_data[7];
    case(q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7])
        4'b0000: N1q_m07 = 5'sd0;
        4'b0001: N1q_m07 = 5'sd1;
        4'b0010: N1q_m07 = 5'sd2;
        4'b0011: N1q_m07 = 5'sd3;
        4'b0100: N1q_m07 = 5'sd4;
        4'b0101: N1q_m07 = 5'sd5;
        4'b0110: N1q_m07 = 5'sd6;
        4'b0111: N1q_m07 = 5'sd7;
        4'b1000: N1q_m07 = 5'sd8;
        default: N1q_m07 = 5'sd0;
    endcase
    N0q_m07 = 5'sd8 - N1q_m07;
end

logic signed [4:0] acc_add;

integer i;

// _169: las senales EFECTIVAS que entran en la parte dependiente de acc. Con
// PIPELINE_QM=0 son las combinacionales de siempre (netlist identico); con 1 son
// su version registrada. Declaradas AQUI, antes de usarse.
logic [8:0]        q_m_eff;
logic signed [4:0] N1q_m07_eff;
logic signed [4:0] N0q_m07_eff;

// ---- PARTE 1: feed-forward. Solo depende de video_data. -------------------
always_comb
begin
    if (N1D > 4'd4 || (N1D == 4'd4 && video_data[0] == 1'd0))
    begin
        q_m[0] = video_data[0];
        for(i = 0; i < 7; i++)
            q_m[i + 1] = q_m[i] ~^ video_data[i + 1];
        q_m[8] = 1'b0;
    end
    else
    begin
        q_m[0] = video_data[0];
        for(i = 0; i < 7; i++)
            q_m[i + 1] = q_m[i] ^ video_data[i + 1];
        q_m[8] = 1'b1;
    end
end

// ---- PARTE 2: aqui empieza el lazo de realimentacion (acc). ----------------
always_comb
begin
    if (acc == 5'sd0 || (N1q_m07_eff == N0q_m07_eff))
    begin
        if (q_m_eff[8])
        begin
            acc_add = N1q_m07_eff - N0q_m07_eff;
            q_out = {~q_m_eff[8], q_m_eff[8], q_m_eff[7:0]};
        end
        else
        begin
            acc_add = N0q_m07_eff - N1q_m07_eff;
            q_out = {~q_m_eff[8], q_m_eff[8], ~q_m_eff[7:0]};
        end
    end
    else
    begin
        if ((acc > 5'sd0 && N1q_m07_eff > N0q_m07_eff) || (acc < 5'sd0 && N1q_m07_eff < N0q_m07_eff))
        begin
            q_out = {1'b1, q_m_eff[8], ~q_m_eff[7:0]};
            acc_add = (N0q_m07_eff - N1q_m07_eff) + (q_m_eff[8] ? 5'sd2 : 5'sd0);
        end
        else
        begin
            q_out = {1'b0, q_m_eff[8], q_m_eff[7:0]};
            acc_add = (N1q_m07_eff - N0q_m07_eff) - (~q_m_eff[8] ? 5'sd2 : 5'sd0);
        end
    end
end

// ============================================================================
// _169 PIPELINE_QM — parte el cono combinacional del codificador 8b/10b.
//
// EL PROBLEMA (medido, no supuesto): el camino video_data -> acc es el peor
// SETUP del diseño entero. 15 niveles de LUT, 13,38 ns contra 13,0 de
// presupuesto (clk_hdmi = 74,25 MHz, msx_console60k.sdc:32). De esos, 7,4 ns son
// CELDA: aunque el rutado fuera perfecto NO cerraria. No es congestion ni mala
// suerte de placement — sale en 1 de cada 3 dados tanto al 91% de CLS como al
// 67%. Es el algoritmo de la Figura 5-7 tal cual: popcount de video_data ->
// cadena XOR/XNOR de 8 etapas (irreducible) -> popcount de q_m -> comparadores
// -> aritmetica con signo de acc_add.
//
// EL CORTE. Los pasos hasta N1q_m07/N0q_m07 son PURAMENTE feed-forward: solo
// dependen de video_data. El lazo de realimentacion de verdad (acc) empieza
// despues. Registrando ahi se parte en ~7,1 / ~6,3 ns, los dos holgados.
//
// ⚠️ POR QUE NO AÑADE NI UN PIXEL DE LATENCIA — esto es lo que desbloqueo la
// decision. NO se añade una etapa: se MUEVE la que ya existe. hdmi.sv:396 es
// `video_data_q <= video_data;`, un FF->FF sin nada de logica en medio. Al
// alimentar este modulo con video_data CRUDO y registrar aqui q_m/N1q_m07,
// queda q_m_q[t] = f(video_data[t-1]), que es EXACTAMENTE lo que hoy vale q_m
// combinacional (= f(video_data_q[t]) = f(video_data[t-1])). Mismo valor, mismo
// ciclo, mismo numero de registros de rgb a tmds.
// Por eso la leccion _134/_135 (pantalla negra por desplazamiento sin
// compensar) NO aplica aqui. Y es DEMOSTRABLE en simulacion, gratis:
// tools/v9968_sim/tb_tmds_equiv.sv compara las dos variantes ciclo a ciclo.
//
// control_data / data_island_data / mode siguen llegando por el camino _q de
// hdmi.sv, asi que en el mux de salida todo queda alineado.
//
// ⚠️ VA PARAMETRIZADO Y POR DEFECTO A 0 A PROPOSITO. Este fichero es de terceros
// (hdl-util, MIT) y NUNCA se habia tocado: un solo commit en toda su historia.
// Lo comparten TRES back-ends, incluida la linea del V9958 clasico que YA ESTA
// PUBLICADA (msx2hdmi.sv:502 y :529, 6 instancias). Con PIPELINE_QM=0 el netlist
// de esa linea es IDENTICO BIT A BIT y no hay nada que re-validar. Se quitara el
// parametro cuando la clasica este re-probada en placa.
// ============================================================================
generate
if (PIPELINE_QM) begin : g_pipe_qm
    (* syn_preserve = 1 *) logic [8:0]        q_m_q       = 9'h100;
    (* syn_preserve = 1 *) logic signed [4:0] N1q_m07_q   = 5'sd0;
    (* syn_preserve = 1 *) logic signed [4:0] N0q_m07_q   = 5'sd8;
    always_ff @(posedge clk_pixel) begin
        q_m_q     <= q_m;
        N1q_m07_q <= N1q_m07;
        N0q_m07_q <= N0q_m07;
    end
    assign q_m_eff     = q_m_q;
    assign N1q_m07_eff = N1q_m07_q;
    assign N0q_m07_eff = N0q_m07_q;
end
else begin : g_comb_qm
    assign q_m_eff     = q_m;
    assign N1q_m07_eff = N1q_m07;
    assign N0q_m07_eff = N0q_m07;
end
endgenerate

always_ff @(posedge clk_pixel) acc <= mode != 3'd1 ? 5'sd0 : acc + acc_add;

// See Section 5.4.2
logic [9:0] control_coding;
always_comb
begin
    unique case(control_data)
        2'b00: control_coding = 10'b1101010100;
        2'b01: control_coding = 10'b0010101011;
        2'b10: control_coding = 10'b0101010100;
        2'b11: control_coding = 10'b1010101011;
    endcase
end

// See Section 5.4.3
logic [9:0] terc4_coding;
always_comb
begin
    unique case(data_island_data)
        4'b0000 : terc4_coding = 10'b1010011100;
        4'b0001 : terc4_coding = 10'b1001100011;
        4'b0010 : terc4_coding = 10'b1011100100;
        4'b0011 : terc4_coding = 10'b1011100010;
        4'b0100 : terc4_coding = 10'b0101110001;
        4'b0101 : terc4_coding = 10'b0100011110;
        4'b0110 : terc4_coding = 10'b0110001110;
        4'b0111 : terc4_coding = 10'b0100111100;
        4'b1000 : terc4_coding = 10'b1011001100;
        4'b1001 : terc4_coding = 10'b0100111001;
        4'b1010 : terc4_coding = 10'b0110011100;
        4'b1011 : terc4_coding = 10'b1011000110;
        4'b1100 : terc4_coding = 10'b1010001110;
        4'b1101 : terc4_coding = 10'b1001110001;
        4'b1110 : terc4_coding = 10'b0101100011;
        4'b1111 : terc4_coding = 10'b1011000011;
    endcase
end

// See Section 5.2.2.1
logic [9:0] video_guard_band;
generate
    if (CN == 0 || CN == 2)
        assign video_guard_band = 10'b1011001100;
    else
        assign video_guard_band = 10'b0100110011;
endgenerate

// See Section 5.2.3.3
logic [9:0] data_guard_band;
generate
    if (CN == 1 || CN == 2)
        assign data_guard_band = 10'b0100110011;
    else
        assign data_guard_band = control_data == 2'b00 ? 10'b1010001110
            : control_data == 2'b01 ? 10'b1001110001
            : control_data == 2'b10 ? 10'b0101100011
            : 10'b1011000011;
endgenerate

// Apply selected mode.
always @(posedge clk_pixel)
begin
    case (mode)
        3'd0: tmds <= control_coding;
        3'd1: tmds <= video_coding;
        3'd2: tmds <= video_guard_band;
        3'd3: tmds <= terc4_coding;
        3'd4: tmds <= data_guard_band;
    endcase
end

endmodule
