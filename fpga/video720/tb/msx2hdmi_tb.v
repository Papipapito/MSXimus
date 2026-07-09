// ============================================================================
// msx2hdmi_tb.v — Testbench del puente VDP(27M) → HDMI 720p (msx2hdmi.sv)
//
// Compilar con -DSIM_NO_HDMI: las instancias hdmi/serializer/ELVDS del DUT se
// sustituyen por contadores cx/cy conductuales (NTSC 1650×750, PAL 1980×750,
// reset síncrono a (0,720) por hdmi_rst). Aquí se verifica SOLO la lógica del
// puente: captura, ring de 32 líneas, lock de frame y escalado.
//
// Checks (contadores de error, $fatal al final si >0):
//  a. GEOMETRÍA: para cada píxel activo muestreado (cada 7 píxeles), el rgb
//     registrado corresponde al píxel nativo esperado, calculado
//     INDEPENDIENTEMENTE desde cx/cy con división real:
//        xx = ((cx-160)*720)/960,  yy = (cy*N)/720  (N=240 NTSC / 288 PAL)
//     y patrón r=x[5:0], g=y_nativa[5:0], b=0x2A.
//  b. CARRERA DEL RING: el TB modela el instante en que el escritor completa
//     cada (línea nativa, frame) [slot_last por slot + writer-in-progress] y
//     comprueba que ninguna lectura usa una línea aún no escrita en ese frame
//     ni una ya sobrescrita ni una en curso de escritura. Además impone
//     lag = líneas_completadas - línea_esperada ∈ [1,31] (lecturas normales)
//     y reporta lag mín/máx por modo.
//  c. PAL: líneas nativas 283..287 no existen (frame de 625 líneas, ver
//     cabecera del DUT): se verifica el alias determinista n-32 (mismo frame).
//  d. BORDE: fuera de la ventana activa rgb debe ser 24'h101010 (muestreado).
//
// NTSC: 4 frames (se comprueban los 3 últimos). PAL: ~4 frames (3 checkeados).
// ============================================================================

`timescale 1ns/1ps

module msx2hdmi_tb;

    // ------------------------------------------------------------------
    // Relojes: 27 MHz (37.037 ns) y 74.25 MHz (13.468 ns)
    // ------------------------------------------------------------------
    reg clk = 1'b0;
    reg clk_pixel = 1'b0;
    always #18.5185 clk       = ~clk;
    always #6.734   clk_pixel = ~clk_pixel;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    reg         resetn   = 1'b0;
    reg         pal_mode = 1'b0;
    reg  [10:0] vdp_cx   = 11'd0;
    reg  [10:0] vdp_cy   = 11'd0;
    reg  [5:0]  r, g, b;

    msx2hdmi dut (
        .clk          (clk),
        .resetn       (resetn),
        .r            (r),
        .g            (g),
        .b            (b),
        .vdp_cx       (vdp_cx),
        .vdp_cy       (vdp_cy),
        .pal_mode     (pal_mode),
        .audio_l      (16'h1234),
        .audio_r      (16'h5678),
        .clk_pixel    (clk_pixel),
        .clk_5x_pixel (1'b0),          // no usado con SIM_NO_HDMI
        .tmds_clk_n   (),
        .tmds_clk_p   (),
        .tmds_d_n     (),
        .tmds_d_p     ()
    );

    // ------------------------------------------------------------------
    // Modelo del VDP (contadores + patrón conocido)
    // ------------------------------------------------------------------
    integer H_TOTAL, V_TOTAL, Y0, N_NATIVE;
    initial begin
        H_TOTAL  = 858;   // NTSC
        V_TOTAL  = 525;
        Y0       = 45;
        N_NATIVE = 240;
    end

    reg vdp_restart = 1'b0;
    always @(posedge clk) begin
        if (!resetn || vdp_restart) begin
            vdp_cx <= 11'd0;
            vdp_cy <= 11'd0;
        end else if (vdp_cx == H_TOTAL-1) begin
            vdp_cx <= 11'd0;
            vdp_cy <= (vdp_cy == V_TOTAL-1) ? 11'd0 : vdp_cy + 11'd1;
        end else
            vdp_cx <= vdp_cx + 11'd1;
    end

    // Ventana visible (PAL: [60,636) truncada por el propio contador a 624)
    wire line_window = (vdp_cy >= Y0) && (vdp_cy < Y0 + 2*N_NATIVE) &&
                       (vdp_cy < V_TOTAL);
    wire visible   = line_window && (vdp_cx < 720);
    wire even_line = line_window && (((vdp_cy - Y0) % 2) == 0);

    integer ynat_w;
    always @* begin
        ynat_w = (vdp_cy - Y0) / 2;
        if (visible) begin
            r = vdp_cx[5:0];
            g = ynat_w[5:0];
            b = 6'h2A;
        end else begin
            r = 6'd0; g = 6'd0; b = 6'd0;
        end
    end

    // ------------------------------------------------------------------
    // Modelo del escritor: completado de líneas, slots y toggle/lock
    // ------------------------------------------------------------------
    integer total_completed;                 // líneas nativas completadas (global)
    integer slot_last [0:31];                // idx global de la última línea completada por slot
    integer base_pending;                    // idx global de la línea 0 del frame lockeado
    integer toggles_mode;                    // toggles del modo actual
    integer k;

    initial begin
        total_completed = 0;
        base_pending    = -1000000;
        toggles_mode    = 0;
        for (k = 0; k < 32; k = k + 1) slot_last[k] = -1000000;
    end

    always @(posedge clk) begin
        if (resetn && !vdp_restart) begin
            // la línea nativa se da por completa en vdp_cx==721 (cubre el
            // pipeline de escritura registrada + write BRAM del DUT)
            if (even_line && vdp_cx == 11'd721) begin
                slot_last[ynat_w % 32] = total_completed;  // idx 0-based de ESTA línea
                total_completed = total_completed + 1;
            end
            // instante del toggle (misma condición que el DUT)
            if (vdp_cy == 11'd50 && vdp_cx == 11'd0) begin
                toggles_mode = toggles_mode + 1;
                // NTSC: en el toggle ya hay 3 líneas del frame actual escritas
                // (vdp_cy 45/47/49). PAL: ninguna (60 > 50).
                base_pending = total_completed - (pal_mode ? 0 : 3);
            end
        end
    end

    // Escritor en curso (para detectar lectura de un slot a medio escribir)
    wire     wr_wip  = resetn && !vdp_restart && even_line && (vdp_cx <= 11'd723);
    integer  wip_slot;
    always @* wip_slot = ynat_w % 32;

    // ------------------------------------------------------------------
    // Lock del lector
    // ------------------------------------------------------------------
    integer rbase;
    integer locks_mode;
    initial begin
        rbase      = -1;
        locks_mode = 0;
    end

    always @(posedge clk_pixel) begin
        if (dut.hdmi_rst) begin
            rbase      = base_pending;
            locks_mode = locks_mode + 1;
        end
    end

    // ------------------------------------------------------------------
    // Checks (muestreo en negedge clk_pixel: señales estables a mitad de ciclo)
    // ------------------------------------------------------------------
    reg     checking = 1'b0;

    integer geo_err   = 0;
    integer race_err  = 0;
    integer border_err = 0;

    integer lagmin_ntsc, lagmax_ntsc, lagmin_pal, lagmax_pal;
    integer lagmin_alias, lagmax_alias;
    integer checks_ntsc, checks_pal, alias_reads, border_checks;
    // lag "de rampa": medido solo mientras el escritor sigue DENTRO del frame
    // (total < rbase + N). Tras acabar el escritor su frame, el lag absoluto
    // satura a N-yy (mínimo 1 en la última línea) pero es el caso MÁS seguro:
    // la próxima escritura del slot llega el frame siguiente. El margen ≥2
    // exigido se impone sobre la rampa, que es lo que LOCK_Y controla.
    integer rlagmin_ntsc, rlagmax_ntsc, rlagmin_pal, rlagmax_pal;
    integer lagmin_ntsc_yy, lagmin_pal_yy;   // en qué línea nativa ocurre el mínimo
    integer tail_ntsc, tail_pal;             // muestras post-fin-de-escritor
    initial begin
        lagmin_ntsc = 1000; lagmax_ntsc = -1000;
        lagmin_pal  = 1000; lagmax_pal  = -1000;
        lagmin_alias = 1000; lagmax_alias = -1000;
        rlagmin_ntsc = 1000; rlagmax_ntsc = -1000;
        rlagmin_pal  = 1000; rlagmax_pal  = -1000;
        lagmin_ntsc_yy = -1; lagmin_pal_yy = -1;
        tail_ntsc = 0; tail_pal = 0;
        checks_ntsc = 0; checks_pal = 0; alias_reads = 0; border_checks = 0;
    end

    integer cxv, cyv, ip, xx_ref, yy_ref, nat, gexp, lag;
    reg [5:0]  xr6, nr6;
    reg [23:0] exp_rgb;
    reg        is_alias;

    always @(negedge clk_pixel) begin
        if (checking && locks_mode >= 2 && rbase >= 0) begin
            cxv = dut.cx;
            cyv = dut.cy;
            if (cyv < 720 && cxv >= 160 && cxv < 1120) begin
                if (((cxv - 160) % 7) == 0) begin
                    // referencia independiente con división real
                    ip     = cxv - 160;
                    xx_ref = (ip * 720) / 960;
                    yy_ref = (cyv * (pal_mode ? 288 : 240)) / 720;
                    nat      = yy_ref;
                    is_alias = 1'b0;
                    if (pal_mode && yy_ref >= 283) begin
                        nat      = yy_ref - 32;   // alias determinista (ver DUT)
                        is_alias = 1'b1;
                        alias_reads = alias_reads + 1;
                    end

                    // -------- a) geometría / patrón --------
                    xr6 = xx_ref % 64;
                    nr6 = nat % 64;
                    exp_rgb = {xr6, 2'b00, nr6, 2'b00, 6'h2A, 2'b00};
                    if (dut.rgb !== exp_rgb) begin
                        geo_err = geo_err + 1;
                        if (geo_err <= 10)
                            $display("GEO  ERR @%0t ns: cx=%0d cy=%0d exp=%h got=%h (xx=%0d nat=%0d pal=%b)",
                                     $time, cxv, cyv, exp_rgb, dut.rgb, xx_ref, nat, pal_mode);
                    end

                    // -------- b) carrera del ring --------
                    gexp = rbase + nat;
                    lag  = total_completed - gexp;
                    // check directo por slot: la última línea completada en el
                    // slot debe ser EXACTAMENTE la esperada, y el escritor no
                    // debe estar escribiendo ese slot ahora mismo
                    if (slot_last[nat % 32] != gexp || (wr_wip && wip_slot == (nat % 32))) begin
                        race_err = race_err + 1;
                        if (race_err <= 10)
                            $display("RACE ERR @%0t ns: cy=%0d nat=%0d gexp=%0d slot_last=%0d lag=%0d wip=%b",
                                     $time, cyv, nat, gexp, slot_last[nat % 32], lag, wr_wip);
                    end
                    if (!is_alias) begin
                        // cota de la spec para lecturas normales
                        if (lag < 1 || lag > 31) begin
                            race_err = race_err + 1;
                            if (race_err <= 10)
                                $display("LAG  ERR @%0t ns: cy=%0d nat=%0d lag=%0d fuera de [1,31]",
                                         $time, cyv, nat, lag);
                        end
                        if (pal_mode) begin
                            checks_pal = checks_pal + 1;
                            if (lag < lagmin_pal) begin lagmin_pal = lag; lagmin_pal_yy = nat; end
                            if (lag > lagmax_pal) lagmax_pal = lag;
                            if (total_completed < rbase + 283) begin  // escritor en frame
                                if (lag < rlagmin_pal) rlagmin_pal = lag;
                                if (lag > rlagmax_pal) rlagmax_pal = lag;
                            end else
                                tail_pal = tail_pal + 1;
                        end else begin
                            checks_ntsc = checks_ntsc + 1;
                            if (lag < lagmin_ntsc) begin lagmin_ntsc = lag; lagmin_ntsc_yy = nat; end
                            if (lag > lagmax_ntsc) lagmax_ntsc = lag;
                            if (total_completed < rbase + 240) begin
                                if (lag < rlagmin_ntsc) rlagmin_ntsc = lag;
                                if (lag > rlagmax_ntsc) rlagmax_ntsc = lag;
                            end else
                                tail_ntsc = tail_ntsc + 1;
                        end
                    end else begin
                        if (lag < lagmin_alias) lagmin_alias = lag;
                        if (lag > lagmax_alias) lagmax_alias = lag;
                    end
                end
            end else if (cyv < 720 &&
                         ((cxv > 8 && cxv < 152) || (cxv > 1128 && cxv < 1640))) begin
                // -------- d) borde: gris fijo fuera de la ventana --------
                if ((cxv % 131) == 0) begin
                    border_checks = border_checks + 1;
                    if (dut.rgb !== 24'h101010) begin
                        border_err = border_err + 1;
                        if (border_err <= 10)
                            $display("BORD ERR @%0t ns: cx=%0d cy=%0d got=%h",
                                     $time, cxv, cyv, dut.rgb);
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Secuencia principal
    // ------------------------------------------------------------------
    initial begin
        resetn = 1'b0;
        repeat (8) @(posedge clk);
        resetn = 1'b1;

        // ================= NTSC: 4 frames =================
        checking = 1'b1;
        wait (toggles_mode == 5);        // 4 frames tras el 1er toggle
        checking = 1'b0;
        $display("NTSC: checks=%0d  lag=[%0d..%0d] (min en yy=%0d)  rampa=[%0d..%0d] tail=%0d  geo_err=%0d race_err=%0d border_err=%0d (border_checks=%0d)",
                 checks_ntsc, lagmin_ntsc, lagmax_ntsc, lagmin_ntsc_yy,
                 rlagmin_ntsc, rlagmax_ntsc, tail_ntsc,
                 geo_err, race_err, border_err, border_checks);

        // ================= cambio a PAL =================
        @(negedge clk);
        vdp_restart  = 1'b1;
        pal_mode     = 1'b1;
        H_TOTAL      = 864;
        V_TOTAL      = 625;
        Y0           = 60;
        N_NATIVE     = 288;
        toggles_mode = 0;
        locks_mode   = 0;
        rbase        = -1;
        base_pending = -1000000;
        @(negedge clk);
        @(negedge clk);
        vdp_restart = 1'b0;

        // ================= PAL: ~4 frames (3 checkeados) =================
        checking = 1'b1;
        wait (toggles_mode == 5);
        checking = 1'b0;
        $display("PAL : checks=%0d  lag=[%0d..%0d] (min en yy=%0d)  rampa=[%0d..%0d] tail=%0d  alias=%0d lag_alias=[%0d..%0d]",
                 checks_pal, lagmin_pal, lagmax_pal, lagmin_pal_yy,
                 rlagmin_pal, rlagmax_pal, tail_pal,
                 alias_reads, lagmin_alias, lagmax_alias);

        // ================= veredicto =================
        if (checks_ntsc < 100000 || checks_pal < 100000) begin
            $display("FAIL: muy pocos checks (ntsc=%0d pal=%0d) - gating roto", checks_ntsc, checks_pal);
            $fatal(1, "TB FAILED");
        end
        if (geo_err + race_err + border_err > 0) begin
            $display("FAIL: geo_err=%0d race_err=%0d border_err=%0d", geo_err, race_err, border_err);
            $fatal(1, "TB FAILED");
        end
        // margen >=2 por ambos lados de [1,31] sobre el lag de rampa (lo que
        // controla LOCK_Y; ver comentario en la declaracion de rlagmin_*)
        if (rlagmin_ntsc < 3 || rlagmax_ntsc > 29 ||
            rlagmin_pal  < 3 || rlagmax_pal  > 29) begin
            $display("FAIL: lag de rampa sin margen >=2: NTSC=[%0d..%0d] PAL=[%0d..%0d] - ajustar LOCK_Y",
                     rlagmin_ntsc, rlagmax_ntsc, rlagmin_pal, rlagmax_pal);
            $fatal(1, "TB FAILED");
        end
        $display("ALL TESTS PASS");
        $display("  NTSC lag_min=%0d lag_max=%0d (rampa [%0d..%0d]; el minimo absoluto ocurre en yy=%0d, fin de frame con escritor ya parado = caso seguro)",
                 lagmin_ntsc, lagmax_ntsc, rlagmin_ntsc, rlagmax_ntsc, lagmin_ntsc_yy);
        $display("  PAL  lag_min=%0d lag_max=%0d (rampa [%0d..%0d]; minimo en yy=%0d) (alias 283..287: lag=[%0d..%0d], %0d lecturas)",
                 lagmin_pal, lagmax_pal, rlagmin_pal, rlagmax_pal, lagmin_pal_yy,
                 lagmin_alias, lagmax_alias, alias_reads);
        $finish;
    end

    // Watchdog
    initial begin
        #350_000_000;
        $fatal(1, "TIMEOUT: la simulacion no termino");
    end

endmodule
