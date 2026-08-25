// ============================================================================
//  tb_sdc_cadena.v — LA CADENA ENTERA: SPI real -> mcu_spi -> sdc_bridge -> SD
//
//  POR QUE
//  --------------------------------------------------------------------------
//  El banco de sdc_bridge lo prueba EN AISLADO, metiendole los strobes a mano,
//  y pasa. En la placa, las lecturas devuelven siempre el sector 0. O sea que
//  el fallo esta en algo que el aislamiento no reproduce: el TRANSPORTE.
//
//  Aqui se pone un maestro SPI de verdad (modo 1, CS bajo toda la trama, MSB
//  primero) que manda EXACTAMENTE las mismas tramas que el firmware, y un
//  modelo de sd_reader que devuelve un sector cuyo CONTENIDO DEPENDE DEL LBA.
//  Asi, si vuelve el sector equivocado, se ve cual y por que.
//
//  Se llega a esto tras medir de uno en uno a traves de la pantalla del S3
//  durante muchas rondas. Reproducir la secuencia completa en simulacion es
//  mas barato y no gasta flasheos.
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_sdc_cadena;

    reg clk = 0;
    always #18.5 clk = ~clk;                 // 27 MHz

    // Pulso de reset de verdad: en la FPGA los registros nacen a cero por el
    // GSR, pero en simulacion nacen en X y todo se propaga como X.
    reg rst = 1;

    // ---- lineas SPI (las mueve el maestro de mentira) --------------------
    reg  sclk = 0, mosi = 0, csn = 1;
    wire miso;

    wire        mcu_sys_strobe, mcu_hid_strobe, mcu_osd_strobe, mcu_sdc_strobe;
    wire        mcu_start;
    wire [7:0]  mcu_dout;
    wire [7:0]  sdc_dout;

    mcu_spi spi (
        .clk(clk), .reset(rst),
        .spi_io_ss(csn), .spi_io_clk(sclk), .spi_io_din(mosi), .spi_io_dout(miso),
        .mcu_sys_strobe(mcu_sys_strobe), .mcu_hid_strobe(mcu_hid_strobe),
        .mcu_osd_strobe(mcu_osd_strobe), .mcu_sdc_strobe(mcu_sdc_strobe),
        .mcu_start(mcu_start), .mcu_dout(mcu_dout),
        .mcu_sys_din(8'h00), .mcu_hid_din(8'h00),
        .mcu_osd_din(8'h00), .mcu_sdc_din(sdc_dout)
    );

    wire        rstart, hold, sd_init, sd_rst;
    wire [31:0] rsector;
    reg         rbusy = 0, rdone = 0;
    reg         outen = 0;
    reg  [8:0]  outaddr = 0;
    reg  [7:0]  outbyte = 0;

    sdc_bridge #(.CLK_HZ(27_000_000), .WDOG_MS(50)) puente (
        .clk(clk), .reset(rst),
        .strobe(mcu_sdc_strobe), .start(mcu_start), .din(mcu_dout), .dout(sdc_dout),
        .rstart(rstart), .rsector(rsector), .rbusy(rbusy), .rdone(rdone),
        .outen(outen), .outaddr(outaddr), .outbyte(outbyte), .card_stat(4'd1),
        .hold(hold), .sd_init(sd_init), .sd_rst(sd_rst)
    );

    // ---- modelo del lector: devuelve un sector MARCADO con su propio LBA --
    // El byte 0 del sector es el LBA que se pidio. Asi, si vuelve otro sector,
    // el dato lo dice directamente en vez de haber que deducirlo.
    integer sectores_leidos = 0;
    reg [31:0] lba_servido;
    integer i;

    always @(posedge clk) begin
        if (rstart && !rbusy) begin
            lba_servido <= rsector;
            rbusy <= 1'b1;
        end
    end

    initial begin : servidor
        forever begin
            @(posedge rbusy);
            repeat (200) @(posedge clk);       // la tarjeta tarda
            for (i = 0; i < 512; i = i + 1) begin
                outen <= 1'b1; outaddr <= i[8:0];
                outbyte <= (i == 0) ? lba_servido[7:0] :
                           (i == 1) ? lba_servido[15:8] : 8'hCC;
                @(posedge clk);
            end
            outen <= 1'b0;
            rbusy <= 1'b0; rdone <= 1'b1; @(posedge clk); rdone <= 1'b0;
            sectores_leidos = sectores_leidos + 1;
        end
    end

    // ---- maestro SPI, modo 1, 4 MHz -------------------------------------
    localparam T = 250;                        // 4 MHz
    task spi_byte(input [7:0] b, output [7:0] r);
        integer k;
    begin
        r = 8'h00;
        for (k = 7; k >= 0; k = k - 1) begin
            // MODO 1: el dato cambia EN el flanco de SUBIDA y el esclavo lo lee
            // en el de BAJADA. Poner `mosi` justo antes de la bajada (como se
            // hacia antes) es una carrera: el esclavo muestreaba el bit
            // SIGUIENTE y todos los bytes llegaban desplazados un bit --
            // mandando 03 se latcheaba 06.
            sclk = 1'b1; mosi = b[k];
            #(T/2);
            r = {r[6:0], miso};                // el maestro lee antes de bajar
            sclk = 1'b0;
            #(T/2);
        end
    end
    endtask

    reg [7:0] rx [0:31];
    task trama(input integer n, input [255:0] bytes_tx);
        integer k; reg [7:0] tmp;
    begin
        csn = 1'b0; #T;
        for (k = 0; k < n; k = k + 1) begin
            spi_byte(bytes_tx[8*(31-k) +: 8], tmp);
            rx[k] = tmp;
        end
        #T; csn = 1'b1; #(T*4);
    end
    endtask

    // Contadores del PROPIO banco: si el maestro simulado no mete bytes, hay
    // que saberlo antes de acusar al RTL.
    integer n_strobe = 0, n_start = 0;
    integer n_neg = 0, n_cs = 0;
    always @(negedge sclk) if (!csn) n_neg = n_neg + 1;
    always @(negedge csn) n_cs = n_cs + 1;
    always @(posedge clk) begin
        if (mcu_sdc_strobe) n_strobe = n_strobe + 1;
        if (mcu_sdc_strobe && mcu_start) n_start = n_start + 1;
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

    initial begin
        $dumpfile("/tmp/tb_sdc_cadena.vcd");
        $dumpvars(0, tb_sdc_cadena);
        repeat (10) @(posedge clk);
        rst = 0;
        repeat (20) @(posedge clk);

        // Pulso de CS "en vacio" ANTES de la primera trama. mcu_spi pone su
        // contador de bits a cero SOLO en el flanco de subida de CS, y como csn
        // arranca ya en 1 ese flanco no llega a producirse nunca: el contador
        // se queda en X toda la primera trama y no se latchea ni un byte. En la
        // FPGA no pasa porque el GSR inicializa los registros al encender.
        csn = 1'b0; #500; csn = 1'b1; #500;
        repeat (20) @(posedge clk);

        // ---- TOMAR ------------------------------------------------------
        trama(2, {8'd3, 8'd1, 240'd0});
        repeat (20) @(posedge clk);
        $display("[TOMAR] hold=%b sd_init=%b  strobes=%0d starts=%0d",
                 hold, sd_init, n_strobe, n_start);
        $display("        banco: bajadas_sclk=%0d  CS_bajado=%0d  csn=%b",
                 n_neg, n_cs, csn);
        $display("        dentro: cnt=%0d ready=%b target=%02X data=%02X in_cnt=%0d",
                 spi.spi_cnt, spi.spi_data_in_ready, spi.spi_target,
                 spi.spi_data_in, spi.spi_in_cnt);
        chk(hold === 1'b1, "TOMAR por SPI real no ha puesto hold");

        // ---- LEER el sector 0x0201 (dos bytes distintos, para verlo) -----
        trama(6, {8'd3, 8'd3, 8'h01, 8'h02, 8'h00, 8'h00, 208'd0});
        repeat (50) @(posedge clk);
        $display("[LEER]  rsector=%08h  (esperado 00000201)", rsector);
        chk(rsector === 32'h00000201, "el LBA NO llega entero por el SPI real");

        // esperar a que el modelo sirva el sector
        repeat (1500) @(posedge clk);
        $display("[LEER]  sectores servidos=%0d  lba_servido=%08h",
                 sectores_leidos, lba_servido);
        chk(sectores_leidos == 1, "la lectura no se ha llegado a servir");
        chk(lba_servido === 32'h00000201, "el lector ha recibido OTRO sector");

        // ---- DATOS: el buffer debe traer el sector MARCADO ---------------
        trama(6, {8'd3, 8'd4, 8'h00, 8'h00, 8'h00, 8'h00, 208'd0});
        $display("[DATOS] rx = %02X %02X %02X %02X %02X %02X",
                 rx[0], rx[1], rx[2], rx[3], rx[4], rx[5]);
        // el puente carga buf[0] en el byte del comando -> se recibe en rx[2]
        chk(rx[2] === 8'h01, "el primer byte del sector no es el marcado (LBA bajo)");
        chk(rx[3] === 8'h02, "el segundo byte del sector no es el marcado (LBA alto)");

        // ---- ESTADO: los contadores tienen que ser DISTINTOS entre si ----
        // OJO: la concatenacion tiene que sumar EXACTAMENTE 256 bits. Antes
        // sumaba 264 y se truncaba por arriba -- el byte de destino se
        // perdia y el ESTADO no contestaba nada.
        trama(11, {8'd3, 8'd0, 240'd0});
        $display("[ESTADO] rx = %02X %02X %02X %02X %02X %02X %02X %02X %02X",
                 rx[2], rx[3], rx[4], rx[5], rx[6], rx[7], rx[8], rx[9], rx[10]);
        chk(rx[2] === 8'h01, "la version del puente no es 1");
        chk(rx[4] === 8'h01, "el ESTADO no dice que tenemos el mando");
        // n_pide=1, n_acaba=1, n_sector=1, ult_sec=0x0201
        chk(rx[6] === 8'h01, "n_pide equivocado");
        chk(rx[8] === 8'h01 && rx[9] === 8'h02,
            "el rsector guardado no es el que se pidio");

        $display("");
        if (fallos == 0) $display("=== VERDE: %0d fallos ===", fallos);
        else             $display("=== ROJO: %0d fallos ===", fallos);
        $finish;
    end

    initial begin
        #50_000_000;
        $display("=== ROJO: colgado ===");
        $finish;
    end

endmodule

`default_nettype wire
