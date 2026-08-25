// ============================================================================
//  tb_sdc_bridge.v — banco de sdc_bridge.v
//
//  POR QUE EXISTE, Y TARDE
//  --------------------------------------------------------------------------
//  launcher_svc tiene banco con sabotajes desde el primer dia. sdc_bridge NO
//  tenia ninguno: todo lo que se creia saber de su comportamiento salia de
//  LEER el codigo. Y resulto estar mal en lo mas basico -- rstart se emitia
//  como pulso de un ciclo y sd_reader no lo veia nunca -- durante DOS DIAS,
//  mientras el "55AA" del peldano 2 hacia creer que las lecturas funcionaban
//  (era el sector que Nextor acababa de leer, que se cuela en el mismo buffer).
//
//  Lo que se vigila:
//   1. TOMAR pone hold y pide el arranque de la tarjeta
//   2. LEER monta el LBA COMPLETO en rsector -- los cuatro bytes, en orden
//   3. rstart se MANTIENE hasta que rbusy sube (no es un pulso)
//   4. sin mando, una peticion de sector se IGNORA (nunca tocar la SD del MSX)
//   5. SOLTAR quita el mando, apaga sd_init y resetea el lector
//   6. el perro guardian hace lo mismo si el S3 desaparece
//   7. DATOS devuelve el buffer desde el byte 0, en orden
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_sdc_bridge;

    reg clk = 0;
    always #18.5 clk = ~clk;             // 27 MHz

    reg         reset = 1;
    reg         strobe = 0, start = 0;
    reg  [7:0]  din = 0;
    wire [7:0]  dout;

    wire        rstart;
    wire [31:0] rsector;
    reg         rbusy = 0, rdone = 0;
    reg         outen = 0;
    reg  [8:0]  outaddr = 0;
    reg  [7:0]  outbyte = 0;
    reg  [3:0]  card_stat = 4'd1;
    wire        hold, sd_init, sd_rst;

    // Perro guardian corto: 2 ms de simulacion en vez de 8 s reales.
    sdc_bridge #(.CLK_HZ(27_000_000), .WDOG_MS(2)) dut (
        .clk(clk), .reset(reset),
        .strobe(strobe), .start(start), .din(din), .dout(dout),
        .rstart(rstart), .rsector(rsector), .rbusy(rbusy), .rdone(rdone),
        .outen(outen), .outaddr(outaddr), .outbyte(outbyte),
        .card_stat(card_stat),
        .hold(hold), .sd_init(sd_init), .sd_rst(sd_rst)
    );

    integer fallos = 0;
    // Comparacion ESTRICTA: una X es un fallo, no un aprobado. Ver
    // ref_verilog_chk_x_trampa: con `if (!cond)` el banco daba VERDE saboteado.
    task chk(input cond, input [255:0] txt);
    begin
        if (cond !== 1'b1) begin
            $display("  FALLO: %0s", txt);
            fallos = fallos + 1;
        end
    end
    endtask

    task spi_byte(input es_primero, input [7:0] b);
    begin
        @(posedge clk);
        start <= es_primero; din <= b; strobe <= 1'b1;
        @(posedge clk);
        strobe <= 1'b0; start <= 1'b0;
        repeat (12) @(posedge clk);
    end
    endtask

    integer i;
    integer ciclos_rstart;

    initial begin
        $dumpfile("/tmp/tb_sdc_bridge.vcd");
        $dumpvars(0, tb_sdc_bridge);

        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // ============ 4. sin mando, la peticion se IGNORA ==================
        // Va primero: tocar la SD mientras es del MSX es como se corrompen
        // sistemas de ficheros, asi que esto no puede fallar nunca.
        chk(hold === 1'b0, "arranca reteniendo, y no deberia");
        spi_byte(1, 8'd3);
        spi_byte(0, 8'h34); spi_byte(0, 8'h12); spi_byte(0, 8'h00); spi_byte(0, 8'h00);
        repeat (20) @(posedge clk);
        chk(rstart === 1'b0, "ha pedido un sector SIN tener el mando");

        // ============ 1. TOMAR ============================================
        spi_byte(1, 8'd1);
        repeat (5) @(posedge clk);
        chk(hold    === 1'b1, "TOMAR no ha puesto hold");
        chk(sd_init === 1'b1, "TOMAR no ha pedido encender la tarjeta");

        // ============ 2 y 3. LEER: LBA completo y rstart SOSTENIDO =========
        rbusy = 0;
        spi_byte(1, 8'd3);
        spi_byte(0, 8'h78); spi_byte(0, 8'h56); spi_byte(0, 8'h34); spi_byte(0, 8'h12);
        repeat (3) @(posedge clk);
        $display("[2] rsector = %08h (esperado 12345678)", rsector);
        chk(rsector === 32'h12345678, "el LBA no llega entero a rsector");

        // rstart tiene que seguir ALTO muchos ciclos: sd_reader solo lo mira
        // cuando su secuenciador esta libre, a su cadencia. Un pulso se pierde.
        ciclos_rstart = 0;
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            if (rstart) ciclos_rstart = ciclos_rstart + 1;
        end
        $display("[3] rstart alto durante %0d de 100 ciclos", ciclos_rstart);
        chk(ciclos_rstart > 50, "rstart es un PULSO: sd_reader no lo vera");

        // y baja cuando el lector arranca de verdad
        rbusy = 1;
        repeat (5) @(posedge clk);
        chk(rstart === 1'b0, "rstart no se suelta cuando rbusy sube");

        // ============ 7. DATOS desde el byte 0 =============================
        // se rellena el buffer como lo haria el sd_reader
        @(posedge clk);
        for (i = 0; i < 512; i = i + 1) begin
            outen <= 1'b1; outaddr <= i[8:0]; outbyte <= i[7:0];
            @(posedge clk);
        end
        outen <= 1'b0;
        rbusy = 0; rdone = 1; @(posedge clk); rdone = 0;
        repeat (5) @(posedge clk);

        spi_byte(1, 8'd4);                 // carga buf[0]
        chk(dout === 8'd0, "DATOS no empieza por el byte 0");
        spi_byte(0, 8'h00);
        chk(dout === 8'd1, "el segundo byte de DATOS no es el 1");
        spi_byte(0, 8'h00);
        chk(dout === 8'd2, "el tercer byte de DATOS no es el 2");

        // ============ 5. SOLTAR ===========================================
        spi_byte(1, 8'd2);
        repeat (5) @(posedge clk);
        chk(hold    === 1'b0, "SOLTAR no ha quitado el mando");
        chk(sd_init === 1'b0, "SOLTAR no ha apagado el arranque de la tarjeta");
        chk(sd_rst  === 1'b1, "SOLTAR no resetea el lector (Nextor no podra usarlo)");

        // ============ 6. perro guardian ===================================
        spi_byte(1, 8'd1);                 // tomar otra vez
        repeat (5) @(posedge clk);
        chk(hold === 1'b1, "no ha vuelto a tomar el mando");
        // ...y ahora silencio: 2 ms sin trafico
        repeat (60000) @(posedge clk);
        chk(hold    === 1'b0, "el guardian no ha soltado tras el silencio");
        chk(sd_init === 1'b0, "el guardian deja la tarjeta encendida: el MSX no arrancara");

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
