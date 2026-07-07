// ============================================================================
//  hdmi_test_top.v — TEST MÍNIMO de la salida HDMI en la Console 60K
// ----------------------------------------------------------------------------
//  Discriminador del bring-up: SOLO relojes (Gowin_PLL + CLKDIV÷5, idénticos al
//  core, MISMOS nombres de instancia para que el SDC case) + el pipeline HDMI
//  del tn_vdp (hdmi.sv con los MISMOS parámetros que hdmi_ntsc de v9958_top:
//  VIC=2/480p, audio 44.1k a cero) + serializer + ELVDS, pintando BARRAS de
//  color. Sin VDP, sin Z80, sin memoria.
//    - Barras → el fallo del core está DENTRO del plumbing del v9958.
//    - Negro/no-signal → el fallo es de infraestructura (PLL/OSER/pines).
//  Debug en PMOD1: [0]=lock, [1]=latido 27M (CLKDIV), [2]=latido 135M,
//                  [3]=latido de frame (cy==0, ~60Hz÷32), [4]=ON fijo.
// ============================================================================
`define GW_IDE

module top (
    input  wire ex_clk_27m,        // Console 60K: 50 MHz (V22)

    // HDMI (mismos nombres de net que el core → mismas constraints)
    output wire [2:0] data_p,
    output wire [2:0] data_n,
    output wire clk_p,
    output wire clk_n,

    // debug PMOD1
    output wire [5:0] dbg_pmod1
);

    // ---- relojes: EXACTAMENTE como el core (mismos nombres de instancia) ----
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

    // ---- reset de encendido (contador sobre el 27) ----
    reg [15:0] por_cnt = 0;
    wire       reset_w = ~(&por_cnt);
    always @(posedge clk_27m) begin
        if (!clock_locked)      por_cnt <= 0;
        else if (~&por_cnt)     por_cnt <= por_cnt + 1'b1;
    end

    // ---- audio a cero (mismo CLOCK_DIV que v9958_top) ----
    localparam AUDIO_RATE = 44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam NUM_CHANNELS = 3;
    localparam NTSC_Y = 525-45;

    wire clk_audio;
    CLOCK_DIV #(
        .CLK_SRC(27),
        .CLK_DIV(0.044100),
        .PRECISION_BITS(16)
    ) audioclkd (
        .clk_src(clk_27m),
        .clk_div(clk_audio)
    );
    wire [15:0] audio_zero [1:0];
    assign audio_zero[0] = 16'd0;
    assign audio_zero[1] = 16'd0;

    // ---- hdmi con los MISMOS parámetros que hdmi_ntsc del v9958_top ----
    logic [9:0] cx;
    logic [9:0] cy;
    logic [9:0] tmds_internal [NUM_CHANNELS-1:0];

    // patrón: 8 barras verticales (área activa de VIC=2: 720x480, cx 138..857)
    reg [23:0] rgb;
    always @(posedge clk_27m) begin
        case (cx[8:6])
            3'd0: rgb <= 24'hFFFFFF;  // blanco
            3'd1: rgb <= 24'hFFFF00;  // amarillo
            3'd2: rgb <= 24'h00FFFF;  // cian
            3'd3: rgb <= 24'h00FF00;  // verde
            3'd4: rgb <= 24'hFF00FF;  // magenta
            3'd5: rgb <= 24'hFF0000;  // rojo
            3'd6: rgb <= 24'h0000FF;  // azul
            default: rgb <= 24'h404040; // gris
        endcase
    end

    hdmi #( .VIDEO_ID_CODE(2),
            .DVI_OUTPUT(0),
            .VIDEO_REFRESH_RATE(59.94),
            .IT_CONTENT(1),
            .AUDIO_RATE(AUDIO_RATE),
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}),
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
            .SOURCE_DEVICE_INFORMATION(8'h00),
            .START_X(0),
            .START_Y(NTSC_Y),
            .NUM_CHANNELS(NUM_CHANNELS)
          )
    hdmi_test (
        .clk_pixel_x5(clk_135),
        .clk_pixel(clk_27m),
        .clk_audio(clk_audio),
        .rgb(rgb),
        .reset(reset_w),
        .audio_sample_word(audio_zero),
        .aspect_16_9(1'b0),
        .cx(cx),
        .cy(cy),
        .tmds_internal(tmds_internal)
    );

    // ---- serializer + ELVDS: EXACTAMENTE como v9958_top ----
    logic [2:0] tmds;
    serializer #(.NUM_CHANNELS(NUM_CHANNELS), .VIDEO_RATE(0)) serializer(
        .clk_pixel(clk_27m), .clk_pixel_x5(clk_135), .reset(reset_w),
        .tmds_internal(tmds_internal), .tmds(tmds) );

    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_27m, tmds}),
        .O({clk_p, data_p}),
        .OB({clk_n, data_n})
    );

    // ---- debug ----
    reg [23:0] hb27 = 0;  always @(posedge clk_27m)  hb27  <= hb27  + 1'b1;
    reg [26:0] hb135 = 0; always @(posedge clk_135)  hb135 <= hb135 + 1'b1;
    reg [5:0] frame_div = 0;
    reg cy0_d = 0;
    always @(posedge clk_27m) begin
        cy0_d <= (cy == 10'd0);
        if ((cy == 10'd0) && !cy0_d) frame_div <= frame_div + 1'b1;  // 1 tick/frame
    end
    assign dbg_pmod1[0] = clock_locked;
    assign dbg_pmod1[1] = hb27[23];
    assign dbg_pmod1[2] = hb135[26];
    assign dbg_pmod1[3] = frame_div[5];   // ~1 Hz si el frame corre (59.94/64)
    assign dbg_pmod1[4] = 1'b1;
    assign dbg_pmod1[5] = ~reset_w;

endmodule
