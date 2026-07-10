`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Testbench de la conmutacion de cadencia turbo del MSXnano (fix v1.9a).
// Replica VERBATIM la logica de top.v: divisor /30 (3.6MHz) + sync, divisor /20
// (5.4MHz) + sync s5m4 + "period swallow" pana (5.369MHz), y el nuevo turbo_eff
// (conmutado glitch-free) + el mux clk_enable_cpu_54/clk_falling_cpu_54.
// Hace toggle de `turbo` en MUCHAS fases distintas y comprueba la INVARIANTE que
// el Z80 (G80a) necesita: la cadencia muxada NUNCA entrega dos ENABLE ni dos
// FALLING seguidos, ni un ENABLE y un FALLING el mismo ciclo. Si el fix no fuera
// glitch-free, un toggle mal alineado produciria EN,EN o FALL,FALL -> FAIL.
//
//   Correr:  bash run.sh   (WSL/bash con Icarus Verilog)
//   Salida:  "RESULT: PASS (N toggles, M pulsos)" o "RESULT: FAIL ..."
// -----------------------------------------------------------------------------
module turbo_tb;

    reg clk_108m = 0;
    reg clk_54m  = 0;
    reg rstn     = 0;
    reg turbo    = 0;

    // 54 MHz = 108/2. Relojes del PLL: mismo ratio 2:1 y el posedge de clk_54m cae
    // a MITAD del periodo de clk_108m -> las señales de dominio 108 (clk_3m6/5m4_internal,
    // que cambian en posedge de clk_108m) estan ESTABLES al muestrear en clk_54m (sin
    // carrera delta). clk_108m posedge @ t=2,6,10..; clk_54m posedge @ t=4,12,20..
    always #2 clk_108m = ~clk_108m;
    always #4 clk_54m  = ~clk_54m;

    // ---- 3.6 MHz: /30 sobre clk_108m + sync a clk_54m (top.v 220-233, 195-200) ----
    reg [4:0] div30_cnt = 0;
    reg clk_3m6_internal = 0;
    always @(posedge clk_108m or negedge rstn) begin
        if (~rstn) begin div30_cnt <= 0; clk_3m6_internal <= 0; end
        else if (div30_cnt == 5'd14) begin clk_3m6_internal <= ~clk_3m6_internal; div30_cnt <= 0; end
        else div30_cnt <= div30_cnt + 1;
    end
    wire bus_clk_3m6 = clk_3m6_internal;
    reg bus_clk_3m6_54 = 0, bus_clk_3m6_prev_54 = 0;
    always @(posedge clk_54m) begin
        bus_clk_3m6_54 <= bus_clk_3m6;
        bus_clk_3m6_prev_54 <= bus_clk_3m6_54;
    end
    wire clk_enable_3m6_54  = (bus_clk_3m6_54 == 0 && bus_clk_3m6 == 1);
    wire clk_falling_3m6_54 = (bus_clk_3m6_54 == 1 && bus_clk_3m6 == 0);

    // ---- 5.37 MHz: /20 + sync s5m4 + swallow (top.v 894-934) ----
    reg [4:0] div20_cnt = 0;
    reg clk_5m4_internal = 0;
    always @(posedge clk_108m or negedge rstn) begin
        if (~rstn) begin div20_cnt <= 0; clk_5m4_internal <= 0; end
        else if (div20_cnt >= 5'd9) begin clk_5m4_internal <= ~clk_5m4_internal; div20_cnt <= 0; end
        else div20_cnt <= div20_cnt + 1;
    end
    reg s5m4_a = 0, s5m4_b = 0;
    always @(posedge clk_54m) begin s5m4_a <= clk_5m4_internal; s5m4_b <= s5m4_a; end
    wire clk_enable_5m4_raw  = (s5m4_b == 0 && s5m4_a == 1);
    wire clk_falling_5m4_raw = (s5m4_b == 1 && s5m4_a == 0);
    reg [7:0] pana_per_cnt = 0;
    reg pana_skip_pend = 0;
    wire pana_skip_now = (pana_per_cnt == 8'd175) && clk_enable_5m4_raw;
    always @(posedge clk_54m) begin
        if (~rstn) begin pana_per_cnt <= 0; pana_skip_pend <= 0; end
        else begin
            if (clk_enable_5m4_raw) begin
                if (pana_per_cnt == 8'd175) begin pana_per_cnt <= 0; pana_skip_pend <= 1; end
                else pana_per_cnt <= pana_per_cnt + 1'b1;
            end
            if (pana_skip_pend && clk_falling_5m4_raw) pana_skip_pend <= 0;
        end
    end
    wire clk_enable_5m4_54  = clk_enable_5m4_raw  & ~pana_skip_now;
    wire clk_falling_5m4_54 = clk_falling_5m4_raw & ~pana_skip_pend;

    // ---- FIX v1.9a: turbo_eff glitch-free + mux (top.v 935-...) ----
    // running: reset3_n/flash_idle/esp_boot_ok = 1; wait_io/wait_m1 = 1 (sin stall)
    wire cadence_safe = (bus_clk_3m6 == 1'b0 && bus_clk_3m6_54 == 1'b0) &&
                        (s5m4_a == 1'b0 && s5m4_b == 1'b0);
    reg turbo_eff = 0;
    always @(posedge clk_54m) begin
        if (~rstn || cadence_safe)   // (running: los 4 terminos de RESET_n = rstn; wait_io&wait_m1=1)
            turbo_eff <= turbo;
    end
    wire clk_enable_cpu_54  = turbo_eff ? clk_enable_5m4_54  : clk_enable_3m6_54;
    wire clk_falling_cpu_54 = turbo_eff ? clk_falling_5m4_54 : clk_falling_3m6_54;

    // ---- Checker: la cadencia que ve el CPU debe alternar EN/FALL estrictamente ----
    integer errors = 0, toggles = 0, pulses = 0;
    reg [1:0] last = 2'd0;   // 0=ninguno, 1=enable, 2=falling
    always @(posedge clk_54m) begin
        if (rstn) begin
            if (clk_enable_cpu_54 && clk_falling_cpu_54) begin
                errors = errors + 1;
                $display("FAIL @%0t: EN y FALL el mismo ciclo (turbo_eff=%b)", $time, turbo_eff);
            end
            if (clk_enable_cpu_54) begin
                pulses = pulses + 1;
                if (last == 2'd1) begin
                    errors = errors + 1;
                    $display("FAIL @%0t: dos ENABLE seguidos (turbo=%b eff=%b)", $time, turbo, turbo_eff);
                end
                last = 2'd1;
            end
            if (clk_falling_cpu_54) begin
                pulses = pulses + 1;
                if (last == 2'd2) begin
                    errors = errors + 1;
                    $display("FAIL @%0t: dos FALLING seguidos (turbo=%b eff=%b)", $time, turbo, turbo_eff);
                end
                last = 2'd2;
            end
        end
    end

    // ---- Estimulo: reset, luego toggle de turbo en MUCHAS fases ----
    integer i;
    initial begin
        rstn = 0;
        repeat (40) @(posedge clk_54m);
        rstn = 1;
        repeat (60) @(posedge clk_54m);   // dejar asentar cadencias
        last = 2'd0;                        // arrancar el checker desde limpio

        // barrido de fase: toggle de turbo cada k ciclos, k recorriendo 1..40,
        // y ademas toggles pseudoaleatorios -> cubre todas las alineaciones
        for (i = 0; i < 200000; i = i + 1) begin
            @(posedge clk_54m);
            if ( (i % ((i % 39) + 1)) == 0 || ($random % 7) == 0 ) begin
                turbo = ~turbo;
                toggles = toggles + 1;
            end
        end

        if (errors == 0)
            $display("\nRESULT: PASS  (%0d toggles de turbo, %0d pulsos CPU verificados)", toggles, pulses);
        else
            $display("\nRESULT: FAIL  (%0d violaciones de alternancia)", errors);
        $finish;
    end
endmodule
