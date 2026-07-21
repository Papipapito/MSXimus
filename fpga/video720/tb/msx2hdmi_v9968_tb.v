// ============================================================================
// msx2hdmi_v9968_tb.v — Testbench del puente V9968(85.9M, ce/2) → HDMI 720p
// (msx2hdmi_v9968.sv). Adaptado de msx2hdmi_tb.v (validado en placa).
//
// Compilar con -DSIM_NO_HDMI (contadores cx/cy conductuales).
//
// Modelo del V9968: hs/vs ACTIVOS ALTOS + blank(=~display_en) + rgb, con la
// geometria de salida real: lineas de 1365 pixeles-ce (2730 clocks de 85.909),
// 525 lineas/frame NTSC, 800 px activos desde HOFF, 480 lineas activas
// (240 nativas, pares identicos) desde VOFF. VS = 3 lineas, HS = 100 ce-px.
//
// Fases (PAL/50Hz APARCADO hasta medir la geometria real del V9968 a 50Hz):
//   0. NTSC 4:3  HOFF=100
//   1. NTSC 4:3  HOFF=400 (inmunidad al offset; 1365-800=565 max)
//   2. NTSC 16:9 HOFF=100 + scanlines ON (patron x3)
//
// Checks identicos al TB original: (a) geometria estricta contra patron
// r=x%64,g=y_nat%64,b=2A con referencia por division real xx=((cx-XW)*800)/AW,
// yy=(cy*240)/720; (b) carrera del ring (slot_last + wip + lag en [1,31]);
// (c) borde gris 101010; (d) scanlines rgb_out vs referencia cerrada.
// ============================================================================

`timescale 1ns/1ps

module msx2hdmi_v9968_tb;

    reg clk = 1'b0;        // 85.909 MHz
    reg clk_pixel = 1'b0;  // 74.25 MHz
    always #5.8207 clk       = ~clk;
    always #6.734  clk_pixel = ~clk_pixel;

    // pixel-enable: 1 de cada 2 ciclos de clk
    reg ce = 1'b0;
    always @(posedge clk) ce <= ~ce;

    reg        resetn   = 1'b0;
    reg        pal_mode = 1'b0;
    reg        aspect   = 1'b0;
    reg        scanln   = 1'b0;
    wire       hs_n, vs_n, blank;
    reg  [5:0] r, g, b;

    msx2hdmi_v9968 dut (
        .clk          (clk),
        .resetn       (resetn),
        .ce           (ce),
        .r            (r),
        .g            (g),
        .b            (b),
        .hs_n         (hs_n),
        .vs_n         (vs_n),
        .blank        (blank),
        .pal_mode     (pal_mode),
        .aspect_wide  (aspect),
        .scanlines    (scanln),
        .audio_l      (16'h1234),
        .audio_r      (16'h5678),
        .clk_pixel    (clk_pixel),
        .clk_5x_pixel (1'b0),
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
    // Modelo del V9968: hs/vs ALTOS + blank + rgb (contadores en ce-px)
    // ------------------------------------------------------------------
    integer LINE_PX, LINES, HOFF, VOFF, NAT;
    integer XW, AW;
    integer phase;
    initial begin
        LINE_PX = 1365; LINES = 525; HOFF = 100; VOFF = 40; NAT = 240;
        XW = 160; AW = 960;
        phase = 0;
    end

    reg        vdp_restart = 1'b0;
    reg [10:0] mcx   = 11'd0;      // pixel-ce dentro de la linea (0..1364)
    reg [9:0]  mline = 10'd0;
    always @(posedge clk) begin
        if (!resetn || vdp_restart) begin
            mcx   <= 11'd0;
            mline <= 10'd0;
        end else if (ce) begin
            if (mcx == LINE_PX-1) begin
                mcx   <= 11'd0;
                mline <= (mline == LINES-1) ? 10'd0 : mline + 10'd1;
            end else
                mcx <= mcx + 11'd1;
        end
    end

    wire vs_act_m = (mline < 3);
    wire hs_act_m = (mcx < 100);
    wire act_line = (mline >= VOFF) && (mline < VOFF + 2*NAT);
    wire act_pix  = act_line && !vs_act_m &&
                    (mcx >= HOFF) && (mcx < HOFF + 800);

    assign hs_n  = hs_act_m;        // V9968: ACTIVO ALTO
    assign vs_n  = vs_act_m;
    assign blank = ~act_pix;

    integer xi, ni;
    always @* begin
        r = 6'd0; g = 6'd0; b = 6'd0;
        if (act_pix) begin
            xi = mcx - HOFF;                 // x nativa 0..799
            ni = (mline - VOFF) / 2;
            r = xi % 64;
            g = ni % 64;
            b = 6'h2A;
        end
    end

    // ------------------------------------------------------------------
    // Modelo del escritor (en ce-px): completados, slots, toggle/lock
    // ------------------------------------------------------------------
    integer total_completed;
    integer frame_done;
    integer slot_last [0:31];
    integer base_pending;
    integer toggles_mode;
    integer k;

    initial begin
        total_completed = 0;
        frame_done      = 0;
        base_pending    = -1000000;
        toggles_mode    = 0;
        for (k = 0; k < 32; k = k + 1) slot_last[k] = -1000000;
    end

    always @(posedge clk) begin
        if (resetn && !vdp_restart && ce) begin
            if (mline == 0 && mcx == 0)
                frame_done = 0;
            // linea escrita ≈3 ce-px tras el ultimo pixel (HOFF+799) -> HOFF+803
            if (act_line && !vs_act_m && (((mline - VOFF) % 2) == 0) &&
                mcx == HOFF + 803) begin
                slot_last[((mline - VOFF) / 2) % 32] = total_completed;
                total_completed = total_completed + 1;
                frame_done      = frame_done + 1;
            end
            if (mline == VOFF + 6 && mcx == 0) begin
                toggles_mode = toggles_mode + 1;
                base_pending = total_completed - frame_done;
            end
        end
    end

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
    // Checks
    // ------------------------------------------------------------------
    reg     checking = 1'b0;

    integer geo_err = 0;
    integer race_err = 0;
    integer border_err = 0;
    integer border_checks = 0;

    integer lagmin  [0:2], lagmax  [0:2];
    integer rlagmin [0:2], rlagmax [0:2];
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

    // -------- d) scanlines: V9968 = patron x3 en TODOS los modos --------
    integer scan_err = 0, scan_checks = 0, scan_dim_checks = 0;
    reg        dim_ref;
    reg [23:0] exp_out;

    always @(negedge clk_pixel) begin
        if (checking && locks_mode >= 2 && rbase >= 0 && dut.cy < 720) begin
            dim_ref = scanln && ((dut.cy % 3) == 2);
            exp_out = dim_ref ? {1'b0, dut.rgb[23:17],
                                 1'b0, dut.rgb[15:9],
                                 1'b0, dut.rgb[7:1]}
                              : dut.rgb;
            if (dut.rgb_out !== exp_out) begin
                scan_err = scan_err + 1;
                if (scan_err <= 10)
                    $display("SCAN ERR @%0t ns: fase=%0d cx=%0d cy=%0d dim_ref=%b rgb=%h exp=%h got=%h",
                             $time, phase, dut.cx, dut.cy, dim_ref, dut.rgb, exp_out, dut.rgb_out);
            end
            scan_checks = scan_checks + 1;
            if (dim_ref) scan_dim_checks = scan_dim_checks + 1;
        end
    end

    always @(negedge clk_pixel) begin
        if (checking && locks_mode >= 2 && rbase >= 0) begin
            cxv = dut.cx;
            cyv = dut.cy;
            if (cyv < 720 && cxv >= XW && cxv < XW + AW) begin
                if ((((cxv - XW) % 7) == 0) || (aspect && (cxv - XW) < 4)) begin
                    ip     = cxv - XW;
                    xx_ref = aspect ? (ip * 3) / 4 : (ip * 800) / AW;  // _127C: wide = x4/3 exacto
                    yy_ref = (cyv * NAT) / 720;

                    // -------- a) geometria / patron --------
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
                    if (total_completed < rbase + NAT) begin
                        if (lag < rlagmin[phase]) rlagmin[phase] = lag;
                        if (lag > rlagmax[phase]) rlagmax[phase] = lag;
                    end else
                        ntail[phase] = ntail[phase] + 1;
                end
            end else if (cyv < 720 &&
                         ((cxv > 8 && cxv < 152) || (cxv > 1128 && cxv < 1640))) begin
                // -------- c) borde --------
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
    initial begin
        resetn = 1'b0;
        repeat (8) @(posedge clk);
        resetn = 1'b1;

        // ============ fase 0: NTSC 4:3, HOFF=100 ============
        checking = 1'b1;
        wait (toggles_mode == 5);
        checking = 1'b0;
        $display("V9968 NTSC A (HOFF=100): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
                 nchecks[0], lagmin[0], lagmax[0], lagmin_yy[0],
                 rlagmin[0], rlagmax[0], ntail[0], geo_err, race_err, border_err);

        // ============ fase 1: NTSC 4:3, HOFF=400 (offset) ============
        @(negedge clk);
        vdp_restart  = 1'b1;
        phase        = 1;
        HOFF         = 400;
        toggles_mode = 0; locks_mode = 0; rbase = -1; base_pending = -1000000;
        @(negedge clk); @(negedge clk);
        vdp_restart = 1'b0;

        checking = 1'b1;
        wait (toggles_mode == 4);
        checking = 1'b0;
        $display("V9968 NTSC B (HOFF=400): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
                 nchecks[1], lagmin[1], lagmax[1], lagmin_yy[1],
                 rlagmin[1], rlagmax[1], ntail[1], geo_err, race_err, border_err);

        // ============ fase 2: NTSC 16:9 + scanlines ============
        @(negedge clk);
        vdp_restart  = 1'b1;
        phase        = 2;
        aspect       = 1'b1;
        scanln       = 1'b1;
        XW           = 107; AW = 1066;  // _127C: pixel-perfecto centrado
        HOFF         = 100;
        toggles_mode = 0; locks_mode = 0; rbase = -1; base_pending = -1000000;
        @(negedge clk); @(negedge clk);
        vdp_restart = 1'b0;

        checking = 1'b1;
        wait (toggles_mode == 4);
        checking = 1'b0;
        $display("V9968 NTSC 16:9+scan (HOFF=100): checks=%0d lag=[%0d..%0d] (min yy=%0d) rampa=[%0d..%0d] tail=%0d  geo=%0d race=%0d bord=%0d",
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
        if (scan_err > 0 || scan_dim_checks < 10000) begin
            $display("FAIL: scan_err=%0d scan_dim_checks=%0d", scan_err, scan_dim_checks);
            $fatal(1, "TB FAILED");
        end
        $display("*** V9968 BRIDGE TB: ALL PASS (borde=%0d, scan=%0d/%0d dim) ***",
                 border_checks, scan_dim_checks, scan_checks);
        $finish;
    end

    initial begin
        #900000000;  // 900 ms
        $display("TIMEOUT: toggles=%0d locks=%0d fase=%0d", toggles_mode, locks_mode, phase);
        $fatal(1, "TB TIMEOUT");
    end

endmodule
