// ============================================================================
// msx2hdmi.sv — Puente de vídeo VDP (27 MHz) → HDMI 720p (74.25 MHz)
//
// Arquitectura nand2mario (smstang/monitorcore): el HDMI corre en su propio
// dominio de reloj (74.25 / 371.25 MHz) y se alimenta desde el dominio del
// VDP (27 MHz) a través de un ring buffer BRAM dual-clock de 32 líneas
// nativas (720 px × 18 bits).
//
// CAPTURA AUTO-CRONOMETRADA (v2): en lugar de los contadores internos del VDP
// (vdp_cx/vdp_cy, cuya semántica real — H_CNT 0..1715, V_CNT en medias
// líneas — no coincidía con la asumida), la escritura se auto-alinea con las
// señales de vídeo reales del VDP: hs_n, vs_n y blank. Es inmune al offset
// horizontal/vertical del área activa.
//
// POLARIDADES (verificadas en el VHDL del core, fork tn_vdp_v3_v9958):
//  - hs_n = PVIDEOHS_N: ACTIVO BAJO. vdp_vga.vhd:229-241 (FF_HSYNC_N <= '0'
//    en HCOUNTERIN=0 y =858, <= '1' en 40/898; 2 pulsos por línea H_CNT de
//    1716 clocks = raster 31 kHz del doubler). vdp.vhd:1101 lo saca tal cual
//    con DISPMODEVGA=1 (v9958_top instancia el VDP con DISPRESO=1).
//  - vs_n = PVIDEOVS_N: ACTIVO BAJO. vdp_vga.vhd:243-281 (FF_VSYNC_N <= '0'
//    durante 3 líneas de salida, p.ej. V_CNT 18..24 NTSC no interlace).
//  - blank = BLANK_o: 1 = blanking. OJO (vdp_vga.vhd:318 + 298-312): en este
//    fork VIDEOOUTX está clavado a '1' (el gate horizontal está comentado),
//    así que BLANK_o == "VS activo" y NO delimita los 720 px. El diseño lo
//    tolera: sin blanking horizontal, x=0 queda ~1 clk tras el flanco de HS,
//    que con DISP_START_X=0 (vdp_vga.vhd:166) coincide con el píxel 0 real
//    (±2 px constantes). Con blanking de píxel real se auto-alinea exacto.
//  Los detectores son parametrizables (HS_ACTIVE_LOW/VS_ACTIVE_LOW) por si
//  en placa hubiera que invertir.
//
// Lado ESCRITURA (clk 27M):
//  - out_line: 0 en el flanco activo de VS, +1 en cada flanco activo de HS.
//  - x_cnt: 0 en el primer ciclo no-blank tras HS, +1 por ciclo no-blank.
//  - y0: primera out_line con píxeles no-blank tras VS (latch por frame).
//  - línea nativa n = (out_line - y0) >> 1; se captura SOLO la scanline PAR
//    del par line-doubled; clamp n < 288; slot del ring = n mod 32.
//  - frame_tgl (lock) se invierte al INICIO de out_line == y0 + LOCK_LINES.
//
// LOCK_LINES = 6, RELATIVO A y0 (¡no a VS!). Justificación:
//  * En el toggle hay exactamente 3 líneas nativas escritas (rel 0,2,4) sea
//    cual sea el offset vertical → misma geometría validada del diseño _36:
//    rampa de lag ≈ 13 + 0.049·yy (NTSC) / 15.5 + 0.042·yy (PAL); dentro de
//    [3,29] con margen ≥2 por ambos lados (valores medidos: ver TB).
//  * Un LOCK absoluto desde VS NO puede valer a la vez para el TB (activo en
//    línea 40/46) y para el HW real (activo en línea 3, porque el VS del core
//    dura 3 líneas y blank=VS): con lock=50 absoluto, en HW habría ~23
//    nativas escritas en el toggle → lag(yy=0) ≈ 34 > 32 → overrun del ring.
//    Relativo a y0, TB y HW quedan con geometría idéntica.
//
// Lado LECTURA (clk_pixel 74.25M) — sin cambios respecto a la versión
// validada en placa (señal 720p OK): ventana activa 960×720 centrada
// (X ∈ [160,1120)), escalado fraccional 720→960 (×4/3) y 240→720 (×3) /
// 288→720 (×2.5), dos hdmi (VIC 4 = 720p60, VIC 19 = 720p50) reseteados a
// (0,720) por el lock cruzado 2FF, mux de tmds_internal por pal_mode
// sincronizado, UN serializer externo (OSER10 RESET=0) y ELVDS_OBUF con
// clk_pixel crudo — patrón v9958_top.v.
//
// `define SIM_NO_HDMI sustituye hdmi/serializer/ELVDS por contadores cx/cy
// conductuales para simular SOLO la lógica del puente con Icarus.
// ============================================================================

// ============================================================================
// msx2hdmi_v9968.sv — variante para el V9968 (MSXimus 60K). Deltas respecto
// a msx2hdmi.sv (que queda INTACTO para los builds con el VDP clasico):
//   * write-side en clk_86 (85.909 MHz) con `ce` (2 ciclos/pixel del V9968);
//   * ring de 32 lineas x 800 px (el V9968 saca 800 activos: 256x3=768 de
//     contenido + bordes — el ring de 720 croparia 48 px de contenido);
//   * lectura: H 800->1200 (x1,5 EXACTO, _127C) 4:3, 800->1280 16:9;
//     V FIJO 240->720 x3 en AMBOS modos (el V9968 normaliza NTSC y PAL a
//     480 lineas dobladas = 240 nativas);
//   * scanlines: patron x3 (1 de cada 3) tambien en PAL;
//   * hs/vs ACTIVO ALTO (display_hs/vs del V9968), blank = ~display_en.
// Back-ends hdmi_ntsc/hdmi_pal, serializer, ELVDS y audio: SIN CAMBIOS.
// ============================================================================
module msx2hdmi_v9968 #(
    // ========================================================================
    // _168 ENABLE_PAL — 0 = solo back-end NTSC (720p60). Es lo que hay HOY.
    //
    // POR QUE ESTE PARAMETRO. El modulo instancia DOS codificadores HDMI
    // completos (hdmi_ntsc VIC 4 = 720p60 y hdmi_pal VIC 19 = 720p50) y
    // multiplexa sus salidas TMDS con pal_x. Pero pal_mode llega CABLEADO A
    // CERO desde el top (top.v:1969 `.pal_mode (1'b0)`, y el V9968 fuerza
    // ff_50hz_mode <= 1'b0 en vdp_cpu_interface.v:613 y :697): el back-end PAL
    // es LOGICA MUERTA — 606 FF y 835 de logica sintetizados para nada.
    //
    // El sintetizador NO lo podaba solo porque pal_mode cruza un sincronizador
    // de 2 registros (pal_sync, ~linea 341) y eso BLOQUEA la propagacion de
    // constantes. Con este parametro, pal_x pasa a ser una constante de
    // ELABORACION y la poda ocurre sola: se van hdmi_pal, su mux, cx_pal y
    // cy_pal, sin tocar ni una linea de la estructura.
    //
    // El camino PAL queda INTACTO en el fuente. Para recuperarlo: poner este
    // parametro a 1 y darle a .pal_mode una senal de verdad. Sigue pendiente
    // medir la geometria 50 Hz del V9968 (top.v:1746).
    // ========================================================================
    parameter ENABLE_PAL = 0
) (
    input  wire        clk,          // 85.909 MHz, dominio del V9968
    input  wire        resetn,       // reset del dominio VDP (activo bajo)
    input  wire        ce,           // pixel-enable (1 de cada 2 ciclos)
    input  wire [5:0]  r,            // color del VDP (truncado 8->6 fuera)
    input  wire [5:0]  g,
    input  wire [5:0]  b,
    input  wire        hs_n,         // display_hs del V9968 (ACTIVO ALTO)
    input  wire        vs_n,         // display_vs del V9968 (ACTIVO ALTO)
    input  wire        blank,        // ~display_en (1 = blanking)
    input  wire        pal_mode,     // cuasi-estático
    input  wire        aspect_wide,  // _56: 0 = 4:3 (960 centrado), 1 = 16:9
                                     // (720→1280 estirado). Cuasi-estático
                                     // desde la config del menú; el cambio en
                                     // caliente puede dar 1 frame feo.
    input  wire        scanlines,    // _58: 1 = atenuar al 50% la última
                                     // repetición de cada línea nativa
                                     // (1 de 3 NTSC ×3; patrón 3-2 PAL ×2.5).
                                     // Cuasi-estático desde la config del menú.
    input  wire [15:0] audio_l,      // muestras del core (cruce 2FF)
    input  wire [15:0] audio_r,
    output wire [15:0] dbg_amp,      // _133: pico |muestra| que consume el HDMI
    input  wire        clk_pixel,    // 74.25 MHz
    input  wire        clk_5x_pixel, // 371.25 MHz
    output wire        tmds_clk_n,
    output wire        tmds_clk_p,
    output wire [2:0]  tmds_d_n,
    output wire [2:0]  tmds_d_p,
    // ---- diagnóstico (polaridad: activo = 1; el top pone la del LED) ----
    output wire        dbg_vs_tick,  // clk: stretch ~39ms del flanco de VS
    output wire        dbg_wr_act,   // clk: stretch de mem_we (hay captura)
    output wire        dbg_nonblack, // clk: stretch de mem_we con dato != 0
    output wire        dbg_lock_tgl, // clk: frame_tgl tal cual (~30 Hz NTSC)
    output wire        dbg_hdmi_rst, // clk_pixel: stretch del pulso hdmi_rst
    output wire        dbg_rd_act,   // clk_pixel: nivel ventana activa lectura
    output wire [31:0] dbg_apkt,     // _127I: {ovr[7:0], 8'h00, paquetes_audio[15:0]}
    output wire [5:0]  dbg_defer,    // _134: yanks diferidos (esperado ~60/s)
    output wire [4:0]  dbg_tear      // _134: resets en zona de peligro (esperado 0)
);

    localparam HS_ACTIVE_LOW   = 0;  // V9968: display_hs/vs activos ALTOS
    localparam VS_ACTIVE_LOW   = 0;
    // [v2.0.2 BORDES] 768 -> 640 columnas nativas: el V9968 saca ahora 640
    // columnas (256 px de contenido x2 + 32 puntos de borde por lado x2) y
    // 640 -> 1280 es un x2 EXACTO. Ahorra 4 BSRAM (24 -> 20 bloques).
    localparam RING_W          = 640; // px por linea del ring (V9968)
    localparam NATIVE_LINES    = 240; // lineas nativas (480 dobladas / 2)
    localparam LOCK_LINES      = 6;  // líneas de salida DESDE y0 (ver cabecera)
    localparam CLKFRQ          = 74250;   // kHz de clk_pixel
    localparam AUDIO_RATE      = 44100;
    localparam AUDIO_BIT_WIDTH = 16;
    localparam NUM_CHANNELS    = 3;
    // _127C (BUILD DE PRUEBA): el 4:3 clasico queda INTACTO (960, ventana
    // 4:3 exacta = proporcionado; el x1,2 fraccional es el precio: cada
    // pixel MSX — 3 columnas nativas del core, que ya escala 256->768 —
    // sale a 3 o 4 columnas alternas = palos desiguales en las fuentes).
    // La POSICION 16:9 del menu pasa a ser el modo PIXEL-PERFECTO para
    // comparar en caliente: 800->1066 (x4/3, acumulador +600 umbral 800,
    // patron 2,1,1 por nativa -> CUALQUIER triplete suma 4): pixel MSX =
    // 4 columnas EXACTAS, inmune a la fase de los bordes. Ventana 1066
    // centrada (~11% mas ancha que el 4:3 puro). En la _128 se decide:
    // tercera opcion de menu o sustitucion.
    // _141 4:3 PIXEL-PERFECT x3: ventana 800 (no 960) -> el nativo del V9968
    // (800 = 256*3 contenido + borde) se pasa 1:1 => cada pixel MSX = 3
    // columnas EXACTAS (uniforme, la "H" con los dos palos iguales) y el
    // contenido 768x576 = 4:3 REAL. Antes 960 daba x1.2 (columnas 4,4,4,3
    // por celda = caracteres descuadrados). El 16:9 sigue siendo pixel-perfect
    // x4 (1066). OJO: los modos de TEXTO de 40/80 col (240/480px de contenido)
    // los escala el propio V9968 a 768 con factor no-entero -> ahi la
    // uniformidad la limita el core, no este escalador (SCREEN1 256px = limpio).
    localparam XSTART          = (1280-800)/2;   // 240   (4:3 pixel-perfect x3)
    localparam XSTOP           = (1280+800)/2;   // 1040  (4:3 pixel-perfect x3)
    localparam XSTART_P        = (1280-1066)/2;  // 107   (pixel-perfecto)
    localparam XSTOP_P         = (1280+1066)/2;  // 1173  (pixel-perfecto)
    // _56 (16:9 estirado): ventana a pantalla completa, 720→1280
    localparam XSTART_W        = 0;
    localparam XSTOP_W         = 1280;

    // ========================================================================
    // Dominio clk (27 MHz): captura auto-cronometrada al ring buffer
    // ========================================================================

    // Ring buffer BRAM dual-clock inferida (mismo patrón que sms2hdmi):
    // escritura en always @(posedge clk), lectura registrada en clk_pixel.
    logic [17:0] mem [0:32*RING_W-1];

    wire hs_act = HS_ACTIVE_LOW ? ~hs_n : hs_n;
    wire vs_act = VS_ACTIVE_LOW ? ~vs_n : vs_n;

    // Registro de entradas (una etapa uniforme: syncs, blank y color alineados)
    reg        hs_q, hs_qq, vs_q, vs_qq, blank_q;
    reg [5:0]  r_q, g_q, b_q;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            hs_q <= 1'b0; hs_qq <= 1'b0;
            vs_q <= 1'b0; vs_qq <= 1'b0;
            blank_q <= 1'b1;
            r_q <= 6'd0; g_q <= 6'd0; b_q <= 6'd0;
        end else if (ce) begin
            hs_q  <= hs_act;  hs_qq <= hs_q;
            vs_q  <= vs_act;  vs_qq <= vs_q;
            blank_q <= blank;
            r_q <= r; g_q <= g; b_q <= b;
        end
    end
    wire hs_lead = hs_q & ~hs_qq;   // inicio de línea de salida (31kHz)
    wire vs_lead = vs_q & ~vs_qq;   // inicio de frame

    reg  [9:0] out_line;      // línea de salida desde VS (0..624 máx)
    reg  [9:0] x_cnt;         // píxel dentro de la línea (satura)
    reg  [9:0] y0;            // primera línea con píxeles no-blank del frame
    reg        y0_valid;
    reg        frame_started; // hubo ya un VS tras reset

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            out_line      <= 10'd0;
            x_cnt         <= 10'h3FF;
            y0            <= 10'd0;
            y0_valid      <= 1'b0;
            frame_started <= 1'b0;
        end else if (ce) begin
            // x_cnt: 0 en el primer no-blank tras hs_lead; para en blank
            if (hs_lead)
                x_cnt <= 10'd0;
            else if (!blank_q && x_cnt != 10'h3FF)
                x_cnt <= x_cnt + 10'd1;

            // contador de líneas de salida + re-arme de y0 por frame
            if (vs_lead) begin
                out_line      <= 10'd0;
                y0_valid      <= 1'b0;
                frame_started <= 1'b1;
            end else if (hs_lead)
                out_line <= out_line + 10'd1;

            // latch de la primera línea activa del frame
            if (!vs_lead && frame_started && !blank_q && !y0_valid) begin
                y0       <= out_line;
                y0_valid <= 1'b1;
            end
        end
    end

    // y0 efectivo: durante la primera línea activa (antes del latch) vale
    // out_line, así el primer píxel del frame ya se captura con n = 0.
    wire [9:0] y0_eff = y0_valid ? y0 : out_line;
    wire [9:0] rel    = out_line - y0_eff;      // línea de salida relativa
    wire [8:0] n_nat  = rel[9:1];               // línea nativa 0..287
    wire cap_ok = frame_started && !blank_q &&
                  ~rel[0] &&                    // solo scanline PAR del par
                  (n_nat < NATIVE_LINES) &&     // clamp (V9968: 240)
                  (x_cnt < RING_W);             // clamp (V9968: 800)

    reg  [14:0] wr_addr;
    reg  [17:0] wr_data;
    reg         wr_en;
    reg  [14:0] rel800;      // rel[5:1]*800 registrado (v4-timing)

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wr_en   <= 1'b0;
            wr_addr <= 15'd0;
            wr_data <= 18'd0;
        end else if (ce) begin
            wr_en <= 1'b0;
            // v4-timing: el producto rel*800 REGISTRADO (camino corto
            // reg->mult->reg, patron _56b del read-side): a 85.9 el x800
            // dentro del mux por-pixel era -2.4ns. rel es estable toda la
            // linea y x_cnt==0 llega >=1 ce tras hs_lead: rel800 ya vale.
            rel800 <= rel[5:1] * 15'd640;
            if (cap_ok) begin
                wr_en   <= 1'b1;
                wr_data <= {r_q, g_q, b_q};
                wr_addr <= (x_cnt == 10'd0) ? rel800 : wr_addr + 15'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // Toggle de frame: al INICIO de la línea y0 + LOCK_LINES (relativo a y0)
    reg frame_tgl = 1'b0;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            frame_tgl <= 1'b0;
        else if (ce && hs_lead && !vs_lead && y0_valid &&
                 (out_line == y0 + LOCK_LINES - 1))
            frame_tgl <= ~frame_tgl;
    end

    // ========================================================================
    // Dominio clk_pixel (74.25 MHz): sincronizadores
    // ========================================================================

    reg [2:0] tgl_x = 3'b000;
    always @(posedge clk_pixel)
        tgl_x <= {tgl_x[1:0], frame_tgl};
    wire hdmi_rst_raw = tgl_x[2] ^ tgl_x[1];    // pulso de 1 ciclo por frame

    // _134 (bug #14, CAUSA RAIZ PROPUESTA): con los relojes reales
    // (clk_86 = 27*35/11, clk_pixel = 27*55/20, ratio exacto 121/140) el
    // yank por-frame aterrizaba SIEMPRE en cx~1595 = DENTRO de la ventana
    // de data islands del frame VIC4 (cx en [1290,1610), todas las lineas)
    // => truncaba un paquete HDMI (audio/ACR/NULL) en el cable CADA frame,
    // sin ECC ni guard de cierre. El video lo tolera; el audio del receptor
    // no: deficit de muestras + CTS basura ocasional = "30-40s bien y luego
    // va y viene" (el colchon del sink se drena y resbala). La v9958
    // aterriza en zona inocua — por eso la _116 suena perfecta con el MISMO
    // transmisor. Fix: DIFERIR el reset hasta que cx salga de la zona de
    // peligro (preambulo + guard + islands + guard de cierre, ensanchada
    // +-2 por el registro del pulso). Retardo maximo ~340 px = 4.6 us,
    // CONSTANTE (el aterrizaje es deterministico) e invisible para el
    // realineado del conversor. defer_cnt/tear_cnt = assert en silicio:
    // esperado defer ~60/s (el yank SI caia en la ventana) y tear = 0.
    // _136 (leccion HW _134/_135: TRES dados en pantalla negra): diferir el
    // reset SIN compensar movia el anclaje cx/cy ~27 px y el lado de
    // lectura del conversor (ventanas por valor de cx/cy calibradas con la
    // fase del reset) dejaba de casar con el lado de escritura => negro.
    // Ahora el reset diferido re-ancla cx a reset_cx = 1 + ciclos
    // diferidos: la trayectoria cx/cy queda IDENTICA ciclo a ciclo a la
    // del diseno viejo — el conversor NO puede notar la diferencia — y el
    // data island en vuelo se salva igual (el reset ya no cae dentro).
    reg  rst_pend  = 1'b0;
    reg  hdmi_rst  = 1'b0;
    reg  [11:0] rst_dly = 12'd0;     // ciclos desde el yank crudo
    reg  [11:0] rst_cx  = 12'd0;     // re-anclaje compensado para hdmi.sv
    // ventana de DECISION (peligro real ensanchada +-2 por el registro del
    // pulso) y zona de PELIGRO real (para el assert tear)
    wire in_defer_win = pal_x ? (cx >= 12'd1278 && cx < 12'd1870)
                              : (cx >= 12'd1278 && cx < 12'd1620);
    wire in_danger    = pal_x ? (cx >= 12'd1280 && cx < 12'd1868)
                              : (cx >= 12'd1280 && cx < 12'd1618);
    reg [5:0] defer_cnt = 6'd0;
    reg [4:0] tear_cnt  = 5'd0;
    always @(posedge clk_pixel) begin
        hdmi_rst <= 1'b0;
        if (hdmi_rst_raw) begin
            rst_dly <= 12'd1;
            if (in_defer_win) begin
                rst_pend  <= 1'b1;
                defer_cnt <= defer_cnt + 6'd1;
            end
            else begin
                hdmi_rst <= 1'b1;
                rst_cx   <= 12'd1;   // 1 ciclo de registro (vs wire viejo)
            end
        end
        else if (rst_pend) begin
            rst_dly <= rst_dly + 12'd1;
            if (!in_defer_win) begin
                rst_pend <= 1'b0;
                hdmi_rst <= 1'b1;
                rst_cx   <= rst_dly + 12'd1;
            end
        end
        if (hdmi_rst && in_danger) tear_cnt <= tear_cnt + 5'd1;
    end
    assign dbg_defer = defer_cnt;
    assign dbg_tear  = tear_cnt;

    reg [1:0] pal_sync = 2'b00;
    always @(posedge clk_pixel)
        pal_sync <= {pal_sync[0], pal_mode};
    // _168: con ENABLE_PAL=0 esto es una CONSTANTE, no una senal. Ver la
    // cabecera del modulo: es lo que permite al sintetizador podar el back-end
    // PAL entero, que hoy esta muerto porque pal_mode llega cableado a cero.
    wire pal_x = (ENABLE_PAL != 0) ? pal_sync[1] : 1'b0;

    // _56: aspecto cuasi-estático desde la config del menú (2FF por higiene)
    reg [1:0] aspect_sync = 2'b00;
    always @(posedge clk_pixel)
        aspect_sync <= {aspect_sync[0], aspect_wide};
    wire wide_x = aspect_sync[1];

    // _58: scanlines cuasi-estático desde la config del menú (2FF por higiene)
    reg [1:0] scan_sync = 2'b00;
    always @(posedge clk_pixel)
        scan_sync <= {scan_sync[0], scanlines};
    wire scan_x = scan_sync[1];

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
    // Escalado a la ventana activa — conmutable por aspecto (_56):
    //   wide_x=0 (4:3, SIN CAMBIOS): 960×720 centrada (X ∈ [160,1120)),
    //     acumulador xcnt+=720 con umbral 960 (720→960), reset en cx==0.
    //   wide_x=1 (16:9 estirado): 1280×720 completa (X ∈ [0,1280)),
    //     xcnt+=720 con umbral 1280 (720→1280). Como la ventana empieza en
    //     x=0 y xx corre 2 ciclos POR DELANTE (pipeline BRAM+RGB), el
    //     acumulador arranca al FINAL de la línea ANTERIOR: acumula en
    //     cx ∈ {W-2,W-1} ∪ [0,1277) y resetea en cx==W-3, con W = ancho de
    //     línea del frame HDMI activo (1650 NTSC / 1980 PAL).
    //
    // xx/yy se generan 2 ciclos POR DELANTE del cx del hdmi para absorber el
    // pipeline BRAM(1)+RGB(1): así rgb en el ciclo (cx,cy) es EXACTAMENTE el
    // píxel nativo (floor(720·(cx-XSTART)/ANCHO), floor(cy·N/720)) del modo.
    // El escalado VERTICAL no cambia con el aspecto.
    // ========================================================================

    reg [9:0]  xx   = 10'd0;    // 0..799 (píxel nativo del V9968)
    reg [10:0] xcnt = 11'd0;
    reg [8:0]  yy   = 9'd0;     // línea nativa (libre; el addr usa yy[4:0])
    reg [10:0] ycnt = 11'd0;
    reg [9:0]  cy_r = 10'd0;

    // _143 PANTALLA COMPLETA SIEMPRE (como el MSXnano): el escalador llena el
    // 1280 entero -> 256px MSX * 5 = 1280 EXACTO => pixeles UNIFORMES y SIN
    // marco. Se retiran el 4:3 pixel-perfect (_141, imagen pequena con marco
    // que molestaba a Albert) y el 1066 pixel-perfect (_127C): Albert quiere
    // UN modo full-screen como el MSXnano (que no tiene 4:3). wide_x deja de
    // afectar a la geometria (misma ventana full-screen con wrap que el
    // MSXnano, ajustado al nativo de 800 del V9968: xcnt+=800, umbral 1280).
    wire [11:0] wlast    = pal_x ? 12'd1979 : 12'd1649;             // W-1
    wire        xacc_en  = (cx >= wlast - 12'd1) || (cx < XSTOP_W - 12'd3);
    wire [10:0] xthresh  = 11'd1280;                     // ventana = 1280 (full)
    wire [10:0] xinc     = 11'd640;                      // nativo del V9968 = 640
                                                         // => xx = cx>>1 (x2 exacto)
    wire        xrst_now = (cx == wlast - 12'd2);

    always @(posedge clk_pixel) begin : scaler
        reg [10:0] xcnt_next;
        reg [10:0] ycnt_next;
        xcnt_next = xcnt + xinc;                 // V9968 _127C: 800->1066 / 800->1280
        ycnt_next = ycnt + 11'd240;              // V9968: x3 FIJO ambos modos

        // Horizontal: acumula en la ventana adelantada 2 ciclos del modo
        // (4:3: cx ∈ [158,1117) → 959 flancos; 16:9: {W-2,W-1} ∪ [0,1277) →
        // 1279 flancos); xx acaba en 719 y se queda ahí (nunca desborda la
        // línea del ring).
        if (xacc_en) begin
            if (xcnt_next >= xthresh) begin
                xcnt <= xcnt_next - xthresh;
                xx   <= xx + 1'b1;
            end else
                xcnt <= xcnt_next;
        end

        // Vertical: acumula al cambiar de línea (como sms2hdmi). SIN CAMBIOS.
        cy_r <= cy;
        if (cy[0] != cy_r[0]) begin
            if (ycnt_next >= 11'd720) begin
                ycnt <= ycnt_next - 11'd720;
                yy   <= yy + 1'b1;
            end else
                ycnt <= ycnt_next;
        end

        // Resets por posición (prioridad: van los últimos).
        if (xrst_now) begin
            xx   <= 10'd0;
            xcnt <= 11'd0;
        end
        if (cy == 10'd0) begin
            yy   <= 9'd0;
            ycnt <= 11'd0;
        end
    end

    // _56b FIX TIMING (clk_hdmi Setup TNS -341ns, 467 endpoints, TODOS
    // cx → ventana/lookahead → yy*720+xx → ADB de la BRAM en un ciclo de
    // 13.468ns): el producto yy*720 es CONSTANTE durante toda la línea →
    // se precalcula REGISTRADO (yy720_r / yy720_inc_r: camino corto
    // reg→mult-por-constante→reg, sin cx) y la dirección por píxel queda
    // base + xx (sumador de 15 bits). Los flags del lookahead 16:9 también
    // van REGISTRADOS un ciclo antes: los comparadores de cx salen por
    // completo del cono del ADB.
    //
    // Lookahead vertical 16:9 (con la base registrada, un ciclo MÁS que en
    // la _56 original): los fetches cuya línea destino aún no está en
    // yy720_r son los de cx ∈ {W-2, W-1, 0, 1}. En ESOS 4 ciclos la base
    // correcta es EXACTAMENTE yy720_inc_r (el producto de yy_inc registrado
    // el ciclo ANTERIOR): en cx∈{W-2,W-1} yy_inc se calculó con los regs de
    // la línea actual (→ línea siguiente), y en cx∈{0,1} con los de la línea
    // previa (→ línea actual) porque el acumulador vertical actualiza en el
    // flanco 0→1 — en los 4 casos da la línea DESTINO del fetch (verificado
    // caso a caso; el TB lo cubre con la geometría estricta de x=0..3 de
    // cada línea). Si el destino es la línea 0 del frame, base = 0.
    // En 4:3 los flags no aplican: base = yy720_r = yy*720 con 1 ciclo de
    // retardo — idéntico dentro de su ventana (yy estable desde cx=1, sus
    // fetches empiezan en cx=158). Geometría de AMBOS modos sin cambios.
    wire [10:0] ycnt_nx = ycnt + 11'd240;        // V9968: x3 fijo
    wire [8:0]  yy_inc  = (ycnt_nx >= 11'd720) ? yy + 9'd1 : yy;

    reg [14:0] yy720_r     = 15'd0;   // yy[4:0]     * 800, registrado (nombre historico)
    reg [14:0] yy720_inc_r = 15'd0;   // yy_inc[4:0] * 800, registrado
    reg        use_tgt_r   = 1'b0;    // ciclo ACTUAL de prefetch 16:9 (cx ∈ {W-2,W-1,0,1})
    reg        tgt_is0_r   = 1'b0;    // ...y la línea destino es la 0 del frame

    always @(posedge clk_pixel) begin
        yy720_r     <= yy[4:0]     * 15'd640;
        yy720_inc_r <= yy_inc[4:0] * 15'd640;
        // flags para el ciclo SIGUIENTE: cx+1 ∈ {W-2,W-1,0,1} ⟺ cx ∈ {W-3,W-2,W-1,0}
        use_tgt_r   <= (cx >= wlast - 12'd2) || (cx == 12'd0);
        tgt_is0_r   <= ((cx >= wlast - 12'd2) && (cy == 10'd749)) ||
                       ((cx == 12'd0) && (cy == 10'd0));
    end

    // Lectura del ring: base registrada + xx; dato registrado + registro rgb.
    // _143: full-screen SIEMPRE -> el wrap de fin de linea (use_tgt_r) aplica
    // en ambos aspectos (ya no gateado por wide_x).
    wire [14:0] rd_base = use_tgt_r ? (tgt_is0_r ? 15'd0 : yy720_inc_r)
                                    : yy720_r;
    wire [14:0] rd_addr = rd_base + {5'd0, xx};
    reg  [17:0] rd_data = 18'd0;
    reg  [23:0] rgb     = 24'd0;

    // _143: ventana activa = PANTALLA COMPLETA (como el MSXnano): cx+1 ∈
    // [0,1280); en cx==wlast el proximo pixel es el x=0 de la linea siguiente
    // (activa si cy<719, o cy==749 -> linea 0). wide_x ya no afecta.
    wire win_next = ((cx < XSTOP_W - 12'd1) && (cy < 10'd720)) ||
                    ((cx == wlast) && ((cy < 10'd719) || (cy == 10'd749)));

    always @(posedge clk_pixel) begin
        rd_data <= mem[rd_addr];
        rgb     <= win_next ? {rd_data[17:12], 2'b00,
                               rd_data[11:6],  2'b00,
                               rd_data[5:0],   2'b00}
                            : 24'h101010;
    end

    // ========================================================================
    // _58: scanlines — atenuación al 50% (el look del core 480p original:
    // {1'b0, Video, 1'b0} = mitad) de la ÚLTIMA repetición de cada línea
    // nativa. Con el acumulador vertical arrancando en ycnt=0 en cy=0, la
    // fase de repetición es una función cerrada de cy:
    //   NTSC ×3:  dim ⟺ cy mod 3 == 2            (1 línea oscura de cada 3)
    //   PAL ×2.5: dim ⟺ cy mod 5 ∈ {2,4}         (patrón 3-2: última de cada
    //                                              grupo de 3 y de 2)
    // dim es constante por línea de salida → se calcula con contadores de
    // fase registrados y se LATCHEA al FINAL de la línea anterior
    // (cx == wlast): válido desde el cx==0 de su línea (cubre el x=0 del
    // 16:9) y fuera de todo camino crítico (nada de esto toca el cono del
    // ADB de la BRAM que dio el TNS -341 de la _56). Con scanlines=0,
    // dim_r=0 y rgb_out ≡ rgb (cero cambio).
    // ========================================================================
    reg [1:0] ph3   = 2'd0;      // fase NTSC 0..2 de la línea ACTUAL
    reg [2:0] ph5   = 3'd0;      // fase PAL  0..4 de la línea ACTUAL
    reg       dim_r = 1'b0;

    wire [1:0] ph3_nx = (cy >= 10'd749) ? 2'd0
                                        : ((ph3 == 2'd2) ? 2'd0 : ph3 + 2'd1);
    wire [2:0] ph5_nx = (cy >= 10'd749) ? 3'd0
                                        : ((ph5 == 3'd4) ? 3'd0 : ph5 + 3'd1);

    always @(posedge clk_pixel) begin
        if (cx == wlast) begin
            ph3   <= ph3_nx;
            ph5   <= ph5_nx;
            // V9968: vertical x3 en AMBOS modos -> patron 1-de-3 tambien en PAL
            dim_r <= scan_x && (ph3_nx == 2'd2);
        end
    end

    wire [23:0] rgb_out = dim_r ? {1'b0, rgb[23:17],
                                   1'b0, rgb[15:9],
                                   1'b0, rgb[7:1]}
                                : rgb;

    // ========================================================================
    // Audio: divisor a 44100 Hz desde clk_pixel + cruce 2FF (como sms2hdmi)
    // ========================================================================

    // _127G (bug #14, bajones de volumen): el divisor ENTERO truncaba
    // 74.25M/44100/2 = 841.83 -> 841 y el sample rate real era 44144.5 Hz
    // frente a los 44100 que anuncia el ACR (N=6272/CTS=82500): +0.1% de
    // deriva continua. El buffer del receptor la aguanta ~30-40 s y luego
    // corrige a trompicones cada ~3 s — EXACTAMENTE lo observado en HW
    // (OPL4 wave bien 30-40 s y luego cortes ritmicos; FM/SCC "mal desde
    // el principio" porque su musica arranca con la deriva ya saturada).
    // Fix: acumulador FRACCIONAL — 88200 toggles/s exactos de media
    // (2 por muestra) => 44100.000 Hz. Jitter de +-1 ciclo de pixel:
    // irrelevante (el dato cruza por audio_sample_word y el modulo hdmi
    // empaqueta por muestra).
    // _127I (bug #14, LA CAUSA): clk_audio era un REGISTRO usado como reloj —
    // Gowin lo rutaba por fabric generico (PR1014 en el log del PnR:
    // "excessive delay or skew") y el skew intra-dominio en el contador del
    // ACR corrompia el CTS => el monitor re-engancha su PLL de audio a
    // trompicones (cortes ~3s tras 30-40s). Con el diseno v9958 (holgado)
    // el skew no mordia; con el V9968 (congestionado) si. FIX: se ELIMINA el
    // reloj de fabric — clock-enable de 1 ciclo a 44100.000 Hz exactos de
    // media (acumulador fraccional 44100/74250000), todo sincrono a
    // clk_pixel. De regalo el CTS medido queda exacto y el SDC ya no
    // necesita el create_clock clock_audio68 (retirado de msx_v9968.sdc).
    reg  [26:0] audio_acc = 27'd0;
    reg         audio_ce  = 1'b0;

    always_ff @(posedge clk_pixel) begin : audio_div_frac
        reg [27:0] acc_n;
        acc_n = {1'b0, audio_acc} + 28'd44100;
        if (acc_n >= 28'd74250000) begin
            audio_acc <= acc_n[26:0] - 27'd74250000;
            audio_ce  <= 1'b1;
        end else begin
            audio_acc <= acc_n[26:0];
            audio_ce  <= 1'b0;
        end
    end

    // _126 (bug #14, bajones de volumen): el "cruce 2FF" era un 2FF sobre un
    // BUS de 16 bits — protege la metaestabilidad de cada bit pero NO la
    // coherencia del conjunto: una captura a caballo de un cambio del
    // mezclador (27MHz async; p.ej. 0x0001->0xFFFF en un cruce por cero)
    // produce un valor RASGADO = pico fuerte. Picos frecuentes activan el
    // limitador/AGC del televisor -> "bajones y subidas de volumen" en
    // TODAS las fuentes (SCC/OPL4 FM/wave: es el camino comun), y la tasa
    // depende del jitter relativo de PLLs -> variable por build/placement.
    // FILTRO DE ESTABILIDAD: 3 capturas a clk_pixel; la muestra solo se
    // acepta cuando las dos ultimas (ya asentadas) coinciden. El mezclador
    // cambia cada ~280ns y aqui se muestrea cada 13.5ns: como mucho se
    // retrasa una muestra 27ns — inaudible; el rasgado desaparece.
    reg [15:0] aud_c0 [1:0], aud_c1 [1:0], aud_c2 [1:0];
    reg [15:0] audio_sample_word [1:0];
    always @(posedge clk_pixel) begin
        aud_c0[0] <= audio_l;      aud_c1[0] <= aud_c0[0];   aud_c2[0] <= aud_c1[0];
        aud_c0[1] <= audio_r;      aud_c1[1] <= aud_c0[1];   aud_c2[1] <= aud_c1[1];
        if (aud_c1[0] == aud_c2[0]) audio_sample_word[0] <= aud_c2[0];
        if (aud_c1[1] == aud_c2[1]) audio_sample_word[1] <= aud_c2[1];
    end

    // _133 VUMETRO (bug #14): pico de |audio_sample_word[0]| por ventana de
    // ~0.23s (2^24 ciclos de pixel) con registro de retencion — el COM11 lo
    // muestrea cuasi-estatico. Si durante un corte audible este pico se
    // DESPLOMA, las muestras que consume el HDMI van ya muertas (reo aguas
    // arriba); si sigue alto, el reo es el empaquetado o el receptor.
    reg [15:0] amp_acc = 16'd0;
    reg [23:0] amp_win = 24'd0;
    reg [15:0] dbg_amp_r = 16'd0;
    wire [15:0] asw_abs = audio_sample_word[0][15]
                        ? (~audio_sample_word[0] + 16'd1)
                        : audio_sample_word[0];
    always @(posedge clk_pixel) begin
        amp_win <= amp_win + 24'd1;
        if (amp_win == 24'd0) begin
            dbg_amp_r <= amp_acc;
            amp_acc   <= 16'd0;
        end
        else if (asw_abs > amp_acc) amp_acc <= asw_abs;
    end
    assign dbg_amp = dbg_amp_r;

    // ========================================================================
    // Diagnóstico (stretchers retriggerables; activo = 1)
    // ========================================================================

    localparam DBG_W_CLK = 20;  // 2^20 @ 27 MHz  ≈ 38.8 ms
    localparam DBG_W_PIX = 21;  // 2^21 @ 74.25 MHz ≈ 28.2 ms

    reg [DBG_W_CLK-1:0] str_vs = '0, str_wr = '0, str_nb = '0;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            str_vs <= '0; str_wr <= '0; str_nb <= '0;
        end else begin
            if (vs_lead)                  str_vs <= {DBG_W_CLK{1'b1}};
            else if (str_vs != 0)         str_vs <= str_vs - 1'b1;
            if (wr_en)                    str_wr <= {DBG_W_CLK{1'b1}};
            else if (str_wr != 0)         str_wr <= str_wr - 1'b1;
            if (wr_en && wr_data != 0)    str_nb <= {DBG_W_CLK{1'b1}};
            else if (str_nb != 0)         str_nb <= str_nb - 1'b1;
        end
    end
    assign dbg_vs_tick  = (str_vs != 0);
    assign dbg_wr_act   = (str_wr != 0);
    assign dbg_nonblack = (str_nb != 0);
    assign dbg_lock_tgl = frame_tgl;

    reg [DBG_W_PIX-1:0] str_rst = '0;
    always @(posedge clk_pixel) begin
        if (hdmi_rst)          str_rst <= {DBG_W_PIX{1'b1}};
        else if (str_rst != 0) str_rst <= str_rst - 1'b1;
    end
    assign dbg_hdmi_rst = (str_rst != 0);
    assign dbg_rd_act   = win_next;

`ifndef SIM_NO_HDMI

    // ========================================================================
    // HDMI real: dos hdmi (fork tn_vdp con salida tmds_internal), mux por
    // pal_x, serializer externo y ELVDS — patrón v9958_top.v líneas 449-523.
    // ========================================================================

    logic [9:0] tmds_ntsc [NUM_CHANNELS-1:0];
    wire apkt_pulse_ntsc, aovr_pulse_ntsc;      // _127I telemetria bug #14
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
            .NUM_CHANNELS(NUM_CHANNELS),
            // _169: parte el cono del codificador 8b/10b, que es el peor SETUP
            // del diseño (ver el bloque grande en tmds_channel.sv). Se activa
            // SOLO en la linea del V9968: msx2hdmi.sv (la clasica del V9958, ya
            // publicada, 6 instancias) se queda con el valor por defecto 0 y su
            // netlist es identico bit a bit al de siempre.
            // Bit-exactitud demostrada en tb_tmds_equiv.sv: 320.010 ciclos,
            // cero discrepancias en tmds y en acc.
            .PIPELINE_QM(1'b1)
            )
    hdmi_ntsc ( .clk_pixel_x5(clk_5x_pixel),
          .clk_pixel(clk_pixel),
          .audio_ce(audio_ce),
          .rgb(rgb_out),       // _58: con dim de scanlines aplicado
          .reset( hdmi_rst ),
          .reset_cx( rst_cx[10:0] ),   // _136: anclaje compensado
          .audio_sample_word(audio_sample_word),
          .aspect_16_9(1'b0),  // v3.0: con VIC 4/19 el hack VIC+aspect del AVI InfoFrame anunciaria 1080i
          .cx(cx_ntsc),
          .cy(cy_ntsc),
          .tmds_internal(tmds_ntsc),
          .audio_pkt_pulse(apkt_pulse_ntsc),
          .audio_ovr_pulse(aovr_pulse_ntsc)
        );

    // _127I telemetria bug #14: contadores de paquetes de audio despachados
    // y de overruns del doble buffer del packet_picker (instancia NTSC — la
    // salida real; el nucleo es NTSC-only). Esperado: 11025.0 paquetes/s
    // CLAVADOS y ovr=0. Si la tasa baja o hay ovr durante un corte audible,
    // el lado transmisor es culpable; si sigue perfecta -> receptor/cable.
    reg [15:0] apkt_cnt = 16'd0;
    reg [7:0]  aovr_cnt = 8'd0;
    always @(posedge clk_pixel) begin
        if (apkt_pulse_ntsc) apkt_cnt <= apkt_cnt + 1'b1;
        if (aovr_pulse_ntsc) aovr_cnt <= aovr_cnt + 1'b1;
    end
    assign dbg_apkt = {aovr_cnt, 8'h00, apkt_cnt};

    logic [9:0] tmds_pal [NUM_CHANNELS-1:0];

    // ========================================================================
    // _168 BACK-END PAL BAJO generate. Ver la cabecera del modulo: hoy es
    // LOGICA MUERTA (pal_mode llega cableado a 0 desde top.v:1969).
    //
    // ⚠️ POR QUE UN generate Y NO SOLO LA CONSTANTE. El primer intento fue
    // hacer `pal_x` constante de elaboracion y confiar en que la propagacion de
    // constantes podara la instancia sola. NO FUNCIONA: medido en la campana
    // s003, el informe de sintesis seguia listando
    //     name="hdmi_pal" T_Register="606" T_Lut="808"
    // y el CLS no bajo ni un punto. Gowin NO elimina instancias de jerarquia
    // aunque ninguna de sus salidas se use. Hace falta que la instancia no
    // llegue a elaborarse, y eso solo lo da un generate sobre un parametro.
    // (Coste de averiguarlo en la linea ligera: 2 minutos. En la completa
    // habrian sido 50.)
    // ========================================================================
    generate
    if (ENABLE_PAL != 0) begin : g_hdmi_pal
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
                .NUM_CHANNELS(NUM_CHANNELS),
                .PIPELINE_QM(1'b1)          // _169, igual que el NTSC
                )
        hdmi_pal ( .clk_pixel_x5(clk_5x_pixel),
              .clk_pixel(clk_pixel),
              .audio_ce(audio_ce),
              .rgb(rgb_out),       // _58: con dim de scanlines aplicado
              .reset( hdmi_rst ),
              .reset_cx( rst_cx[11:0] ),   // _136: anclaje compensado
              .audio_sample_word(audio_sample_word),
              .aspect_16_9(1'b0),  // v3.0: con VIC 4/19 el hack VIC+aspect del AVI InfoFrame anunciaria 1080i
              .cx(cx_pal),
              .cy(cy_pal),
              .tmds_internal(tmds_pal)
            );
    end
    else begin : g_sin_pal
        // Sin back-end PAL: se atan las salidas para no dejarlas sin conducir.
        // Con pal_x constante 0 no las lee nadie (el mux de mas abajo y los
        // cx/cy de la linea ~390 se pliegan al lado NTSC en elaboracion).
        assign cx_pal = 12'd0;
        assign cy_pal = 10'd0;
        for (genvar gp = 0; gp < NUM_CHANNELS; gp = gp + 1) begin : tie_pal
            assign tmds_pal[gp] = 10'd0;
        end
    end
    endgenerate

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
