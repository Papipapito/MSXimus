// ============================================================================
//  tb_launcher_svc.v — banco de launcher_svc.v
//
//  Que se vigila, y por que estas cosas y no otras:
//   1. una escritura suelta llega al bus del VDP con puerto y dato correctos
//   2. un volcado de N bytes llega ENTERO y EN ORDEN (la FIFO cruza 27->86 MHz;
//      un fallo aqui se ve en placa como "a veces la pantalla sale mal")
//   3. el VDP lento no pierde bytes: la FIFO absorbe
//   4. si se desborda de verdad, PERDIDOS lo cuenta (no se pierde en silencio)
//   5. sin mando (owns=0) no se toca el bus
//   6. la lectura de teclas devuelve el vector que se congelo al empezar
// ============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_launcher_svc;

    reg clk = 0, clk_vdp = 0;
    always #18.5 clk     = ~clk;          // 27 MHz
    always #5.8  clk_vdp = ~clk_vdp;      // ~86 MHz

    reg          reset = 1;
    reg          strobe = 0, start = 0;
    reg  [7:0]   din = 0;
    wire [7:0]   dout;
    reg  [127:0] keys = 0;

    reg          rst_vdp_n = 0;
    reg          owns = 0;
    wire [2:0]   vdp_address;
    wire         vdp_ioreq, vdp_write, vdp_valid;
    reg          vdp_ready = 0;
    wire [7:0]   vdp_wdata;

    launcher_svc dut (
        .clk(clk), .reset(reset),
        .strobe(strobe), .start(start), .din(din), .dout(dout), .keys(keys),
        .clk_vdp(clk_vdp), .rst_vdp_n(rst_vdp_n), .owns(owns),
        .vdp_address(vdp_address), .vdp_ioreq(vdp_ioreq),
        .vdp_write(vdp_write), .vdp_valid(vdp_valid),
        .vdp_ready(vdp_ready), .vdp_wdata(vdp_wdata)
    );

    // ---- consumidor del VDP: acepta tras READY_DELAY ciclos ----------------
    integer READY_DELAY = 2;
    integer espera = 0;
    reg [10:0] recibido [0:4095];
    integer    n_rx = 0;

    always @(posedge clk_vdp) begin
        if (!rst_vdp_n) begin
            vdp_ready <= 1'b0; espera <= 0;
        end else begin
            vdp_ready <= 1'b0;
            if (vdp_valid && !vdp_ready) begin
                if (espera >= READY_DELAY) begin
                    vdp_ready      <= 1'b1;
                    recibido[n_rx]  = {vdp_address, vdp_wdata};
                    n_rx            = n_rx + 1;
                    espera         <= 0;
                end else espera <= espera + 1;
            end else espera <= 0;
        end
    end

    integer fallos = 0;
    // OJO: la comparacion tiene que ser ESTRICTA. Con `if (!cond)`, un dato sin
    // inicializar hace que `==` devuelva X, y `if (!X)` NO entra: el banco daba
    // VERDE con el RTL saboteado. Una X es un fallo, no un aprobado.
    task chk(input cond, input [255:0] txt);
    begin
        if (cond !== 1'b1) begin
            $display("  FALLO: %0s", txt);
            fallos = fallos + 1;
        end
    end
    endtask

    // ---- un byte por el SPI (hueco = ciclos entre bytes) -------------------
    integer hueco = 16;                   // 8 bits a 13,33 MHz ~= 16 clk de 27
    task spi_byte(input es_primero, input [7:0] b);
    begin
        @(posedge clk);
        start  <= es_primero; din <= b; strobe <= 1'b1;
        @(posedge clk);
        strobe <= 1'b0; start <= 1'b0;
        repeat (hueco) @(posedge clk);
    end
    endtask

    integer i;
    integer base;

    initial begin
        $dumpfile("/tmp/tb_launcher_svc.vcd");
        $dumpvars(0, tb_launcher_svc);

        repeat (10) @(posedge clk);
        reset = 0; rst_vdp_n = 1;
        repeat (10) @(posedge clk);

        // ================= 5. sin mando no se toca el bus ===================
        // (primero, para que un fallo aqui no contamine el resto)
        owns = 0;
        n_rx = 0;
        spi_byte(1, 8'd1); spi_byte(0, 8'd1); spi_byte(0, 8'hA5);
        repeat (200) @(posedge clk_vdp);
        $display("[5] sin mando: transacciones=%0d (deben ser 0)", n_rx);
        chk(n_rx == 0, "sin owns el modulo ha escrito en el bus del VDP");

        owns = 1;
        repeat (50) @(posedge clk_vdp);
        $display("[5b] al dar el mando se vacia lo encolado: %0d", n_rx);
        chk(n_rx == 1, "lo encolado sin mando deberia salir al darlo");

        // ================= 1. escritura suelta ==============================
        n_rx = 0;
        spi_byte(1, 8'd1); spi_byte(0, 8'd2); spi_byte(0, 8'h5C);
        repeat (300) @(posedge clk_vdp);
        $display("[1] suelta: n=%0d addr=%0d dato=%02h",
                 n_rx, recibido[0][10:8], recibido[0][7:0]);
        chk(n_rx == 1,                  "la escritura suelta no llego una sola vez");
        chk(recibido[0][10:8] == 3'd2,  "puerto equivocado");
        chk(recibido[0][7:0]  == 8'h5C, "dato equivocado");

        // ================= 2. volcado de 64 bytes en orden ==================
        n_rx = 0;
        spi_byte(1, 8'd2); spi_byte(0, 8'd0);
        for (i = 0; i < 64; i = i + 1) spi_byte(0, i[7:0]);
        repeat (600) @(posedge clk_vdp);
        $display("[2] volcado: recibidos=%0d de 64", n_rx);
        chk(n_rx == 64, "el volcado no llego entero");
        for (i = 0; i < 64 && i < n_rx; i = i + 1) begin
            chk(recibido[i][7:0] == i[7:0],  "volcado fuera de orden o corrupto");
            chk(recibido[i][10:8] == 3'd0,   "el volcado cambio de puerto");
        end

        // ================= 3. VDP lento, sin perdidas =======================
        READY_DELAY = 20;                 // el VDP tarda 20 ciclos por byte
        n_rx = 0;
        spi_byte(1, 8'd2); spi_byte(0, 8'd0);
        for (i = 0; i < 64; i = i + 1) spi_byte(0, 8'hF0 + i[3:0]);
        repeat (4000) @(posedge clk_vdp);
        $display("[3] VDP lento: recibidos=%0d de 64", n_rx);
        chk(n_rx == 64, "con el VDP lento se han perdido bytes que la FIFO debia absorber");
        READY_DELAY = 2;

        // ================= 4. desbordar de verdad y CONTARLO ================
        // 400 bytes seguidos y pegados contra una FIFO de 256 con el VDP a
        // paso de tortuga: tiene que desbordar, y tiene que NOTARSE.
        READY_DELAY = 200;
        hueco = 2;
        n_rx = 0;
        spi_byte(1, 8'd2); spi_byte(0, 8'd0);
        for (i = 0; i < 400; i = i + 1) spi_byte(0, i[7:0]);
        hueco = 16;
        repeat (200) @(posedge clk);
        // OJO con el desfase: en full-duplex el esclavo CARGA dout durante un
        // byte y el maestro lo RECIBE durante el siguiente. Asi que aqui, tras
        // cada spi_byte, dout ya vale lo que cargo ESE byte.
        spi_byte(1, 8'd0);                // ESTADO  -> carga VERSION
        chk(dout == 8'd1, "la version del ESTADO no es 1");
        spi_byte(0, 8'h00);               // state 0 -> carga {7'b0, lleno}
        spi_byte(0, 8'h00);               // state 1 -> carga perdidos_hi
        base = dout;
        spi_byte(0, 8'h00);               // state 2 -> carga perdidos_lo
        $display("[4] desbordado: perdidos=%0d (previsto ~120)", (base << 8) | dout);
        chk(((base << 8) | dout) > 0, "se desbordo y PERDIDOS se quedo a cero (perdida silenciosa)");
        READY_DELAY = 2;

        // ================= 6. lectura de teclas =============================
        keys = 128'h0F0E0D0C_0B0A0908_07060504_03020100;
        repeat (10) @(posedge clk);
        spi_byte(1, 8'd3);                // congela el vector
        for (i = 0; i < 16; i = i + 1) begin
            spi_byte(0, 8'h00);           // state i -> carga el byte i
            chk(dout == i[7:0], "byte de teclado equivocado");
            if (dout !== i[7:0])
                $display("      tecla[%0d]: esperado %02h, llego %02h", i, i[7:0], dout);
        end
        $display("[6] teclas leidas");

        $display("");
        if (fallos == 0) $display("=== VERDE: %0d fallos ===", fallos);
        else             $display("=== ROJO: %0d fallos ===", fallos);
        $finish;
    end

    initial begin
        #8_000_000;
        $display("=== ROJO: el banco se ha colgado ===");
        $finish;
    end

endmodule

`default_nettype wire
