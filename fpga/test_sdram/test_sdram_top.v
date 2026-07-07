// ============================================================================
//  test_sdram_top.v — AUTO-TEST de SDRAM en placa, resultado por HDMI + LEDs
// ----------------------------------------------------------------------------
//  PANTALLA:  AZUL = test en curso · VERDE = PASS (bucle infinito sin errores)
//             ROJO = errores en el puerto CPU · MAGENTA = errores en VRAM
//  PMOD1 (LEDs activos-bajo): 1=PASS(fijo) · 2=FALLO CPU · 3=FALLO VRAM ·
//             4=latido de pasadas (~cada 0.5-1s) · resto apagados
// ============================================================================
`define GW_IDE

module top (
    input  wire ex_clk_27m,        // 50 MHz (V22)

    // SDRAM (modulo Tang SDRAM)
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n,
    output wire O_sdram_cas_n,
    output wire O_sdram_ras_n,
    output wire O_sdram_wen_n,
    inout  wire [15:0] IO_sdram_dq,
    output wire [12:0] O_sdram_addr,
    output wire [1:0]  O_sdram_ba,
    output wire [1:0]  O_sdram_dqm,

    // HDMI
    output wire [2:0] data_p,
    output wire [2:0] data_n,
    output wire clk_p,
    output wire clk_n,

    // debug
    output wire [5:0] dbg_pmod1
);

    // ---- relojes (mismas instancias que el core) ----
    wire clk_108m, clk_54m, clk_27m, clk_135, clock_locked;
    Gowin_PLL pll_main (
        .clkin  (ex_clk_27m),
        .clkout0(clk_108m),
        .clkout1(clk_54m),
        .clkout2(),
        .clkout3(clk_135),
        .lock   (clock_locked),
        .mdclk  (ex_clk_27m)
    );
    CLKDIV #(.DIV_MODE(5)) div5_video (
        .CLKOUT(clk_27m),
        .HCLKIN(clk_135),
        .RESETN(1'b1),
        .CALIB(1'b0)
    );

    // ---- POR ----
    reg [15:0] por_cnt = 0;
    wire       rst_n = &por_cnt;
    always @(posedge clk_54m) begin
        if (!clock_locked)   por_cnt <= 0;
        else if (~&por_cnt)  por_cnt <= por_cnt + 1'b1;
    end

    // ---- tester ----
    wire [1:0]  t_status;
    wire        t_pass_tick;
    wire [15:0] t_err_cpu, t_err_vram;
    sdram_tester #(.SDCLK_INVERT(1'b0)) tester (   // (la variante _17 se construye con 1'b1)
        .clk_108m(clk_108m), .clk_54m(clk_54m), .rst_n(rst_n),
        .O_sdram_clk(O_sdram_clk), .O_sdram_cke(O_sdram_cke),
        .O_sdram_cs_n(O_sdram_cs_n), .O_sdram_cas_n(O_sdram_cas_n),
        .O_sdram_ras_n(O_sdram_ras_n), .O_sdram_wen_n(O_sdram_wen_n),
        .IO_sdram_dq(IO_sdram_dq), .O_sdram_addr(O_sdram_addr),
        .O_sdram_ba(O_sdram_ba), .O_sdram_dqm(O_sdram_dqm),
        .status(t_status), .pass_tick(t_pass_tick),
        .err_cpu(t_err_cpu), .err_vram(t_err_vram)
    );

    // ---- HDMI: color plano por estado ----
    localparam AUDIO_RATE = 44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam NUM_CHANNELS = 3;
    localparam NTSC_Y = 525-45;

    wire clk_audio;
    CLOCK_DIV #(.CLK_SRC(27), .CLK_DIV(0.044100), .PRECISION_BITS(16)) audioclkd (
        .clk_src(clk_27m), .clk_div(clk_audio));
    wire [15:0] audio_zero [1:0];
    assign audio_zero[0] = 16'd0;
    assign audio_zero[1] = 16'd0;

    reg [23:0] rgb;
    always @(posedge clk_27m) begin
        case (t_status)
            2'd0: rgb <= 24'h0040C0;   // AZUL: corriendo
            2'd1: rgb <= 24'h00C020;   // VERDE: PASS
            2'd2: rgb <= 24'hE00000;   // ROJO: fallo CPU
            2'd3: rgb <= 24'hE000C0;   // MAGENTA: fallo VRAM
        endcase
    end

    logic [9:0] cx, cy;
    logic [9:0] tmds_internal [NUM_CHANNELS-1:0];
    hdmi #( .VIDEO_ID_CODE(2), .DVI_OUTPUT(0), .VIDEO_REFRESH_RATE(59.94),
            .IT_CONTENT(1), .AUDIO_RATE(AUDIO_RATE), .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}), .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
            .SOURCE_DEVICE_INFORMATION(8'h00), .START_X(0), .START_Y(NTSC_Y),
            .NUM_CHANNELS(NUM_CHANNELS))
    hdmi_test (
        .clk_pixel_x5(clk_135), .clk_pixel(clk_27m), .clk_audio(clk_audio),
        .rgb(rgb), .reset(~rst_n), .audio_sample_word(audio_zero),
        .aspect_16_9(1'b0), .cx(cx), .cy(cy), .tmds_internal(tmds_internal));

    logic [2:0] tmds;
    serializer #(.NUM_CHANNELS(NUM_CHANNELS), .VIDEO_RATE(0)) serializer(
        .clk_pixel(clk_27m), .clk_pixel_x5(clk_135), .reset(~rst_n),
        .tmds_internal(tmds_internal), .tmds(tmds));

    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_27m, tmds}),
        .O({clk_p, data_p}),
        .OB({clk_n, data_n})
    );

    // ---- LEDs (activos a nivel bajo: ON = pin 0) ----
    reg [5:0] pass_div = 0;
    always @(posedge clk_54m) if (t_pass_tick) pass_div <= pass_div + 1'b1;
    assign dbg_pmod1[0] = ~(t_status == 2'd1);   // ON = PASS
    assign dbg_pmod1[1] = ~(t_status == 2'd2);   // ON = FALLO CPU
    assign dbg_pmod1[2] = ~(t_status == 2'd3);   // ON = FALLO VRAM
    assign dbg_pmod1[3] = pass_div[0];           // toggle por pasada (parpadea)
    assign dbg_pmod1[4] = 1'b1;
    assign dbg_pmod1[5] = 1'b1;

endmodule
