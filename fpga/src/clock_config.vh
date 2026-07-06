// ============================================================================
//  clock_config.vh — base de reloj centralizada del port a la Console 60K
// ----------------------------------------------------------------------------
//  Todas las constantes absolutas del core que dependen del reloj se derivan
//  aquí de UN único parámetro CLK_108_HZ. Con 108.000000 MHz exactos, TODOS los
//  valores coinciden con los literales actuales del RTL del TN20K.
//
//  ⚠ OPEN-ITEM Nº1 (ver docs/PORT_FINDINGS.md §2): el reloj de ENTRADA del
//  Console 60K es 50 MHz (pin V22), NO 27 MHz. Generar 108.000 exactos desde
//  50 MHz con PLL entera NO es trivial (PFD caería <3 MHz). Hasta resolverlo
//  (fuente de 27 MHz / PLLA fraccional / base cercana + re-derivar), CLK_108_HZ
//  debe fijarse a lo que el PLLA del GW5A produzca REALMENTE. Si no son 108
//  exactos, los símbolos marcados [C] (turbo WSX, prescaler WiFi) hay que
//  re-derivarlos con las fórmulas de docs/CLOCK_CONSTANTS.md §4, NO a ojo.
//
//  Anclajes: docs/CLOCK_CONSTANTS.md (tabla file:line del TN20K).
// ============================================================================
`ifndef CLOCK_CONFIG_VH
`define CLOCK_CONFIG_VH

// ---- Base (fijar al valor REAL que dé el PLLA del GW5A) ----
localparam integer CLK_108_HZ = 108_000_000;            // salida de CLK_108P/PLLA
localparam integer CLK_54_HZ  = CLK_108_HZ / 2;         // Gowin_CLKDIV2  = 54_000_000
localparam integer CLK_27_HZ  = CLK_108_HZ / 4;         // Gowin_CLKDIV   = 27_000_000

// ---- Bus MSX 3.6 MHz interno (÷30 sobre 108): medio-periodo ----   [top.v:225]
localparam integer BUS_3M6_HZ = 3_600_000;
localparam integer DIV30_HALF = CLK_108_HZ/(2*BUS_3M6_HZ) - 1;        // = 14

// ---- Turbo WSX: base 5.4 MHz (÷20 sobre 108) + trago 175/176 ----  [top.v:899,917/924]  [C]
//  5.4M * 175/176 = 5_369_318 Hz EXACTO. El par (÷20, 175/176) SOLO da el
//  valor exacto si TURBO_BASE_HZ == 5.400000 MHz. Validado en HW a 5.369318 MHz.
localparam integer TURBO_BASE_HZ  = CLK_108_HZ / 20;                  // 5_400_000 (debe ser exacto)
localparam integer DIV20_HALF     = CLK_108_HZ/(2*TURBO_BASE_HZ) - 1; // = 9
localparam integer PANA_SWALLOW_N = 175;   // enmascara 1 de cada 176
localparam integer PANA_SWALLOW_D = 176;

// ---- Power-on WiFi/ESP: ~3 s @27 ----                              [top.v:836]
localparam integer ESP_BOOT_CNT = 3 * CLK_27_HZ;                     // = 81_000_000

// ---- Autofire: semiperiodo 50 ms @54 ----                          [top.v:516]
localparam integer AF_HALF_CNT  = CLK_54_HZ / 20;                    // = 2_700_000

// ---- Secuencia reset power-on: ~38.8 ms/paso @27 ----              [top.v:290]
localparam integer RST_STEP_CNT = 1 << 20;                          // 1_048_576 (~38.8 ms)

// ---- Filtro PSG/OPLL (enables) @27 ----                            [psg_filter.v:28,32]
localparam integer PSG_2M7_DIV  = CLK_27_HZ/2_450_000 - 1;          // = 10  (÷11)
localparam integer PSG_270K_DIV = CLK_27_HZ/  267_000 - 1;          // = 100 (÷101)

// ---- LED activity stretch @27 ----                                 [top.v:2797-2799]
localparam integer LED_50MS = CLK_27_HZ / 20;                       // 1_350_000
localparam integer LED_20MS = CLK_27_HZ / 50;                       // 540_000

// ---- WS2812: frecuencia del driver en MHz ----                     [top.v:2811]
localparam integer WS2812_CLK_MHZ = CLK_27_HZ / 1_000_000;          // 27

// ---- WiFi UART: prescaler del baudrate FIJO del firmware ESP de ducasp ----  [wifi_lite.vhd:205]  [C]
//  Objetivo = 859_372 bps (lo fija el firmware, no negociable). NO es fracción
//  de la base: prescaler = round(CLK_WIFI / 859_372). Con 27 MHz -> 31.
localparam integer WIFI_BAUD_HZ   = 859_372;
localparam integer WIFI_PRESCALER = (CLK_27_HZ + WIFI_BAUD_HZ/2) / WIFI_BAUD_HZ; // = 31 @27MHz
localparam integer WIFI_TMO_25MS  = CLK_27_HZ / 40;                 // = 675_000   [wifi_lite.vhd:243]

// ---- CASO APARTE: RTC 1 segundo (rtc.v:66) ----                    [C]
//  NO es un contador lineal: es un patrón terminal de LFSR de 22 bits que
//  recorre 3_579_547 estados (= 1 s) del enable de 3.579545 MHz (clk_enable_3m6_27).
//  Mientras ese enable siga siendo 3.579545 MHz, el valor NO cambia:
//      c_1sec_cnt0 = 22'h2D94A3
//  Si cambia el nº de ticks/segundo del enable, REGENERAR con el LFSR de KdL
//  (polinomio ~(bit21^bit20)), NUNCA restando. Por eso no está como localparam.

`endif // CLOCK_CONFIG_VH
