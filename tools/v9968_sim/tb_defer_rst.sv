// ============================================================================
// tb_defer_rst.sv — prueba de IDENTIDAD DE FASE del diferidor _136 (bug #14).
// Leccion _134/_135: diferir el reset sin compensar movio el anclaje cx/cy
// ~27px y el conversor 720p quedo en NEGRO en 3 dados. El _136 re-ancla con
// reset_cx = 1 + ciclos diferidos. Este TB modela DOS contadores hdmi.sv
// (VIC4, 1650x750, START 0/720):
//   A = reset crudo por wire (el diseno de siempre, el que FUNCIONA)
//   B = diferidor _136 + reset_cx compensado
// y exige:
//   P1: fuera de la ventana transitoria [yank, release+2] cxB/cyB IDENTICOS
//       a cxA/cyA ciclo a ciclo (el conversor no puede notar nada)
//   P2: el reset de B NUNCA se emite con cx en la zona de peligro de los
//       data islands [1280,1618)
//   P3: el diferidor se ENGANCHA al menos una vez (si no, el TB no prueba)
// frame_tgl va por contador de ciclos clk_86 (2736x524) con relojes al
// ratio real ~121:140 — el pelin de deriva del ps-grid BARRE el punto de
// aterrizaje por muchas fases = mas cobertura, no menos.
// ============================================================================
`timescale 1ns/1ps
module tb_defer_rst;

    logic clk_pixel = 0;  always #6.734  clk_pixel = ~clk_pixel;  // 74.25M
    logic clk_86    = 0;  always #5.8201 clk_86    = ~clk_86;     // 85.909M

    // frame_tgl: toggle cada frame V9968 NTSC = 2736*524 ciclos clk_86
    localparam int FRAME_86 = 2736 * 524;
    int f86 = 0;
    logic frame_tgl = 0;
    always @(posedge clk_86) begin
        f86 <= f86 + 1;
        if (f86 == FRAME_86 - 1) begin
            f86 <= 0;
            frame_tgl <= ~frame_tgl;
        end
    end

    // sincronizador comun (identico al puente)
    logic [2:0] tgl_x = 3'b000;
    always @(posedge clk_pixel) tgl_x <= {tgl_x[1:0], frame_tgl};
    wire hdmi_rst_raw = tgl_x[2] ^ tgl_x[1];

    // ---------------- contador hdmi.sv (VIC4) ----------------
    localparam int FW = 1650, FH = 750;

    // ---------------- A: diseno viejo (reset crudo, wire) ----------------
    logic [10:0] cxA = 0; logic [9:0] cyA = 0;
    always @(posedge clk_pixel) begin
        if (hdmi_rst_raw) begin
            cxA <= 11'd0; cyA <= 10'd720;
        end
        else begin
            cxA <= (cxA == FW-1) ? 11'd0 : cxA + 11'd1;
            cyA <= (cxA == FW-1) ? ((cyA == FH-1) ? 10'd0 : cyA + 10'd1) : cyA;
        end
    end

    // ---------------- B: diferidor _136 ----------------
    logic rst_pend = 0, hdmi_rstB = 0;
    logic [11:0] rst_dly = 0, rst_cx = 0;
    logic [10:0] cxB = 0; logic [9:0] cyB = 0;
    wire [11:0] cxBw = {1'b0, cxB};
    wire in_defer_win = (cxBw >= 12'd1278 && cxBw < 12'd1620);
    wire in_danger    = (cxBw >= 12'd1280 && cxBw < 12'd1618);
    int defers = 0, tears = 0;
    always @(posedge clk_pixel) begin
        hdmi_rstB <= 1'b0;
        if (hdmi_rst_raw) begin
            rst_dly <= 12'd1;
            if (in_defer_win) begin
                rst_pend <= 1'b1;
                defers   <= defers + 1;
            end
            else begin
                hdmi_rstB <= 1'b1;
                rst_cx    <= 12'd1;
            end
        end
        else if (rst_pend) begin
            rst_dly <= rst_dly + 12'd1;
            if (!in_defer_win) begin
                rst_pend  <= 1'b0;
                hdmi_rstB <= 1'b1;
                rst_cx    <= rst_dly + 12'd1;
            end
        end
        if (hdmi_rstB && in_danger) tears <= tears + 1;
    end
    always @(posedge clk_pixel) begin
        if (hdmi_rstB) begin
            cxB <= rst_cx[10:0]; cyB <= 10'd720;
        end
        else begin
            cxB <= (cxB == FW-1) ? 11'd0 : cxB + 11'd1;
            cyB <= (cxB == FW-1) ? ((cyB == FH-1) ? 10'd0 : cyB + 10'd1) : cyB;
        end
    end

    // ---------------- propiedades ----------------
    // ventana transitoria permitida: desde el yank crudo hasta 2 ciclos
    // tras la emision de B (holgura de registro)
    int grace = 0;
    always @(posedge clk_pixel) begin
        if (hdmi_rst_raw)      grace <= 500;   // maximo teorico ~345+margen
        else if (hdmi_rstB)    grace <= 2;
        else if (grace != 0)   grace <= grace - 1;
    end

    int errsP1 = 0;
    always @(posedge clk_pixel) begin
        if (grace == 0 && !hdmi_rst_raw && !rst_pend) begin
            if (cxA !== cxB || cyA !== cyB) begin
                if (errsP1 < 10)
                    $display("FALLO P1 t=%0t cxA=%0d cyA=%0d cxB=%0d cyB=%0d",
                             $time, cxA, cyA, cxB, cyB);
                errsP1 <= errsP1 + 1;
            end
        end
    end

    initial begin
        // 20 frames ~ 24.8M ciclos de pixel
        repeat (20) @(posedge frame_tgl or negedge frame_tgl);
        repeat (1000) @(posedge clk_pixel);
        $display("RESULTADO: defers=%0d tears=%0d errsP1=%0d", defers, tears, errsP1);
        if (tears == 0 && errsP1 == 0 && defers > 0)
            $display("*** DEFER_RST: FASE IDENTICA + ISLA A SALVO — TODO OK ***");
        else if (defers == 0)
            $display("*** DEFER_RST: OJO — el diferidor nunca engancho (aterrizaje fuera de ventana?) ***");
        else
            $display("*** DEFER_RST: %0d FALLOS ***", tears + errsP1);
        $finish;
    end

endmodule
