// ============================================================================
// scc_tb_cen27.v -- Testbench del SCC con el camino REAL de clk_enable_3m6_27.
//
// Variante de scc_tb.v que replica VERBATIM el camino del enable que usan los
// chips de sonido en HW desde la _44 (top.v:240-328):
//   div30 en el dominio de 108M (reset asincrono) -> ex_bus_clk_3m6 (~3.6M)
//   -> PINFILTER REAL (src/wondertang/pinfilter.v) a 54M -> bus_clk_3m6
//   -> cadena de OCHO FFs de sincronizacion a clk_27m (bus_clk_3m6_27_6.._0
//      -> bus_clk_3m6_27) -> edge detect (bus_clk_3m6_prev_27)
//   -> clk_enable_3m6_27 de 1 ciclo.
// El chip instanciado es el GENERADO POR GHDL (fpga/src/scc_wave2_ghdl.v),
// con clk21m = clk_27m y clkena = clk_enable_3m6_27 (config exacta de
// top.v:1951, v3.4/_44). El glue sigue a 54M y la megaram a 54M, como top.v.
//
// Relojes con fase realista de PLLA (clkout0/1/2): 108/54/27 EN FASE, flancos
// de subida coincidentes (semiperiodos exactos en ps: 4630/9260/18520 -> el
// "108M" queda en 107.99 MHz, error 0.01%, irrelevante para los checks).
//
// Checks: los MISMOS 21 de scc_tb.v + N1 (avance del puntero ch.A): cuenta
// los CAMBIOS DE VALOR de scc_wav y los toggles del puerto _49dbg dbg_ptr_lsb
// durante el tono 0x020; el fallo de placa (scc_wav congelado en DC) daria
// CERO cambios y CERO toggles tras las escrituras.
//
// Uso:  bash run_cen27.sh   (sale 0 si "RESULT: PASS")
// ============================================================================
`timescale 1ns/1ps

module scc_tb_cen27;

    // ------------------------------------------------------------------
    // relojes: replica del PLLA (pll_main clkout0/1/2) — 108/54/27 EN FASE
    // ------------------------------------------------------------------
    reg clk108 = 1'b1;
    reg clk54  = 1'b1;
    reg clk27  = 1'b1;
    always #4.630  clk108 = ~clk108;    // 107.99 MHz (semiperiodo 4630 ps)
    always #9.260  clk54  = ~clk54;     //  53.99 MHz
    always #18.520 clk27  = ~clk27;     //  27.00 MHz (subidas coinciden con 54/108)

    reg bus_reset_n = 0;

    // 108 MHz / 30 = 3.6 MHz interno (top.v:315-328 VERBATIM, incl. el
    // reset asincrono del divisor)
    wire ex_bus_clk_3m6;
    reg [4:0] div30_cnt;
    reg clk_3m6_internal;
    always @(posedge clk108 or negedge bus_reset_n) begin
        if (~bus_reset_n) begin
            div30_cnt <= 0;
            clk_3m6_internal <= 0;
        end else begin
            if (div30_cnt == 5'd14) begin
                clk_3m6_internal <= ~clk_3m6_internal;
                div30_cnt <= 0;
            end else begin
                div30_cnt <= div30_cnt + 1;
            end
        end
    end
    assign ex_bus_clk_3m6 = clk_3m6_internal;

    // PINFILTER REAL a 54M (top.v:248, mismo modulo del bitstream)
    wire bus_clk_3m6;
    PINFILTER dn1(
        .clk(clk54),
        .reset_n(1'b1),
        .din(ex_bus_clk_3m6),
        .dout(bus_clk_3m6)
    );

    // >>> resolvedor z->hold (SOLO SIMULACION, documentado) <<<
    // El PINFILTER real emite 1'bz durante 1 ciclo de 54M en CADA transicion
    // del 3m6 (dpipe=01/10 -> d_com=z -> d=z). En SILICIO no existe z: la
    // sintesis resuelve ese idiom como HOLD (mantener el ultimo valor) y asi
    // lleva anos funcionando (GW2AR; y el PSG del GW5A suena por este mismo
    // camino). En Icarus la z se propaga a la cadena de 27M y el edge-detect
    // produce clkena=X, que envenena los contadores del chip (el mux
    // "clkena ? a : b" del netlist da X permanente) => sintoma IDENTICO al de
    // placa pero por ARTEFACTO DE SIM. Modelamos el hold fisico aqui;
    // verificado con sonda: sin esto cen sale a 1.8M y cnt_a=XXX, con esto
    // cen=3.600M exacto y el tono corre.
    reg  bus_clk_3m6_hold = 1'b0;
    always @(bus_clk_3m6)
        if (bus_clk_3m6 !== 1'bz) bus_clk_3m6_hold <= bus_clk_3m6;
    wire bus_clk_3m6_r = (bus_clk_3m6 === 1'bz) ? bus_clk_3m6_hold : bus_clk_3m6;

    // cadena de 8 FFs de sincronizacion a 27M + edge detect
    // (top.v:255-282 VERBATIM): el camino REAL de clk_enable_3m6_27
    reg bus_clk_3m6_27;
    reg bus_clk_3m6_27_0;
    reg bus_clk_3m6_27_1;
    reg bus_clk_3m6_27_2;
    reg bus_clk_3m6_27_3;
    reg bus_clk_3m6_27_4;
    reg bus_clk_3m6_27_5;
    reg bus_clk_3m6_27_6;
    always @(posedge clk27) begin
        bus_clk_3m6_27_6 <= bus_clk_3m6_r;   // (la _r = z ya resuelta a hold)
        bus_clk_3m6_27_5 <= bus_clk_3m6_27_6;
        bus_clk_3m6_27_4 <= bus_clk_3m6_27_5;
        bus_clk_3m6_27_3 <= bus_clk_3m6_27_4;
        bus_clk_3m6_27_2 <= bus_clk_3m6_27_3;
        bus_clk_3m6_27_1 <= bus_clk_3m6_27_2;
        bus_clk_3m6_27_0 <= bus_clk_3m6_27_1;
        bus_clk_3m6_27   <= bus_clk_3m6_27_0;
    end
    wire clk_enable_3m6_27;
    wire clk_falling_3m6_27;
    reg bus_clk_3m6_prev_27;
    always @(posedge clk27) begin
        bus_clk_3m6_prev_27 <= bus_clk_3m6_27;
    end
    assign clk_enable_3m6_27  = (bus_clk_3m6_prev_27 == 0 && bus_clk_3m6_27 == 1);
    assign clk_falling_3m6_27 = (bus_clk_3m6_prev_27 == 1 && bus_clk_3m6_27 == 0);

    // ------------------------------------------------------------------
    // bus Z80 (modelo: CPU a cadencia cen_27, como el G80/rtc de top.v)
    // ------------------------------------------------------------------
    reg [15:0] bus_addr  = 16'hFFFF;
    reg [7:0]  cpu_dout  = 8'hFF;
    reg        bus_mreq_n = 1;
    reg        bus_wr_n   = 1;
    reg        bus_rd_n   = 1;

    // config quasi-estatica (megaram3 activa, slot correcto: como en el MSXnano)
    reg [1:0]  map_sel = 2'b10;     // modo SCC (SWIO smart cmd #0F / menu)

    // ------------------------------------------------------------------
    // DUT 1: glue (EL MISMO fichero que usa top.v; a 54M como top.v)
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
    // DUT 2: chip SCC GENERADO POR GHDL, config EXACTA de top.v:1951
    // (clk_27m + clk_enable_3m6_27, v3.4/_44)
    // ------------------------------------------------------------------
    wire [7:0]  scc_dout;
    wire [14:0] scc_wav;
    wire        dbg_ptr_lsb_w;      // _49dbg: LSB del puntero de onda ch.A
    wire        dbg_scan_lsb_w;     // _51dbg: ff_ch_num(0), escaneo a reloj pleno
    wire        dbg_mix_nz_w;       // _51dbg: ff_mix /= 0
    wire        dbg_wavlatch_w;     // _52dbg: togglea en cada captura de ff_wave
    wire        dbg_capnz_w;        // _53dbg: la ultima captura fue con ff_mix /= 0
    wire        dbg_wave_nz_w;      // _53dbg: ff_wave (registro interno) /= 0
    wire        dbg_mix5_nz_w;      // _54dbg: ff_mix /= 0 en el slot dl==101

    scc_wave2 SccCh (
        .clk21m (clk27),
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_27),
        .req (scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav),
        .sccplus (scc_mode_plus),
        .dbg_ptr_lsb (dbg_ptr_lsb_w),
        .dbg_scan_lsb (dbg_scan_lsb_w),
        .dbg_mix_nz (dbg_mix_nz_w),
        .dbg_wavlatch (dbg_wavlatch_w),
        .dbg_capnz (dbg_capnz_w),
        .dbg_wave_nz (dbg_wave_nz_w),
        .dbg_mix5_nz (dbg_mix5_nz_w)
        // dbg_vol_nz / dbg_sel_nz / dbg_freq_nz sin conectar
    );

    // ------------------------------------------------------------------
    // DUT 3: megaram_scc (regs de modo SCC-I: BFFE, bank3). Alimentado con
    // el request general de megaram, replica de top.v (gates=1), a 54M.
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
    // (top.v): scc_term = SCC solo en modo SCC (no Konami4/ASCII)
    wire [7:0]  cpu_din   = ( scc_rd_r == 1 ) ? scc_dout : 8'hFF;
    wire [15:0] scc_term  = ( map_sel == 2'b10 ) ? { scc_wav, 1'b0 } : 16'd0;

    // ------------------------------------------------------------------
    // tareas de ciclo de bus (3 T-states de 3.6MHz + 1 T idle), a cadencia
    // del cen_27 REAL (el CPU de top.v corre con clk_enable_3m6_27)
    // ------------------------------------------------------------------
    task at_rise; begin
        @(posedge clk27);
        while (clk_enable_3m6_27 !== 1'b1) @(posedge clk27);
    end endtask

    task at_fall; begin
        @(posedge clk27);
        while (clk_falling_3m6_27 !== 1'b1) @(posedge clk27);
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
    // monitor del wave: min/max, transiciones (histeresis +-500), periodo,
    // CAMBIOS DE VALOR de scc_wav y toggles de dbg_ptr_lsb (avance puntero)
    // ------------------------------------------------------------------
    wire signed [15:0] wav_s = { scc_wav[14], scc_wav };

    reg mon_en = 0;
    reg mon_state = 0;
    integer mon_min, mon_max, mon_trans, mon_rises;
    integer mon_changes;            // cambios de VALOR de scc_wav (sin histeresis)
    reg signed [15:0] wav_prev;
    integer term_viol;              // scc_term inconsistente con el gate
    realtime mon_rise_first, mon_rise_last;

    always @(posedge clk54) begin
        if (mon_en) begin
            if (wav_s > mon_max) mon_max = wav_s;
            if (wav_s < mon_min) mon_min = wav_s;
            if (wav_s !== wav_prev) mon_changes = mon_changes + 1;
            wav_prev = wav_s;
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

    // sondas _49dbg/_51dbg (dominio 27M del chip): toggles del puntero,
    // toggles del escaneo y duty del acumulador /= 0
    integer ptr_toggles;
    reg ptr_prev;
    integer scan_toggles;
    reg scan_prev;
    integer mix_nz_cnt, mon_cycles27;
    integer wavlatch_toggles;
    reg wavlatch_prev;
    integer capnz_cnt, wave_nz_cnt, mix5_nz_cnt;
    always @(posedge clk27) begin
        if (mon_en) begin
            mon_cycles27 = mon_cycles27 + 1;
            if (dbg_ptr_lsb_w !== ptr_prev) ptr_toggles = ptr_toggles + 1;
            ptr_prev = dbg_ptr_lsb_w;
            if (dbg_scan_lsb_w !== scan_prev) scan_toggles = scan_toggles + 1;
            scan_prev = dbg_scan_lsb_w;
            if (dbg_mix_nz_w === 1'b1) mix_nz_cnt = mix_nz_cnt + 1;
            if (dbg_wavlatch_w !== wavlatch_prev) wavlatch_toggles = wavlatch_toggles + 1;
            wavlatch_prev = dbg_wavlatch_w;
            if (dbg_capnz_w === 1'b1) capnz_cnt = capnz_cnt + 1;
            if (dbg_wave_nz_w === 1'b1) wave_nz_cnt = wave_nz_cnt + 1;
            if (dbg_mix5_nz_w === 1'b1) mix5_nz_cnt = mix5_nz_cnt + 1;
        end
    end

    task mon_start; begin
        mon_min = 99999; mon_max = -99999;
        mon_trans = 0; mon_rises = 0; mon_state = 0;
        mon_changes = 0; wav_prev = wav_s;
        ptr_toggles = 0; ptr_prev = dbg_ptr_lsb_w;
        scan_toggles = 0; scan_prev = dbg_scan_lsb_w;
        mix_nz_cnt = 0; mon_cycles27 = 0;
        wavlatch_toggles = 0; wavlatch_prev = dbg_wavlatch_w;
        capnz_cnt = 0; wave_nz_cnt = 0; mix5_nz_cnt = 0;
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
    // secuencia de test (IDENTICA a scc_tb.v + check N1 de avance)
    // ------------------------------------------------------------------
    integer i, errs;
    reg [7:0] rd;
    real period_meas, period_exp;

    initial begin
`ifdef DUMP
        $dumpfile("scc_tb_cen27.vcd");
        $dumpvars(0, scc_tb_cen27);
`endif
        // reset
        bus_reset_n = 0;
        repeat (40) @(posedge clk54);
        #2000;
        bus_reset_n = 1;
        #5000;

        $display("--- A. SCC compat (secuencia SCCTEST, map_sel=10, cen_27 REAL) ---");

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
        $display("  tono FD: min=%0d max=%0d trans=%0d changes=%0d ptr_toggles=%0d (esperado meseta +-1440)",
                 mon_min, mon_max, mon_trans, mon_changes, ptr_toggles);
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

        // NUEVO (ronda cen_27): prueba directa de que el puntero ch.A AVANZA.
        // Tono 0x020 -> avance cada 33 ticks de 3.6M ~ 109kHz: en 1.5ms se
        // esperan ~163 toggles de dbg_ptr_lsb y ~10 cambios de valor de
        // scc_wav (2 por ciclo de onda cuadrada; ~6800 cambios/s). El fallo
        // de placa (scc_wav CONGELADO en DC) daria 0 y 0.
        $display("  avance ch.A: %0d cambios de valor de scc_wav (~%0d/s), %0d toggles de dbg_ptr_lsb en 1.5ms",
                 mon_changes, mon_changes * 667, ptr_toggles);
        check("N1 puntero ch.A AVANZA (scc_wav cambia y dbg_ptr_lsb togglea)",
              (mon_changes >= 8) && (ptr_toggles >= 50));

        // NUEVO (_51dbg): calibracion de las sondas de la cadena interna.
        // dbg_scan_lsb debe togglear CADA ciclo de 27M (ff_ch_num avanza a
        // reloj pleno; sin accesos CPU en esta ventana -> ~100%); dbg_mix_nz
        // debe estar activo la mayor parte del tiempo con el tono sonando
        // (teorico 5/6 ~ 83%: solo cae a 0 en el slot de reset del scan).
        $display("  sondas _51dbg: scan_toggles=%0d de %0d ciclos27 (%0d%%), mix_nz activo %0d%% del tiempo",
                 scan_toggles, mon_cycles27,
                 (scan_toggles * 100) / mon_cycles27,
                 (mix_nz_cnt * 100) / mon_cycles27);
        check("N2 escaneo ff_ch_num VIVO (dbg_scan_lsb togglea cada ciclo)",
              scan_toggles > (mon_cycles27 * 9) / 10);
        check("N3 acumulador ff_mix ve senal (dbg_mix_nz activo con el tono)",
              mix_nz_cnt > mon_cycles27 / 2);

        // NUEVO (_52dbg): tasa de CAPTURA real del latch final ff_wave.
        // Sin el guard ce_dl (experimento _52) captura UNA vez por vuelta del
        // scan (ff_ch_num_dl==000 = 1 de cada 6 ciclos de 27M) => toggles
        // esperados = ciclos/6 (~4.5M capturas/s; aqui 40496/6 ~ 6749), CON o
        // SIN tono. Latch muerto = 0; ligado-a-accesos = ~0 (sin CPU aqui).
        $display("  sonda _52dbg: wavlatch_toggles=%0d (esperado ~%0d = ciclos27/6)",
                 wavlatch_toggles, mon_cycles27 / 6);
        check("N4 latch final CAPTURA a ritmo de scan (dbg_wavlatch ~ciclos/6)",
              (wavlatch_toggles > mon_cycles27 / 8) && (wavlatch_toggles < mon_cycles27 / 4));

        // NUEVO (_53dbg): contenido de la captura + registro de salida.
        // dbg_capnz = la ultima captura fue /= 0: con la onda CUADRADA del TB
        // (todas las muestras /= 0) debe ser '1' ~100% (en placa con la
        // sierra del beeper ~97% = 31/32, la muestra 0x00 captura cero).
        // dbg_wave_nz = ff_wave interno /= 0: idem ~100% aqui, ~97% sierra.
        // "Captura ceros" (sintoma _52 de placa) = ambos 0% fijo.
        $display("  sondas _53dbg: capnz=%0d%% wave_nz=%0d%% del tiempo (tono cuadrado: esperado ~100%%)",
                 (capnz_cnt * 100) / mon_cycles27,
                 (wave_nz_cnt * 100) / mon_cycles27);
        check("N5 la captura LLEVA senal y ff_wave la retiene (capnz+wave_nz)",
              (capnz_cnt > (mon_cycles27 * 9) / 10) && (wave_nz_cnt > (mon_cycles27 * 9) / 10));

        // NUEVO (_54dbg): la suma sigue viva en el ULTIMO slot de acumulacion
        // (dl==101). Con la onda cuadrada del TB: ~100% (sierra en placa
        // ~97%). Caso no-cura del fix _54: mix5_nz ON + capnz OFF confirma el
        // desvanecimiento dl5 -> dl0.
        $display("  sonda _54dbg: mix5_nz=%0d%% del tiempo (esperado ~100%% con tono cuadrado)",
                 (mix5_nz_cnt * 100) / mon_cycles27);
        check("N6 suma viva en dl==101 (dbg_mix5_nz activo con el tono)",
              mix5_nz_cnt > (mon_cycles27 * 9) / 10);

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
        $display("  SCC+: min=%0d max=%0d trans=%0d changes=%0d ptr_toggles=%0d",
                 mon_min, mon_max, mon_trans, mon_changes, ptr_toggles);
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
