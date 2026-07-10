`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// turbo_m1_tb.v — velocidad EFECTIVA de la CPU con el M1-wait activo, en ambas
// cadencias (3.58 normal / 5.37 turbo). Diagnostico del F11 "se vuelve loco"
// de la _62/_63diag: si el generador de M1-wait funcionara mal a 5.37, la
// velocidad efectiva saldria >150% aqui. Cadencias y M1-wait replicados
// VERBATIM de top.v (mismas fuentes que turbo_tb.v).
//
//   Correr:  iverilog -g2012 -o turbo_m1_tb turbo_m1_tb.v && vvp turbo_m1_tb
//   Esperado (ciclo de 7 T-states con 1 M1): cada M1 pierde exactamente 1 T
//   -> 3.58: ~3.579*7/8 = 3.132 MHz ef.; 5.37: ~5.369*7/8 = 4.698 MHz ef.
//   (el "150%" de los benchmarks MSX sale del ratio 5.369/3.579 constante)
// -----------------------------------------------------------------------------
module turbo_m1_tb;

    reg clk_108m = 0;
    reg clk_54m  = 0;
    reg rstn     = 0;
    reg turbo    = 0;

    always #2 clk_108m = ~clk_108m;
    always #4 clk_54m  = ~clk_54m;

    // ---- 3.6 MHz: /30 sobre clk_108m + sync ----
    reg [4:0] div30_cnt = 0;
    reg clk_3m6_internal = 0;
    always @(posedge clk_108m or negedge rstn) begin
        if (~rstn) begin div30_cnt <= 0; clk_3m6_internal <= 0; end
        else if (div30_cnt == 5'd14) begin clk_3m6_internal <= ~clk_3m6_internal; div30_cnt <= 0; end
        else div30_cnt <= div30_cnt + 1;
    end
    wire bus_clk_3m6 = clk_3m6_internal;
    reg bus_clk_3m6_54 = 0;
    always @(posedge clk_54m) bus_clk_3m6_54 <= bus_clk_3m6;
    wire clk_enable_3m6_54  = (bus_clk_3m6_54 == 0 && bus_clk_3m6 == 1);
    wire clk_falling_3m6_54 = (bus_clk_3m6_54 == 1 && bus_clk_3m6 == 0);

    // ---- 5.37 MHz: /20 + sync + swallow ----
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

    // ---- turbo_eff + mux (running: resets=1, waits del gate aparte) ----
    wire cadence_safe = (bus_clk_3m6 == 1'b0 && bus_clk_3m6_54 == 1'b0) &&
                        (s5m4_a == 1'b0 && s5m4_b == 1'b0);
    reg turbo_eff = 0;
    wire wait_io = 1'b1;   // sin waits de IO en este banco
    always @(posedge clk_54m) begin
        if (~rstn || (cadence_safe && wait_io && wait_m1))
            turbo_eff <= turbo;
    end
    wire clk_enable_cpu_54  = turbo_eff ? clk_enable_5m4_54  : clk_enable_3m6_54;
    wire clk_falling_cpu_54 = turbo_eff ? clk_falling_5m4_54 : clk_falling_3m6_54;

    // ---- M1-wait generator VERBATIM (top.v ENABLE_M1_WAIT) ----
    reg  bus_m1_n = 1'b1;
    reg  wait_m1 = 1'b1;
    reg  bus_m1_n_prev_54 = 1'b1;
    reg  m1_active = 1'b0;
    reg  m1_masked_en = 1'b0;
    reg  m1_masked_fall = 1'b0;
    always @ (posedge clk_54m) begin
        if (~rstn) begin
            wait_m1 <= 1'b1; bus_m1_n_prev_54 <= 1'b1;
            m1_active <= 1'b0; m1_masked_en <= 1'b0; m1_masked_fall <= 1'b0;
        end else begin
            bus_m1_n_prev_54 <= bus_m1_n;
            if (!m1_active) begin
                if (bus_m1_n_prev_54 == 1'b1 && bus_m1_n == 1'b0) begin
                    m1_active <= 1'b1; wait_m1 <= 1'b0;
                    m1_masked_en <= 1'b0; m1_masked_fall <= 1'b0;
                end
            end else begin
                if (clk_enable_cpu_54)  m1_masked_en   <= 1'b1;
                if (clk_falling_cpu_54) m1_masked_fall <= 1'b1;
                if ((m1_masked_en  || clk_enable_cpu_54) &&
                    (m1_masked_fall || clk_falling_cpu_54)) begin
                    wait_m1 <= 1'b1; m1_active <= 1'b0;
                end
            end
        end
    end

    // ---- patron M1 estilo Z80: ciclo de 7 T (M1_n baja en T1, sube en T3) ----
    wire cpu_en = clk_enable_cpu_54 & wait_m1;
    integer tstate = 0;
    integer m1_count = 0;
    integer en_count = 0;
    always @ (posedge clk_54m) begin
        if (~rstn) begin tstate <= 0; bus_m1_n <= 1; end
        else if (cpu_en) begin
            en_count <= en_count + 1;
            tstate <= (tstate == 6) ? 0 : tstate + 1;
            if (tstate == 6) begin bus_m1_n <= 0; m1_count <= m1_count + 1; end
            if (tstate == 1) bus_m1_n <= 1;
        end
    end

    // ---- medida ----
    integer e0, m0, de, dm, fallos;
    real mhz, esperado;
    task medir(input tm);
        begin
            @(posedge clk_54m); turbo = tm;
            repeat (3000) @(posedge clk_54m);
            e0 = en_count; m0 = m1_count;
            repeat (270000) @(posedge clk_54m);       // 5 ms simulados
            de = en_count - e0; dm = m1_count - m0;
            mhz = de / 5000.0;
            esperado = (tm ? 5.369318 : 3.579545) * 7.0 / 8.0;
            $display("  turbo=%0d: %0.4f MHz efectivos (esperado %0.4f), %0d M1s, %0.3f T perdidos/M1",
                     tm, mhz, esperado, dm,
                     (5000.0 * (tm ? 5.369318 : 3.579545) - de) / dm);
            if (mhz > esperado * 1.02 || mhz < esperado * 0.98) begin
                fallos = fallos + 1;
                $display("  *** FUERA DE RANGO ***");
            end
        end
    endtask

    initial begin
        fallos = 0;
        rstn = 0;
        repeat (40) @(posedge clk_54m);
        rstn = 1;
        repeat (100) @(posedge clk_54m);
        $display("== Velocidad efectiva con M1-wait (ciclo 7 T, 1 M1 c/u) ==");
        medir(1'b0);
        medir(1'b1);
        medir(1'b0);
        if (fallos == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL (%0d medidas fuera de rango)", fallos);
        $finish;
    end
endmodule
