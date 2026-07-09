// ============================================================================
// msx2hdmi.sv — Puente de vídeo VDP (27 MHz) → HDMI 720p (74.25 MHz)
//
// Arquitectura nand2mario (smstang/monitorcore): el HDMI corre en su propio
// dominio de reloj (74.25 / 371.25 MHz) y se alimenta desde el dominio del
// VDP (27 MHz) a través de un ring buffer BRAM dual-clock de 32 líneas
// nativas (720 px × 18 bits).
//
//  - Escritura (clk 27M): captura solo la scanline PAR de cada par
//    line-doubled del VDP → línea nativa n = (vdp_cy - y0) >> 1
//    (y0 = 45 NTSC / 60 PAL). Slot del ring = n mod 32.
//  - Lock de frame: frame_tgl se invierte en (vdp_cy==LOCK_Y, vdp_cx==0);
//    cruzado con 2FF a clk_pixel, su flanco genera hdmi_rst (1 ciclo) que
//    realinea los contadores cx/cy de los hdmi a (0, 720) = inicio del
//    vblank de 720p (720 activas, 750 totales).
//  - Lectura (clk_pixel 74.25M): ventana activa 960×720 centrada
//    (X ∈ [160,1120)); escalado fraccional por acumuladores:
//    horizontal 720→960 (×4/3), vertical 240→720 (×3) / 288→720 (×2.5).
//  - Salida: dos hdmi (VIC 4 = 720p60 para NTSC, VIC 19 = 720p50 para PAL),
//    mux de tmds_internal por pal_mode sincronizado, UN serializer externo
//    (OSER10 con RESET=1'b0 constante dentro) y ELVDS_OBUF con clk_pixel
//    crudo — patrón idéntico a v9958_top.v (tn_vdp_v3_v9958).
//
// LOCK_Y = 50 (mismo valor NTSC y PAL). Justificación numérica:
//   El lector arranca en (0,720) → 30 líneas HDMI de vblank antes de leer.
//   NTSC: línea HDMI = 22.22 µs, par de scanlines VDP = 63.56 µs. En el
//     toggle (vdp_cy=50) ya hay 3 líneas nativas escritas (vdp_cy 45/47/49).
//     lag(yy) ≈ 12.5 + 0.049·yy → [12, 25] líneas  (medido en sim: 12..25).
//   PAL:  línea HDMI = 26.67 µs, par VDP = 64 µs. En el toggle (50 < 60) aún
//     no hay líneas escritas; el lector tarda 800 µs en llegar a yy=0.
//     lag(yy) ≈ 8 + 0.042·yy → [8, 20] líneas      (medido en sim: 8..20).
//   Ambos modos quedan dentro de [1,31] con margen ≥ 2 por ambos lados.
//
// NOTA PAL (inconsistencia de la spec de entrada, documentada): la ventana
// visible teórica [60, 60+576) no cabe en un frame de 625 líneas
// (vdp_cy 0..624). Solo se escriben las líneas nativas 0..282; las líneas
// nativas 283..287 del lector (las 12 últimas líneas de pantalla) leen el
// contenido de la línea n-32 del MISMO frame (alias determinista del ring,
// slots 27..31). En el MSX real esas líneas son borde inferior, así que el
// alias es invisible. Verificado explícitamente en el testbench.
//
// `define SIM_NO_HDMI sustituye hdmi/serializer/ELVDS por contadores cx/cy
// conductuales para simular SOLO la lógica del puente con Icarus.
// ============================================================================

module msx2hdmi (
    input  wire        clk,          // 27 MHz, dominio VDP
    input  wire        resetn,       // reset del dominio VDP (activo bajo)
    input  wire [5:0]  r,            // color del VDP
    input  wire [5:0]  g,
    input  wire [5:0]  b,
    input  wire [10:0] vdp_cx,       // 0..857 (NTSC) / 0..863 (PAL)
    input  wire [10:0] vdp_cy,       // 0..524 (NTSC) / 0..624 (PAL)
    input  wire        pal_mode,     // cuasi-estático
    input  wire [15:0] audio_l,      // muestras del core (cruce 2FF)
    input  wire [15:0] audio_r,
    input  wire        clk_pixel,    // 74.25 MHz
    input  wire        clk_5x_pixel, // 371.25 MHz
    output wire        tmds_clk_n,
    output wire        tmds_clk_p,
    output wire [2:0]  tmds_d_n,
    output wire [2:0]  tmds_d_p
);

    localparam LOCK_Y          = 50;            // ver cuenta en la cabecera
    localparam CLKFRQ          = 74250;         // kHz de clk_pixel
    localparam AUDIO_RATE      = 44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam NUM_CHANNELS    = 3;
    localparam XSTART          = (1280-960)/2;  // 160
    localparam XSTOP           = (1280+960)/2;  // 1120

    // ========================================================================
    // Dominio clk (27 MHz): captura al ring buffer
    // ========================================================================

    // Ring buffer BRAM dual-clock inferida (mismo patrón que sms2hdmi):
    // escritura en always @(posedge clk), lectura registrada en clk_pixel.
    logic [17:0] mem [0:32*720-1];

    wire [10:0] y_off    = vdp_cy - (pal_mode ? 11'd60 : 11'd45);
    wire        line_vis = pal_mode ? (vdp_cy >= 11'd60 && vdp_cy < 11'd636)
                                    : (vdp_cy >= 11'd45 && vdp_cy < 11'd525);
    wire        cap_line = line_vis && ~y_off[0];   // solo scanline PAR del par
    wire [9:0]  n_native = y_off[10:1];             // línea nativa 0..239/287

    reg  [14:0] wr_addr;
    reg  [17:0] wr_data;
    reg         wr_en;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wr_en   <= 1'b0;
            wr_addr <= 15'd0;
            wr_data <= 18'd0;
        end else begin
            wr_en <= 1'b0;
            if (cap_line && vdp_cx < 11'd720) begin
                wr_en   <= 1'b1;
                wr_data <= {r, g, b};
                // *720 solo al inicio de línea (constante, shift+add);
                // por píxel solo incremento.
                wr_addr <= (vdp_cx == 11'd0) ? n_native[4:0] * 15'd720
                                             : wr_addr + 15'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // Toggle de frame: invierte en (LOCK_Y, 0), mismo valor NTSC y PAL.
    reg frame_tgl = 1'b0;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            frame_tgl <= 1'b0;
        else if (vdp_cy == LOCK_Y && vdp_cx == 11'd0)
            frame_tgl <= ~frame_tgl;
    end

    // ========================================================================
    // Dominio clk_pixel (74.25 MHz): sincronizadores
    // ========================================================================

    reg [2:0] tgl_x = 3'b000;
    always @(posedge clk_pixel)
        tgl_x <= {tgl_x[1:0], frame_tgl};
    wire hdmi_rst = tgl_x[2] ^ tgl_x[1];        // pulso de 1 ciclo por frame

    reg [1:0] pal_sync = 2'b00;
    always @(posedge clk_pixel)
        pal_sync <= {pal_sync[0], pal_mode};
    wire pal_x = pal_sync[1];

    // ========================================================================
    // Contadores HDMI (reales o conductuales) y mux NTSC/PAL
    // ========================================================================

    logic [10:0] cx_ntsc;   // VIC 4:  BIT_WIDTH 11 (frame 1650×750)
    logic [9:0]  cy_ntsc;
    logic [11:0] cx_pal;    // VIC 19: BIT_WIDTH 12 (frame 1980×750)
    logic [9:0]  cy_pal;

    wire [11:0] cx = pal_x ? cx_pal : {1'b0, cx_ntsc};
    wire [9:0]  cy = pal_x ? cy_pal : cy_ntsc;

    // ========================================================================
    // Escalado a ventana activa 960×720 centrada (X ∈ [160,1120))
    //
    // xx/yy se generan 2 ciclos POR DELANTE del cx del hdmi para absorber el
    // pipeline BRAM(1)+RGB(1): así rgb en el ciclo (cx,cy) es EXACTAMENTE el
    // píxel nativo (floor(3·(cx-160)/4), floor(cy·N/720)), sin desfase.
    // ========================================================================

    reg [9:0]  xx   = 10'd0;    // 0..719 (píxel nativo)
    reg [10:0] xcnt = 11'd0;
    reg [8:0]  yy   = 9'd0;     // línea nativa (libre; el addr usa yy[4:0])
    reg [10:0] ycnt = 11'd0;
    reg [9:0]  cy_r = 10'd0;

    always @(posedge clk_pixel) begin : scaler
        reg [10:0] xcnt_next;
        reg [10:0] ycnt_next;
        xcnt_next = xcnt + 11'd720;
        ycnt_next = ycnt + (pal_x ? 11'd288 : 11'd240);

        // Horizontal: acumula en cx ∈ [XSTART-2, XSTOP-3) → 959 flancos;
        // xx acaba en 719 y se queda ahí (nunca desborda la línea del ring).
        if (cx >= XSTART-2 && cx < XSTOP-3) begin
            if (xcnt_next >= 11'd960) begin
                xcnt <= xcnt_next - 11'd960;
                xx   <= xx + 1'b1;
            end else
                xcnt <= xcnt_next;
        end

        // Vertical: acumula al cambiar de línea (como sms2hdmi).
        cy_r <= cy;
        if (cy[0] != cy_r[0]) begin
            if (ycnt_next >= 11'd720) begin
                ycnt <= ycnt_next - 11'd720;
                yy   <= yy + 1'b1;
            end else
                ycnt <= ycnt_next;
        end

        // Resets por posición (prioridad: van los últimos).
        if (cx == 12'd0) begin
            xx   <= 10'd0;
            xcnt <= 11'd0;
        end
        if (cy == 10'd0) begin
            yy   <= 9'd0;
            ycnt <= 11'd0;
        end
    end

    // Lectura del ring: dato registrado + registro rgb (2 etapas).
    wire [14:0] rd_addr = yy[4:0] * 15'd720 + {5'd0, xx};
    reg  [17:0] rd_data = 18'd0;
    reg  [23:0] rgb     = 24'd0;

    // "El PRÓXIMO ciclo está dentro de la ventana activa" (cx+1 ∈ [160,1120)).
    wire win_next = (cx >= XSTART-1) && (cx < XSTOP-1) && (cy < 10'd720);

    always @(posedge clk_pixel) begin
        rd_data <= mem[rd_addr];
        rgb     <= win_next ? {rd_data[17:12], 2'b00,
                               rd_data[11:6],  2'b00,
                               rd_data[5:0],   2'b00}
                            : 24'h101010;
    end

    // ========================================================================
    // Audio: divisor a 44100 Hz desde clk_pixel + cruce 2FF (como sms2hdmi)
    // ========================================================================

    localparam AUDIO_CLK_DELAY = CLKFRQ * 1000 / AUDIO_RATE / 2;
    logic [$clog2(AUDIO_CLK_DELAY)-1:0] audio_divider = '0;
    logic clk_audio = 1'b0;

    always_ff @(posedge clk_pixel) begin
        if (audio_divider != AUDIO_CLK_DELAY - 1)
            audio_divider <= audio_divider + 1'b1;
        else begin
            clk_audio     <= ~clk_audio;
            audio_divider <= '0;
        end
    end

    reg [15:0] audio_sample_word [1:0], audio_sample_word0 [1:0];
    always @(posedge clk_pixel) begin
        audio_sample_word0[0] <= audio_l;
        audio_sample_word[0]  <= audio_sample_word0[0];
        audio_sample_word0[1] <= audio_r;
        audio_sample_word[1]  <= audio_sample_word0[1];
    end

`ifndef SIM_NO_HDMI

    // ========================================================================
    // HDMI real: dos hdmi (fork tn_vdp con salida tmds_internal), mux por
    // pal_x, serializer externo y ELVDS — patrón v9958_top.v líneas 449-523.
    // ========================================================================

    logic [9:0] tmds_ntsc [NUM_CHANNELS-1:0];
    hdmi #( .VIDEO_ID_CODE(4),                  // 720p60, frame 1650×750
            .DVI_OUTPUT(0),
            .VIDEO_REFRESH_RATE(60.0),
            .IT_CONTENT(1),
            .AUDIO_RATE(AUDIO_RATE),
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}),
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
            .SOURCE_DEVICE_INFORMATION(8'h00),
            .START_X(0),
            .START_Y(720),                      // reset → inicio del vblank
            .NUM_CHANNELS(NUM_CHANNELS)
            )
    hdmi_ntsc ( .clk_pixel_x5(clk_5x_pixel),
          .clk_pixel(clk_pixel),
          .clk_audio(clk_audio),
          .rgb(rgb),
          .reset( hdmi_rst ),
          .audio_sample_word(audio_sample_word),
          .aspect_16_9(1'b0),  // v3.0: con VIC 4/19 el hack VIC+aspect del AVI InfoFrame anunciaria 1080i; 720p ya es 16:9
          .cx(cx_ntsc),
          .cy(cy_ntsc),
          .tmds_internal(tmds_ntsc)
        );

    logic [9:0] tmds_pal [NUM_CHANNELS-1:0];
    hdmi #( .VIDEO_ID_CODE(19),                 // 720p50, frame 1980×750
            .DVI_OUTPUT(0),
            .VIDEO_REFRESH_RATE(50.0),
            .IT_CONTENT(1),
            .AUDIO_RATE(AUDIO_RATE),
            .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH),
            .VENDOR_NAME({"Unknown", 8'd0}),
            .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
            .SOURCE_DEVICE_INFORMATION(8'h00),
            .START_X(0),
            .START_Y(720),
            .NUM_CHANNELS(NUM_CHANNELS)
            )
    hdmi_pal ( .clk_pixel_x5(clk_5x_pixel),
          .clk_pixel(clk_pixel),
          .clk_audio(clk_audio),
          .rgb(rgb),
          .reset( hdmi_rst ),
          .audio_sample_word(audio_sample_word),
          .aspect_16_9(1'b0),  // v3.0: con VIC 4/19 el hack VIC+aspect del AVI InfoFrame anunciaria 1080i; 720p ya es 16:9
          .cx(cx_pal),
          .cy(cy_pal),
          .tmds_internal(tmds_pal)
        );

    logic [2:0] tmds;
    logic [9:0] tmds_internal [NUM_CHANNELS-1:0];

    // mux NTSC/PAL de los 10 bits pre-serializador (elemento a elemento:
    // el ternario sobre arrays unpacked no es portable)
    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin : tmds_mux
            assign tmds_internal[ch] = pal_x ? tmds_pal[ch] : tmds_ntsc[ch];
        end
    endgenerate

    // El serializer del árbol (tn_vdp_v3_v9958/src/hdmi/serializer.sv) lleva
    // los OSER10 con RESET=1'b0 constante: el reset por-frame (hdmi_rst) solo
    // realinea cx/cy de los hdmi, nunca el gearbox de serialización.
    serializer #(.NUM_CHANNELS(NUM_CHANNELS), .VIDEO_RATE(0)) serializer(
        .clk_pixel(clk_pixel), .clk_pixel_x5(clk_5x_pixel), .reset(1'b0),
        .tmds_internal(tmds_internal), .tmds(tmds) );

    // Gowin LVDS output buffer — reloj TMDS = clk_pixel crudo (como nestang).
    ELVDS_OBUF tmds_bufds [3:0] (
        .I({clk_pixel, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );

`else

    // ========================================================================
    // SIM_NO_HDMI: contadores cx/cy conductuales con la misma semántica de
    // reset que hdmi.sv (síncrono, → (START_X, START_Y) = (0,720)).
    // NTSC: frame 1650×750 (VIC 4). PAL: frame 1980×750 (VIC 19).
    // ========================================================================

    initial begin
        cx_ntsc = 11'd0;  cy_ntsc = 10'd720;
        cx_pal  = 12'd0;  cy_pal  = 10'd720;
    end

    always @(posedge clk_pixel) begin
        if (hdmi_rst) begin
            cx_ntsc <= 11'd0;
            cy_ntsc <= 10'd720;
        end else begin
            cx_ntsc <= (cx_ntsc == 11'd1649) ? 11'd0 : cx_ntsc + 1'b1;
            if (cx_ntsc == 11'd1649)
                cy_ntsc <= (cy_ntsc == 10'd749) ? 10'd0 : cy_ntsc + 1'b1;
        end
    end

    always @(posedge clk_pixel) begin
        if (hdmi_rst) begin
            cx_pal <= 12'd0;
            cy_pal <= 10'd720;
        end else begin
            cx_pal <= (cx_pal == 12'd1979) ? 12'd0 : cx_pal + 1'b1;
            if (cx_pal == 12'd1979)
                cy_pal <= (cy_pal == 10'd749) ? 10'd0 : cy_pal + 1'b1;
        end
    end

    assign tmds_clk_p = 1'b0;
    assign tmds_clk_n = 1'b1;
    assign tmds_d_p   = 3'b000;
    assign tmds_d_n   = 3'b111;

`endif

endmodule
