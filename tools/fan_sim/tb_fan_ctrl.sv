//============================================================================
// tb_fan_ctrl.sv — Testbench del control de ventilador (termometro RO)
//
// Mock del ro_osc: cuando fan_ctrl cierra la ventana (ro_en 1->0) el mock
// publica la cuenta programada (tb_count). La temperatura se simula como
// caida porcentual de la cuenta respecto de la baseline de 100000.
//============================================================================
`timescale 1ns/1ps

module tb_fan_ctrl;

    localparam CLK_HZ = 27_000;   // 1 "segundo" = 27000 ciclos
    localparam WIN    = 1024;     // ventana corta para sim

    reg         clk = 0;
    reg         reset_n = 0;
    wire        ro_en;
    wire        ro_cnt_rst;
    reg  [19:0] ro_cnt = 20'd0;
    wire        fan_en;
    wire [19:0] dbg_cnt;

    integer     tb_count = 100000;   // cuenta que "mide" el anillo
    integer     errores = 0;

    fan_ctrl #(
        .CLK_HZ  (CLK_HZ),
        .WIN_CYC (WIN),
        .K_ON    (10'd32),    // 3.1%
        .K_OFF   (10'd20)     // 2.0%
    ) dut (
        .clk        (clk),
        .reset_n    (reset_n),
        .ro_en      (ro_en),
        .ro_cnt_rst (ro_cnt_rst),
        .ro_cnt     (ro_cnt),
        .fan_en     (fan_en),
        .dbg_cnt    (dbg_cnt)
    );

    always #10 clk = ~clk;

    // Mock del anillo: limpiar con cnt_rst, publicar al cerrar la ventana
    always @(posedge ro_cnt_rst) ro_cnt <= 20'd0;
    always @(negedge ro_en)      ro_cnt <= tb_count[19:0];

    task espera_medidas(input integer nmed);
        integer i;
        begin
            for (i = 0; i < nmed; i = i + 1) begin
                @(negedge ro_en);           // ventana cerrada
                repeat (100) @(posedge clk); // deja evaluar
            end
        end
    endtask

    task check(input cond, input [8*44:1] msg);
        begin
            if (!cond) begin
                $display("FALLO: %0s (fan=%b dbg=%0d t=%0t)", msg, fan_en, dbg_cnt, $time);
                errores = errores + 1;
            end
            else $display("ok: %0s (fan=%b)", msg, fan_en);
        end
    endtask

    initial begin
        repeat (10) @(posedge clk);
        reset_n = 1;

        // 1) Arranque frio: baseline 100000, OFF
        tb_count = 100000;
        espera_medidas(2);
        check(fan_en == 1'b0, "arranque frio -> OFF");

        // 2) Caida 1.5% (98500): tibio, sigue OFF
        tb_count = 98500;
        espera_medidas(1);
        check(fan_en == 1'b0, "caida 1.5% -> sigue OFF");

        // 3) Caida 3.5% (96500 < th_on 96875): caliente -> ON
        tb_count = 96500;
        espera_medidas(1);
        check(fan_en == 1'b1, "caida 3.5% -> ON");

        // 4) Caida 2.5% (97500, entre umbrales): histeresis, sigue ON
        tb_count = 97500;
        espera_medidas(1);
        check(fan_en == 1'b1, "caida 2.5% -> sigue ON (histeresis)");

        // 5) Caida 1% (99000 > th_off 98047): enfriado -> OFF
        tb_count = 99000;
        espera_medidas(1);
        check(fan_en == 1'b0, "caida 1% -> OFF");

        // 6) Anillo muerto (0): fail-safe ON
        tb_count = 0;
        espera_medidas(1);
        check(fan_en == 1'b1, "anillo muerto -> fail-safe ON");

        // 7) Recupera cuenta normal: OFF
        tb_count = 100000;
        espera_medidas(1);
        check(fan_en == 1'b0, "anillo recuperado -> OFF");

        // 8) Mas frio que la baseline (101000): OFF y baseline sube
        tb_count = 101000;
        espera_medidas(1);
        check(fan_en == 1'b0, "mas frio que baseline -> OFF");
        // con baseline 101000, un 3.2% de caida (97768) debe dar ON
        tb_count = 97700;
        espera_medidas(1);
        check(fan_en == 1'b1, "baseline subida detecta ON antes");

        if (errores == 0) $display("TB_FAN_ALL_PASS");
        else $display("TB_FAN_FAIL: %0d errores", errores);
        $finish;
    end

    initial begin
        #200_000_000;
        $display("TB_FAN_TIMEOUT");
        $finish;
    end

endmodule
