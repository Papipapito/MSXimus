// ============================================================================
// scc_tb.v -- Testbench del SCC del port Console 60K (Icarus Verilog).
//
// Instancia el MISMO RTL que el bitstream:
//   - fpga/src/scc_glue.v    (glue de ventana/banco/strobes, extraido de top.v)
//   - fpga/src/scc_wave2v.v  (chip SCC en Verilog puro; sustituye al VHDL cuya
//                             entity scc_wave_mul barria la sintesis GW5A)
//   - fpga/src/megaram.v     (megaram_scc: registros de modo SCC-I / BFFE)
//
// Reloj y enables calcados de top.v: clk108 -> div/30 -> 3.6MHz interno,
// sincronizado a 54M (PINFILTER equiv.) y clk_enable_3m6_54 = flanco.
// El bus Z80 se modela con ciclos MREQ realistas (3 T-states de 3.6MHz:
// ~278ns/T; WR bajo 1 T-state completo = ~15 ticks de 54M; req NIVEL).
//
// Secuencia = lo que hace SCCTEST/un juego Konami:
//   bank2 9000<=3F, onda cuadrada en 9800-981F, freq 9880/9881, vol 988A,
//   canal 988F -> el wave DEBE oscilar. + readback, + conmutacion de banco,
//   + caso SCC+ (B000 bit7 + BFFE bit5 -> ventana B800, regs B8A0),
//   + gate de mixer scc_term/map_sel (sintoma "readback OK pero mudo").
//
// Uso:  bash run.sh   (sale 0 si "RESULT: PASS")
// ============================================================================
`timescale 1ns/1ps

module scc_tb;

    // ------------------------------------------------------------------
    // relojes y enables (calcados de fpga/top.v)
    // ------------------------------------------------------------------
    reg clk108 = 0;
    always #4.6296 clk108 = ~clk108;        // 108 MHz

    reg clk54 = 0;
    always @(posedge clk108) clk54 <= ~clk54;   // 54 MHz (fase alineada, como PLL)

    reg bus_reset_n = 0;

    // 108 MHz / 30 = 3.6 MHz (top.v:315-328)
    reg [4:0] div30_cnt = 0;
    reg clk_3m6_internal = 0;
    always @(posedge clk108) begin
        if (div30_cnt == 5'd14) begin
            clk_3m6_internal <= ~clk_3m6_internal;
            div30_cnt <= 0;
        end else
            div30_cnt <= div30_cnt + 1'b1;
    end

    // PINFILTER equivalente (2FF @54M) -> bus_clk_3m6 en dominio 54M
    reg [1:0] p36 = 0;
    always @(posedge clk54) p36 <= {p36[0], clk_3m6_internal};
    wire bus_clk_3m6 = p36[1];

    // enables exactos de top.v:288-295
    reg bus_clk_3m6_54 = 0;
    always @(posedge clk54) bus_clk_3m6_54 <= bus_clk_3m6;
    wire clk_enable_3m6_54  = (bus_clk_3m6_54 == 0 && bus_clk_3m6 == 1);
    wire clk_falling_3m6_54 = (bus_clk_3m6_54 == 1 && bus_clk_3m6 == 0);

    // ------------------------------------------------------------------
    // bus Z80 (modelo: G80a con clk_enable/clk_falling a cadencia 3.6M)
    // ------------------------------------------------------------------
    reg [15:0] bus_addr  = 16'hFFFF;
    reg [7:0]  cpu_dout  = 8'hFF;
    reg        bus_mreq_n = 1;
    reg        bus_wr_n   = 1;
    reg        bus_rd_n   = 1;

    // config quasi-estatica (megaram3 activa, slot correcto: como en el MSXnano)
    reg [1:0]  map_sel = 2'b10;     // modo SCC (SWIO smart cmd #0F / menu)

    // ------------------------------------------------------------------
    // DUT 1: glue (EL MISMO fichero que usa top.v)
    // ------------------------------------------------------------------
    wire scc_req, scc_wrt, scc_req3_r, scc_rd_r, x98h, xb8h;
    wire scc_mode_plus, sccplus_win_en, scc_sound_disable;

    scc_glue sccglue1 (
        .clk (clk54),
        .reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_mreq_n (bus_mreq_n),
        .bus_wr_n (bus_wr_n),
        .bus_rd_n (bus_rd_n),
        .gate_bank2_wr3 (1'b1),     // pri_slot_num[SD_SLOT] & exp_slotx_num[3]
        .gate_bank2_wr12 (1'b0),
        .gate_req3 (1'b1),          // config_enable_megaram3 & slot hit & exp[3]
        .gate_req12 (1'b0),
        .scc_mode_plus (scc_mode_plus),
        .sccplus_win_en (sccplus_win_en),
        .scc_sound_disable (scc_sound_disable),
        .scc_req (scc_req),
        .scc_wrt (scc_wrt),
        .scc_req3_r (scc_req3_r),
        .scc_rd_r (scc_rd_r),
        .x98h (x98h),
        .xb8h (xb8h)
    );

    // ------------------------------------------------------------------
    // DUT 2: chip SCC (Verilog puro, el del fix)
    // ------------------------------------------------------------------
    wire [7:0]  scc_dout;
    wire [14:0] scc_wav;

    scc_wave2v SccCh (
        .clk21m (clk54),
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_54),
        .req (scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav),
        .sccplus (scc_mode_plus)
    );

    // ------------------------------------------------------------------
    // DUT 3: megaram_scc (regs de modo SCC-I: BFFE, bank3). Alimentado con
    // el request general de megaram, replica de top.v:1931-1942 (gates=1).
    // ------------------------------------------------------------------
    wire xffff = (bus_addr == 16'hFFFF);
    reg scc2_req3 = 0;
    always @(posedge clk54)
        scc2_req3 <= ( bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0) && xffff == 0 ) ? 1'b1 : 1'b0;
    wire scc2_req = scc2_req3;
    wire scc2_wrt = ( scc2_req == 1 && bus_wr_n == 0 ) ? 1'b1 : 1'b0;

    megaram_scc megaram1 (
        .clk_27m (clk54),           // v2.6: megaram tambien a 54M en top.v
        .bus_reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_rd_n (bus_rd_n),
        .bus_wr_n (bus_wr_n),
        .scc_req (scc2_req),
        .scc_wrt (scc2_wrt),
        .map_sel (map_sel),
        .map_linear (1'b0),
        .sram_cfg (8'h00),
        .console_mode (2'b00),
        .megaram_req (),
        .megaram_wrt (),
        .megaram_addr (),
        .scc_sound_disable (scc_sound_disable),
        .scc_mode_plus (scc_mode_plus),
        .sccplus_win_en (sccplus_win_en)
    );

    // replica del mux de lectura del cpu_din (top.v:684) y del gate del mixer
    // (top.v:2045): scc_term = SCC solo en modo SCC (no Konami4/ASCII)
    wire [7:0]  cpu_din   = ( scc_rd_r == 1 ) ? scc_dout : 8'hFF;
    wire [15:0] scc_term  = ( map_sel == 2'b10 ) ? { scc_wav, 1'b0 } : 16'd0;

    // ------------------------------------------------------------------
    // tareas de ciclo de bus (3 T-states de 3.6MHz + 1 T idle)
    // ------------------------------------------------------------------
    task at_rise; begin
        @(posedge clk54);
        while (clk_enable_3m6_54 !== 1'b1) @(posedge clk54);
    end endtask

    task at_fall; begin
        @(posedge clk54);
        while (clk_falling_3m6_54 !== 1'b1) @(posedge clk54);
    end endtask

    task mem_write(input [15:0] a, input [7:0] d); begin
        at_rise;                    // T1 sube: direccion valida
        bus_addr <= a;
        at_fall;                    // T1 baja: MREQ, dato del T80 en el bus
        bus_mreq_n <= 0;
        cpu_dout   <= d;
        at_rise;                    // T2
        at_fall;                    // T2 baja: WR
        bus_wr_n <= 0;
        at_rise;                    // T3
        at_fall;                    // T3 baja: fin (WR bajo = 1 T ~ 278ns ~ 15 ticks 54M)
        bus_wr_n   <= 1;
        bus_mreq_n <= 1;
        at_rise;                    // T idle (M1 siguiente): direccion cambia
        bus_addr <= 16'hFFFF;
        cpu_dout <= 8'hFF;
        at_fall;
    end endtask

    task mem_read(input [15:0] a, output [7:0] d); begin
        at_rise;                    // T1 sube
        bus_addr <= a;
        at_fall;                    // T1 baja: MREQ+RD
        bus_mreq_n <= 0;
        bus_rd_n   <= 0;
        at_rise;                    // T2
        at_fall;
        at_rise;                    // T3
        at_fall;                    // T3 baja: el Z80 muestrea el dato
        d = cpu_din;
        bus_rd_n   <= 1;
        bus_mreq_n <= 1;
        at_rise;
        bus_addr <= 16'hFFFF;
        at_fall;
    end endtask

    // ------------------------------------------------------------------
    // monitor del wave: min/max, transiciones (histeresis +-500) y periodo
    // ------------------------------------------------------------------
    wire signed [15:0] wav_s = { scc_wav[14], scc_wav };

    reg mon_en = 0;
    reg mon_state = 0;
    integer mon_min, mon_max, mon_trans, mon_rises;
    integer term_viol;              // scc_term inconsistente con el gate
    realtime mon_rise_first, mon_rise_last;

    always @(posedge clk54) begin
        if (mon_en) begin
            if (wav_s > mon_max) mon_max = wav_s;
            if (wav_s < mon_min) mon_min = wav_s;
            if (mon_state == 0 && wav_s > 500) begin
                mon_state = 1;
                mon_trans = mon_trans + 1;
                if (mon_rises == 0) mon_rise_first = $realtime;
                mon_rise_last = $realtime;
                mon_rises = mon_rises + 1;
            end
            else if (mon_state == 1 && wav_s < -500) begin
                mon_state = 0;
                mon_trans = mon_trans + 1;
            end
            if (map_sel == 2'b10) begin
                if (scc_term !== {scc_wav, 1'b0}) term_viol = term_viol + 1;
            end else begin
                if (scc_term !== 16'd0) term_viol = term_viol + 1;
            end
        end
    end

    task mon_start; begin
        mon_min = 99999; mon_max = -99999;
        mon_trans = 0; mon_rises = 0; mon_state = 0;
        term_viol = 0;
        mon_en = 1;
    end endtask

    task mon_stop; begin
        mon_en = 0;
    end endtask

    // ------------------------------------------------------------------
    // infraestructura de checks
    // ------------------------------------------------------------------
    integer n_pass = 0, n_fail = 0;
    task check(input [8*64:1] name, input cond); begin
        if (cond) begin
            n_pass = n_pass + 1;
            $display("PASS: %0s", name);
        end else begin
            n_fail = n_fail + 1;
            $display("FAIL: %0s", name);
        end
    end endtask

    // ------------------------------------------------------------------
    // secuencia de test
    // ------------------------------------------------------------------
    integer i, errs;
    reg [7:0] rd;
    real period_meas, period_exp;

    initial begin
`ifdef DUMP
        $dumpfile("scc_tb.vcd");
        $dumpvars(0, scc_tb);
`endif
        // reset
        bus_reset_n = 0;
        repeat (40) @(posedge clk54);
        #2000;
        bus_reset_n = 1;
        #5000;

        $display("--- A. SCC compat (secuencia SCCTEST, map_sel=10) ---");

        // ventana ON: bank2 9000 <= 3F
        mem_write(16'h9000, 8'h3F);

        // onda cuadrada ch.A: 16 x 60 + 16 x A0 (como SCCTEST play_tone)
        for (i = 0; i < 16; i = i + 1) mem_write(16'h9800 + i, 8'h60);
        for (i = 16; i < 32; i = i + 1) mem_write(16'h9800 + i, 8'hA0);

        // readback 9800-981F
        errs = 0;
        for (i = 0; i < 32; i = i + 1) begin
            mem_read(16'h9800 + i, rd);
            if (rd !== ((i < 16) ? 8'h60 : 8'hA0)) begin
                errs = errs + 1;
                $display("  readback 98%02x = %02x (esperado %02x)", i, rd, (i < 16) ? 8'h60 : 8'hA0);
            end
        end
        check("A1 readback wave RAM 9800-981F == escrito", errs == 0);

        // conmutacion de banco (deteccion SCCTEST): con ventana OFF la celda no cambia
        mem_write(16'h9000, 8'h00);        // ventana OFF
        mem_write(16'h9800, 8'hBE);        // NO debe llegar a la wave RAM
        mem_read(16'h9800, rd);
        check("A2 lectura 9800 con ventana OFF devuelve FF (rd_r=0)", rd === 8'hFF);
        mem_write(16'h9000, 8'h3F);        // ventana ON otra vez
        mem_read(16'h9800, rd);
        check("A3 celda 9800 conserva 60 tras conmutar banco (no #BE)", rd === 8'h60);

        // registros del tono SCCTEST: freq FD (periodo 253), vol F, canal A on
        mem_write(16'h9880, 8'hFD);
        mem_write(16'h9881, 8'h00);
        mem_write(16'h988A, 8'h0F);
        mem_write(16'h988F, 8'h01);

        // ~2.6ms: media onda dura 16*254/3.6MHz ~ 1.13ms -> deben verse >=2 flancos
        mon_start;
        #2600000;
        mon_stop;
        $display("  tono FD: min=%0d max=%0d trans=%0d (esperado meseta +-1440)", mon_min, mon_max, mon_trans);
        check("A4 wave alcanza meseta positiva (>= +1000)", mon_max >= 1000);
        check("A5 wave alcanza meseta negativa (<= -1000)", mon_min <= -1000);
        check("A6 wave OSCILA (>= 2 transiciones)", mon_trans >= 2);
        check("A7 scc_term == {scc_wav,0} con map_sel==10 (gate integro)", term_viol == 0);

        // tono rapido para medir el periodo: freq 0x020 -> T = 33*32/3.6MHz = 293.3us
        mem_write(16'h9880, 8'h20);
        #400000;                            // settle (el contador puede agotar el periodo viejo)
        mon_start;
        #1500000;                           // 1.5ms ~ 5 ciclos
        mon_stop;
        period_exp = (32.0 + 1.0) * 32.0 / 3.6e6 * 1.0e9;   // ns
        if (mon_rises >= 2)
            period_meas = (mon_rise_last - mon_rise_first) / (mon_rises - 1);
        else
            period_meas = 0.0;
        $display("  tono 020: trans=%0d periodo medido=%0.1fns esperado=%0.1fns", mon_trans, period_meas, period_exp);
        check("A8 frecuencia correcta (periodo +-5%)",
              (mon_rises >= 2) && (period_meas > period_exp * 0.95) && (period_meas < period_exp * 1.05));
        check("A9 oscilacion sostenida (>= 8 transiciones en 1.5ms)", mon_trans >= 8);

        // volumen a 0 -> salida plana a 0 (camino reg_vol -> multiplicador)
        mem_write(16'h988A, 8'h00);
        #100000;
        mon_start;
        #200000;
        mon_stop;
        check("A10 vol=0 silencia (wave == 0 constante)", mon_min == 0 && mon_max == 0);

        // canal off -> plana; canal on -> vuelve (camino reg_ch_sel)
        mem_write(16'h988A, 8'h0F);
        mem_write(16'h988F, 8'h00);
        #100000;
        mon_start;
        #200000;
        mon_stop;
        check("A11 canal off silencia (wave == 0 constante)", mon_min == 0 && mon_max == 0);

        mem_write(16'h988F, 8'h01);
        mon_start;
        #600000;
        mon_stop;
        check("A12 canal on: vuelve a oscilar", mon_trans >= 2 && mon_max >= 1000 && mon_min <= -1000);

        $display("--- C. gate del mixer scc_term / map_sel (hipotesis 4) ---");
        // con map_sel != 10 el chip sigue sonando pero el termino va a 0:
        // exactamente el sintoma "readback OK pero mudo" visto en placa.
        map_sel = 2'b00;
        #20000;
        mon_start;
        #600000;
        mon_stop;
        check("C1 chip sigue oscilando con map_sel==00", mon_trans >= 2);
        check("C2 scc_term == 0 con map_sel==00 (SCC mudo por el gate)", term_viol == 0);
        map_sel = 2'b10;
        #20000;

        // martilleo de accesos CPU durante la reproduccion (req NIVEL ~15 ticks
        // de 54M por ciclo): el pipeline del mixer solo se congela 1 tick por
        // acceso y no debe corromperse nada (hipotesis 1)
        for (i = 0; i < 40; i = i + 1) begin
            mem_read(16'h9800 + (i % 32), rd);
            mem_write(16'h9820 + (i % 32), 8'h55);   // wave ch.B (vol 0: inaudible)
        end
        mem_read(16'h9800, rd);
        check("C3 readback integro tras martilleo (9800 == 60)", rd === 8'h60);
        mon_start;
        #600000;
        mon_stop;
        check("C4 sigue oscilando tras martilleo de accesos", mon_trans >= 2 && mon_max >= 1000 && mon_min <= -1000);

        $display("--- B. SCC+ / SCC-I (ventana B800 via megaram BFFE) ---");
        // apagar el tono compat y cerrar la ventana 9800
        mem_write(16'h988A, 8'h00);
        mem_write(16'h988F, 8'h00);
        mem_write(16'h9000, 8'h00);

        // modo SCC+: bank3 bit7 (B000<=80) + modo BFFE bit5 (BFFE<=20)
        mem_write(16'hB000, 8'h80);
        mem_write(16'hBFFE, 8'h20);
        check("B1 megaram: scc_mode_plus=1 y sccplus_win_en=1", scc_mode_plus === 1'b1 && sccplus_win_en === 1'b1);

        mem_read(16'h9800, rd);
        check("B2 ventana compat 9800 cerrada en modo SCC+ (lee FF)", rd === 8'hFF);

        // onda cuadrada ch.A en B800 + readback
        for (i = 0; i < 16; i = i + 1) mem_write(16'hB800 + i, 8'h70);
        for (i = 16; i < 32; i = i + 1) mem_write(16'hB800 + i, 8'h90);
        errs = 0;
        for (i = 0; i < 32; i = i + 1) begin
            mem_read(16'hB800 + i, rd);
            if (rd !== ((i < 16) ? 8'h70 : 8'h90)) errs = errs + 1;
        end
        check("B3 readback wave RAM B800-B81F == escrito", errs == 0);

        // registros SCC+ en B8A0-B8BF: freq 020, vol F, canal A on
        mem_write(16'hB8A0, 8'h20);
        mem_write(16'hB8A1, 8'h00);
        mem_write(16'hB8AA, 8'h0F);
        mem_write(16'hB8AF, 8'h01);
        #400000;
        mon_start;
        #1200000;
        mon_stop;
        $display("  SCC+: min=%0d max=%0d trans=%0d", mon_min, mon_max, mon_trans);
        check("B4 SCC+ oscila (regs en B8A0, onda en B800)", mon_trans >= 4 && mon_max >= 1000 && mon_min <= -1000);

        // modo OFF -> ventana B800 cerrada
        mem_write(16'hBFFE, 8'h00);
        mem_read(16'hB800, rd);
        check("B5 BFFE=0 cierra la ventana B800 (lee FF)", rd === 8'hFF);

        // ------------------------------------------------------------------
        $display("");
        $display("checks: %0d PASS, %0d FAIL", n_pass, n_fail);
        if (n_fail == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end

    // guarda de tiempo maximo
    initial begin
        #20000000;  // 20 ms
        $display("TIMEOUT");
        $display("RESULT: FAIL");
        $finish;
    end

endmodule
