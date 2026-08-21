// ============================================================================
//  tb_dbguart_trig — banco del modo POR EVENTO del dbg_uart (V3.1b).
//
//  Lo que vigila, y por que:
//   1. Un pulso de trig = UNA linea, con el valor de cnt_g correcto.
//   2. UN TRIG QUE LLEGA MIENTRAS SE TRANSMITE NO SE PIERDE. Una linea dura
//      ~5,7 ms a 115200 baud y las escrituras de sector llegan cada ~19 ms,
//      pero se apelotonan: si el trig que cae dentro de una transmision se
//      tira, la traza pierde justo los eventos rapidos, que son los que se
//      quieren cazar. Es el mismo fallo de instrumentacion que ya costo una
//      ronda entera (contadores a 0 sin testigo de vida).
//   3. Sin trig sigue habiendo LATIDO cada PERIOD_MS. No es adorno: si el
//      temporizador se apaga, PERIOD_MS queda como logica muerta, la sintesis
//      lo poda, y como PERIOD_MS es lo que perturban los DADOS de la campana,
//      los cuatro dados salen con el MISMO bitstream (medido: los .fs solo
//      diferian en la hora del comentario). Ademas dice que el enlace respira
//      cuando no se escribe nada.
//
//  ⚠️ LOS TIEMPOS IMPORTAN: una linea tarda 5,7 ms a 115200 baud. La primera
//  version de este banco esperaba 2 ms para comprobar "no se emite nada" y
//  daba verde SIEMPRE, porque en 2 ms la linea ni ha terminado de salir. Con
//  PERIOD_MS=50 las pruebas 1 y 2 caben enteras antes del primer latido.
// ============================================================================
`timescale 1ns/1ps
module tb_dbguart_trig;
    reg clk = 0;
    always #9.26 clk = ~clk;                    // ~54 MHz
    reg  rst_n = 0;
    reg  trig  = 0;
    reg [31:0] g = 32'h1234_5678;
    wire tx;

    dbg_uart #(.CLK_HZ(53_996_000), .BAUD(115_200), .PERIOD_MS(50), .TRIG_MODE(1)) dut (
        .clk(clk), .rst_n(rst_n), .trig(trig),
        .cnt_a(32'd0), .cnt_b(32'd0), .cnt_c(32'd0), .cnt_d(32'd0),
        .cnt_e(32'd0), .cnt_f(32'd0), .cnt_g(g), .tx(tx)
    );

    localparam real BIT_NS = 1e9 / 115200.0;
    integer lineas = 0, errores = 0, n = 0, b, latidos = 0;
    reg [7:0] ch, line [0:79];
    reg [8*9:1] ultimo;

    task pulso; begin @(posedge clk); trig <= 1; @(posedge clk); trig <= 0; end endtask

    // receptor
    initial begin
        @(posedge rst_n);
        forever begin
            @(negedge tx);
            #(BIT_NS * 1.5);
            ch = 0;
            for (b = 0; b < 8; b = b + 1) begin ch[b] = tx; #(BIT_NS); end
            line[n] = ch; n = n + 1;
            if (ch == 8'h0A) begin
                lineas = lineas + 1;
                $write("  linea %0d (%0d chars): ", lineas, n);
                for (b = 0; b < n; b = b + 1) if (line[b] >= 32) $write("%c", line[b]);
                $write("\n");
                if (n != 66) begin
                    $display("  FALLO: la linea mide %0d, esperaba 66", n);
                    errores = errores + 1;
                end else begin
                    // cnt_g = ultima palabra, chars 56..63
                    ultimo = {line[56],line[57],line[58],line[59],
                              line[60],line[61],line[62],line[63]};
                    if (ultimo !== "12345678") begin
                        $display("  FALLO: cnt_g salio distinto de 12345678");
                        errores = errores + 1;
                    end
                end
                n = 0;
            end
        end
    end

    initial begin
        repeat (20) @(posedge clk);
        rst_n = 1;

        $display("== 1. un trig = una linea ==");
        pulso;
        #7_000_000;                              // una linea dura ~5,7 ms
        if (lineas != 1) begin
            $display("  FALLO: %0d lineas, esperaba 1", lineas); errores = errores + 1;
        end

        $display("== 2. un trig DURANTE la transmision no se pierde ==");
        pulso;                                   // arranca la 2a linea
        #500_000;                                // 0,5 ms: en plena transmision
        pulso;                                   // este tiene que quedar pendiente
        #14_000_000;                             // sitio para las dos
        if (lineas != 3) begin
            $display("  FALLO: %0d lineas en total, esperaba 3 (el trig de dentro se perdio)",
                     lineas);
            errores = errores + 1;
        end else $display("   el trig pendiente sobrevivio");

        $display("== 3. LATIDO: sin ningun trig sigue emitiendo ==");
        // van ~21 ms; PERIOD_MS=50 => el latido aun no ha entrado. Esperar a
        // que entre y que de tiempo a SALIR una linea entera (5,7 ms).
        latidos = lineas;
        #90_000_000;                             // 90 ms sin tocar trig
        if (lineas <= latidos) begin
            $display("  FALLO: 0 latidos en 90 ms. El temporizador esta muerto y");
            $display("         los dados de la campana dejan de perturbar nada.");
            errores = errores + 1;
        end else $display("   %0d latido(s), el temporizador sigue vivo", lineas - latidos);

        $display("");
        if (errores == 0) $display("*** TB DBG_UART TRIG: OK (3 pruebas) ***");
        else              $display("*** TB DBG_UART TRIG: %0d FALLOS ***", errores);
        $finish;
    end

    initial begin #400_000_000; $display("TIMEOUT"); $finish; end
endmodule
