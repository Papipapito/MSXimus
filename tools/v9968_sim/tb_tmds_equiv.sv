// ============================================================================
// tb_tmds_equiv.sv — _169: ¿es BIT-EXACTO partir el cono del codificador TMDS?
//
// QUE SE PRUEBA. tmds_channel.sv (hdl-util, MIT) tiene el peor camino de SETUP
// del diseño: 15 niveles de LUT, 13,38 ns contra 13,0 de presupuesto, de los
// cuales 7,4 son CELDA — aunque el rutado fuera perfecto no cerraria. El
// parametro PIPELINE_QM registra q_m/N1q_m07/N0q_m07 y lo parte en ~7,1/~6,3.
//
// LA AFIRMACION A VERIFICAR, que es la que desbloquea todo: el corte NO AÑADE
// LATENCIA, porque no se AÑADE una etapa sino que se MUEVE la que ya existe.
// Hoy hdmi.sv:396 hace `video_data_q <= video_data;` (un FF->FF sin logica) y
// alimenta al canal con video_data_q. Con el corte, el canal se alimenta de
// video_data CRUDO y registra despues del popcount+XOR:
//     ref[t] : q_m      = f(video_data_q[t]) = f(video_data[t-1])
//     new[t] : q_m_q    = f(video_data[t-1])          <-- el MISMO valor
// Mismo valor, mismo ciclo, mismo numero de registros de rgb a tmds. Si eso es
// cierto, la leccion _134/_135 (pantalla negra por desplazamiento) NO aplica.
//
// POR ESO ESTE BANCO EXISTE: es la unica forma de comprobarlo SIN gastar una
// campana. Si sale UNA sola discrepancia, el corte no es bit-exacto, todo el
// argumento se cae y no se sintetiza nada.
//
// EL MONTAJE, calcado de lo que hara hdmi.sv:
//   ref (PIPELINE_QM=0) <- video_data_q, control_data_q, island_q, mode_q
//   new (PIPELINE_QM=1) <- video_data CRUDO, y el resto por el camino _q
// Se comparan `tmds` y `acc` CICLO A CICLO, incluido el ciclo 0.
//
// TOLERANCIA CERO. No vale "casi igual".
//
// Uso:  bash run_tmds_equiv.sh        (WSL Ubuntu-24.04; iverilog solo esta ahi)
// ============================================================================
`timescale 1ns/1ps

module tb_tmds_equiv;

    localparam int CICLOS = 300000;   // el escéptico pedia >= 200.000

    logic clk_pixel = 0;
    always #5 clk_pixel = ~clk_pixel;

    // --- estimulo crudo ---
    logic [7:0] video_data       = 8'd0;
    logic [3:0] data_island_data = 4'd0;
    logic [1:0] control_data     = 2'd0;
    logic [2:0] mode             = 3'd0;

    // --- el camino _q que ya existe en hdmi.sv:391-400 ---
    logic [7:0] video_data_q       = 8'd0;
    logic [3:0] data_island_data_q = 4'd0;
    logic [1:0] control_data_q     = 2'd0;
    logic [2:0] mode_q             = 3'd0;
    always @(posedge clk_pixel) begin
        video_data_q       <= video_data;
        data_island_data_q <= data_island_data;
        control_data_q     <= control_data;
        mode_q             <= mode;
    end

    wire [9:0] tmds_ref, tmds_new;

    // REFERENCIA: exactamente como esta hoy en el arbol.
    tmds_channel #( .CN(0), .PIPELINE_QM(1'b0) ) u_ref (
        .clk_pixel(clk_pixel),
        .video_data(video_data_q),
        .data_island_data(data_island_data_q),
        .control_data(control_data_q),
        .mode(mode_q),
        .tmds(tmds_ref)
    );

    // NUEVA: video_data CRUDO (el registro se ha movido dentro), resto igual.
    tmds_channel #( .CN(0), .PIPELINE_QM(1'b1) ) u_new (
        .clk_pixel(clk_pixel),
        .video_data(video_data),
        .data_island_data(data_island_data_q),
        .control_data(control_data_q),
        .mode(mode_q),
        .tmds(tmds_new)
    );

    // --- comprobacion ciclo a ciclo ---
    integer fallos_tmds = 0;
    integer fallos_acc  = 0;
    integer comparados  = 0;
    integer primeros    = 0;

    always @(posedge clk_pixel) begin
        comparados = comparados + 1;
        if (tmds_ref !== tmds_new) begin
            fallos_tmds = fallos_tmds + 1;
            if (primeros < 10) begin
                primeros = primeros + 1;
                $display("  DIFF tmds  ciclo %0d: ref=%b new=%b  (video_data=%02x mode=%0d)",
                         comparados, tmds_ref, tmds_new, video_data_q, mode_q);
            end
        end
        // el acumulador de disparidad es el estado interno que de verdad importa:
        // si diverge, la senal TMDS deja de estar balanceada en DC aunque los
        // simbolos coincidan un rato.
        if (u_ref.acc !== u_new.acc) begin
            fallos_acc = fallos_acc + 1;
            if (primeros < 10) begin
                primeros = primeros + 1;
                $display("  DIFF acc   ciclo %0d: ref=%0d new=%0d",
                         comparados, u_ref.acc, u_new.acc);
            end
        end
    end

    // --- generador de estimulo con una secuencia de `mode` REALISTA ---
    // 0=control, 1=video, 2=video guard, 3=island, 4=island guard.
    // Se recorre un patron parecido al de una linea real: control largo,
    // preambulo, guard, video, y de vez en cuando una isla de datos.
    integer paso;
    integer fase;
    initial begin
        $display("=== tb_tmds_equiv: %0d ciclos, tolerancia CERO ===", CICLOS);
        fase = 0;
        for (paso = 0; paso < CICLOS; paso = paso + 1) begin
            @(negedge clk_pixel);
            video_data       = $random;
            data_island_data = $random;
            control_data     = $random;
            // ciclo de fases: ~70% video, con guardas e islas intercaladas
            case (fase % 10)
                0, 1:    mode = 3'd0;   // control
                2:       mode = 3'd2;   // video guard
                3,4,5,6: mode = 3'd1;   // video
                7:       mode = 3'd4;   // island guard
                8:       mode = 3'd3;   // island
                default: mode = 3'd1;   // video
            endcase
            if (paso % 37 == 0) fase = fase + 1;
        end

        // Un tramo final de video PURO y largo: es donde acc acumula de verdad
        // y donde una divergencia se haria visible.
        mode = 3'd1;
        for (paso = 0; paso < 20000; paso = paso + 1) begin
            @(negedge clk_pixel);
            video_data = $random;
        end

        #100;
        $display("");
        $display("  ciclos comparados : %0d", comparados);
        $display("  discrepancias tmds: %0d", fallos_tmds);
        $display("  discrepancias acc : %0d", fallos_acc);
        $display("");
        if (fallos_tmds == 0 && fallos_acc == 0)
            $display("*** BIT-EXACTO: PIPELINE_QM no cambia ni un simbolo ni el acumulador ***");
        else
            $display("*** NO ES BIT-EXACTO — el corte NO vale, no sintetizar nada ***");
        $finish;
    end

    initial begin
        #900000000;
        $display("TIMEOUT (comparados=%0d)", comparados);
        $finish;
    end

endmodule
