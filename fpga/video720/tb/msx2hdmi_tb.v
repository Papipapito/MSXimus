// ============================================================================
// msx2hdmi_tb.v — Testbench del puente VDP(27M) → HDMI 720p (msx2hdmi.sv v2,
// captura auto-cronometrada con hs_n/vs_n/blank)
//
// Compilar con -DSIM_NO_HDMI: las instancias hdmi/serializer/ELVDS del DUT se
// sustituyen por contadores cx/cy conductuales (NTSC 1650×750, PAL 1980×750,
// reset síncrono a (0,720) por hdmi_rst). Aquí se verifica SOLO la lógica del
// puente: captura auto-alineada, ring de 32 líneas, lock y escalado.
//
// Modelo del VDP: emite SOLO hs_n/vs_n/blank/rgb con la geometría de salida
// real del doubler y offsets ARBITRARIOS del área activa (el diseño debe ser
// inmune a ellos):
//   NTSC: líneas de 858 clocks @27M, 525 líneas/frame, 720 px activos desde
//         el clock HOFF, 480 líneas activas (240 nativas, pares idénticos)
//         desde la línea 40. VS = 3 líneas, HS = 64 clocks.
//   PAL : 864 clocks/línea, 625 líneas, 576 activas desde la 46 (288 nativas).
//
// Fases:
//   0. NTSC HOFF=100 (4 frames tras el 1er toggle, 3 checkeados)
//   1. NTSC HOFF=130 — inmunidad al offset horizontal: mismos checks
//      ESTRICTOS deben pasar sin tocar nada. (La spec pedía 140, pero no
//      cabe: 858-720 = 138 máx → se usa 130.)
//   2. PAL  HOFF=100 (todas las 288 nativas caben: 46+576 = 622 ≤ 625,
//      sin alias)
//
// Checks (contadores de error, $fatal al final si >0):
//  a. GEOMETRÍA estricta contra el patrón r=x[5:0], g=y_nativa[5:0], b=0x2A,
//     con referencia independiente por división real:
//        xx = ((cx-160)*720)/960,  yy = (cy*N)/720   (N = 240/288)
//  b. CARRERA DEL RING: slot_last por slot + writer-in-progress + cota
//     lag = líneas_completadas - línea_esperada ∈ [1,31]; lag mín/máx por
//     fase, y rampa (escritor aún en frame) con margen ≥2 → [3,29].
//  c. BORDE: fuera de la ventana activa rgb debe ser 24'h101010 (muestreado).
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
    reg        resetn   = 1'b0;
    reg        pal_mode = 1'b0;
    wire       hs_n, vs_n, blank;
    reg  [5:0] r, g, b;

    msx2hdmi dut (
        .clk          (clk),
        .resetn       (resetn),
        .r            (r),
        .g            (g),
        .b            (b),
        .hs_n         (hs_n),
        .vs_n         (vs_n),
        .blank        (blank),
        .pal_mode     (pal_mode),
        .audio_l      (16'h1234),
        .audio_r      (16'h5678),
        .clk_pixel    (clk_pixel),
        .clk_5x_pixel (1'b0),          // no usado con SIM_NO_HDMI
        .tmds_clk_n   (),
        .tmds_clk_p   (),
        .tmds_d_n     (),
        .tmds_d_p     (),
        .dbg_vs_tick  (),
        .dbg_wr_act   (),
        .dbg_nonblack (),
        .dbg_lock_tgl (),
        .dbg_hdmi_rst (),
        .dbg_rd_act   ()
    );

    // ------------------------------------------------------------------
    // Modelo del VDP: solo hs_n / vs_n / blank / rgb
    // ------------------------------------------------------------------
    integer LINE_CLKS, LINES, HOFF, VOFF, NAT;
    integer phase;                       // 0/1 = NTSC, 2 = PAL
    initial begin
        LINE_CLKS = 858; LINES = 525; HOFF = 100; VOFF = 40; NAT = 240;
        phase = 0;
    end

    reg        vdp_restart = 1'b0;
    reg [10:0] mcx   = 11'd0;
    reg [9:0]  mline = 10'd0;
    always @(posedge clk) begin
        if (!resetn || vdp_restart) begin
            mcx   <= 11'd0;
            mline <= 10'd0;
        end else if (mcx == LINE_CLKS-1) begin
            mcx   <= 11'd0;
            mline <= (mline == LINES-1) ? 10'd0 : mline + 10'd1;
        end else
            mcx <= mcx + 11'd1;
    end

    wire vs_act_m = (mline < 3);                 // VS: 3 líneas de salida
    wire hs_act_m = (mcx < 64);                  // HS: 64 clocks por línea
    wire act_line = (mline >= VOFF) && (mline < VOFF + 2*NAT);
    wire act_pix  = act_line && !vs_act_m &&
                    (mcx >= HOFF) && (mcx < HOFF + 720);

    assign hs_n  = ~hs_act_m;                    // activo BAJO
    assign vs_n  = ~vs_act_m;                    // activo BAJO
    assign blank = ~act_pix;                     // 1 = blanking

    integer xi, ni;
    always @* begin
        r = 6'd0; g = 6'd0; b = 6'd0;
        if (act_pix) begin
            xi = mcx - HOFF;                     // x nativa 0..719
            ni = (mline - VOFF) / 2;             // línea nativa (par idéntico)
            r = xi % 64;
            g = ni % 64;
            b = 6'h2A;
        end
    end

    // ------------------------------------------------------------------
    // Modelo del escritor: completado de líneas, slots y toggle/lock
    // ------------------------------------------------------------------
    integer total_completed;             // líneas nativas completadas (global)
    integer frame_done;                  // completadas en el frame actual
    integer slot_last [0:31];            // idx global de la última línea por slot
    integer base_pending;                // idx global de la línea 0 del frame lockeado
    integer toggles_mode;                // toggles de la fase actual
    integer k;

    initial begin
        total_completed = 0;
        frame_done      = 0;
        base_pending    = -1000000;
        toggles_mode    = 0;
        for (k = 0; k < 32; k = k + 1) slot_last[k] = -1000000;
    end

    always @(posedge clk) begin
        if (resetn && !vdp_restart) begin
            if (mline == 0 && mcx == 0)
                frame_done = 0;
            // el DUT tiene escrita la línea (pipeline entrada+escritura ≈ 3
            // clocks tras el último píxel en HOFF+719) en HOFF+723
            if (act_line && !vs_act_m && (((mline - VOFF) % 2) == 0) &&
                mcx == HOFF + 723) begin
                slot_last[((mline - VOFF) / 2) % 32] = total_completed;
                total_completed = total_completed + 1;
                frame_done      = frame_done + 1;
            end
            // instante del toggle del DUT: inicio de la línea y0+LOCK_LINES
            // (y0 = VOFF en este modelo; se registra ANTES del toggle real,
            // que ocurre en mcx≈2 de esa línea)
            if (mline == VOFF + 6 && mcx == 0) begin
                toggles_mode = toggles_mode + 1;
                base_pending = total_completed - frame_done;
            end
        end
    end

    // Escritor en curso (para detectar lectura de un slot a medio escribir)
    wire    wr_wip = resetn && !vdp_restart && act_line && !vs_act_m &&
                     (((mline - VOFF) % 2) == 0);
    integer wip_slot;
    always @* wip_slot = ((mline - VOFF) / 2) % 32;

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

    integer geo_err = 0;
    integer race_err = 0;
    integer border_err = 0;
    integer border_checks = 0;

    integer lagmin  [0:2], lagmax  [0:2];     // absoluto por fase
    integer rlagmin [0:2], rlagmax [0:2];     // rampa (escritor en frame)
    integer nchecks [0:2], ntail   [0:2], lagmin_yy [0:2];
    initial begin
        for (k = 0; k < 3; k = k + 1) begin
            lagmin[k]  = 1000; lagmax[k]  = -1000;
            rlagmin[k] = 1000; rlagmax[k] = -1000;
            nchecks[k] = 0;    ntail[k]   = 0;    lagmin_yy[k] = -1;
        end
    end

    integer cxv, cyv, ip, xx_ref, yy_ref, gexp, lag;
    reg [5:0]  xr6, nr6;
    reg [23:0] exp_rgb;

    always @(negedge clk_pixel) begin
        if (checking && locks_mode >= 2 && rbase >= 0) begin
            cxv = dut.cx;
            cyv = dut.cy;
            if (cyv < 720 && cxv >= 160 && cxv < 1120) begin
                if (((cxv - 160) % 7) == 0) begin
                    // referencia independiente con división real
                    ip     = cxv - 160;
                    xx_ref = (ip * 720) / 960;
                    yy_ref = (cyv * NAT) / 720;

                    // -------- a) geometría / patrón --------
                    xr6 = xx_ref % 64;
                    nr6 = yy_ref % 64;
                    exp_rgb = {xr6, 2'b00, nr6, 2'b00, 6'h2A, 2'b00};
                    if (dut.rgb !== exp_rgb) begin
                        geo_err = geo_err + 1;
                        if (geo_err <= 10)
                            $display("GEO  ERR @%0t ns: fase=%0d cx=%0d cy=%0d exp=%h got=%h (xx=%0d yy=%0d)",
                                     $time, phase, cxv, cyv, exp_rgb, dut.rgb, xx_ref, yy_ref);
                    end

                    // -------- b) carrera del ring --------
                    gexp = rbase + yy_ref;
                    lag  = total_completed - gexp;
                    // check directo por slot: la última línea completada en
                    // el slot debe ser EXACTAMENTE la esperada, y el escritor
                    // no debe estar escribiendo ese slot ahora mismo
                    if (slot_last[yy_ref % 32] != gexp ||
                        (wr_wip && wip_slot == (yy_ref % 32))) begin
                        race_err = race_err + 1;
                        if (race_err <= 10)
                            $display("RACE ERR @%0t ns: fase=%0d cy=%0d yy=%0d gexp=%0d slot_last=%0d lag=%0d wip=%b",
                                     $time, phase, cyv, yy_ref, gexp, slot_last[yy_ref % 32], lag, wr_wip);
                    end
                    if (lag < 1 || lag > 31) begin
                        race_err = race_err + 1;
                        if (race_err <= 10)
                            $display("LAG  ERR @%0t ns: fase=%0d cy=%0d yy=%0d lag=%0d fuera de [1,31]",
                                     $time, phase, cyv, yy_ref, lag);
                    end
                    nchecks[phase] = nchecks[phase] + 1;
                    if (lag < lagmin[phase]) begin
                        lagmin[phase]    = lag;
                        lagmin_yy[phase] = yy_ref;
                    end
                    if (lag > lagmax[phase]) lagmax[phase] = lag;
                    if (total_completed < rbase + NAT) begin  // escritor en frame
                        if (lag < rlagmin[phase]) rlagmin[phase] = lag;
                        if (lag > rlagmax[phase]) rlagmax[phase] = lag;
                    end else
                        ntail[phase] = ntail[phase] + 1;
                end
            end else if (cyv < 720 &&
                         ((cxv > 8 && cxv < 152) || (cxv > 1128 && cxv < 1640))) begin
                // -------- c) borde: gris fijo fuera de la ventana --------
                if ((cxv % 131) == 0) begin
                    border_checks = border_checks + 1;
                    if (dut.rgb !== 24'h101010) begin
                        border_err = border_err + 1;
                        if (border_err <= 10)
                            $display("BORD ERR @%0t ns: fase=%0d cx=%0d cy=%0d got=%h",
                                     $time, phase, cxv, cyv, dut.rgb);
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Secuencia principal
    // ------------------------------------------------------------------
    integer ph;
    initial begin
        resetn = 1'b0;
        repeat (8) @(posedge clk);
        resetn = 1'b1;

        // ============ fase 0: NTSC, HOFF=100 (4 frames) ============
        checking = 1'b1;
        wait (toggles_mode == 5);
        checking = 1'b0;
        $display("NTSC A (HOFF=100): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
                 nchecks[0], lagmin[0], lagmax[0], lagmin_yy[0],
                 rlagmin[0], rlagmax[0], ntail[0], geo_err, race_err, border_err);

        // ============ fase 1: NTSC, HOFF=130 (inmunidad al offset) ============
        @(negedge clk);
        vdp_restart  = 1'b1;
        phase        = 1;
        HOFF         = 130;   // la spec pedia 140: no cabe (858-720=138 max)
        toggles_mode = 0; locks_mode = 0; rbase = -1; base_pending = -1000000;
        @(negedge clk); @(negedge clk);
        vdp_restart = 1'b0;

        checking = 1'b1;
        wait (toggles_mode == 4);
        checking = 1'b0;
        $display("NTSC B (HOFF=130): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
                 nchecks[1], lagmin[1], lagmax[1], lagmin_yy[1],
                 rlagmin[1], rlagmax[1], ntail[1], geo_err, race_err, border_err);

        // ============ fase 2: PAL, HOFF=100 (4 frames) ============
        @(negedge clk);
        vdp_restart  = 1'b1;
        phase        = 2;
        pal_mode     = 1'b1;
        LINE_CLKS    = 864; LINES = 625; HOFF = 100; VOFF = 46; NAT = 288;
        toggles_mode = 0; locks_mode = 0; rbase = -1; base_pending = -1000000;
        @(negedge clk); @(negedge clk);
        vdp_restart = 1'b0;

        checking = 1'b1;
        wait (toggles_mode == 5);
        checking = 1'b0;
        $display("PAL    (HOFF=100): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
                 nchecks[2], lagmin[2], lagmax[2], lagmin_yy[2],
                 rlagmin[2], rlagmax[2], ntail[2], geo_err, race_err, border_err);

        // ============ veredicto ============
        if (nchecks[0] < 100000 || nchecks[1] < 100000 || nchecks[2] < 100000) begin
            $display("FAIL: muy pocos checks (%0d/%0d/%0d) - gating roto",
                     nchecks[0], nchecks[1], nchecks[2]);
            $fatal(1, "TB FAILED");
        end
        if (geo_err + race_err + border_err > 0) begin
            $display("FAIL: geo_err=%0d race_err=%0d border_err=%0d",
                     geo_err, race_err, border_err);
            $fatal(1, "TB FAILED");
        end
        // margen >=2 por ambos lados de [1,31] sobre el lag de rampa (lo que
        // controla LOCK_LINES; el minimo absoluto satura a fin de frame con
        // el escritor ya parado = caso seguro, verificado por el check de slot)
        for (ph = 0; ph < 3; ph = ph + 1) begin
            if (rlagmin[ph] < 3 || rlagmax[ph] > 29) begin
                $display("FAIL: rampa fase %0d = [%0d..%0d] sin margen >=2 - ajustar LOCK_LINES",
                         ph, rlagmin[ph], rlagmax[ph]);
                $fatal(1, "TB FAILED");
            end
        end
        $display("ALL TESTS PASS");
        $display("  NTSC lag rampa=[%0d..%0d] (HOFF=100) y [%0d..%0d] (HOFF=130); abs min=%0d en yy=%0d (fin de frame, escritor parado = seguro)",
                 rlagmin[0], rlagmax[0], rlagmin[1], rlagmax[1], lagmin[0], lagmin_yy[0]);
        $display("  PAL  lag rampa=[%0d..%0d]; abs=[%0d..%0d] (min en yy=%0d)",
                 rlagmin[2], rlagmax[2], lagmin[2], lagmax[2], lagmin_yy[2]);
        $display("  Inmunidad al offset horizontal verificada: fases A (HOFF=100) y B (HOFF=130) pasan los mismos checks estrictos.");
        $finish;
    end

    // Watchdog
    initial begin
        #450_000_000;
        $fatal(1, "TIMEOUT: la simulacion no termino");
    end

endmodule
