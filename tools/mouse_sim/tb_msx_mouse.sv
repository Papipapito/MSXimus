// ============================================================================
//  tb_msx_mouse — banco del raton MSX emulado (fpga/src/msx_mouse.v)
//
//  Imita lo que hace de verdad la rutina del MSX: mover el pin 8 y leer el
//  puerto A del PSG entre movimiento y movimiento. Contrasta contra el
//  protocolo de openMSX (src/input/Mouse.cc), que es de donde salio el
//  diseño.
//
//  Lo que vigila, en orden de lo que mas duele si se rompe:
//   1. Que los cuatro nibbles reconstruyan el delta, NEGADO (el error de
//      signo es 50/50 y cuesta un viaje a la placa).
//   2. Que el ciclo ALTERNO devuelva CEROS (si no, el software cree que hay
//      un trackball).
//   3. Que el TIMEOUT resincronice: es donde fallan casi todas las
//      implementaciones, y una FSM desincronizada hace que el puntero "gire"
//      solo.
//   4. Que con sensibilidad alta los movimientos LENTOS no se pierdan (el
//      resto se conserva en el acumulador).
//   5. Botones activos a nivel bajo.
// ============================================================================
`timescale 1ns/1ps

module tb_msx_mouse;

    localparam real CLK_NS = 18.518;   // 54 MHz

    reg clk = 0;
    always #(CLK_NS/2.0) clk = ~clk;

    reg               rst_n = 0;
    reg               rep_pulse = 0;
    reg signed  [7:0] dx = 0, dy = 0;
    reg         [1:0] btn = 2'b00;
    reg         [2:0] sens = 3'd0;
    reg               strobe = 1'b0;   // en reposo BAJO: cada ronda empieza con un flanco de subida
    wire        [7:0] data;

    msx_mouse dut (
        .clk(clk), .rst_n(rst_n),
        .rep_pulse(rep_pulse), .dx(dx), .dy(dy), .btn(btn),
        .sens(sens), .strobe(strobe), .data(data), .dbg_phase()
    );

    integer errores = 0;

    task fallo(input string que);
        begin
            $display("  FALLO: %0s", que);
            errores = errores + 1;
        end
    endtask

    // un informe del raton USB
    task informe(input signed [7:0] mx, input signed [7:0] my);
        begin
            @(posedge clk);
            dx <= mx; dy <= my; rep_pulse <= 1'b1;
            @(posedge clk);
            rep_pulse <= 1'b0; dx <= 0; dy <= 0;
            @(posedge clk);
        end
    endtask

    // mover el pin 8 y esperar como haria el Z80 (varios us)
    task pin8(input v);
        begin
            strobe <= v;
            repeat (60) @(posedge clk);     // ~1,1 us
        end
    endtask

    // Una ronda de sondeo completa: devuelve los 4 nibbles leidos.
    // Secuencia calcada de la referencia: strobe 1,0,1,0 leyendo tras cada
    // cambio.
    task ronda(output [7:0] rx, output [7:0] ry, output [7:0] est);
        reg [3:0] n0, n1, n2, n3;
        begin
            pin8(1'b1); n0 = data[3:0]; est = data;
            pin8(1'b0); n1 = data[3:0];
            pin8(1'b1); n2 = data[3:0];
            pin8(1'b0); n3 = data[3:0];
            rx = {n0, n1};
            ry = {n2, n3};
        end
    endtask

    // dejar pasar el timeout (1,5 ms) sin tocar el pin 8
    task esperar_timeout;
        begin
            repeat (90000) @(posedge clk);   // 1,67 ms
        end
    endtask

    reg [7:0] rx, ry, est;
    reg signed [7:0] esperado;

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        // ---------------------------------------------------------------
        $display("== 1. delta basico: debe llegar NEGADO ==");
        esperar_timeout;
        informe(8'sd20, -8'sd10);
        ronda(rx, ry, est);
        esperado = -8'sd20;
        if (rx !== esperado[7:0]) fallo($sformatf("X: leido %0d, esperaba %0d (negado)", $signed(rx), $signed(esperado)));
        esperado = 8'sd10;
        if (ry !== esperado[7:0]) fallo($sformatf("Y: leido %0d, esperaba %0d (negado)", $signed(ry), $signed(esperado)));
        $display("   X=%0d Y=%0d (host 20,-10)", $signed(rx), $signed(ry));

        // ---------------------------------------------------------------
        $display("== 2. ciclo ALTERNO: tiene que dar CEROS ==");
        ronda(rx, ry, est);
        if (rx !== 8'h00 || ry !== 8'h00)
            fallo($sformatf("el ciclo alterno devolvio X=%0d Y=%0d en vez de 0", $signed(rx), $signed(ry)));

        // ---------------------------------------------------------------
        $display("== 3. sin movimiento: 0 en el ciclo principal ==");
        esperar_timeout;
        ronda(rx, ry, est);
        if (rx !== 8'h00 || ry !== 8'h00)
            fallo($sformatf("sin mover dio X=%0d Y=%0d", $signed(rx), $signed(ry)));

        // ---------------------------------------------------------------
        $display("== 4. TIMEOUT a media ronda: debe resincronizar ==");
        // dejamos la ronda a medias y esperamos el timeout; la siguiente
        // ronda completa tiene que salir bien igualmente
        esperar_timeout;
        informe(8'sd7, 8'sd3);
        pin8(1'b1);                 // arranca ronda (aqui se latchea Y CONSUME el delta,
        pin8(1'b0);                 //  igual que la referencia) ... y la abandonamos
        esperar_timeout;            // el timeout debe devolver la fase a YLOW2
        informe(-8'sd9, 8'sd4);     // movimiento NUEVO tras el corte
        ronda(rx, ry, est);
        esperado = 8'sd9;           // negado
        if (rx !== esperado[7:0])
            fallo($sformatf("tras timeout a media ronda X=%0d, esperaba %0d", $signed(rx), $signed(esperado)));
        else begin
            esperado = -8'sd4;
            if (ry !== esperado[7:0])
                fallo($sformatf("tras timeout a media ronda Y=%0d, esperaba %0d", $signed(ry), $signed(esperado)));
            else
                $display("   resincronizado bien: X=%0d Y=%0d", $signed(rx), $signed(ry));
        end

        // ---------------------------------------------------------------
        $display("== 5. sensibilidad 2: movimientos LENTOS no se pierden ==");
        sens = 3'd2;
        esperar_timeout;
        // ocho informes de 1: con division entera pura darian 0 siempre
        begin : lentos
            integer i;
            integer total;
            total = 0;
            for (i = 0; i < 8; i = i + 1) begin
                informe(8'sd1, 8'sd0);
                ronda(rx, ry, est);
                total = total + (-$signed(rx));   // deshacer la negacion
                ronda(rx, ry, est);               // ciclo alterno
            end
            // 8 pasos de 1 con sens=2 -> 8/4 = 2 unidades entregadas
            if (total != 2)
                fallo($sformatf("movimiento lento: entregado %0d, esperaba 2", total));
            else
                $display("   ocho pasos de 1 con sens=2 -> %0d unidades (correcto)", total);
        end
        sens = 3'd0;

        // ---------------------------------------------------------------
        $display("== 6. saturacion a +-127 ==");
        esperar_timeout;
        informe(8'sd127, 8'sd0);
        informe(8'sd127, 8'sd0);   // 254 acumulado
        ronda(rx, ry, est);
        esperado = -8'sd127;
        if (rx !== esperado[7:0])
            fallo($sformatf("saturacion: X=%0d, esperaba %0d", $signed(rx), $signed(esperado)));
        else
            $display("   254 acumulado -> entrega %0d (saturado)", $signed(rx));

        // ---------------------------------------------------------------
        $display("== 7. botones, activos a nivel BAJO ==");
        esperar_timeout;
        btn = 2'b01;                       // izquierdo
        ronda(rx, ry, est);
        if (est[4] !== 1'b0) fallo("boton izquierdo pulsado y el bit 4 no bajo");
        if (est[5] !== 1'b1) fallo("bit 5 bajo sin pulsar el derecho");
        btn = 2'b10;                       // derecho
        esperar_timeout;
        ronda(rx, ry, est);
        if (est[5] !== 1'b0) fallo("boton derecho pulsado y el bit 5 no bajo");
        if (est[4] !== 1'b1) fallo("bit 4 bajo sin pulsar el izquierdo");
        btn = 2'b00;
        esperar_timeout;
        ronda(rx, ry, est);
        if (est[5:4] !== 2'b11) fallo("sin botones y los bits 4/5 no estan altos");
        $display("   botones OK");

        // ---------------------------------------------------------------
        $display("");
        if (errores == 0) $display("VEREDICTO: OK — 7 pruebas, 0 errores");
        else              $display("VEREDICTO: %0d ERRORES", errores);
        $finish;
    end

    initial begin
        #200_000_000;
        $display("VEREDICTO: TIMEOUT del banco");
        $finish;
    end

endmodule
