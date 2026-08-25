// ============================================================================
//  tb_msx_s1990.v — banco del interfaz S1990 (turboR) del MSXimus
//
//  Lo que vigila, y por que cada cosa:
//   1. La FIRMA (registros 13/14/15 = 03/2F/8B). Si falla, el software no
//      reconoce la maquina y todo lo demas da igual.
//   2. El indice se escribe por E4h y se puede releer.
//   3. 🚨 El registro 6 dice **Z80** aunque acaben de pedirle R800. Es la
//      decision de diseno de la cabecera del modulo: no mentir.
//   4. El registro 6 SI se queda con el modo ROM (bit 6).
//   5. Registros no implementados -> 0xFF (no basura).
//   6. El contador AVANZA, y a la cadencia correcta (3,911 us +-1%).
//   7. Escribir en E6h lo pone a cero.
//   8. Fuera de E4h-E7h el modulo NO reclama el bus (si lo hiciera, pisaria a
//      otro dispositivo del mux del top).
//   9. En ciclo M1 no responde: un opcode fetch no es una lectura de E/S.
//
//  Comparaciones con !== a proposito: con `if (!cond)` una X pasa por buena y
//  el banco da VERDE con el RTL saboteado (ya paso en este proyecto).
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_msx_s1990;

    reg clk = 0;
    always #18.5 clk = ~clk;            // 27 MHz

    reg        reset_n = 0;
    reg        iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
    reg  [7:0] addr = 0, din = 0;
    wire [7:0] dout;
    wire       req, rom_mode;
    reg        pause_sw = 0;
    reg        turbo_on = 0;            // estado del turbo del MSXimus
    wire       turbo_set, turbo_val;

    msx_s1990 #(.CLK_HZ(27_000_000)) dut (
        .clk(clk), .reset_n(reset_n),
        .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
        .addr(addr), .din(din), .dout(dout), .req(req),
        .pause_sw(pause_sw), .rom_mode(rom_mode),
        .turbo_on(turbo_on), .turbo_set(turbo_set), .turbo_val(turbo_val)
    );

    // Un pulso de turbo_set es de UN ciclo: si el banco mira despues, se lo
    // pierde. Se engancha aqui igual que haria el top.
    reg turbo_pedido = 1'b0, turbo_pedido_val = 1'b0;
    always @(posedge clk) if (turbo_set) begin
        turbo_pedido     <= 1'b1;
        turbo_pedido_val <= turbo_val;
    end

    integer fallos = 0;
    task chk(input cond, input [511:0] txt);
    begin
        if (cond !== 1'b1) begin
            $display("  FALLO: %0s", txt);
            fallos = fallos + 1;
        end
    end
    endtask

    // OJO: el modulo REGISTRA el bus por dentro (leccion _95), asi que el efecto
    // de una escritura llega un ciclo mas tarde. Sin este margen el banco
    // comprobaba antes de que el dato hubiera entrado, y daba un fallo FALSO.
    task io_wr(input [7:0] a, input [7:0] d);
    begin
        @(posedge clk); addr <= a; din <= d; iorq_n <= 0; wr_n <= 0;
        @(posedge clk); iorq_n <= 1; wr_n <= 1;
        repeat (3) @(posedge clk);
    end
    endtask

    task io_rd(input [7:0] a, output [7:0] d);
    begin
        @(posedge clk); addr <= a; iorq_n <= 0; rd_n <= 0;
        @(posedge clk); #1; d = dout;
        iorq_n <= 1; rd_n <= 1;
        @(posedge clk);
    end
    endtask

    task reg_rd(input [3:0] idx, output [7:0] d);
    begin
        io_wr(8'hE4, {4'd0, idx});
        io_rd(8'hE5, d);
    end
    endtask

    reg [7:0] d;
    reg [15:0] c0, c1;
    integer i;
    real ticks_medidos, us_por_tick;

    // ---- vigilante de la carrera puesta-a-cero vs tick ---------------------
    // Desde FUERA no se puede distinguir "ha hecho tick despues de escribir" de
    // "el tick ha ganado la carrera": entre la escritura y la relectura pasan
    // ciclos y el contador puede subir con todo el derecho. Intentarlo asi daba
    // un FALLO falso con el RTL bueno. Se mira por dentro.
    //
    // En este flanco `dut.contador` todavia tiene el valor ANTERIOR (las
    // asignaciones no bloqueantes no se han aplicado), asi que con la marca
    // retrasada un ciclo se esta viendo justo el resultado de la carrera.
    integer carreras = 0;
    reg     carrera_d = 1'b0;
    always @(posedge clk) begin
        if (carrera_d && dut.contador !== 16'd0) begin
            $display("  FALLO: el tick GANA a la puesta a cero (contador=%0d)", dut.contador);
            fallos = fallos + 1;
        end
        carrera_d <= reset_n && dut.escribir && (dut.r_addr[1:0] == 2'd2) && dut.tick;
        if (reset_n && dut.escribir && (dut.r_addr[1:0] == 2'd2) && dut.tick)
            carreras = carreras + 1;
    end

    initial begin
        $dumpfile("/tmp/tb_msx_s1990.vcd");
        $dumpvars(0, tb_msx_s1990);
        repeat (5) @(posedge clk);
        reset_n = 1;
        repeat (5) @(posedge clk);

        // ---- 1. la FIRMA -------------------------------------------------
        reg_rd(4'd13, d); $display("[1] reg13 = %02X (esperado 03)", d);
        chk(d === 8'h03, "reg 13 no es 0x03: el software NO reconocera la maquina");
        reg_rd(4'd14, d); $display("[1] reg14 = %02X (esperado 2F)", d);
        chk(d === 8'h2F, "reg 14 no es 0x2F");
        reg_rd(4'd15, d); $display("[1] reg15 = %02X (esperado 8B)", d);
        chk(d === 8'h8B, "reg 15 no es 0x8B");

        // ---- 2. el indice se relee por E4h --------------------------------
        io_wr(8'hE4, 8'h0D);
        io_rd(8'hE4, d);
        chk(d === 8'h0D, "E4h no devuelve el indice que se acaba de escribir");

        // ---- 3. el bit de CPU SIGUE al turbo, en los dos sentidos ---------
        io_wr(8'hE4, 8'd6);

        turbo_on = 1'b0;                 // sin turbo -> tiene que decir Z80
        io_rd(8'hE5, d);
        $display("[3a] turbo OFF -> reg6 = %02X (bit5 debe ser 1 = Z80)", d);
        chk(d[5] === 1'b1, "con el turbo apagado deberia decir Z80");

        turbo_on = 1'b1;                 // con turbo -> R800
        io_rd(8'hE5, d);
        $display("[3b] turbo ON  -> reg6 = %02X (bit5 debe ser 0 = R800)", d);
        chk(d[5] === 1'b0, "con el turbo puesto deberia decir R800");

        // ...y escribir tiene que PEDIR el cambio (es lo que hace CHGCPU)
        turbo_pedido = 1'b0;
        io_wr(8'hE5, 8'b0000_0000);      // bit5=0 -> quiero R800
        $display("[3c] pedir R800 -> set=%b val=%b", turbo_pedido, turbo_pedido_val);
        chk(turbo_pedido === 1'b1, "escribir el registro 6 no pide el cambio de CPU");
        chk(turbo_pedido_val === 1'b1, "pedir R800 deberia ENCENDER el turbo");

        turbo_pedido = 1'b0;
        io_wr(8'hE5, 8'b0010_0000);      // bit5=1 -> quiero Z80
        chk(turbo_pedido === 1'b1, "no pide el cambio al volver a Z80");
        chk(turbo_pedido_val === 1'b0, "pedir Z80 deberia APAGAR el turbo");

        // ---- 4. ...pero el modo ROM si se guarda --------------------------
        io_wr(8'hE4, 8'd6);
        io_wr(8'hE5, 8'b0000_0000);      // bit6 = 0 -> modo RAM
        chk(rom_mode === 1'b0, "el registro 6 no recoge el modo ROM");
        io_wr(8'hE5, 8'b0100_0000);      // bit6 = 1 -> modo ROM
        chk(rom_mode === 1'b1, "el registro 6 no vuelve a modo ROM");

        // ---- 5. registro no implementado ----------------------------------
        reg_rd(4'd1, d);
        chk(d === 8'hFF, "un registro no implementado deberia leer 0xFF");

        // ---- 6. el contador avanza, y a su ritmo --------------------------
        io_rd(8'hE6, d); c0[7:0] = d;
        io_rd(8'hE7, d); c0[15:8] = d;
        #500_000;                        // 500 us
        io_rd(8'hE6, d); c1[7:0] = d;
        io_rd(8'hE7, d); c1[15:8] = d;
        ticks_medidos = c1 - c0;
        us_por_tick   = 500.0 / ticks_medidos;
        $display("[6] %0d ticks en 500 us -> %.4f us/tick (esperado 3.911)",
                 c1 - c0, us_por_tick);
        chk(c1 > c0, "el contador no avanza");
        chk((us_por_tick > 3.872) && (us_por_tick < 3.950),
            "la cadencia del contador se sale del 1%");

        // ---- 7. E6h lo pone a cero ----------------------------------------
        io_wr(8'hE6, 8'h00);
        io_rd(8'hE6, d); c1[7:0] = d;
        io_rd(8'hE7, d); c1[15:8] = d;
        $display("[7] tras poner a cero = %0d", c1);
        chk(c1 < 16'd8, "escribir en E6h no pone el contador a cero");

        // ---- 7b. la carrera se vigila POR DENTRO (ver el monitor de abajo) --
        // Se dejan correr escrituras a E6h a distintas fases para provocarla.
        // El tick cae cada ~105,6 ciclos. Con un desplazamiento FIJO el bucle
        // se acompasa con el y no coincide JAMAS (paso: con `i % 11` salieron
        // cero carreras). Barriendo 0..129 se cubre el periodo entero.
        for (i = 0; i < 130; i = i + 1) begin
            repeat (i) @(posedge clk);
            io_wr(8'hE6, 8'h00);
        end
        $display("[7b] carreras provocadas: %0d", carreras);
        chk(carreras > 0, "no se ha provocado NI UNA carrera: la prueba no vale");

        // ---- 8. fuera de E4h-E7h no somos nadie ---------------------------
        @(posedge clk); addr <= 8'hE8; iorq_n <= 0; rd_n <= 0;
        @(posedge clk); #1;
        chk(req !== 1'b1, "reclama E8h, que NO es suyo: pisaria a otro dispositivo");
        addr <= 8'hE3;
        @(posedge clk); #1;
        chk(req !== 1'b1, "reclama E3h, que tampoco es suyo");
        iorq_n <= 1; rd_n <= 1;

        // ---- 9. un ciclo M1 no es una lectura de E/S ----------------------
        @(posedge clk); addr <= 8'hE4; iorq_n <= 0; rd_n <= 0; m1_n <= 0;
        @(posedge clk); #1;
        chk(req !== 1'b1, "responde en ciclo M1: eso es un opcode fetch, no E/S");
        iorq_n <= 1; rd_n <= 1; m1_n <= 1;

        $display("");
        if (fallos == 0) $display("=== VERDE: %0d fallos ===", fallos);
        else             $display("=== ROJO: %0d fallos ===", fallos);
        $finish;
    end

    initial begin
        #20_000_000;
        $display("=== ROJO: el banco se ha colgado ===");
        $finish;
    end

endmodule

`default_nettype wire
