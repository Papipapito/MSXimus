`define ENABLE_V9958
`define ENABLE_BIOS
`define ENABLE_SOUND //v9958, bios required
`define ENABLE_MAPPER //bios required
`define ENABLE_SCAN_LINES
`define ENABLE_SDCARD
`define ENABLE_CONFIG
`define ENABLE_WAIT //extra wait state for mreq+wr
//`define ENABLE_WAIT_ADAPTIVE //wait required
`define ENABLE_M1_WAIT //STANDALONE: 1 wait-state per M1 opcode fetch (the real-MSX brake). Comment out to disable.
//`define SWAP23
// ============ v3.0 BASE MINIMA (Fase 1-REDUX, 2026-07-09) ============
// Video 720p por puente BRAM (video720/msx2hdmi.sv) + subsistemas fuera.
// IMPORTANTE: VIDEO720 tambien esta `define'd en tn_vdp_v3_v9958/src/
// v9958_top.v (ficheros de compilacion distintos) — mantener SINCRONIZADOS.
`define VIDEO720
`define ENABLE_WIFI       // F1 (_73): WiFi UNAPI por el BL616 ONBOARD (UART en V14/U15, ver uwifi)
`define ENABLE_WIFI_ESP32 // _153: la UART del WiFi va al ESP32-C6 externo por el conector J10 (2x20 libre, fila PAR: 12=GND, 14=TX(W21), 16=RX(N17)) en vez del BL616 (sin antena/fw). Mismo wifi_lite, mismo baud 27M/31: el fw ducasp/ESP32-UNAPI a 859372 ya esta validado con este prescaler en el MSXnano.
//`define WIFI_PMOD_TEST  // (_77diag) UART del WiFi al PMOD1 — apagado
//`define WIFI_TAP_BL616TX  // _78diag (APAGADO en _111c: llevaba desde la _78 robandole E22 a todo; la telemetria _111 nunca salio por su culpa)
`define ENABLE_OPLL         // F3 (_38): OPLL de vuelta — 1a pieza re-añadida sobre la base validada
`define ENABLE_Y8950        // F2 (_79): MSX-Audio (Y8950) FM via jtopl2 (core ya vendido en fpga/jtopl/), puertos C0/C1. VALIDADO EN HW (juego OK)
`define ENABLE_Y8950_ADPCM  // F2 (_80): ADPCM-B del Y8950 — y8950_adpcm.v (glue openMSX-exacto) + decoder jt10_adpcmb + RAM samples 32KB BSRAM (NMS-1205 de serie). VALIDADO HW+VGMPlay
`define ENABLE_Y8950_IRQ    // F2 (_81): IRQ del Y8950 (timers+EOS+BUF ya enmascarados) al /INT del Z80 (wired-AND como el Music Module real). Arranca todo enmascarado = sin IRQ hasta que el software la pida
`define ENABLE_OPL4FM       // F2 (_82-_85): MoonSound FM (OPL3) en C4-C7 + stub wave 7E/7F. VALIDADO EN HW (reloj 96/98, limpio)
`define ENABLE_WAVE_DDR3    // F2 (_86): bring-up de la DDR3 del SOM para la memoria de ondas OPL4 (cliente independiente + puerto debug I/O 34-37h). Fase wavetable
`define ENABLE_WAVE_LOADER  // F2 (_87): carga de la YRW801 (2MB) de flash 0x500000 a DDR3 en BACKGROUND tras el boot (no bloquea el arranque). Status: bit2 de IN 36h = cargando
`define ENABLE_OPL4_WAVE    // F2 (_89): motor PCM 24 slots del OPL4 (YMF278B.sv de srg320 + permiso) en clk_x1 de la DDR3, CE fraccionario 44.1kHz con stall. REQUIERE ENABLE_WAVE_DDR3+LOADER. Con esto el MoonSound esta COMPLETO (FM+wavetable)
`define ENABLE_USB_KBD      // F3 (_39): teclado por USB-A DIRECTO al fabric (usb_hid_host, sin hub)
`define ENABLE_SCC          // F3 (_40): SCC de vuelta — scc_wave2v Verilog puro (el VHDL scc_wave_mul era BARRIDO por la sintesis GW5A)
`define ENABLE_TURBO       // P1: turbo WSX 5.37 de vuelta con la receta v1.9 (turbo_eff sin glitch + boot-turbo solo en frio)
//`define ENABLE_V9968_VDP   // F1 V9968: VDP de HRA! (fpga/v9968, tag+eco) + shim VRAM a SDRAM compartida (puerto wv2) + puente 800px (msx2hdmi_v9968). Sustituye v9958_top ENTERO. Activar en el build _117
//`define ENABLE_VRAM_DDR3   // _128X EXPERIMENTO: la VRAM del V9968 en la DDR3 del SOM (v9968_ddr3_backend; requiere ENABLE_V9968_VDP y USE_VRAM_DDR3=1 en build.tcl). ADVERTENCIA: DDR3 analogicamente marginal en esta placa (saga _94-_103)
//`define DISABLE_BOOT_MENU  // _127D: arranque MSX DIRECTO (enmascara la firma AB del menu; tambien salta el init FM de esa pagina). Solo builds de prueba.

// _159: la RAM de muestras del ADPCM-B pasa de 32KB en BSRAM a los 256KB
// COMPLETOS del Y8950 servidos desde la SDRAM (adpcm_sdram.v -> puerto wv2,
// filas 5120+). Esto NO se decide a mano: se DERIVA, porque solo es legal
// cuando wv2 esta libre. Lo esta con el V9968 apagado y con el V9968 + VRAM
// en DDR3 (la linea principal _138); en la linea de respaldo _137 (VRAM del
// V9968 en la SDRAM) lo conduce el bridge del V9968 y el ADPCM cae solo a
// los 32KB de BSRAM de siempre (adpcm_sdram con FALLBACK_BSRAM=1). Derivarlo
// hace IMPOSIBLE por construccion la combinacion con dos drivers de wv2.
`ifdef ENABLE_Y8950_ADPCM
 `ifndef ENABLE_V9968_VDP
  `define ENABLE_ADPCM_SDRAM
 `else
  `ifdef ENABLE_VRAM_DDR3
   `define ENABLE_ADPCM_SDRAM
  `endif
 `endif
`endif

module top
#(
    parameter SD_SLOT = 3
)(
    input wire ex_clk_27m,  // Console 60K: 50 MHz (pin V22); el nombre se conserva del TN20K
    input wire s1,
    input wire s2,

    // --- STANDALONE MERGE: MSX bus ports removed; replaced by USB (BL616) + LED ---
    // The old external MSX bus signals (ex_bus_wait_n/int_n/reset_n/clk_3m6,
    // ex_bus_data, ex_msel, ex_bus_m1_n/rfsh_n/mreq_n/iorq_n/rd_n/wr_n,
    // ex_bus_data_reverse_n, ex_bus_mp) are now INTERNAL wires/tie-offs (see below).

    // SPI to on-board BL616 (FPGA Companion) - USB KEYBOARD and gamepads
    // (Console 60K: puertos m0s del dock M0S eliminados; companion BL616 onboard)
    input  wire spi_sclk,
    input  wire spi_csn,
    output wire spi_dir,
    input  wire spi_dat,
    output wire spi_irqn,
    // _153: WiFi por ESP32-C6 externo (Waveshare C6-LCD-1.3, fw ESP32-UNAPI-
    // Firmware rama msxnano, 859372 bps) en el CONECTOR J10 (el 2x20 libre,
    // "SDRAM1 CONN." del esquematico oficial 32001C; el modulo SDRAM del core
    // va en el otro). Peticion de Albert (v2, foto de la placa): los pines en
    // FILA UNICA para cable plano de una hilera -> COLUMNA PAR, pines 12-14-16
    // consecutivos: GND(12) TX(14=W21) RX(16=N17). El +5V (pin 11) queda en la
    // columna impar, asi que el C6 se alimenta por su USB-C.
    // esp_rx_i PULL_UP = idle UART correcto sin modulo pinchado.
    // ⚠ Si algun dia se pincha un 2o modulo SDRAM en J10, esto se muda.
    input  wire esp_rx_i,    // N17 = J10 pin 16 (SDRAM1_D10) <- IO16 (TX) del C6
    output wire esp_tx_o,    // W21 = J10 pin 14 (SDRAM1_D12) -> IO17 (RX) del C6
    // _156: indicador de TURBO en la pantalla del C6 (mismo esquema que el
    // nano: turbo_status pin 29 -> GPIO3, Display.ino TURBO_PIN con pulldown).
    // J10 pin 18 = el siguiente par del bloque => cable plano de 4 seguidos:
    // 12=GND 14=TX 16=RX 18=TURBO. Cablear al GPIO3 del C6. Peticion de Albert.
    output wire esp_turbo_o, // N13 = J10 pin 18 (SDRAM1_D8) -> GPIO3 del C6
    // Console 60K, mecánica JTAG→SPI (estilo C64Nano): jtagseln (NET_LOC
    // V_JTAGSELN) entrega los pines JTAG al fabric cuando vale 1; el BL616
    // reclama JTAG subiendo bl616_jtagsel (PULL_UP: sin firmware companion la
    // placa queda en modo JTAG = siempre reprogramable).
    input  wire bl616_jtagsel,
    output wire jtagseln,

    // discrete status LEDs (active low)
    output wire [5:0] led,
    output wire ws2812_led,   // external WS2812B status strip (case)

    // ---- DEBUG BRING-UP 60K: "electrocardiograma" por los dos PMODs ----
    //  (se retirará al terminar el bring-up; pines de C64Nano, LVCMOS33)
    //  PMOD1 io[0..5]=W19,W20,F19,F20,E22,D22 · PMOD0=V19,V18,G22,G21,E18
    output wire [4:0] dbg_pmod1,   // (D22/bit5 liberado para uart_pmod_rx)
    output wire [4:0] dbg_pmod0,
    input  wire uart_pmod_rx,      // PMOD1 D22: RX del WiFi en modo WIFI_PMOD_TEST (PC-de-ESP)

    //hdmi out
    output wire [2:0] data_p,
    output wire [2:0] data_n,
    output wire clk_p,
    output wire clk_n,

    // flash
    output wire mspi_cs,
    output wire mspi_sclk,
    inout wire mspi_miso,
    inout wire mspi_mosi,
    // Console 60K: la flash va cableada QSPI (W25Q64) — /WP y /HOLD deben ir a
    // nivel alto o la flash puede bloquearse/pausarse con los pines flotando.
    output wire mspi_wp,
    output wire mspi_hold,

    // MicroSD
    output wire sd_sclk,
    inout wire sd_cmd,      // MOSI
    inout  wire sd_dat0,     // MISO
    output wire sd_dat1,     // 1
    output wire sd_dat2,     // 1
    output wire sd_dat3,     // 1

    // F1 (_73): los puertos uart_tx/uart_rx del ESP-01S (nano) NO existen en el
    // 60K — la UART del WiFi va al BL616 ONBOARD por los pads ya constreñidos
    // bl616_jtagsel (V14 = GPIO28 TX del BL616) y spi_irqn (U15 = GPIO27 RX).

    //usb uart
    output wire usb_uart_tx,

`ifdef ENABLE_USB_KBD
    // F3 (_39): los 2 USB-A de la Console 60K van DIRECTOS al fabric
    // (H13/G13, M15/M16 — verificado en los .cst de TangCore; el esquematico
    // de Sipeed esta mal). Soft-host low-speed 1.5Mbps por puerto.
    inout wire usb1_dp,
    inout wire usb1_dn,
    inout wire usb2_dp,
    inout wire usb2_dn,
`endif

    // Magic ports for SDRAM to be inferred
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n, // chip select
    output wire O_sdram_cas_n, // columns address select
    output wire O_sdram_ras_n, // row address select
    output wire O_sdram_wen_n, // write enable
    inout wire [15:0] IO_sdram_dq, // 16 bit bidirectional data bus (Console 60K: SDR externa W9825G6KH)
    output wire [12:0] O_sdram_addr, // 13 bit multiplexed address bus
    output wire [1:0] O_sdram_ba, // two banks
    output wire [1:0] O_sdram_dqm, // 16/2

    // ---- _86: DDR3 del SOM (memoria de ondas OPL4; cliente independiente,
    //      la SDRAM/memory.v NO se toca). Pines del ddr3_framebuffer_gowin.
    output wire [14:0] ddr_addr,
    output wire [2:0]  ddr_bank,
    output wire        ddr_cs,
    output wire        ddr_ras,
    output wire        ddr_cas,
    output wire        ddr_we,
    output wire        ddr_ck,
    output wire        ddr_ck_n,
    output wire        ddr_cke,
    output wire        ddr_odt,
    output wire        ddr_reset_n,
    output wire [1:0]  ddr_dm,
    inout  wire [15:0] ddr_dq,
    inout  wire [1:0]  ddr_dqs,
    inout  wire [1:0]  ddr_dqs_n,

    // Ventilador de la Console 60K (FAN_EN, pin AB12 Bank9 1.5V): la placa
    // conmuta los 5V del conector SH1.0 con 1 = ON. Gobernado por fan_ctrl
    // (termometro de anillo de latches, ver fan_ctrl.v / ro_osc.v).
    output wire        fan_en_o

    //output wire SLTSL3

);

// ============================================================================
// GUARDAS de la matriz ENABLE_* (niquelado B, bug #22 del informe): las
// combinaciones rotas COMPILABAN con nets implicitas de 1 bit sin driver
// (el patron que ya mordio en la _40). Ahora fallan en sintesis instanciando
// un modulo inexistente cuyo NOMBRE es el mensaje de error. Coste cero en
// builds sanos.
`ifdef ENABLE_OPL4_WAVE
 `ifndef ENABLE_WAVE_DDR3
    ERROR_ENABLE_OPL4_WAVE_requiere_ENABLE_WAVE_DDR3 u_guarda_def1();
 `endif
 `ifndef ENABLE_WAVE_LOADER
    ERROR_ENABLE_OPL4_WAVE_requiere_ENABLE_WAVE_LOADER u_guarda_def2();
 `endif
 `ifndef ENABLE_OPL4FM
    ERROR_ENABLE_OPL4_WAVE_requiere_ENABLE_OPL4FM u_guarda_def3();
 `endif
`endif
`ifdef ENABLE_WAVE_LOADER
 `ifndef ENABLE_WAVE_DDR3
    ERROR_ENABLE_WAVE_LOADER_requiere_ENABLE_WAVE_DDR3 u_guarda_def4();
 `endif
`endif
`ifdef ENABLE_VRAM_DDR3
 `ifndef ENABLE_V9968_VDP
    ERROR_ENABLE_VRAM_DDR3_requiere_ENABLE_V9968_VDP u_guarda_def5();
 `endif
`endif
// Stubs para builds SIN estos subsistemas (nets que el resto del top consume
// incondicionalmente — sin ellos, net implicita sin driver):
`ifndef ENABLE_CONFIG
    wire config_reset_req = 1'b0;   // warm-reset: sin bloque config no hay peticion
    wire pana41_wr        = 1'b0;   // turbo Panasonic: sin config no hay decode
`endif
`ifndef ENABLE_SDCARD
    wire sd_busy_w = 1'b0;
`endif

initial begin

end
    //`default_nettype none

    //assign SLTSL3 = bus_mreq_disable ^ bus_iorq_disable ^ xffh ^ xffl ^ mapper_read ^ exp_slotx_req_r ^ bios_req ^ subrom_req ^ vdp_csr_n;

    // ===== STANDALONE MERGE: internalized MSX bus signals =====
    // These used to be top-level ports driven/sensed by a real MSX board.
    // Now: data bus is internal, WAIT/INT tied inactive, RESET from button + PLL lock,
    // 3.58MHz CPU clock generated internally. (Ported verbatim from MSXnano/fpga/top.v.)
    wire [7:0] ex_bus_data;          // internal (no external bus); see assign below
    wire ex_bus_wait_n  = 1'b1;      // no external wait
    wire opl4pcm_wait_n;             // _89: /WAIT del motor PCM OPL4 (IN 7Fh)
    wire ex_bus_int_n   = 1'b1;      // INT comes from internal VDP only

    wire clock_locked;
    wire ex_bus_reset_n;
    // Console 60K: los botones S1/S2 son ACTIVOS A NIVEL BAJO (PULL_UP en el CST,
    // reposo=1, pulsado=0 — C64Nano los llama key_*_n). En el TN20K eran activos
    // a nivel ALTO: con el pull-up del 60K, el ~s1 original dejaba ex_bus_reset_n
    // =0 PERMANENTE = todo el core MSX en reset eterno (causa raiz del bring-up
    // muerto 2026-07-07/08). Normalizamos a "press" activo-alto:
    wire s1_press = ~s1;
    wire s2_press = ~s2;
    assign ex_bus_reset_n = ~s1_press && clock_locked;   // s1 pulsado = reset


    // 108 MHz / 30 = 3.6 MHz internal CPU clock (replaces ex_bus_clk_3m6 pin)
    wire ex_bus_clk_3m6;
    reg [4:0] div30_cnt;
    reg clk_3m6_internal;

    // dangling sinks for the (now internal) bus-control nets the old logic still drives
    wire [1:0] ex_msel;
    wire ex_bus_m1_n;
    wire ex_bus_rfsh_n;
    wire ex_bus_mreq_n;
    wire ex_bus_iorq_n;
    wire ex_bus_rd_n;
    wire ex_bus_wr_n;
    wire ex_bus_data_reverse_n;
    wire [7:0] ex_bus_mp;

    //clocks
    // Console 60K: un unico Gowin_PLL (PLLA GW5A) sustituye a las 3 IPs GW2A
    // (rPLL CLK_108P + CLKDIV /4 + CLKDIV /2). clk_108m_n (fase CLKOUTP del
    // rPLL viejo) no tenia consumidores y se ha eliminado.
    wire clk_108m;
    wire clk_135;               // TMDS x5 del HDMI (mismo VCO: 135 = 5 x 27 exacto)
    wire clk_wave375; // _104: 37.5 MHz del PLLA (motor OPL4) — declarado ANTES
                      // de su primer uso (leccion Gowin de los implicitos)
    Gowin_PLL pll_main (
        .clkin  (ex_clk_27m),   // ⚠ en la Console 60K este pin lleva 50 MHz (V22)
        .clkout0(clk_108m),     // 108.000000 MHz (fraccional, exacto)
        .clkout1(clk_54m),      //  54.000000 MHz
        .clkout2(clk_27m),      // v3.0: 27M del PLLA (fase CONOCIDA vs 54/108, como el
                                //  rPLL del TN20K). Ya NO alimenta ningun OSER10 (el
                                //  TMDS vive a 74.25/371.25 en pll_74) -> la restriccion
                                //  que motivo el CLKDIV desaparece con el video 720p.
        .clkout3(clk_135),      // 135.000000 MHz (TMDS; sustituye al CLK_135 del tn_vdp)
        .clkout4(clk_wave375),  // _104: 37.500 MHz (motor OPL4 wave; VCO/36, fase t=0)
        .lock   (clock_locked),
        .mdclk  (ex_clk_27m)    // reloj de init del PLLA (secuencia mDRP)
    );

    // clk_27m = CLKDIV ÷5 del 135 (patrón nestang/z8086/Gowin en GW5A): el par
    // PCLK(27)/FCLK(135) de los OSER10 del TMDS queda alineado POR CONSTRUCCIÓN.
    // Dos salidas independientes del PLLA NO garantizan la fase de arranque de
    // sus divisores → serialización TMDS muerta (bring-up 2026-07-07: z8086
    // funcionaba en la placa y nuestro _06 no; este era el delta restante).
    // v2.4: CLKDIV/5 RESTAURADO (el OSER10 lo exige; _28 lo demostro en placa).
    // Su fase vs 54M es arbitraria -> NADA con bus de CPU debe clockear a 27M:
    // el PSG se movio al dominio 54M (v2.4); el arbitro DH/DL queda como unico
    // frente de fase pendiente (F11) — plan B: cruce en el linebuffer.
    // ================================================================
    // v3.0 FASE 1-REDUX: cadena de video 720p CALCADA de monitorcore
    // (la plantilla oficial de nand2mario para esta placa, validada por
    // Albert 10/10 arranques compilada con NUESTRA toolchain). Cascada
    // 50(pad) -> pll_27 -> 27 -> pll_74 -> 74.25 (pixel) + 371.25 (x5
    // TMDS), PLLA crudas identicas a las suyas. El CLKDIV desaparece:
    // clk_27m del MSX sale ahora del PLLA principal (clkout2, arriba) y
    // el HDMI ya no comparte NADA con el arbol del MSX — el cruce es
    // solo el ring BRAM dual-clock + toggles 2FF de msx2hdmi.
    // ================================================================
    wire clk27_video;           // 27M intermedio de la cascada (SOLO alimenta pll_74)
    wire clk_hdmi;              // 74.25 MHz pixel 720p
    wire clk_hdmi5;             // 371.25 MHz TMDS x5
    wire pll27_lock;            // _87: gatea el reset del PLL DDR3 (calib estable)
    pll_27 pll27_video (
        .clkin  (ex_clk_27m),   // pad 50 MHz
        .clkout0(clk27_video),
        .lock_o (pll27_lock)
    );
    pll_74 pll74_video (
        .clkin  (clk27_video),
        .clkout0(clk_hdmi),
        .clkout1(clk_hdmi5)
    );

    // _84: el OPL3 corre en clk_27m (PLLA principal, HERMANO de clk_54m):
    // cruce host_if emparentado que el STA cronometra (la afifo llevaba
    // ASYNC_REG de Xilinx que Gowin ignora — con PLLs distintos el CDC iba
    // sin blindar: candidato a las escrituras poco fiables de la _82/_83).
    // Sin 3er PLL. El pkg compensa: CLK_DIV_COUNT=545 -> fs 49.541 kHz
    // (+0.05%). pll_3375.v queda en el arbol por si se quiere volver.

    // JTAG→SPI del companion (estilo C64Nano): los pines JTAG se entregan al
    // fabric (SPI del BL616) solo con el PLL en lock y sin petición de JTAG del
    // BL616 (bl616_jtagsel, PULL_UP). Sin término de botón: s2 es el reset MSX
    // y no debe flapear el modo JTAG.
`ifdef ENABLE_WIFI
    // F1 (_73): GPIO28 del BL616 pasa a ser su UART TX (idle ALTO + trafico) ->
    // la mecanica jtagsel/companion queda invalida (el companion-SPI se
    // sacrifica: el teclado sigue por el soft-host USB-A). JTAG fijo en modo
    // JTAG: el flasheo del FPGA via partner queda intacto y sin flapeos.
    assign jtagseln = 1'b0;
`else
    assign jtagseln = clock_locked & ~bl616_jtagsel;
`endif

    // ================================================================
    //  VENTILADOR por temperatura, TOMA 2 (_122): en HW la toma 1 no
    //  disparo con el disipador caliente (umbral +30C demasiado alto o
    //  pendiente del anillo menor que la estimada). Albert pide disparo
    //  ~40C: umbral RELATIVO bajado a ~+7-10C sobre el arranque
    //  (K_ON=10/1024 ~1%, K_OFF=5/1024) — con el die tibio deberia
    //  arrancar solo. Fail-safe intacto (anillo muerto -> ON).
    //  TOMA 3 (_123): en HW _122 TAMPOCO disparo con el disipador bien
    //  caliente — la pendiente real del anillo es aun menor. Umbral a
    //  K_ON=5/1024 (~0.5%) y, sobre todo, dbg_cnt del termometro SALE
    //  por el COM11 (4a palabra de la telemetria) para calibrar de una
    //  vez con lecturas reales frio/caliente en vez de seguir adivinando.
    //  TOMA 4 (_124): CALIBRADO con la telemetria de HW _123 — pendiente
    //  real ~6x menor (frio 386400, caliente-que-Albert-quiere-fan
    //  ~385400, WIN 2^17). Umbrales ABSOLUTOS (inmunes al reflasheo en
    //  caliente que envenenaba la baseline relativa) con WIN doblada a
    //  2^18 (menos ruido; cuentas x2: frio ~772800, ON <771600,
    //  OFF >772300).
    // ================================================================
    wire        fan_ro_en, fan_ro_rst;
    wire [19:0] fan_ro_cnt;
    wire [19:0] fan_dbg_cnt;
    //  TOMA 5 (_125): los umbrales ABSOLUTOS de la toma 4 murieron al
    //  rebuild (el anillo de la _124 corria un 8% mas rapido que el de la
    //  _123: la frecuencia depende del placement). Modo RELATIVO con la K
    //  real medida (K_ON=2/1024 = -0.195%, el punto de Albert era -0.26%)
    //  + garantia por tiempo: fan FIJO a los 6 min si no ha disparado.
    // _152: ventilador ~5 grados MAS TARDE + EL DOBLE DE HISTERESIS.
    // Albert reporto DOS cosas: que arranca pronto y que "se enciende y apaga
    // bastante" (ciclado audible, visible en el COM11: la columna fan alterna
    // ON/of cada pocos segundos). Lo segundo es histeresis corta, no umbral.
    // Un paso de K vale 1/1024 = 0.0977% de la cuenta del anillo; con la
    // pendiente REAL medida en placa (~0.0167%/grado, ver cabecera de
    // fan_ctrl.v: 6x menor que la teorica de 0.1%/grado) eso son ~5.9 grados.
    // Subiendo SOLO K_ON se arreglan las dos a la vez: el arranque sube ~5.9
    // grados y la banda pasa de 1 a 2 unidades (~5.9 -> ~11.7 grados), asi que
    // una vez encendido sopla el doble antes de parar y cicla la mitad.
    //   K_ON  2->3 : arranca a ~17.5 grados sobre el frio (antes ~11.7)
    //   K_OFF 1    : para    a  ~5.9 grados sobre el frio (SIN CAMBIO)
    // _173 EXPERIMENTO (peticion de Albert, 03/08): VENTILADOR SIEMPRE ON.
    // Motivo doble: (1) en placa el ventilador NO gira NUNCA, ni siquiera
    // pasados los 360 s de la garantia FORCE_ON_SEC — o sea que o el control
    // no llega al pin o el camino fisico (conector/polaridad/fan) esta mal, y
    // clavar el pin a 1 separa las dos cosas; (2) hay sospecha de margen
    // TERMICO en el arranque (bucle de resets en SCREEN 1 con la placa
    // caliente): con el fan fijo la temperatura deja de ser variable.
    // El fan_ctrl se queda instanciado SOLO como termometro: fan_dbg_cnt
    // sigue saliendo por el COM11 (columna T), su decision se ignora.
    wire fan_en_ctrl;  // decision del control, hoy ignorada (telemetria)
    fan_ctrl #(.WIN_CYC(32'd262144), .K_ON(10'd3), .K_OFF(10'd1),
               .FORCE_ON_SEC(32'd360)) u_fanctrl (
        .clk        (clk_27m),
        .reset_n    (clock_locked),
        .ro_en      (fan_ro_en),
        .ro_cnt_rst (fan_ro_rst),
        .ro_cnt     (fan_ro_cnt),
        .fan_en     (fan_en_ctrl),
        .dbg_cnt    (fan_dbg_cnt)
    );
    // _175: experimento _173 CERRADO — con el pin a 1 el ventilador giro
    // perfecto en placa (03/08): el camino fisico (AB12/conector/fan) esta
    // BIEN. El "no gira nunca" de las s006/s007 tiene explicacion mundana:
    // sesiones con power-cycle cada 100-200s (up_sec nunca llega a los 360
    // de FORCE_ON_SEC) + baseline envenenada por reflasheo en caliente
    // (leccion _124). Vuelta al control automatico como en la v2.0.
    assign fan_en_o = fan_en_ctrl;
    ro_osc u_roosc (
        .ro_en   (fan_ro_en),
        .cnt_rst (fan_ro_rst),
        .cnt_out (fan_ro_cnt)
    );

    // ================================================================
    //  DEBUG BRING-UP 60K — latidos de reloj y estado vital por PMODs
    // ================================================================
    wire [5:0] dbg_video_w;   // sondas de video r2: {reset_w, video_reset, tick_pal, tick_ntsc, vdp_hdmi_reset, pal_mode}
`ifdef VIDEO720
    wire [5:0] dbg_bridge_w;  // v3.1: diagnostico del puente msx2hdmi (a PMOD0)
`endif
    reg [24:0] dbg_cnt50  = 0;  always @(posedge ex_clk_27m) dbg_cnt50  <= dbg_cnt50  + 1'b1;  // XO 50MHz REAL (independiente del PLL)
    reg [23:0] dbg_cnt27  = 0;  always @(posedge clk_27m)    dbg_cnt27  <= dbg_cnt27  + 1'b1;
    reg [24:0] dbg_cnt54  = 0;  always @(posedge clk_54m)    dbg_cnt54  <= dbg_cnt54  + 1'b1;
    reg [25:0] dbg_cnt108 = 0;  always @(posedge clk_108m)   dbg_cnt108 <= dbg_cnt108 + 1'b1;
    reg [26:0] dbg_cnt135 = 0;  always @(posedge clk_135)    dbg_cnt135 <= dbg_cnt135 + 1'b1;

    // PMOD1 = relojes: [0] lock fijo · [1] 50M · [2] 27M · [3] 54M · [4] 108M · [5] 135M(TMDS)
    // (los assigns de dbg_pmod1 viven en el bloque de debug del final del
    //  fichero, junto a los divisores de frame que los alimentan)

    wire clk_enable_27m;
    wire clk_enable_54m;
    reg [1:0] cnt_clk_enable_27m;
    always @ (posedge clk_108m) begin
        cnt_clk_enable_27m <= cnt_clk_enable_27m + 1;
    end
    assign clk_enable_27m = ( cnt_clk_enable_27m == 2'b00 ) ? 1: 0;
    assign clk_enable_54m = ( cnt_clk_enable_27m[0] == 1 ) ? 1: 0;


    wire bus_clk_3m6;
    PINFILTER dn1(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_clk_3m6),
        .dout(bus_clk_3m6)
    );

    reg bus_clk_3m6_27;
    reg bus_clk_3m6_27_0;
    reg bus_clk_3m6_27_1;
    reg bus_clk_3m6_27_2;
    reg bus_clk_3m6_27_3;
    reg bus_clk_3m6_27_4;
    reg bus_clk_3m6_27_5;
    reg bus_clk_3m6_27_6;

    always @ (posedge clk_27m) begin
        bus_clk_3m6_27_6 <= bus_clk_3m6;
        bus_clk_3m6_27_5 <= bus_clk_3m6_27_6;
        bus_clk_3m6_27_4 <= bus_clk_3m6_27_5;
        bus_clk_3m6_27_3 <= bus_clk_3m6_27_4;
        bus_clk_3m6_27_2 <= bus_clk_3m6_27_3;
        bus_clk_3m6_27_1 <= bus_clk_3m6_27_2;
        bus_clk_3m6_27_0 <= bus_clk_3m6_27_1;
        bus_clk_3m6_27 <= bus_clk_3m6_27_0;
    end

    wire clk_enable_3m6_27;
    wire clk_falling_3m6_27;
    reg bus_clk_3m6_prev_27;
    always @ (posedge clk_27m) begin
        bus_clk_3m6_prev_27 <= bus_clk_3m6_27;
    end
    assign clk_enable_3m6_27 = (bus_clk_3m6_prev_27 == 0 && bus_clk_3m6_27 == 1);
    assign clk_falling_3m6_27 = (bus_clk_3m6_prev_27 == 1 && bus_clk_3m6_27 == 0);

    wire clk_54m;   // Console 60K: generado por pll_main (clkout1); antes Gowin_CLKDIV2 /2

    wire clk_enable_3m6_54;
    wire clk_falling_3m6_54;
    reg bus_clk_3m6_54;
    reg bus_clk_3m6_prev_54;
    always @ (posedge clk_54m) begin
        bus_clk_3m6_54 <= bus_clk_3m6;
        bus_clk_3m6_prev_54 <= bus_clk_3m6_54;
    end
    assign clk_enable_3m6_54 = (bus_clk_3m6_54 == 0 && bus_clk_3m6 == 1);
    assign clk_falling_3m6_54 = (bus_clk_3m6_54 == 1 && bus_clk_3m6 == 0);

    wire bus_wait_n;
    PINFILTER dn2(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_wait_n),
        .dout(bus_wait_n)
    );

    wire bus_reset_n;
    PINFILTER dn3(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_reset_n & ~config_reset),
        .dout(bus_reset_n)
    );

    // STANDALONE: generate the 3.58MHz CPU bus clock internally (was ex_bus_clk_3m6 pin).
    // 108 MHz / 30 = 3.6 MHz. (Ported verbatim from MSXnano/fpga/top.v.)
    always @(posedge clk_108m or negedge bus_reset_n) begin
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

    wire bus_int_n;
//    PINFILTER dn4(
//        .clk(clk_108m),
//        .reset_n(1),
//        .din(ex_bus_int_n),
//        .dout(bus_int_n)
//    );
    denoise dn4 (
		.data_in (ex_bus_int_n),
		.clock(clk_54m),
		.data_out (bus_int_n)
    );

    reg [7:0] bus_data;
    genvar i;
    generate
        for (i = 0; i <= 7; i++)
        begin: bus_din
            PINFILTER dn(
                .clk(clk_54m),
                .reset_n(1),
                .din(ex_bus_data[i]),
                .dout(bus_data[i])
            );
//            denoise2 dn (
//                .data_in (ex_bus_data[i]),
//                .clock(clk_108m),
//                .data_out (bus_data[i])
//            );
        end
    endgenerate

//    always @ (posedge clk_108m) begin
//        bus_data <= ex_bus_data;
//    end

    //startup logic
    reg reset1_n_ff;
    reg reset2_n_ff;
    reg reset3_n_ff;
    wire reset1_n;
    wire reset2_n;
    wire reset3_n;

    reg [20:0] counter_reset = 0;
    reg [1:0] rst_seq;
    reg rst_step;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
            rst_step <= 0;
            counter_reset <= 0;
        end
        else begin
            rst_step <= 0;
            if ( counter_reset <= 21'b100000000000000000000 ) 
                counter_reset <= counter_reset + 1;
            else begin
                rst_step <= 1;
                counter_reset <= 0;
            end
        end
    end

    always @ (posedge clk_27m or negedge bus_reset_n ) begin
        if (bus_reset_n == 0 ) begin
            rst_seq <= 2'b00;
            reset1_n_ff <= 0;
            reset2_n_ff <= 0;
            reset3_n_ff <= 0;
        end
        else begin
            case ( rst_seq )
                2'b00: 
                    if (rst_step == 1 ) begin
                        reset1_n_ff <= 1;
                        rst_seq <= 2'b01;
                    end
                2'b01: 
                    if (rst_step == 1) begin
                        reset2_n_ff <= 1;
                        rst_seq <= 2'b10;
                    end
                2'b10:
                    if (rst_step == 1) begin
                        reset3_n_ff <= 1;
                        rst_seq <= 2'b11;
                    end
            endcase
        end
    end
    assign reset1_n = reset1_n_ff;
    assign reset2_n = reset2_n_ff;
    assign reset3_n = reset3_n_ff;

    //bus demux
    reg [1:0] msel;
    reg [7:0] bus_mp;
    reg [4:0] mp_cnt;
    wire [15:0] bus_addr;
    assign ex_msel = msel;
    assign ex_bus_mp = bus_mp;

    localparam IDLE = 2'd0;
    localparam LATCH = 2'd1;
    localparam FINISH1 = 2'd3;
    localparam FINISH2 = 2'd2;
    localparam [3:0] TON = 4'd3;
    localparam [3:0] TP = 4'd1; //prefetch time
    reg [1:0] state_demux;
    reg [3:0] counter_demux;
    reg low_byte_demux;
    wire update_demux;
    assign bus_mp = ( low_byte_demux == 0 ) ? bus_addr[15:8] : bus_addr[7:0];
    always @ (posedge clk_108m) begin
        if (~bus_reset_n) begin
            state_demux <= LATCH;
            counter_demux <= 4'd0;
            low_byte_demux <= 0;
        end 
        else begin
            counter_demux = counter_demux + 4'd1;
            casex ({state_demux, counter_demux})
                {IDLE, 4'bxxxx}: begin
                    msel <= 2'b00;
                    counter_demux <= 4'd0;
                    low_byte_demux <= 0;
                    if (update_addr == 1 ) begin
                        state_demux <= LATCH;
                    end
                end
                {LATCH, 4'd1} : begin
                    msel[1] <= 1;
                end
                {LATCH, 4'd1 + TON} : begin
                    msel[1] <= 0;
                end
                {LATCH, 4'd1 + TON + TP} : begin
                    low_byte_demux <= 1;
                end
                {LATCH, 4'd1 + TON + TP + TP} : begin
                    msel[0] <= 1;
                end
                {LATCH, 4'd1 + TON + TP + TP + TON} : begin
                    msel[0] <= 0;
                    msel[1] <= 0;
                    state_demux <= FINISH1;
                end
                {FINISH1, 4'bxxxx}: begin
                    if (update_addr == 0 ) begin
                        state_demux <= IDLE;
                    end
                end
                {FINISH2, 4'bxxxx}: begin
                    if (update_addr == 0 ) begin
                        state_demux <= IDLE;
                    end
                end
            endcase
        end
    end




    //bus isolation
    wire bus_data_reverse;
    wire bus_m1_n;
    wire bus_mreq_n;
    wire bus_iorq_n;
    wire bus_rd_n;
    wire bus_wr_n;
    wire bus_rfsh_n;
    reg [7:0] cpu_din;
    wire [7:0] cpu_dout;
    wire bus_mreq_disable;
    wire bus_iorq_disable;
    wire bus_disable;
    assign ex_bus_m1_n = bus_m1_n;
    assign ex_bus_rfsh_n = bus_rfsh_n;
    assign ex_bus_data_reverse_n = ~ bus_data_reverse;
    //assign ex_bus_data_reverse = bus_data_reverse;
    //assign ex_bus_mreq_n = bus_mreq_n;
    //assign ex_bus_iorq_n = bus_iorq_n;
    //assign ex_bus_rd_n = bus_rd_n;
    //assign ex_bus_wr_n = bus_wr_n;

    assign bus_mreq_disable = 0;
    assign bus_iorq_disable = (
                                0
                        `ifdef ENABLE_V9958
                                || vdp_csr_n == 0 || vdp_csw_n == 0 
                        `endif 
                                ) ? 1 : 0;

    assign bus_disable = bus_mreq_disable | bus_iorq_disable;
//    assign ex_bus_data = ( bus_data_reverse == 1 && slot0_req_w == 0 ) ? cpu_dout : 
//                         ( slot0_req_w == 1 ) ? 8'hff :  8'hzz;
`ifndef SWAP23
    assign ex_bus_data =  ( bus_data_reverse == 1 ) ? cpu_dout : 8'hzz;
`else

    function [1:0] swap;
        input [1:0] entrada;
        begin
            case (entrada)
                2'b00: swap = 2'b00;
                2'b01: swap = 2'b01;
                2'b10: swap = 2'b11;
                2'b11: swap = 2'b10;
                default: swap = 2'b00; // Por seguridad
            endcase
        end
    endfunction

    wire [7:0] cpu_dout_swap;
    assign cpu_dout_swap = { swap(cpu_dout[7:6]), swap(cpu_dout[5:4]), swap(cpu_dout[3:2]), swap(cpu_dout[1:0]) };

    reg ppi_swap;
    always @ (posedge clk_27m) begin
        if (~bus_reset_n) begin
            ppi_swap <= 0;
        end
        else begin
            if (ppi_swap == 0) begin
                if (bus_data_reverse == 1  && ppi_req_w == 1) begin
                    ppi_swap <= 1;
                end
            end
            else begin
                if (bus_data_reverse == 0) begin
                    ppi_swap <= 0;
                end
            end
        end
    end

    assign ex_bus_data =  ( bus_data_reverse == 1  && ppi_swap == 0) ? cpu_dout :
                          ( bus_data_reverse == 1  && ppi_swap == 1) ? cpu_dout_swap : 8'hzz;
`endif

// ===== STANDALONE MERGE: USB joystick (PSG 0xA2/reg14) — ported from MSXnano/fpga/top.v =====
wire psg_req_r;
assign psg_req_r = (bus_addr[7:0] == 8'hA2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0) ? 1 : 0;

// USB joystick data wires (driven by fpga_companion instance below)
wire [7:0] joystick0;
wire [7:0] joystick1;

// Track which PSG register was last latched via I/O A0h
reg [3:0] psg_addr_latch;
always @(posedge clk_54m or negedge bus_reset_n) begin
    if (!bus_reset_n)
        psg_addr_latch <= 4'd0;
    else if (bus_addr[7:0] == 8'hA0 && bus_iorq_n == 0 && bus_wr_n == 0 && bus_m1_n == 1)
        psg_addr_latch <= cpu_dout[3:0];
end

// Track PSG reg 15 (Port B) bits [7:6] which select joystick port
// bit6=0 selects joy1, bit7=0 selects joy2 (active low)
reg [1:0] psg_reg15_joy_sel;
always @(posedge clk_54m or negedge bus_reset_n) begin
    if (!bus_reset_n)
        psg_reg15_joy_sel <= 2'b11;
    else if (bus_addr[7:0] == 8'hA1 && bus_iorq_n == 0 && bus_wr_n == 0 && bus_m1_n == 1
             && psg_addr_latch == 4'd15)
        psg_reg15_joy_sel <= cpu_dout[7:6];
end

// ===== AUTOFIRE (turbo) on the otherwise-unused joystick buttons 3 & 4 =====
// The FPGA-Companion joy byte uses bits 0-5 (dirs + A + B); bits 6/7 carry the
// extra pad buttons 3/4 (unused by the MSX 2-button joystick). While button 3
// is held it pulses TrigA, button 4 pulses TrigB, at ~10 Hz (50 ms ON / 50 ms
// OFF). Each phase must outlast one MSX PSG scan (~1 frame @50/60 Hz) so every
// press AND release is sampled; 50 ms = 2.5-3 frames is safe even on PAL.
// Ported from the goauld+RP2040 fork (there it lived in firmware; here, no
// RP2040 -> it lives in the FPGA on the PSG joystick-injection path).
//   54 MHz * 0.050 s = 2,700,000 cycles per half period.
reg        af_phase = 1'b0;
reg [21:0] af_cnt   = 22'd0;
always @(posedge clk_54m) begin
    if (af_cnt >= 22'd2700000) begin
        af_cnt   <= 22'd0;
        af_phase <= ~af_phase;
    end else begin
        af_cnt   <= af_cnt + 22'd1;
    end
end
// fire = manual press OR (autofire button held AND square-wave high). If the pad
// has no button 3/4 (bits 6/7 stay 0) this reduces to the original behaviour.
wire af_fa0 = joystick0[4] | (joystick0[6] & af_phase);   // joy0 TrigA: manual + btn3 turbo
wire af_fb0 = joystick0[5] | (joystick0[7] & af_phase);   // joy0 TrigB: manual + btn4 turbo
wire af_fa1 = joystick1[4] | (joystick1[6] & af_phase);   // joy1 TrigA
wire af_fb1 = joystick1[5] | (joystick1[7] & af_phase);   // joy1 TrigB

// Companion joy byte (active-high): bit0=Right, bit1=Left, bit2=Down, bit3=Up, bit4=A, bit5=B
// MSX PSG Port A (active-low):      bit0=Up,    bit1=Down,  bit2=Left, bit3=Right, bit4=TrigA, bit5=TrigB
wire [7:0] joy0_msx = {2'b11, ~af_fb0, ~af_fa0, ~joystick0[0], ~joystick0[1], ~joystick0[2], ~joystick0[3]};
wire [7:0] joy1_msx = {2'b11, ~af_fb1, ~af_fa1, ~joystick1[0], ~joystick1[1], ~joystick1[2], ~joystick1[3]};
// ===== RATON MSX (era V3) =====
// Emulado sobre un raton USB de PC. Vive en el PUERTO 2, que es donde lo
// espera el software de MSX, y solo se hace cargo del puerto cuando hay un
// raton USB enchufado; si no lo hay, el puerto 2 sigue siendo joystick como
// siempre. El protocolo entero esta en fpga/src/msx_mouse.v (y su banco en
// tools/mouse_sim). Los drivers detectan el raton solos ejecutando el
// handshake, asi que no hay nada que configurar en el MSX.
wire [7:0] msx_mouse_data;      // lo que el raton presenta en el registro 14
wire       msx_mouse_present;   // hay un raton USB vivo

wire [7:0] psg_joy_data = (!psg_reg15_joy_sel[0]) ? joy0_msx :
                          (!psg_reg15_joy_sel[1]) ? (msx_mouse_present ? msx_mouse_data
                                                                       : joy1_msx) :
                          8'hFF;

// ===== STANDALONE MERGE: USB keyboard (PPI port B 0xA9 read / port C 0xAA latch) =====
wire ppi_portb_req_r = (bus_addr[7:0] == 8'hA9 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0) ? 1 : 0;
wire ppi_portc_req_w = (bus_addr[7:0] == 8'hAA && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0);

wire [3:0] keyboard_addr;
reg [7:0] keyboard_data;
wire [1:12] function_keys;

reg [7:0] ppi_port_c = 8'h00;   // R4: ppi_port_c did not exist in base — created here
always @(posedge clk_54m or negedge bus_reset_n) begin
    if (!bus_reset_n)
        ppi_port_c <= 8'h00;
    else if (ppi_portc_req_w)
        ppi_port_c <= cpu_dout;
end
assign keyboard_addr = ppi_port_c[3:0];

    // FPGA/bitstream version readable on I/O port 0x2F. The boot menu reads it and
    // warns if you flashed mismatched .fs/.bin (e.g. a v1.8 bitstream + a v1.7 BIOS pack).
    // Encoding 0xMN = version M.N. Bump FPGA_VERSION each release together with the pack.
    //
    // era V3 (18/08): 0x19 -> 0x30. La linea v3 es la version 3.0, la primera
    // sin SSRAM (problema de silicio del GW5AT-60B) y la que estrena el raton
    // MSX sobre raton USB.
    //
    // ⚠️ ESTO VA EMPAREJADO CON EL PACK. El menu de arranque compara este byte
    // con el que espera y AVISA si no cuadra. El fuente del menu NO esta en
    // este repo (docs/ROADMAP.md:39: "traerlo a la carpeta menu/ cuando toque
    // tocarlo"), asi que hasta que se regenere el pack con el menu esperando
    // 0x30, arrancar este bitstream con el pack_bios_v2.1b da un aviso de
    // version desemparejada. Es cosmetico -- el sistema arranca igual -- pero
    // hay que cerrarlo antes de publicar la 3.0.
    localparam [7:0] FPGA_VERSION = 8'h30;
    wire ver_req_r = (bus_iorq_n == 1'b0 && bus_m1_n == 1'b1 && bus_rd_n == 1'b0 && bus_addr[7:0] == 8'h2F);
    always @ (posedge clk_54m) begin
        cpu_din <=
                ( ver_req_r == 1 ) ? FPGA_VERSION :
                ( psg_req_r == 1 ) ? ((psg_addr_latch == 4'd14) ? psg_joy_data : 8'hFF) :
                `ifdef ENABLE_SOUND
                     ( psg2_req_r == 1 ) ? psg2_dout :
                `endif
                ( ppi_portb_req_r == 1 ) ? keyboard_data :
                `ifdef ENABLE_V9958
                     ( vdp_csr_n == 0) ? vdp_dout :
                `endif
                `ifdef ENABLE_MAPPER
                     ( mapper_read == 1) ? ram_dout :
                `endif
                `ifdef ENABLE_BIOS
                     ( exp_slot0_req_r == 1) ? ~exp_slot0  :
                     ( exp_slotx_req_r == 1) ? ~exp_slotx  :
                     ( bios_req == 1) ? ram_dout :
`ifdef DISABLE_BOOT_MENU
                     // _127D: SIN MENU — se enmascara la firma "AB" del menu
                     // (slot expandido, bytes 0x4000/0x4001): el slot-scan de
                     // la BIOS no ve cartucho y el MSX arranca DIRECTO.
                     // OJO: tambien salta el init encadenado de esa pagina
                     // (FM-BIOS del pack) — build de prueba, no de uso diario.
                     ( subrom_logo_req == 1 ) ? ((bus_addr[14:1] == 14'h2000) ? 8'h00 : ram_dout) :
`else
                     ( subrom_logo_req == 1 ) ? ram_dout :
`endif
                `endif
                `ifdef ENABLE_SDCARD
                     ( sd_busreq_w == 1) ? sd_cd_w :
                     ( sram_busreq_w == 1) ? sram_cd_w :
                     ( megarom_req == 1) ? ram_dout :
                     //( slot3_req_r == 1) ? 8'hff :
                 `endif
                `ifdef ENABLE_SOUND
                     ( megaram_req == 1 ) ? ram_dout:
                     ( scc_rd_r == 1 ) ? scc_dout:
                     ( scc2x_rd_r == 1 ) ? scc2x_dout:
                    `ifdef ENABLE_Y8950
                     ( y8950_rd_r == 1 ) ? y8950_dout :   // C0/C1: status (IRQ/timer) del MSX-Audio
                    `endif
                    `ifdef ENABLE_OPL4FM
                     ( opl4fm_rd_w == 1 ) ? opl4fm_dout :     // C4-C7: status/shadow del OPL3
                     `ifdef ENABLE_OPL4_WAVE
                     ( opl4pcm_rd_w == 1 ) ? opl4pcm_dout :   // 7E/7F: motor PCM real (_89)
                     `else
                     ( opl4wave_rd_w == 1 ) ? opl4wave_dout : // 7F: stub wave (device ID)
                     `endif
                    `endif
                    `ifdef ENABLE_WAVE_DDR3
                     ( wdbg_rd34_w == 1 ) ? wdbg_diag_ddr3 :  // 34h: diag DDR3 (_95)
                     ( wdbg_rd35_w == 1 ) ? wdbg_diag_eng :   // 35h: diag motor (_95)
                     ( wdbg_rd36_w == 1 ) ? wdbg_status :     // 36h: {err,ret,done,act,busy,rdy}
                     ( wdbg_rd37_w == 1 ) ? wdbg_rdata :      // 37h: byte DDR3 prefetchado
                    `endif
                `endif
                `ifdef ENABLE_CONFIG
                     ( config_req == 1 && pana_sel == 1 ) ? pana_dout :
                     ( config_req == 1 && config_ok == 1) ? config_dout :
                     ( config_req == 1 && config_ok == 0) ? swio_dout :
                `endif
                     ( kanji_driver_req == 1 ) ? ram_dout :
                     ( kanji_data_req_r == 1 ) ? ram_dout :
                `ifdef ENABLE_WIFI
                     ( wifi_req == 1 ) ? ram_dout :
                     ( f2_req_r == 1 ) ? f2_port :
                     ( uart_req == 1 ) ? uart_dout :
                `endif
                     ( logo_req == 1 ) ? ram_dout :
                     ( rtc_req_r == 1 ) ? rtc_dout :
                     ( ppi_req_r == 1 ) ? ppi_port_a :
                     ( slot0_req_r == 1 ) ? 8'hff :
                     ( slotx_req_r == 1 ) ? 8'hff :
                      8'hFF;   // STANDALONE: was bus_data (external MSX board). No bus -> FF.
    end


//    wire ex_bus_rd_n_test;
//    wire ex_bus_wr_n_test;
//    wire ex_bus_iorq_n_test;
//    wire ex_bus_mreq_n_test;
    reg ex_bus_rd_n_ff;
    reg ex_bus_wr_n_ff;
    reg ex_bus_iorq_n_ff;
    reg ex_bus_mreq_n_ff;
    localparam IDLE_ISO = 2'd0;
    localparam ACTIVE_ISO = 2'd1;
    localparam WAIT_ISO = 2'd2;
    reg [1:0] state_iso;
    reg [2:0] counter_iso;
    wire io_active;

    //assign ex_bus_rd_n = ( bus_rd_n | ex_bus_rd_n_ff | bus_disable);
    assign ex_bus_rd_n = bus_rd_n;
    //assign ex_bus_wr_n = ( bus_wr_n | ex_bus_wr_n_ff | bus_disable);
    assign ex_bus_wr_n = bus_wr_n;
    assign ex_bus_iorq_n = ( bus_iorq_n | bus_iorq_disable );
    assign ex_bus_mreq_n = ( bus_mreq_n | bus_mreq_disable );
    assign io_active = ( state_iso != IDLE_ISO ) ? 1 : 0;

    always @ ( posedge clk_108m ) begin
        if (~bus_reset_n) begin
            state_iso <= IDLE_ISO;
            ex_bus_rd_n_ff <= 1;
            ex_bus_wr_n_ff <= 1;
        end 
        else begin
            counter_iso = counter_iso + 3'd1;
            casex ({state_iso, counter_iso})
                {IDLE_ISO, 3'bxxx}: begin
                    ex_bus_rd_n_ff <= 1;
                    ex_bus_wr_n_ff <= 1;
                    counter_iso <= 3'd0;
                    if (bus_rd_n == 0 || bus_wr_n == 0 ) begin
                        state_iso <= ACTIVE_ISO;
                    end
                end
                {ACTIVE_ISO, 3'd2} : begin
                    ex_bus_rd_n_ff <= bus_rd_n;
                    ex_bus_wr_n_ff <= bus_wr_n;
                    state_iso <= WAIT_ISO;
                end
                {WAIT_ISO, 3'bxxx} : begin
                    if ( bus_rd_n == 1 && bus_wr_n == 1 ) begin
                        state_iso <= IDLE_ISO;
                    end
                end
            endcase
        end
    end

    // v2.1 60K: declarados AQUI (antes del FSM de waits) para poder alinear la
    // LIBERACION del wait al tren ACTIVO de la CPU en turbo. En el 60K el tren
    // 3m6 nace del dominio 27M (CLKDIV, fase arbitraria) y el 5m4 del 108M:
    // liberar con uno y consumir con el otro = carrera dependiente de fase
    // (en el TN20K ambos dominios salian ALINEADOS del mismo rPLL).
    reg  turbo = 1'b0;
    reg  turbo_eff = 1'b0;   // P1-iter.2: adelantado (el FSM de waits lo consume)
    wire clk_enable_cpu_54;
    wire clk_falling_cpu_54;

`ifdef ENABLE_WAIT
    wire wait_io;
    reg wait_io_ff = 1;

    reg [6:0] wait_cycles;
    reg [6:0] state_wait;
    localparam WAIT_IDLE = 7'd0;
    localparam WAIT_STATE1 = 7'd1;
    localparam WAIT_STATE2 = 7'd3;
    localparam WAIT_STATE3 = 7'd2;
    localparam WAIT_STATE4 = 7'd4;
    localparam WAIT_RELEASE = 7'd5;

    assign wait_io = wait_io_ff;

  `ifndef ENABLE_WAIT_ADAPTIVE
    always @ (posedge clk_54m) begin
        if (~bus_reset_n) begin
            state_wait <= WAIT_IDLE;
            wait_io_ff <= 1;
        end 
        else begin
            case (state_wait)
                WAIT_IDLE: begin
                    // P1-iter.2 (_64): handshake de LECTURA con la SDRAM, SOLO en
                    // turbo (turbo_eff) — a 5.37 los T-states (186ns) ya no tapan
                    // la latencia/contencion de la SDRAM externa (VDP+refresh) y
                    // la CPU leia basura ("se vuelve loco y se cuelga"; la nota
                    // iter.2 del port lo predijo). A 3.58 el termino es INERTE:
                    // camino validado byte-identico.
                    // P1-iter.2b (_66, DEFINITIVA): guard por NIVEL en TODA lectura
                    // SDRAM turbo, ciclos M1 incluidos. Post-mortem de las variantes:
                    //  - iter.2c (_67, flanco): bench 10-12 "MHz" de basura -> lecturas
                    //    corruptas. RETIRADA.
                    //  - iter.2d (_68, eximir M1): NI ARRANCA en turbo -> el T-state del
                    //    freno M1 NO cubre la latencia real de la SDRAM; los fetch salian
                    //    corruptos. RETIRADA.
                    // Moraleja: cuando ram_busy=1 los datos NO estan; no hay margen en el
                    // handshake. Ir mas alla de ~4.3 efectivos exige acelerar el propio
                    // controlador de memoria (P1c), no apostar en el guard.
                    if ( ram_write == 1 || (turbo_eff == 1 && bus_mreq_n == 0 && bus_rd_n == 0 && ram_busy == 1) || (ex_bus_iorq_n == 0)&& (bus_rd_n == 0 || bus_wr_n == 0) ) begin  // P2: sin Compatible Mode (= v1.9 nano)
                        wait_io_ff <= 0;
                        state_wait <= WAIT_STATE1;
                    end
                end
                // P1-iter.2b (_66): medir y liberar con el tren ACTIVO de la CPU
                // (la intencion declarada del v2.1). Con el release fijo a 3m6,
                // cada espera en turbo costaba hasta 280ns (cuantizacion del tren
                // lento) y z80bench leia 4.11 en vez de 5.37 (medido en HW). A
                // 3.58 (turbo_eff=0) las expresiones colapsan al 3m6 original:
                // camino validado byte-identico. OJO: pulsos SIN gatear (los
                // gateados estan parados por el propio wait -> deadlock).
                WAIT_STATE1: begin
                    if ( (turbo_eff ? clk_enable_5m4_54 : clk_enable_3m6_54) == 1 ) begin
                        state_wait <= WAIT_STATE2;
                    end
                end
                // P1-iter.2: en turbo, ademas, NO liberar con la SDRAM ocupada.
                WAIT_STATE2: begin
                    if ( (turbo_eff ? clk_falling_5m4_54 : clk_falling_3m6_54) == 1 && (turbo_eff == 0 || ram_busy == 0) ) begin
                        wait_io_ff <= 1;
                        state_wait <= WAIT_STATE3;
                    end
                end
                WAIT_STATE3: begin
                    if ( bus_rd_n == 1 && bus_wr_n == 1) begin
                        state_wait <= WAIT_IDLE;
                    end
                end
            endcase
        end
    end
  `else
    always @ (posedge clk_54m) begin
        if (~bus_reset_n) begin
            state_wait <= WAIT_IDLE;
            wait_io_ff <= 1;
        end 
        else begin
            case (state_wait)
                WAIT_IDLE: begin
                    if ( (ex_bus_iorq_n == 0 || bus_mreq_n == 0 ) && (bus_rd_n == 0 || bus_wr_n == 0) ) begin
                        wait_io_ff <= 0;
                        wait_cycles <= 7'd6;
                        state_wait <= WAIT_STATE1;
                    end
                end
                WAIT_STATE1: begin
                    wait_cycles <= wait_cycles - 1;
                    if ( wait_cycles == 0 ) begin
                        state_wait <= WAIT_STATE2;
                    end
                end
                WAIT_STATE2: begin
                    if ( ram_busy == 0 && clk_enable_3m6_54 == 1 ) begin
                        state_wait <= WAIT_STATE3;
                    end
                end
                WAIT_STATE3: begin
                    // v2.2: semantica v1.9 restaurada — con la fase 27<->54
                    // alineada (clk27_align) la disciplina original es valida
                    if ( clk_falling_3m6_54 == 1 ) begin
                        wait_io_ff <= 1;
                        state_wait <= WAIT_STATE4;
                    end
                end
                WAIT_STATE4: begin
                    if ( bus_rd_n == 1 && bus_wr_n == 1) begin
                        state_wait <= WAIT_IDLE;
                    end
                end
            endcase
        end
    end
  `endif

`endif

    // v1.9: los wires de cadencia de CPU estan declarados ARRIBA (v2.1) junto
    // al FSM de waits; se asignan en el bloque de turbo de abajo.

`ifdef ENABLE_M1_WAIT
    // ===== STANDALONE M1 wait-state generator (frenado a ~100% MSX) =====
    // A real MSX inserts exactly 1 wait-state in every M1 (opcode-fetch) cycle.
    // The goauld got this from the MSX board via ex_bus_wait_n; standalone tied
    // ex_bus_wait_n=1 (top.v ~95), losing the brake -> CPU ran ~16% too fast.
    //
    // MECHANISM: GATE the CPU clock-enable, do NOT use WAIT_n.
    // The earlier WAIT_n version released the pulse at the T1->T2 boundary, so it
    // was already high when the core sampled WAIT_n inside T2 -> no wait inserted
    // (bench stayed at 116%). Instead we mirror the proven wait_io stall: mask
    // exactly one full CPU-clock period (one clk_enable_cpu_54 + one
    // clk_falling_cpu_54, i.e. the ACTIVE cadence) per M1 opcode fetch. Skipping one
    // removes exactly one T-state of progress = one wait-state, independent of
    // the core's internal T-state sampling. RFSH is T3/T4 with M1_n already high
    // (t80.vhd:1077), so refresh cycles are NOT slowed. clk_54m domain.
    reg  wait_m1 = 1'b1;            // active-high CPU clock-enable allow (0 = stall)
    reg  bus_m1_n_prev_54 = 1'b1;
    reg  m1_active = 1'b0;          // currently inserting the wait for this M1
    reg  m1_masked_en = 1'b0;       // masked one clk_enable pulse this wait
    reg  m1_masked_fall = 1'b0;     // masked one clk_falling pulse this wait

    always @ (posedge clk_54m) begin
        if (~bus_reset_n) begin
            wait_m1          <= 1'b1;
            bus_m1_n_prev_54 <= 1'b1;
            m1_active        <= 1'b0;
            m1_masked_en     <= 1'b0;
            m1_masked_fall   <= 1'b0;
        end else begin
            bus_m1_n_prev_54 <= bus_m1_n;
            if (!m1_active) begin
                // Falling edge of M1_n = new opcode fetch -> start one wait.
                if (bus_m1_n_prev_54 == 1'b1 && bus_m1_n == 1'b0) begin
                    m1_active      <= 1'b1;
                    wait_m1        <= 1'b0;   // stall CPU clock from next cycle
                    m1_masked_en   <= 1'b0;
                    m1_masked_fall <= 1'b0;
                end
            end else begin
                // While stalled (wait_m1==0) the coincident enable/falling pulses
                // are masked out of the CPU clock-enable. Track one of each, then
                // release -> exactly one CPU-clock period (one T-state) inserted.
                // v1.9: tracks the MUXED cadence so the wait is exactly 1 T-state
                // in both 3.6 (normal) and 5.37 (turbo) modes.
                if (clk_enable_cpu_54)  m1_masked_en   <= 1'b1;
                if (clk_falling_cpu_54) m1_masked_fall <= 1'b1;
                if ((m1_masked_en  || clk_enable_cpu_54) &&
                    (m1_masked_fall || clk_falling_cpu_54)) begin
                    wait_m1   <= 1'b1;   // release on next cycle
                    m1_active <= 1'b0;
                end
            end
        end
    end
`endif

    // ===== v1.9-fh: retraso de power-on para el ESP-01S (WiFi) =====
    // El INIT del driver ESP corre en el escaneo de slots ~1-2s tras dar
    // corriente, pero el ESP-01S tarda ~3-5s en arrancar: quedaba instalado
    // "sin ESP" (discovery UNAPI = 0 implementaciones) hasta re-init manual
    // via el setup W. Retener el Z80 en reset ~3s SOLO en el power-on da
    // tiempo al ESP y el INIT lo encuentra a la primera. El contador SATURA
    // y no se re-arma: los soft-reset siguen siendo instantaneos (regla de la
    // megaram) y el coste real es ~1.5-2s extra (el stream de flash ya tapa
    // parte). Sin ENABLE_WIFI no aplica.
`ifdef ENABLE_WIFI
    reg [26:0] esp_boot_cnt = 0;
    reg        esp_boot_ok  = 0;
    always @(posedge clk_27m) begin
        if (!esp_boot_ok) begin
            if (esp_boot_cnt == 27'd81000000)   // ~3.0s @ 27 MHz
                esp_boot_ok <= 1;
            else
                esp_boot_cnt <= esp_boot_cnt + 1'b1;
        end
    end
`else
    wire esp_boot_ok = 1'b1;
`endif

    // ===== Turbo mode toggle (F11) =====
    // Default turbo=0 -> M1 wait active -> ~100% real-MSX speed (3.58MHz behaviour).
    // Press F11 (USB HID usage 0x44 = keyboard[68]) to toggle. v1.9: turbo=1 switches
    // the CPU cadence to 5.37 MHz (WSX-style) while the per-M1 wait STAYS active, like
    // the real T9769 does at 5.37 MHz -> benchmarks report ~5.37 (150%). (The v1.8
    // "bypass M1 wait" turbo stacked on the 5.4 clock read as ~6.2 MHz on HW.)
    // Toggle survives MSX soft-reset; powers on in real-MSX mode. LED5 shows the state.
    // NOTE: F12 is captured by the BL616 FPGA-Companion firmware (its OSD) and never
    // reaches the FPGA, so F11 (which does reach it, verified on HW) is used instead.
    // (reg turbo declarado arriba, v2.1)
    // P1 (receta MSXnano v1.9 ce46ef9): los eventos escriben `turbo` DIRECTO y el
    // conmutado seguro lo hace turbo_eff (mas abajo): limite de T-estado limpio
    // (fix de cadencia del nano, validado en su HW) COMBINADO con el guard de
    // bus/memoria en reposo propio del 60K (SDRAM externa: no conmutar con un
    // acceso en vuelo). El esquema turbo_req anterior queda sustituido.
    reg boot_done = 1'b0;   // 1 tras la PRIMERA (fria) salida de reset; sobrevive warm resets
    reg f11_s0  = 1'b0;
    reg f11_s1  = 1'b0;
    reg f11_prev= 1'b0;
    always @ (posedge clk_54m) begin
        f11_s0   <= keyboard[68];   // sync HID F11 state into clk_54m domain
        f11_s1   <= f11_s0;
        f11_prev <= f11_s1;
`ifdef ENABLE_TURBO
        if (f11_s1 & ~f11_prev)     // rising edge = F11 pressed
            turbo <= ~turbo;        // toggle real-MSX <-> turbo
`endif
        // v1.9: control software Panasonic — OUT &H41,n con el dispositivo 8
        // seleccionado (decode pana41_wr junto al bloque config). bit0 activo-bajo:
        // 0 = turbo 5.37 MHz, 1 = 3.58. Puesto tras el F11: si coinciden en el
        // mismo ciclo gana el software (en el T9769 real el puerto es el unico control).
`ifdef ENABLE_TURBO
        if (pana41_wr)
            turbo <= ~cpu_dout[0];
`endif
        // v1.9: "Boot Turbo" persistido (ajuste del menu, puerto #45). Siembra el
        // turbo durante la ventana config_init del stream de flash. Va el ULTIMO
        // del bloque de eventos: domina sobre F11/puerto durante el boot.
        // v1.9b FIX pantalla-negra Save&Reset-con-turbo: el boot-turbo (5.37) SOLO
        // se aplica en arranque en FRIO (boot_done=0). En warm reset -> 3.58 (= un
        // Save&Reset normal); el boot-turbo entra al PROXIMO encendido.
`ifdef ENABLE_TURBO
        if (config_init)
            turbo <= (~boot_done && !s2_press && config_sig[4] == 8'h54) ? 1'b1 : 1'b0;
        // estado conocido de `turbo` en cualquier reset (mirror del cold boot). Ultimo = prioridad.
        if (~bus_reset_n)
            turbo <= 1'b0;
`endif
    end
    // boot_done: se pone a 1 la primera vez que el CPU sale de reset (arranque en
    // frio) y NO se borra nunca (sin clausula de reset -> sobrevive warm resets;
    // GSR lo inicia a 0 al encender). Discriminador frio/warm del boot-turbo.
    always @ (posedge clk_54m)
        if (bus_reset_n & reset3_n & flash_idle & esp_boot_ok & ~config_init)
            boot_done <= 1'b1;   // ~config_init: no marcar boot_done durante la siembra

    // ===== v1.9 Panasonic-WSX turbo: 5.37 MHz CPU cadence =====
    // /20 divider on 108 MHz -> 5.40 MHz base cadence + "period swallow" trim ->
    // EXACT WSX 5.369318 MHz (see below). The sound chips keep the /30
    // clk_enable_3m6_27 (untouched). At turbo=0 the CPU uses the ORIGINAL
    // clk_enable_3m6_54 verbatim (3.58 behaviour byte-identical). NOTE: NO
    // ram_busy handshake yet, so if HW shows corruption during active display,
    // add the handshake (dormant ENABLE_WAIT_ADAPTIVE, top.v ~707) in iter.2.
    //
    // Divisor /20 PURO (mitades de 10 ciclos, pares: fase constante vs clk_54m).
    // NOTA: durante el desarrollo se probo un divisor fraccionario (17x10+1x11,
    // 5.37 directo reformando el reloj) y se descarto; los "cuelgues" que se le
    // atribuyeron resultaron ser un falso contacto del teclado, pero el esquema
    // /20 puro + trago (abajo) es mas simple, conserva las fases 108->54
    // validadas y da el 5.37 EXACTO. Validado en HW (juegos/DOS en turbo).
    reg [4:0] div20_cnt;
    reg       clk_5m4_internal;
    always @(posedge clk_108m or negedge bus_reset_n) begin
        if (~bus_reset_n) begin div20_cnt <= 0; clk_5m4_internal <= 0; end
        else if (div20_cnt >= 5'd9) begin clk_5m4_internal <= ~clk_5m4_internal; div20_cnt <= 0; end
        else div20_cnt <= div20_cnt + 1;
    end
    wire clk_enable_5m4_raw, clk_falling_5m4_raw;
    reg  s5m4_a, s5m4_b;
    always @(posedge clk_54m) begin s5m4_a <= clk_5m4_internal; s5m4_b <= s5m4_a; end
    assign clk_enable_5m4_raw  = (s5m4_b == 0 && s5m4_a == 1);
    assign clk_falling_5m4_raw = (s5m4_b == 1 && s5m4_a == 0);

    // Ajuste EXACTO a 5.37: "trago" de periodo. De cada 176 periodos de 5.4 MHz
    // se enmascara 1 completo (su enable Y su falling, en pareja) ->
    // 5.4 MHz * 175/176 = 5 369 318 Hz = el turbo WSX exacto (315/88 * 1.5 MHz).
    // Mismo mecanismo probado que los waits M1/IO (saltar pulsos de enable en el
    // dominio 54), SIN tocar la forma del reloj 5m4 ni sus fases 108->54. El CPU
    // solo percibe una pausa de 1 T-state cada ~33 us; la alternancia
    // enable/falling se conserva (se traga la pareja completa).
    reg [7:0] pana_per_cnt   = 0;
    reg       pana_skip_pend = 0;   // enmascarando el falling del periodo tragado
    wire      pana_skip_now  = (pana_per_cnt == 8'd175) && clk_enable_5m4_raw;
    always @(posedge clk_54m) begin
        if (~bus_reset_n) begin
            pana_per_cnt   <= 0;
            pana_skip_pend <= 0;
        end else begin
            if (clk_enable_5m4_raw) begin
                if (pana_per_cnt == 8'd175) begin
                    pana_per_cnt   <= 0;
                    pana_skip_pend <= 1;    // el falling de ESTE periodo tambien se traga
                end else
                    pana_per_cnt <= pana_per_cnt + 1'b1;
            end
            if (pana_skip_pend && clk_falling_5m4_raw)
                pana_skip_pend <= 0;
        end
    end
    wire clk_enable_5m4_54  = clk_enable_5m4_raw  & ~pana_skip_now;
    wire clk_falling_5m4_54 = clk_falling_5m4_raw & ~pana_skip_pend;
    // ===== v1.9: conmutado de cadencia SIN glitch =====
    // El mux elige entre dos cadencias de FASE INDEPENDIENTE (3.6 del /30, 5.37
    // del /20). Conmutar sobre `turbo` crudo a mitad de T-estado puede entregar
    // al Z80 dos ENABLE (o dos FALLING) seguidos sin pareja -> opcode mal
    // latcheado -> cuelgue (el F11 en el menu del nano). turbo_eff (el select
    // REAL) solo adopta `turbo` cuando AMBAS cadencias estan bajas Y el CPU no
    // esta en ningun wait (receta v1.9, validada en el TN20K) Y ADEMAS el bus
    // Z80 y la SDRAM estan en reposo (guard 60K: memoria externa, no conmutar
    // con un acceso en vuelo). En reset adopta directo (semilla del boot-turbo).
    wire cadence_safe = (bus_clk_3m6 == 1'b0 && bus_clk_3m6_54 == 1'b0) &&
                        (s5m4_a == 1'b0 && s5m4_b == 1'b0);
    // v1.9b: un warm reset EN CURSO debe CRUZAR la entrada del reset a 3.58
    // (la grabacion en flash tarda decenas de ms con bus_reset_n aun alto).
    wire warm_reset_pending = flash_write_busy | config_reset_req;
    // _177: /WAIT del puerto CPU del V9968 (glue en clk_86) re-sincronizado
    // al dominio del T80 con 2FF. Latencia de asercion total ~60-70ns desde
    // la caida de IORQ — dentro de la ventana de muestreo de WAIT del Z80
    // incluso en turbo (T=186ns). Seguro por diseno: el glue lo gatea al
    // ciclo I/O del VDP y lleva timeout fail-open (~12us); el stall ya no
    // puede matar de hambre al refresco de la SDRAM (autonomo desde _175).
    wire v68_wait86_n;
    reg [1:0] v68_wait_s = 2'b11;
    always @(posedge clk_54m) v68_wait_s <= {v68_wait_s[0], v68_wait86_n};
    wire vdp_wait54_n = v68_wait_s[1];
    // (reg turbo_eff adelantado junto al FSM de waits, P1-iter.2)
    always @ (posedge clk_54m) begin
        if (!(bus_reset_n & reset3_n & flash_idle & esp_boot_ok))
            turbo_eff <= turbo;                                 // en reset: sigue a turbo (semilla / 0)
        else if (cadence_safe & wait_io & wait_m1
                 & bus_rd_n & bus_wr_n & bus_mreq_n & ex_bus_iorq_n & (ram_busy == 0))
            turbo_eff <= warm_reset_pending ? 1'b0 : turbo;     // corriendo: 3.58 si hay warm-reset pendiente
    end
    // CPU cadence mux: turbo_eff (conmutado sin glitch) elige 5.37; si no, la 3.6 intacta.
    assign clk_enable_cpu_54  = turbo_eff ? clk_enable_5m4_54  : clk_enable_3m6_54;
    assign clk_falling_cpu_54 = turbo_eff ? clk_falling_5m4_54 : clk_falling_3m6_54;

    // ----- M1-wait fallback (divisor) -----
    // If on real HW the benchmark still does not land near 100% with the WAIT_n
    // brake above, comment out `define ENABLE_M1_WAIT and instead SLOW the CPU
    // clock by changing the 108MHz divider at top.v ~223 from /30 (3.6MHz) to
    // /35 (~3.09MHz): replace `if (div30_cnt == 5'd14)` with a half-period of
    // ~17.5 -> alternate 17/18, e.g.:
    //     reg div_tgl;  // toggles every edge to alternate 17/18
    //     if (div30_cnt == (div_tgl ? 5'd17 : 5'd16)) begin
    //         clk_3m6_internal <= ~clk_3m6_internal; div30_cnt <= 0; div_tgl <= ~div_tgl;
    //     end else div30_cnt <= div30_cnt + 1;
    // This lowers the clock instead of inserting a wait (less authentic, but a
    // guaranteed % knob). Do NOT enable both at once.

    wire update_addr;
    G80a  #(
        .Mode    (0),     // 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
        //.T2Write (0),     //0 => WR_n active in T3, /=0 => WR_n active in T2
        .IOWait   (1)      // 0 => Single I/O cycle, 1 => Std I/O cycle
    ) cpu1 (
        .RESET_n   (bus_reset_n & reset3_n & flash_idle & esp_boot_ok),
        .CLK_n     (clk_54m),
    `ifdef ENABLE_WAIT
      `ifdef ENABLE_M1_WAIT
        // v1.9: M1 wait is NOT bypassed in turbo (real WSX keeps it at 5.37 MHz);
        // the speed change comes only from the 3.6/5.37 cadence mux.
        .clk_enable (clk_enable_cpu_54 & wait_io & wait_m1),
        .clk_falling (clk_falling_cpu_54 & wait_io & wait_m1),
      `else
        .clk_enable (clk_enable_3m6_54 & wait_io ),
        .clk_falling (clk_falling_3m6_54 & wait_io ),
      `endif
    `else
      `ifdef ENABLE_M1_WAIT
        // (inactive branch) v1.9 semantics: cadence mux + M1 wait always on
        .clk_enable (clk_enable_cpu_54 & wait_m1),
        .clk_falling (clk_falling_cpu_54 & wait_m1),
      `else
        .clk_enable (clk_enable_3m6_54),
        .clk_falling (clk_falling_3m6_54),
      `endif
    `endif
    `ifdef ENABLE_WIFI
      `ifndef ENABLE_WAIT_ADAPTIVE
        .WAIT_n    (bus_wait_n & wait_uart & opl4pcm_wait_n & vdp_wait54_n),
      `else
        .WAIT_n    (wait_uart & opl4pcm_wait_n & vdp_wait54_n),
      `endif
    `else
      `ifndef ENABLE_WAIT_ADAPTIVE
        .WAIT_n    (bus_wait_n & opl4pcm_wait_n & vdp_wait54_n),
      `else
        .WAIT_n    (opl4pcm_wait_n & vdp_wait54_n),
      `endif
    `endif
    `ifdef ENABLE_V9958
        .INT_n     (bus_int_n & vdp_int & y8950_int_n & opl4_int_n),  // _81 Y8950 + _108 OPL4
    `else
        .INT_n     (bus_int_n & y8950_int_n & opl4_int_n),
    `endif
        .NMI_n     (1),
        .BUSRQ_n   (1),
        .M1_n      (bus_m1_n),
        .MREQ_n    (bus_mreq_n),
        .IORQ_n    (bus_iorq_n),
        .RD_n      (bus_rd_n),
        .WR_n      (bus_wr_n),
        .RFSH_n    (bus_rfsh_n),
        .HALT_n    ( ),
        .BUSAK_n   ( ),
        .A         (bus_addr),
        .update_addr(update_addr),
        .DI         (cpu_din),
        .DO         (cpu_dout),
        .Data_Reverse (bus_data_reverse)
    );

    //slots decoding
    reg [7:0] ppi_port_a = 8'h00;
    wire ppi_req_r;
    wire ppi_req_w;
    wire [1:0] pri_slot;
    wire [3:0] pri_slot_num;
    wire [3:0] page_num;

    //----------------------------------------------------------------
    //-- PPI(8255) / primary-slot
    //----------------------------------------------------------------
    assign ppi_req_r = (bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign ppi_req_w = (bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0)
            ppi_port_a <= 8'h00;
        else begin
            if (ppi_req_w == 1 ) begin
                ppi_port_a <= cpu_dout;
            end
        end
    end

    //expanded slots 0 & 3
    reg [7:0] exp_slot0;
    wire [1:0] exp_slot0_page;
    wire [3:0] exp_slot0_num;
    reg exp_slot0_req_r;
    reg exp_slot0_req_w;
    reg [7:0] exp_slotx;
    wire [1:0] exp_slotx_page;
    wire [3:0] exp_slotx_num;
    reg exp_slotx_req_r;
    reg exp_slotx_req_w;
    wire xffff;
    reg xffh;
    reg xffl;
    always @ (posedge clk_54m) begin
        xffh <= bus_addr[15:8] == 8'hff;
        xffl <= bus_addr[7:0] == 8'hff;
        exp_slot0_req_w <= ( bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slot0_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slotx_req_w <= ( bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
        exp_slotx_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
    end
    //assign xffff = ( bus_addr == 16'hffff ) ? 1 : 0;
    assign xffff = xffh & xffl;

//    assign exp_slotx_req_w = ( bus_mreq_n == 0 && bus_wr_n == 0 && xffff == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
//    assign exp_slotx_req_r = ( bus_mreq_n == 0 && bus_rd_n == 0 && xffff == 1 && pri_slot_num[0] == 1 ) ? 1: 0;

    // slot #0
    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0 )
            exp_slot0 <= 8'h00;
        else begin
            if (exp_slot0_req_w == 1 ) begin
                exp_slot0 <= cpu_dout;
            end
        end
    end

    // slot #3
    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0 )
            exp_slotx <= 8'h00;
        else begin
            if (exp_slotx_req_w == 1 ) begin
                exp_slotx <= cpu_dout;
            end
        end
    end

    // slots decoding
    assign pri_slot = ( bus_addr[15:14] == 2'b00) ? ppi_port_a[1:0] :
                      ( bus_addr[15:14] == 2'b01) ? ppi_port_a[3:2] :
                      ( bus_addr[15:14] == 2'b10) ? ppi_port_a[5:4] :
                                             ppi_port_a[7:6];

    assign pri_slot_num = ( pri_slot == 2'b00 ) ? 4'b0001 :
                          ( pri_slot == 2'b01 ) ? 4'b0010 :
                          ( pri_slot == 2'b10 ) ? 4'b0100 :
                                                  4'b1000;

    assign page_num = ( bus_addr[15:14] == 2'b00) ? 4'b0001 :
                      ( bus_addr[15:14] == 2'b01) ? 4'b0010 :
                      ( bus_addr[15:14] == 2'b10) ? 4'b0100 :
                                                    4'b1000;
    assign exp_slot0_page = ( bus_addr[15:14] == 2'b00) ? exp_slot0[1:0] :
                            ( bus_addr[15:14] == 2'b01) ? exp_slot0[3:2] :
                            ( bus_addr[15:14] == 2'b10) ? exp_slot0[5:4] :
                                                          exp_slot0[7:6];

    assign exp_slot0_num = ( exp_slot0_page == 2'b00 ) ? 4'b0001 :
                           ( exp_slot0_page == 2'b01 ) ? 4'b0010 :
                           ( exp_slot0_page == 2'b10 ) ? 4'b0100 :
                                                         4'b1000;

    assign exp_slotx_page = ( bus_addr[15:14] == 2'b00) ? exp_slotx[1:0] :
                            ( bus_addr[15:14] == 2'b01) ? exp_slotx[3:2] :
                            ( bus_addr[15:14] == 2'b10) ? exp_slotx[5:4] :
                                                          exp_slotx[7:6];

    assign exp_slotx_num = ( exp_slotx_page == 2'b00 ) ? 4'b0001 :
                           ( exp_slotx_page == 2'b01 ) ? 4'b0010 :
                           ( exp_slotx_page == 2'b10 ) ? 4'b0100 :
                                                         4'b1000;

    reg slot0_req_r;
    reg slotx_req_r;
    always @ (posedge clk_54m) begin
        slot0_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
        slotx_req_r <= ( ( config_enable_mapper3 == 1 || config_enable_megaram3 == 1 || config_enable_sdcard == 1 ) && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 ) ? 1 : 0;
    end

`ifdef ENABLE_BIOS
    //bios
    reg bios_req;
    wire [7:0] bios_dout;
    always @ (posedge clk_54m) begin
        bios_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 && exp_slot0_num[0] == 1) ? 1 : 0;
    end

    //subrom
    reg subrom_req;
    wire [7:0] subrom_dout;
    always @ (posedge clk_54m) begin
        subrom_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && page_num[0] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //msx logo
    reg msx_logo_req;
    wire [7:0] msx_logo_dout;
    always @ (posedge clk_54m) begin
        msx_logo_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //subrom + logo
    reg subrom_logo_req;
    always @ (posedge clk_54m) begin
        subrom_logo_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[0] == 1 || page_num[1] == 1) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //kanji driver
    reg kanji_driver_req;
    always @ (posedge clk_54m) begin
        kanji_driver_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[1] == 1 || page_num[2] == 1) && pri_slot_num[0] == 1 && exp_slot0_num[1] == 1 ) ? 1 : 0;
    end


`else

    wire bios_req;
    wire [7:0] bios_dout;
    wire subrom_req;
    wire [7:0] subrom_dout;
    wire msx_logo_req;
    wire [7:0] msx_logo_dout;
    wire kanji_driver_req;
    wire subrom_logo_req;

`endif

    //logo ROM: SIEMPRE (v3.0 — estaba atrapado en ENABLE_WIFI; es del menu, no del WiFi)
`ifdef ENABLE_WIFI

    //wifi driver
    reg wifi_req;
    always @ (posedge clk_54m) begin
        wifi_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[2] == 1 ) ? 1 : 0;
    end
`endif

    //logo ROM (FREE16KB del pack @0x7C000) en slot 0-3 pagina 1: pantalla de
    //marca del menu (rutina+imagen autocontenidas; el menu la llama con CALLF)
    reg logo_req;
    always @ (posedge clk_54m) begin
        logo_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[3] == 1 ) ? 1 : 0;
    end

`ifdef ENABLE_WIFI
    //uart
    wire uart_req;
    wire wait_uart;
    wire [7:0] uart_dout;

    assign uart_req = (bus_addr[7:1] == 7'b0000011 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // ESP ports 06-07h

    // F1 (_73): la UART va al BL616 ONBOARD (firmware UNAPI propio, repo
    // BL616-UNAPI-Firmware). RX = pad bl616_jtagsel (V14 <- GPIO28 TX del
    // BL616, PULL_UP = idle UART correcto). TX = pad spi_irqn (U15 -> GPIO27
    // RX del BL616), robado al companion (sacrificado en F1). Baud del core:
    // 27M/31 = 870968; el firmware BL616 va a 869565 (-0.16%).
    wire bl616_uart_tx_w;
    // _95: BUS REGISTRADO (patron _91) — uwifi vive en clk_27m y decodificaba
    // el bus del T80 (lanzado en bajada de 54M) directo: camino de medio
    // ciclo que perdio la loteria de placement en la _95 (p1r1: -0.905 en
    // cpu1/RD->my_rx_state). Flop directo en 27M = cono trivial; el modulo
    // ve el bus 1 ciclo de 27M tarde (37ns, nada frente a los ~560ns del
    // ciclo I/O en turbo). wait_o llega <100ns tras IORQ: el T80 muestrea
    // /WAIT a >=186ns — margen sobrado. Sin tocar wifi_lite.vhd.
    reg        w27_iorq_n, w27_wr_n, w27_rd_n;
    reg [15:0] w27_addr;
    reg [7:0]  w27_din;
    always @(posedge clk_27m) begin
        w27_iorq_n <= bus_iorq_n;
        w27_wr_n   <= bus_wr_n;
        w27_rd_n   <= bus_rd_n;
        w27_addr   <= bus_addr;
        w27_din    <= cpu_dout;
    end
    wifi uwifi (
        .clk_i      (clk_27m),
        .wait_o     (wait_uart),
        .reset_i    (bus_reset_n),
        .iorq_i     (w27_iorq_n),
        .wrt_i      (w27_wr_n),
        .rd_i       (w27_rd_n),
`ifdef WIFI_PMOD_TEST
        .rx_i       (uart_pmod_rx),          // TEST: RX por PMOD1 D22 (CH340 TX / PC-de-ESP)
`elsif ENABLE_WIFI_ESP32
        .rx_i       (esp_rx_i),              // _153c: J10 pin 16 (N17) <- ESP32-C6 IO16
`else
        .rx_i       (bl616_jtagsel),         // onboard: V14 <- BL616 IO28 TX
`endif
        .tx_o       (bl616_uart_tx_w),
        .adr_i      (w27_addr),
        .db_i       (w27_din),
        .db_o       (uart_dout)
    );

`endif 

    //rtc
    wire rtc_req_r;
    wire rtc_req_w;
    wire [7:0] rtc_dout;
    assign rtc_req_w = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC
    assign rtc_req_r = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC

    rtc rtc1(
        .clk21m(clk_27m),
        .reset(0),
        .clkena(clk_enable_3m6_27),
        .req(rtc_req_w | rtc_req_r),
        .ack(),
        .wrt(rtc_req_w),
        .adr(bus_addr),
        .dbi(rtc_dout),
        .dbo(cpu_dout)
    );

    //vdp
	wire vdp_csw_n; //VDP write request
	wire vdp_csr_n; //VDP read request	
    wire [7:0] vdp_dout;
    wire vdp_int;
    wire WeVdp_n;
    wire [16:0] VdpAdr;
    wire [15:0] VrmDbi;
    wire [7:0] VrmDbo;
    wire VideoDHClk;
    wire VideoDLClk;
    //decode del VDP: 98-9Bh
    wire vdp_io_hit;
`ifdef ENABLE_V9968_VDP
    // _140 ESPEJO 88-8Bh: la demo ru66-v9968-demo y el software de cartucho
    // V9968 EXTERNO hablan SOLO por 88-8Bh (nunca 98-9B). En HW real son dos
    // chips (V9968 externo en 88-8B + VDP interno en 98-9B, "switch to the
    // V9968 display"); en el MSXimus el V9968 YA ES el VDP interno, asi que
    // aliasamos AMBOS rangos al mismo chip. Se ignora bus_addr[4]: 98-9B
    // (bit4=1) y 88-8B (bit4=0) son las UNICAS combinaciones con [7:5]=100 y
    // [3:2]=10 (0x88-8B libre en el MSXimus; vecinos PSG A0-A2/PPI A8-AA/
    // Y8950 C0-C1). mode = bus_addr[1:0] es identico en ambos rangos, asi
    // que el glue recibe el mismo puerto; BIOS/DOS siguen en 98-9B intactos.
    assign vdp_io_hit = ( bus_addr[7:5] == 3'b100 && bus_addr[3:2] == 2'b10 );
`else
    assign vdp_io_hit = ( bus_addr[7:2] == 6'b100110 );
`endif
    assign vdp_csw_n = (vdp_io_hit == 1 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 0:1; // VDP write
    assign vdp_csr_n = (vdp_io_hit == 1 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 0:1; // VDP read

`ifndef ENABLE_V9968_VDP
    v9958_top vdp4 (
        .clk (clk_27m),
        .clk_135 (clk_135),           // legado (sin uso con VIDEO720)
        .clk_135_lock (clock_locked), // mismo PLL -> mismo lock (antes: lock del CLK_135 propio)
`ifdef VIDEO720
        .clk_hdmi  (clk_hdmi),        // v3.0: pixel 720p 74.25 (pll_74, cascada monitorcore)
        .clk_hdmi5 (clk_hdmi5),       // v3.0: TMDS x5 371.25
        .dbg_bridge(dbg_bridge_w),    // v3.1: diagnostico del puente -> PMOD0
`endif
        .dbg_video (dbg_video_w),     // sondas de video del bring-up
        .s1 (0),
        .clk_50 (0),
        .clk_125 (0),

    `ifdef ENABLE_V9958
        .reset_n (bus_reset_n ),
    `else
        .reset_n (0),
    `endif
        .mode    (bus_addr[1:0]),
        .csw_n   (vdp_csw_n),
        .csr_n   (vdp_csr_n),

        .int_n   (vdp_int),
        .gromclk (),
        .cpuclk  (),
        .cdi     (vdp_dout),
        .cdo     (cpu_dout),

        .audio_sample   (audio_sample),
        .audio_sample_r (audio_sample_r),
        .aspect_16_9    (config_enable_16_9),

        .adc_clk  (),
        .adc_cs   (),
        .adc_mosi (),
        .adc_miso (0),

    `ifdef ENABLE_CONFIG
        .maxspr_n    (~config_enable_8sprites),  // Sprite Limit 8/linea (menu, config2[6]); 1 = limite clasico 4
    `else
        .maxspr_n    (1),
    `endif
    `ifdef ENABLE_SCAN_LINES
        .scanlin_n   (~config_enable_scanlines),
    `else
        .scanlin_n   (1),
    `endif
        .gromclk_ena_n (1),
        .cpuclk_ena_n  (1),

        .WeVdp_n(WeVdp_n),
        .VdpAdr(VdpAdr),
        .VrmDbi(VrmDbi2),
        .VrmDbo(VrmDbo),

        .VideoDHClk(VideoDHClk),
        .VideoDLClk(VideoDLClk),

        .tmds_clk_p    (clk_p),
        .tmds_clk_n    (clk_n),
        .tmds_data_p   (data_p),
        .tmds_data_n   (data_n)
    );

`else  // ==================== ENABLE_V9968_VDP ====================
    // F1 V9968: el VDP de HRA! (fpga/v9968, parche tag+eco) sustituye al
    // v9958_top ENTERO. VRAM en la SDRAM compartida via shim (contrato 8
    // ciclos) + bridge CDC al puerto wv2 de memory.v. Video: puente 800px
    // msx2hdmi_v9968 (ring BRAM, back-end TMDS intacto). v1: NTSC (la
    // geometria 50Hz del V9968 esta sin medir; pal_mode=0).

    // ---- reloj maestro 85.909 MHz (27 x 35/11, 0 ppm vs 24x colorburst) ----
    wire clk_86, pll86_lock;
    pll_86 pll86_vdp ( .clkout0(clk_86), .lock(pll86_lock), .clkin(clk27_video) );

    // _125b: syn_maxfan — rst86_n abanica a TODO el dominio clk_86 (shim +
    // core V9968) y su ultima etapa aparecio como migaja de -0.063 en el
    // roll P235 (rst86_sync[3] -> CEs de pfq). La replica de la herramienta
    // (identica por construccion) acorta las redes del arbol de reset.
    (* syn_maxfan = 16 *) reg [3:0] rst86_sync = 4'd0;
    always @(posedge clk_86) rst86_sync <= {rst86_sync[2:0], bus_reset_n & pll86_lock};
    wire rst86_n = rst86_sync[3];

    // ---- glue bus T80 -> valid/ready (una transaccion por ciclo I/O) ----
    wire [2:0] v68_bus_address;
    wire       v68_ioreq, v68_write, v68_valid, v68_ready;
    wire [7:0] v68_wdata, v68_rdata;
    wire       v68_rdata_en;
    v9968_cpu_glue u_v68glue (
        .clk_86(clk_86), .rst_n(rst86_n),
        .csw_n(vdp_csw_n), .csr_n(vdp_csr_n),
        .mode(bus_addr[1:0]), .cdo(cpu_dout), .cdi_r(vdp_dout),
        .wait_n(v68_wait86_n),   // _177: /WAIT del puerto CPU del V9968
        .bus_address(v68_bus_address), .bus_ioreq(v68_ioreq),
        .bus_write(v68_write), .bus_valid(v68_valid), .bus_ready(v68_ready),
        .bus_wdata(v68_wdata), .bus_rdata(v68_rdata), .bus_rdata_en(v68_rdata_en)
    );

    // ---- el V9968 ----
    wire [17:2] v68_vram_address;
    wire        v68_vram_write, v68_vram_valid, v68_vram_refresh;
    wire [31:0] v68_vram_wdata, v68_vram_rdata;
    wire [3:0]  v68_vram_mask;
    wire [4:0]  v68_vram_tag, v68_vram_rtag;
    wire        v68_vram_rdata_en;
    wire        v68_vram_stall;
    wire        v68_hs, v68_vs, v68_de;
    wire [7:0]  v68_r8, v68_g8, v68_b8;
    vdp u_v9968 (
        .reset_n(rst86_n), .clk(clk_86), .initial_busy(1'b0),
        .bus_address(v68_bus_address), .bus_ioreq(v68_ioreq), .bus_write(v68_write),
        .bus_valid(v68_valid), .bus_ready(v68_ready),
        .bus_wdata(v68_wdata), .bus_rdata(v68_rdata), .bus_rdata_en(v68_rdata_en),
        .int_n(vdp_int),
        .vram_address(v68_vram_address), .vram_write(v68_vram_write),
        .vram_valid(v68_vram_valid), .vram_wdata(v68_vram_wdata),
        .vram_wdata_mask(v68_vram_mask),
        .vram_rdata(v68_vram_rdata), .vram_rdata_en(v68_vram_rdata_en),
        .vram_tag(v68_vram_tag), .vram_rtag(v68_vram_rtag),
        .vram_stall(v68_vram_stall),
        .vram_refresh(v68_vram_refresh),
        .display_hs(v68_hs), .display_vs(v68_vs), .display_en(v68_de),
        .display_r(v68_r8), .display_g(v68_g8), .display_b(v68_b8),
        .force_highspeed(1'b0), .button(2'b00),
        .pulse0(), .pulse1(), .pulse2(), .pulse3(),
        .pulse4(), .pulse5(), .pulse6(), .pulse7()
    );

    // ---- shim VRAM (contrato 8 ciclos) + bridges CDC 85.9<->108 ----
    // _120: DOS canales — las lecturas de palabra piden las dos mitades en
    // paralelo (bk por wv2, bk2 por wv3): los modos de 256B/linea (SC7/8/12)
    // consumen 1 palabra/730ns y un canal solo daba ~800ns.
    wire [31:0] v68dbg_miss, v68dbg_bka, v68dbg_bkb;   // _121diag → COM11
    wire [31:0] v68dbg_park;                           // _124: park del shim
    wire [31:0] v68dbg_drops;                          // _154: {s1_pfq, wq_full} — drops reales
    wire        v68bk_req, v68bk_we, v68bk_done_t;
    wire [21:0] v68bk_addr;
    // _148 FIX B: el shim escribe PALABRAS de 32b con mascara de bytes (1 op de
    // backend por palabra en vez de hasta 4). Ver v9968_vram_shim.v.
    wire [31:0] v68bk_wdata;
    wire [3:0]  v68bk_wmask;
    wire [15:0] v68bk_rword;
    wire        v68bk2_req, v68bk2_done_t;
    wire [21:0] v68bk2_addr;
    wire [15:0] v68bk2_rword;
    v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_v68shim (
        .clk_vdp(clk_86), .rst_n(rst86_n),
        .vram_address(v68_vram_address), .vram_write(v68_vram_write),
        .vram_valid(v68_vram_valid), .vram_wdata(v68_vram_wdata),
        .vram_wdata_mask(v68_vram_mask), .vram_tag(v68_vram_tag),
        .vram_rdata(v68_vram_rdata), .vram_rdata_en(v68_vram_rdata_en),
        .vram_rtag(v68_vram_rtag),
        .bk_req(v68bk_req), .bk_we(v68bk_we), .bk_addr(v68bk_addr),
        .bk_wdata(v68bk_wdata), .bk_wmask(v68bk_wmask),
        .bk_rword(v68bk_rword), .bk_done_t(v68bk_done_t),
        .bk2_req(v68bk2_req), .bk2_addr(v68bk2_addr),
        .bk2_rword(v68bk2_rword), .bk2_done_t(v68bk2_done_t),
        .vram_stall(v68_vram_stall),
        .diag(),
        .dbg_miss(v68dbg_miss), .dbg_bka(v68dbg_bka), .dbg_bkb(v68dbg_bkb),
        .dbg_park(v68dbg_park),
        .dbg_drops(v68dbg_drops)
    );
`ifdef ENABLE_VRAM_DDR3
    // ==== EXPERIMENTO _128X: la VRAM del V9968 vive en la DDR3 del SOM ====
    // Los MISMOS bridges CDC, con el lado far a clk_x1 (74.25, lo genera la
    // IP DDR3) y hablando con v9968_ddr3_backend en vez de memory.v. Los
    // puertos wv2/wv3 de memory.v quedan inertes (reqs a 0, abajo). El shim
    // NO se toca. ADVERTENCIA saga _94-_103: la DDR3 de esta placa es
    // analogicamente marginal (loteria de calibracion) — telemetria
    // vddr_diag en cnt_c[23:16] del COM11.
    wire        vddr_clk_x1;
    wire        vddr_a_req, vddr_a_we, vddr_b_req;
    wire [21:0] vddr_a_addr, vddr_b_addr;
    wire [31:0] vddr_a_wdata;      // _148 FIX B: palabra de 32b + mascara
    wire [3:0]  vddr_a_wmask;
    wire [15:0] vddr_a_dout, vddr_b_dout;
    wire        vddr_a_done, vddr_b_done;
    wire        vddr_ready;
    wire [7:0]  vddr_diag;
    wire [31:0] vddr_ops;      // _129b: {lecturas[31:16], escrituras[15:0]}

    v9968_sdram_bridge u_v68bridge (
        .clk_vdp(clk_86), .rst_n(rst86_n),
        .bk_req(v68bk_req), .bk_we(v68bk_we), .bk_addr(v68bk_addr),
        .bk_wdata(v68bk_wdata), .bk_wmask(v68bk_wmask),
        .bk_rword(v68bk_rword), .bk_done_t(v68bk_done_t),
        .clk_108m(vddr_clk_x1),
        .wv2_req(vddr_a_req), .wv2_we(vddr_a_we), .wv2_addr(vddr_a_addr),
        .wv2_wdata(vddr_a_wdata), .wv2_wmask(vddr_a_wmask),
        .wv2_dout(vddr_a_dout), .wv2_done(vddr_a_done)
    );
    v9968_sdram_bridge u_v68bridge2 (
        .clk_vdp(clk_86), .rst_n(rst86_n),
        .bk_req(v68bk2_req), .bk_we(1'b0), .bk_addr(v68bk2_addr),
        .bk_wdata(32'd0), .bk_wmask(4'd0),
        .bk_rword(v68bk2_rword), .bk_done_t(v68bk2_done_t),
        .clk_108m(vddr_clk_x1),
        .wv2_req(vddr_b_req), .wv2_we(), .wv2_addr(vddr_b_addr),
        .wv2_wdata(), .wv2_wmask(), .wv2_dout(vddr_b_dout), .wv2_done(vddr_b_done)
    );

    v9968_ddr3_backend u_vddr3 (
        .a_req(vddr_a_req), .a_we(vddr_a_we), .a_addr(vddr_a_addr),
        .a_wdata(vddr_a_wdata), .a_wmask(vddr_a_wmask),
        .a_dout(vddr_a_dout), .a_done(vddr_a_done),
        .b_req(vddr_b_req), .b_addr(vddr_b_addr),
        .b_dout(vddr_b_dout), .b_done(vddr_b_done),
        .clk_x1_out(vddr_clk_x1), .ready(vddr_ready), .diag(vddr_diag),
        .dbg_ops(vddr_ops),        // _129b: {lecturas, escrituras} servidas
        .recal_req(1'b0),
        .clk_27(clk27_video),      // misma topologia que wave_ddr3/_86
        // _130 FIDELIDAD nand2mario: clk/mdclk del controlador desde el PAD
        // de 50MHz, EXACTAMENTE como su ddr3_framebuffer (probado con imagen
        // en esta placa). (La _128Z probo clk_54m del PLL — tambien calibro;
        // la teoria pad-vs-PLL de alanswx no era LA variable: lo decisivo
        // era darle TIEMPO a la calibracion. Fidelidad total = pad.)
        .clk_g50(ex_clk_27m),
        .pll27_lock(pll27_lock),
        .ddr_addr(ddr_addr), .ddr_bank(ddr_bank), .ddr_cs(ddr_cs),
        .ddr_ras(ddr_ras), .ddr_cas(ddr_cas), .ddr_we(ddr_we),
        .ddr_ck(ddr_ck), .ddr_ck_n(ddr_ck_n), .ddr_cke(ddr_cke),
        .ddr_odt(ddr_odt), .ddr_reset_n(ddr_reset_n), .ddr_dm(ddr_dm),
        .ddr_dq(ddr_dq), .ddr_dqs(ddr_dqs), .ddr_dqs_n(ddr_dqs_n)
    );
`else
    // _148 FIX B — CAMINO LEGACY (VRAM en la SDRAM compartida, respaldo _137).
    // memory.v solo sabe escribir 1 BYTE por operacion en wv2/wv3 (SdrDat =
    // {wdata,wdata} con la DQM sacada de addr[0]) y NO se toca. El bridge se
    // instancia con NARROW_BYTE=1: acepta la palabra de 32b del shim y la
    // SERIALIZA en hasta 4 round-trips hacia memory.v, devolviendo bk_done_t
    // solo al terminar la palabra entera. Coste identico al esquema byte-a-byte
    // que este camino ya tenia; el shim ve una escritura atomica.
    // FAR_DW=8 mantiene el bus de datos far del ancho de memory.v (sin
    // conexiones de anchura desigual, que Gowin resuelve mal).
    v9968_sdram_bridge #(.NARROW_BYTE(1), .FAR_DW(8)) u_v68bridge (
        .clk_vdp(clk_86), .rst_n(rst86_n),
        .bk_req(v68bk_req), .bk_we(v68bk_we), .bk_addr(v68bk_addr),
        .bk_wdata(v68bk_wdata), .bk_wmask(v68bk_wmask),
        .bk_rword(v68bk_rword), .bk_done_t(v68bk_done_t),
        .clk_108m(clk_108m),
        .wv2_req(wv2_req), .wv2_we(wv2_we), .wv2_addr(wv2_addr),
        .wv2_wdata(wv2_wdata), .wv2_wmask(),
        .wv2_dout(wv2_dout), .wv2_done(wv2_done)
    );
    v9968_sdram_bridge #(.NARROW_BYTE(1), .FAR_DW(8)) u_v68bridge2 (
        .clk_vdp(clk_86), .rst_n(rst86_n),
        .bk_req(v68bk2_req), .bk_we(1'b0), .bk_addr(v68bk2_addr),
        .bk_wdata(32'd0), .bk_wmask(4'd0),
        .bk_rword(v68bk2_rword), .bk_done_t(v68bk2_done_t),
        .clk_108m(clk_108m),
        .wv2_req(wv3_req), .wv2_we(wv3_we), .wv2_addr(wv3_addr),
        .wv2_wdata(wv3_wdata), .wv2_wmask(),
        .wv2_dout(wv3_dout), .wv2_done(wv3_done)
    );
`endif

    // ---- puente de video 800px -> HDMI 720p (back-end TMDS intacto) ----
    // _127H: telemetria del audio — eventos de reset del HDMI y toggles del
    // lock del puente (pulsos estirados ~30ms; 2FF + flanco a clk_54m). El
    // lock togglea a ~30Hz en regimen: su TASA en el lector delata perdidas.
    // Si los cortes de ~3s del audio coinciden con saltos de rst_cnt, el
    // culpable es el re-arranque del stream HDMI (el receptor silencia).
    wire v68_dbg_lock, v68_dbg_rst;
    wire [31:0] v68_dbg_apkt;        // _127I: contadores del packet_picker
    wire [5:0]  v68_dbg_defer;       // _134: yanks del reset diferidos
    wire [4:0]  v68_dbg_tear;        // _134: assert en silicio (esperado 0)
    reg [2:0]  aud_rst_sy = 3'd0, aud_lock_sy = 3'd0;
    reg [15:0] aud_rst_cnt = 16'd0, aud_lock_cnt = 16'd0;
    always @(posedge clk_54m) begin
        aud_rst_sy  <= {aud_rst_sy[1:0],  v68_dbg_rst};
        aud_lock_sy <= {aud_lock_sy[1:0], v68_dbg_lock};
        if (aud_rst_sy[1]  & ~aud_rst_sy[2])  aud_rst_cnt  <= aud_rst_cnt  + 16'd1;
        if (aud_lock_sy[1] & ~aud_lock_sy[2]) aud_lock_cnt <= aud_lock_cnt + 16'd1;
    end
    // ce de pixel: el V9968 emite 1 pixel cada 2 ciclos de 85.9; un toggle
    // libre muestrea cada pixel exactamente una vez (la fase da igual: el
    // dato es estable 2 ciclos y la captura se auto-alinea con HS).
    reg ce86 = 1'b0;
    always @(posedge clk_86) ce86 <= ~ce86;

    wire [15:0] amp_hdmi;   // _133: vumetro del lado HDMI (ver dbg_uart)

    msx2hdmi_v9968 u_msx2hdmi68 (
        .clk          (clk_86),
        .resetn       (rst86_n),
        .ce           (ce86),
        .r            (v68_r8[7:2]),
        .g            (v68_g8[7:2]),
        .b            (v68_b8[7:2]),
        .hs_n         (v68_hs),          // ACTIVO ALTO (convencion V9968)
        .vs_n         (v68_vs),
        .blank        (~v68_de),
        .pal_mode     (1'b0),            // v1: solo back-end NTSC (720p60)
`ifdef ENABLE_CONFIG
        .aspect_wide  (config_enable_16_9),
        .scanlines    (config_enable_scanlines),
`else
        .aspect_wide  (1'b0),
        .scanlines    (1'b0),
`endif
        .audio_l      (audio_sample),
        .audio_r      (audio_sample_r),
        .dbg_amp      (amp_hdmi),
        .clk_pixel    (clk_hdmi),
        .clk_5x_pixel (clk_hdmi5),
        .tmds_clk_n   (clk_n),
        .tmds_clk_p   (clk_p),
        .tmds_d_n     (data_n),
        .tmds_d_p     (data_p),
        .dbg_vs_tick  (),
        .dbg_wr_act   (),
        .dbg_nonblack (),
        .dbg_lock_tgl (v68_dbg_lock),    // _127H: telemetria audio
        .dbg_hdmi_rst (v68_dbg_rst),
        .dbg_rd_act   (),
        .dbg_apkt     (v68_dbg_apkt),    // _127I: {ovr, 0, paquetes_audio}
        .dbg_defer    (v68_dbg_defer),   // _134: yanks diferidos (~60/s sano)
        .dbg_tear     (v68_dbg_tear)     // _134: resets en zona de peligro (0 sano)
    );

    // ---- dh/dl: divisor LIBRE clk_108m ÷8/÷16 — el patron EXACTO con el
    // que sdr16_tb valida memory_ctrl (T1-T10, W1-W4). Slots CPU a 6.75MHz:
    // mas huecos vacios para wave+wv2 que con el VDP viejo.
    reg [3:0] v68_phc = 4'd0;
    always @(posedge clk_108m) v68_phc <= v68_phc + 1'b1;
    assign VideoDHClk = ~v68_phc[2];
    assign VideoDLClk = ~v68_phc[3];

    // VRAM del VDP viejo: inactiva (el slot VDP de la SDRAM queda vacio)
    assign WeVdp_n = 1'b1;
    assign VdpAdr  = 17'd0;
    assign VrmDbo  = 8'd0;

    // sondas de video del bring-up: pll86_lock + contador de frames (vs)
    reg [2:0] v68_frm = 3'd0;
    reg       v68_vs_d = 1'b0;
    always @(posedge clk_86) begin
        v68_vs_d <= v68_vs;
        if (v68_vs & ~v68_vs_d) v68_frm <= v68_frm + 1'b1;
    end
    assign dbg_video_w = {1'b0, 1'b0, 1'b0, v68_frm[2], pll86_lock, 1'b0};
`ifdef VIDEO720
    assign dbg_bridge_w = 6'd0;
`endif
`endif // ENABLE_V9968_VDP

`ifdef ENABLE_MAPPER
    //mapper
    wire mapper_read;
    wire mapper_write;
    wire mapper_req;
    reg mapper_req3;
    reg mapper_req12;
    reg [7:0] mapper_dout;
    wire [21:0] mapper_addr;
    reg [7:0] mapper_reg0;
    reg [7:0] mapper_reg1;
    reg [7:0] mapper_reg2;
    reg [7:0] mapper_reg3;
    wire mapper_reg_write;

    assign mapper_addr = (bus_addr [15:14] == 2'b00 ) ? { mapper_reg0, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b01 ) ? { mapper_reg1, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b10 ) ? { mapper_reg2, bus_addr[13:0] } :
                                                        { mapper_reg3, bus_addr[13:0] };

    always @ (posedge clk_54m) begin
        mapper_req3 <= ( bus_rfsh_n == 1 && config_enable_mapper3 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[0] == 1 && xffff == 0) ? 1 : 0;
        mapper_req12 <= ( config_enable_mapper12 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_mapper_slot ) ? 1 : 0;
    end
    assign mapper_req = mapper_req3 | mapper_req12;
    assign mapper_read = mapper_req & ~bus_rd_n;
    assign mapper_write = mapper_req & ~bus_wr_n;
    assign mapper_reg_write = ( (bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) && (bus_addr [7:2] == 6'b111111) )?1:0;

    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
            mapper_reg0	<= 8'b00000011;
            mapper_reg1	<= 8'b00000010;
            mapper_reg2	<= 8'b00000001;
            mapper_reg3	<= 8'b00000000;
        end
        else if (mapper_reg_write == 1) begin
            case (bus_addr[1:0])
                2'b00: mapper_reg0 <= cpu_dout[7:0];
                2'b01: mapper_reg1 <= cpu_dout[7:0];
                2'b10: mapper_reg2 <= cpu_dout[7:0];
                2'b11: mapper_reg3 <= cpu_dout[7:0];
            endcase
        end
    end
`else
    wire mapper_read;
    wire mapper_write;
    wire mapper_req;
    reg [7:0] mapper_dout;
    wire [21:0] mapper_addr;
    assign mapper_read = 0;
    assign mapper_write = 0;
    assign mapper_addr = 22'd0;
`endif

    reg [15:0] VrmDbi2;
    reg [7:0] megaram_dout;
    wire [22:0] ram_addr;
    wire ram_read;
    wire ram_write;
    wire ram_req;
    wire [7:0] ram_din;
    reg [7:0] ram_dout;
    reg ram_busy;

    //rom map, 512 KB, [18:0]
    //876 54321098 76543210
    //111 11xxxxxx xxxxxxxx free, 16 KB, 0x7c000 - 0x7ffff
    //111 10xxxxxx xxxxxxxx esp8266, 16 KB, 0x78000 - 0x7bfff
    //111 0xxxxxxx xxxxxxxx kanji, 32 KB, 0x70000 - 0x77fff
    //110 11xxxxxx xxxxxxxx fm + logo + boot menu, 16 KB, 0x6c000 - 0x6ffff
    //110 10xxxxxx xxxxxxxx msx2+ subrom, 16 KB, 0x68000 - 0x6bfff
    //110 0xxxxxxx xxxxxxxx msx2+ bios, 32 KB, 0x60000 - 0x67fff
    //10x xxxxxxxx xxxxxxxx wondertang disk, 128 KB, 0x40000 - 0x5ffff
    //01x xxxxxxxx xxxxxxxx jis2, 128 KB, 0x20000 - 0x3ffff
    //00x xxxxxxxx xxxxxxxx jis1, 128 KB, 0x00000 - 0x1ffff

    //sdram map, 8 MB, [22:0]
    //2109876 54321098 76543210
    //11111xx xxxxxxxx xxxxxxxx vram, 256 KB, bank D
    //1110111 10xxxxxx xxxxxxxx esp8266, 16 KB, 0x778000 - 0x77bfff
    //1110111 0xxxxxxx xxxxxxxx kanji driver, 32 KB, 0x770000 - 0x777fff
    //1110110 11xxxxxx xxxxxxxx fm + logo + boot menu, 16 KB, 0x76c000 - 0x76ffff
    //1110110 10xxxxxx xxxxxxxx msx2+ subrom, 16 KB, 0x768000 - 0x76bfff
    //1110110 0xxxxxxx xxxxxxxx msx2+ bios, 32 KB, 0x760000 - 0x767fff
    //111010x xxxxxxxx xxxxxxxx wondertang disk, 128 KB, bank D, 0x740000 - 0x75ffff
    //11100xx xxxxxxxx xxxxxxxx kanji data jis1 + jis2, 256 KB, 0x700000 - 0x73ffff
    //10xxxxx xxxxxxxx xxxxxxxx megaram, 2 MB, bank C
    //0xxxxxx xxxxxxxx xxxxxxxx mapper, 4 MB, banks A+B

    assign ram_addr = (~flash_idle) ? rom_addr :
                `ifdef ENABLE_MAPPER
                        (mapper_req == 1) ? { 1'b0, mapper_addr[21:0] } :  //bank A+B
                `endif
                        (bios_req == 1 ) ? { 8'b11101100, bus_addr[14:0] } : //bank D
                        (subrom_logo_req == 1 ) ? { 8'b11101101, bus_addr[14:0] } : //bank D
                `ifdef ENABLE_SDCARD
                        (megarom_req == 1 ) ? { 6'b111010, megarom_addr[16:0] } : //bank D
                `endif
                        (megaram_req == 1 ) ? { 2'b10, megaram_addr[20:0] } :  //bank C
                        (kanji_driver_req == 1 ) ? { 8'b11101110, ~bus_addr[14], bus_addr[13:0] } : //bank D
                        (kanji_data_ram_req == 1 ) ? { 5'b11100, kanji_data_ram_addr[17:0] } : //bank D
                `ifdef ENABLE_WIFI
                        (wifi_req == 1 ) ? { 9'b111011110, bus_addr[13:0] } : //bank D
                `endif
                        // logo SIEMPRE (v3.0): estaba atrapado en ENABLE_WIFI y sin WiFi
                        // se perdia la pantalla de marca del menu
                        (logo_req == 1 ) ? { 9'b111011111, bus_addr[13:0] } : //bank D (pack 0x7C000)
                        23'h7fffff; 
    
    // P1-fix (_64): muxes de habilitacion APLANADOS. Las cascadas ternarias
    // (~10 niveles) devolvian LO MISMO en todas las ramas -> OR plano
    // booleanamente identico (y los reqs son mutuamente exclusivos por decode).
    // Era el grueso del cono strobe->CE (7 niveles de LUT + 1.9ns de net) que
    // la loteria de placement no siempre absorbia; el OR de 2 niveles lo mata
    // de raiz sin pins INS_LOC (leccion del ESC de la _62: los samplers no se
    // mueven).
    wire any_ram_rd_req =
                `ifdef ENABLE_MAPPER
                      mapper_read |
                `endif
                      bios_req | subrom_logo_req |
                `ifdef ENABLE_SDCARD
                      megarom_req |
                `endif
                      megaram_req | kanji_driver_req | kanji_data_ram_req |
                `ifdef ENABLE_WIFI
                      wifi_req |
                `endif
                      logo_req;
    wire any_ram_req =
                      mapper_req | bios_req | subrom_logo_req |
                `ifdef ENABLE_SDCARD
                      megarom_req |
                `endif
                      megaram_req | kanji_driver_req | kanji_data_ram_req |
                `ifdef ENABLE_WIFI
                      wifi_req |
                `endif
                      logo_req;
    wire any_ram_wr =
                `ifdef ENABLE_MAPPER
                      mapper_write |
                `endif
                      megaram_wrt;

    assign ram_read  = (~flash_idle) ? 1'b0      : (any_ram_rd_req & ~bus_rd_n);

    assign ram_write = (~flash_idle) ? rom_write : (any_ram_wr & ~bus_wr_n);

    // _125c: se EVALUO registrar any_ram_req (el cono T80 ISet/IStatus ->
    // mux A -> mapper -> aceptacion, ~13 niveles, familia final de timing de
    // la campana _125) y el A/B de la W-suite lo RECHAZO: la correccion pasa
    // (W1-W5 OK) pero T10 sostenido cae a la MITAD (296ns vs 148 — el drop
    // retrasado del req hace perder una ventana entre lecturas back-to-back)
    // y T9b pierde 13% de lecturas en 1T @5.369. El turbo manda: la familia
    // se contiene con syn_maxfan (ISet/IStatus en t80.vhd) + sembrado.
    assign ram_req   = (~flash_idle) ? rom_write : any_ram_req;

    assign ram_din = (~flash_idle) ? { rom_dout, rom_dout }  : { cpu_dout, cpu_dout };

// SDCLK_INVERT=1 CONFIRMADO EN HW (2026-07-08): con fase normal el auto-test
// da ROJO (errores CPU) y con 180 grados VERDE; el core arranca (serial _18inv).
// _104: puerto WAVE de la SDRAM (declarado ANTES de su primer uso — Gowin
// declara implicitos de 1 bit si no; leccion _95 de los weng_*)
wire        wv_req, wv_we, wv_done;
wire [21:0] wv_addr;
wire [7:0]  wv_wdata;
wire [15:0] wv_dout;
// V9968: puerto wv2 (VRAM del V9968 via bridge CDC); atado a 0 sin el define
wire        wv2_req, wv2_we, wv2_done;
wire [21:0] wv2_addr;
wire [7:0]  wv2_wdata;
wire [15:0] wv2_dout;
// V9968 _120: puerto wv3 (canal B del shim, solo lecturas — mitad alta)
wire        wv3_req, wv3_we, wv3_done;
wire [21:0] wv3_addr;
wire [7:0]  wv3_wdata;
wire [15:0] wv3_dout;
// _159: wv2 lo conduce el shim del ADPCM-B cuando ENABLE_ADPCM_SDRAM esta
// derivado (ver la cabecera); los tie-offs de wv2 solo sobreviven si no.
`ifndef ENABLE_V9968_VDP
`ifndef ENABLE_ADPCM_SDRAM
assign wv2_req   = 1'b0;
assign wv2_we    = 1'b0;
assign wv2_addr  = 22'd0;
assign wv2_wdata = 8'd0;
`endif
assign wv3_req   = 1'b0;
assign wv3_we    = 1'b0;
assign wv3_addr  = 22'd0;
assign wv3_wdata = 8'd0;
`else
`ifdef ENABLE_VRAM_DDR3
// _128X: la VRAM vive en la DDR3 — los puertos wv2/wv3 de memory.v inertes
`ifndef ENABLE_ADPCM_SDRAM
assign wv2_req   = 1'b0;
assign wv2_we    = 1'b0;
assign wv2_addr  = 22'd0;
assign wv2_wdata = 8'd0;
`endif
assign wv3_req   = 1'b0;
assign wv3_we    = 1'b0;
assign wv3_addr  = 22'd0;
assign wv3_wdata = 8'd0;
`endif
`endif

memory_ctrl #(.SDCLK_INVERT(1'b1)) mem1 (
    .clk_27m(clk_54m),
    .clk_108m(clk_108m),
    .bus_reset_n(bus_reset_n ),
    .video_dhclk(VideoDHClk),
    .video_dlclk(VideoDLClk),

    .ram_din(ram_din),
    .ram_req(ram_req),
    .ram_write(ram_write),
    .ram_addr(ram_addr),
    .vram_din(VrmDbo),
    .vram_write(~WeVdp_n),
    .vram_addr(VdpAdr),
    .bus_rfsh_n(bus_rfsh_n),
    // _181: mismo termino que el RESET_n del T80 — el refresco autonomo solo
    // puede disparar cuando el Z80 esta provadamente parado (ver memory.v)
    .cpu_run(bus_reset_n & reset3_n & flash_idle & esp_boot_ok),

    .ram_dout(ram_dout),
    .vram_dout(VrmDbi2),
    .ram_busy(ram_busy),

    // _104: puerto wave (roba turnos de CPU vacios; filas 4096+)
    .wv_req(wv_req),
    .wv_we(wv_we),
    .wv_addr(wv_addr),
    .wv_wdata(wv_wdata),
    .wv_dout(wv_dout),
    .wv_done(wv_done),

    // V9968: puerto wv2 (mismos turnos vacios, prioridad wave>wv2)
    .wv2_req(wv2_req),
    .wv2_we(wv2_we),
    .wv2_addr(wv2_addr),
    .wv2_wdata(wv2_wdata),
    .wv2_dout(wv2_dout),
    .wv2_done(wv2_done),

    // V9968 _120: puerto wv3 (canal B, prioridad wave>wv2>wv3)
    .wv3_req(wv3_req),
    .wv3_we(wv3_we),
    .wv3_addr(wv3_addr),
    .wv3_wdata(wv3_wdata),
    .wv3_dout(wv3_dout),
    .wv3_done(wv3_done),

    .O_sdram_clk(O_sdram_clk),
    .O_sdram_cke(O_sdram_cke),
    .O_sdram_cs_n(O_sdram_cs_n),
    .O_sdram_cas_n(O_sdram_cas_n),
    .O_sdram_ras_n(O_sdram_ras_n),
    .O_sdram_wen_n(O_sdram_wen_n),
    .IO_sdram_dq(IO_sdram_dq),
    .O_sdram_addr(O_sdram_addr),
    .O_sdram_ba(O_sdram_ba),
    .O_sdram_dqm(O_sdram_dqm)
);

    // ===== _161 ESTRUCTURA DE GANANCIA: registro de ganancia maestra =====
    // 0:x1  1:x1,5  2:x2  3:x3  4:x4  5:x5  6:x6  7:x8   (defecto x5 = +14,0 dB)
    // x5 = el valor que Albert ajusto a oido en placa (28/07): deja el conjunto
    // a la altura del OPL4/MoonSound sin tocar el balance entre chips.
    // Se escribe por el puerto #44 del bloque config y se persiste en el
    // byte[5] del bloque de config de la flash (hoy sin usar, se escribe 0xFF).
    reg [2:0] snd_gain_ff = 3'd5;

`ifdef ENABLE_SOUND

    //YM219 PSG
    wire psgBdir;
    wire psgBc1;
    wire iorq_wr_n;
    wire iorq_rd_n;
    wire [7:0] psg_dout;
    wire [7:0] psgSound1;
    wire [7:0] psgPA;
    wire [7:0] psgPB;
    reg clk_1m8;
    assign iorq_wr_n = bus_iorq_n | bus_wr_n;
    assign iorq_rd_n = bus_iorq_n | bus_rd_n;
    assign psgBdir = ( bus_addr[7:3]== 5'b10100 && iorq_wr_n == 0 && bus_addr[1]== 0 ) ?  1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bdir = 1 when writing to &HA0-&Ha1
    assign psgBc1 = ( bus_addr[7:3]== 5'b10100 && ((iorq_rd_n==0 && bus_addr[1]== 1) || (bus_addr[1]==0 && iorq_wr_n==0 && bus_addr[0]==0))) ? 1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bc1 = 1 when writing A0 or reading A2
    assign psgPA =8'h00;
    // niquelado B: aqui habia un `reg psgPB = 8'hff;` DUPLICANDO el wire [7:0]
    // psgPB de arriba (identificador doble, ancho 1 vs 8 — mina de sintesis).
    // El wire con el loopback O_IOB->I_IOB es la conexion correcta del puerto B.

    // v2.4: el PSG vive ENTERO en 54M (su bus BDIR/BC1/I_DA es del dominio 54M;
    // clockearlo a 27M con la fase arbitraria del CLKDIV lo dejaba MUDO). La
    // cadencia 1.79M se regenera con los pulsos 3m6 del dominio 54.
    wire clk_enable_1m8;
    reg clk_1m8_prev;
    always @ (posedge clk_54m) begin
        if (clk_enable_3m6_54) begin
            clk_1m8 <= ~clk_1m8;
        end
    end
    assign clk_enable_1m8 = (clk_enable_3m6_54 == 1 && clk_1m8 == 1);

    // ===== r10 (_30dbg): AUTO-TEST del PSG (beeper sin CPU) =====
    // De t=1s a t=3s tras el reset, un FSM escribe directamente los registros
    // del psg1 (R7=tono A, R0/R1=periodo ~262Hz, R8=vol 15) y al salir lo
    // silencia. Si SUENA el pitido: chip+mezcla OK -> el corte esta en el
    // camino CPU->PSG. Si NO suena: chip/sintesis.
    reg [27:0] psgtest_cnt = 28'd0;
    always @(posedge clk_54m) begin
        if (~bus_reset_n) psgtest_cnt <= 28'd0;
        else if (psgtest_cnt != 28'hFFFFFFF) psgtest_cnt <= psgtest_cnt + 28'd1;
    end
    wire psgtest_win = (psgtest_cnt > 28'd54000000) && (psgtest_cnt < 28'd162000000);
    // secuencia: 5 escrituras (una cada 64 ciclos: fase addr 24c / data 24c / nop)
    reg [2:0]  ptst_idx = 3'd0;
    reg [5:0]  ptst_ph  = 6'd0;
    reg        ptst_done = 1'b0;
    reg [7:0]  ptst_da   = 8'd0;
    reg        ptst_bdir = 1'b0;
    reg        ptst_bc1  = 1'b0;
    wire [7:0] ptst_reg = (ptst_idx==3'd0) ? 8'd7 :
                          (ptst_idx==3'd1) ? 8'd0 :
                          (ptst_idx==3'd2) ? 8'd1 :
                          (ptst_idx==3'd3) ? 8'd8 : 8'd8;
    wire [7:0] ptst_val = (ptst_idx==3'd0) ? 8'hBE :
                          (ptst_idx==3'd1) ? 8'hAC :
                          (ptst_idx==3'd2) ? 8'h01 :
                          (ptst_idx==3'd3) ? 8'h0F : 8'h00;  // idx4 = silencio final
    reg psgtest_win_d = 1'b0;
    always @(posedge clk_54m) begin
        psgtest_win_d <= psgtest_win;
        if (~bus_reset_n) begin
            ptst_idx <= 3'd0; ptst_ph <= 6'd0; ptst_done <= 1'b0;
            ptst_bdir <= 1'b0; ptst_bc1 <= 1'b0; ptst_da <= 8'd0;
        end
        else if (psgtest_win && !ptst_done) begin
            ptst_ph <= ptst_ph + 6'd1;
            if      (ptst_ph < 6'd24) begin ptst_da <= ptst_reg; ptst_bdir <= 1'b1; ptst_bc1 <= 1'b1; end
            else if (ptst_ph < 6'd48) begin ptst_da <= ptst_val; ptst_bdir <= 1'b1; ptst_bc1 <= 1'b0; end
            else begin
                ptst_bdir <= 1'b0; ptst_bc1 <= 1'b0;
                if (ptst_ph == 6'd63) begin
                    if (ptst_idx == 3'd3) ptst_done <= 1'b1;  // beep armado; queda sonando
                    else ptst_idx <= ptst_idx + 3'd1;
                end
            end
        end
        else if (!psgtest_win && psgtest_win_d && ptst_done) begin
            // fin de ventana: re-armar para la escritura de silencio (idx 4)
            ptst_idx <= 3'd4; ptst_ph <= 6'd0; ptst_done <= 1'b0;
        end
        else if (!psgtest_win && !ptst_done && ptst_idx == 3'd4) begin
            ptst_ph <= ptst_ph + 6'd1;
            if      (ptst_ph < 6'd24) begin ptst_da <= ptst_reg; ptst_bdir <= 1'b1; ptst_bc1 <= 1'b1; end
            else if (ptst_ph < 6'd48) begin ptst_da <= ptst_val; ptst_bdir <= 1'b1; ptst_bc1 <= 1'b0; end
            else begin
                ptst_bdir <= 1'b0; ptst_bc1 <= 1'b0;
                if (ptst_ph == 6'd63) ptst_done <= 1'b1;
            end
        end
    end
    // v3.0 BASE MINIMA: beeper de diagnostico DESARMADO (el PSG quedo absuelto
    // en la ronda 9; el FSM queda arriba por si hiciera falta re-armarlo).
    wire ptst_active = 1'b0;
    // wire ptst_active = (psgtest_win && !ptst_done) || (!psgtest_win && !ptst_done && ptst_idx == 3'd4);

    YM2149 psg1 (
        .I_DA(ptst_active ? ptst_da : cpu_dout),
        .O_DA(),
        .O_DA_OE_L(),
        .I_A9_L(0),
        .I_A8(1),
        .I_BDIR(ptst_active ? ptst_bdir : psgBdir),
        .I_BC2(1),
        .I_BC1(ptst_active ? ptst_bc1 : psgBc1),
        .I_SEL_L(1),
        .O_AUDIO(psgSound1),
        .I_IOA(psgPA),
        .O_IOA(),
        .O_IOA_OE_L(),
        .I_IOB(psgPB),
        .O_IOB(psgPB),
        .O_IOB_OE_L(),
        
        .ENA(clk_enable_1m8), // clock enable for higher speed operation
        .RESET_L(bus_reset_n),
        .CLK(clk_54m),        // v2.4: PSG en 54M (bus mismo dominio)
        .clkHigh(clk_54m),
        .debug ()
    );

    wire [7:0] psgSound3;
    psg_filter filter1 (
        .clk_27m (clk_27m),
        .reset (~bus_reset_n),
        .data_in (psgSound1),
        .data_out (psgSound3)
    );

    // ===== Second PSG (OCM 2nd-gen standard): I/O 10h=latch, 11h=write, 12h=read =====
    wire psg2Bdir;
    wire psg2Bc1;
    assign psg2Bdir = ( bus_addr[7:2] == 6'b000100 && iorq_wr_n == 0 && bus_addr[1] == 0 ) ? 1 : 0;
    assign psg2Bc1  = ( bus_addr[7:2] == 6'b000100 && ((iorq_rd_n == 0 && bus_addr[1] == 1) || (bus_addr[1] == 0 && iorq_wr_n == 0 && bus_addr[0] == 0)) ) ? 1 : 0;

    wire [7:0] psg2Sound1;
    wire [7:0] psg2_dout;

    YM2149 psg2 (
        .I_DA(cpu_dout),
        .O_DA(psg2_dout),
        .O_DA_OE_L(),
        .I_A9_L(0),
        .I_A8(1),
        .I_BDIR(psg2Bdir),
        .I_BC2(1),
        .I_BC1(psg2Bc1),
        .I_SEL_L(1),
        .O_AUDIO(psg2Sound1),
        .I_IOA(8'hff),
        .O_IOA(),
        .O_IOA_OE_L(),
        .I_IOB(8'hff),
        .O_IOB(),
        .O_IOB_OE_L(),

        .ENA(clk_enable_1m8),
        .RESET_L(bus_reset_n),
        .CLK(clk_54m),        // v2.4: PSG en 54M
        .clkHigh(clk_54m),
        .debug ()
    );

    wire [7:0] psg2Sound3;
    psg_filter filter2 (
        .clk_27m (clk_27m),
        .reset (~bus_reset_n),
        .data_in (psg2Sound1),
        .data_out (psg2Sound3)
    );

    // PSG2 register read-back at port 12h (detection by players/trackers)
    wire psg2_req_r;
    assign psg2_req_r = ( bus_addr[7:0] == 8'h12 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0 ) ? 1 : 0;

    //opll
    wire opll_req_n; 
    wire [9:0] opll_mo;
    wire [9:0] opll_ro;
    reg [11:0] opll_mix;
    wire [15:0] jt2413_wav;

    // _108: BUS REGISTRADO (medicina _95, patron y54_*): el jt2413 decodificaba
    // el bus CRUDO del T80 (flanco de bajada) y rotaba como perdedor de la
    // loteria de placement (p0r0: -0.269 en cpu1/WR_n -> opll/u_mmr). Flop del
    // bus = cono trivial; el strobe de escritura del Z80 dura cientos de ns.
    reg        o54_iorq_n, o54_wr_n;
    reg        o54_a0;
    reg [6:0]  o54_adr71;
    reg [7:0]  o54_din;
    always @(posedge clk_54m) begin
        o54_iorq_n <= bus_iorq_n;
        o54_wr_n   <= bus_wr_n;
        o54_a0     <= bus_addr[0];
        o54_adr71  <= bus_addr[7:1];
        o54_din    <= cpu_dout;
    end
    assign opll_req_n = ( o54_iorq_n == 1'b0 && o54_adr71 == 7'b0111110  &&  o54_wr_n == 1'b0 )  ? 1'b0 : 1'b1;    // I/O:7C-7Dh   / OPLL (YM2413)

`ifdef ENABLE_OPLL
    jt2413 opll(
        .rst (~bus_reset_n),        // rst should be at least 6 clk&cen cycles long
        .clk (clk_54m),        // F3/_38: OPLL a 54M+cen (patron smstang con el MISMO chip:
        .cen (clk_enable_3m6_54),   //  bus mismo-dominio y fuera del arbol 27M — su carga
                                    //  re-sorteaba el hold de la paleta del VDP)
        .din (o54_din),
        .addr (o54_a0),
        .cs_n (opll_req_n),
        .wr_n (1'b0),
        // combined output
        .snd (jt2413_wav),
        .sample   ( )
    );
`else
    assign jt2413_wav = 16'd0;      // BASE MINIMA v3.0: OPLL fuera
`endif

    // ===== Y8950 (MSX-Audio) — FM primero via jtopl2 (F2/_79) =====
    // Puertos I/O C0h/C1h (unidad primaria): C0=registro/status, C1=dato.
    // Mismo patron de escritura que el OPLL (write = !cs_n && !wr_n, con wr_n=0
    // y cs_n = strobe de escritura). dout de jtopl es COMBINACIONAL (byte de
    // status: IRQ/timer1/timer2) — se rutea al bus en lecturas de C0/C1, que es
    // lo que la deteccion y los replayers de MSX-Audio necesitan. ADPCM-B en un
    // build posterior (jt10_adpcmb + RAM de samples).
    wire        y8950_req_n;
    wire        y8950_rd_r;
    wire [7:0]  y8950_dout;
    wire [15:0] y8950_wav;
    wire        y8950_int_n;   // _81: hacia el /INT del Z80 (wired-AND)
    wire        opl4_int_n;    // _108: timer OPL4 -> /INT (VGMPlay/MBWave)
    // _95: BUS REGISTRADO (patron _91) para el jtopl2 — el T80 lanza en el
    // flanco de BAJADA de clk_54m y el decode al de subida deja 9.26ns menos
    // el cono: este camino (IORQ->u_mmr/value_*) rotaba como perdedor de la
    // loteria de placement (p0r1: -0.384). Flop directo del bus = cono
    // trivial que SI cierra; el decode pasa a tener ciclo completo. El
    // strobe de escritura del Z80 dura cientos de ns: +18.5ns es nada.
    // (Las strobes del glue ADPCM de abajo ya iban doble-registradas.)
    reg        y54_iorq_n, y54_wr_n;
    reg [1:0]  y54_addr;               // A[1:0] basta: decode C0-C1 + addr[0]
    reg        y54_adr_c0c1;           // A[7:1]==1100000 registrado
    reg [7:0]  y54_din;
    always @(posedge clk_54m) begin
        y54_iorq_n  <= bus_iorq_n;
        y54_wr_n    <= bus_wr_n;
        y54_addr    <= bus_addr[1:0];
        y54_adr_c0c1<= (bus_addr[7:1] == 7'b1100000);
        y54_din     <= cpu_dout;
    end
    assign y8950_req_n = ( y54_iorq_n == 1'b0 && y54_adr_c0c1 && y54_wr_n == 1'b0 ) ? 1'b0 : 1'b1;   // I/O:C0-C1h escritura
    assign y8950_rd_r  = ( bus_iorq_n == 1'b0 && bus_addr[7:1] == 7'b1100000 && bus_rd_n == 1'b0 ) ? 1'b1 : 1'b0;   // I/O:C0-C1h lectura (status/dato)

`ifdef ENABLE_Y8950
    wire [7:0] jtopl2_dout;          // status del jtopl: {~irq_n, ft1, ft2, 5'd6}
    jtopl2 y8950(
        .rst  (~bus_reset_n),        // rst >= 6 ciclos clk&cen
        .clk  (clk_54m),             // mismo dominio que el OPLL
        .cen  (clk_enable_3m6_54),   // FM 3.58 MHz (identico al OPLL)
        .din  (y54_din),             // _95: bus registrado (coherente con cs_n)
        .addr (y54_addr[0]),         // 0=registro (C0), 1=dato (C1)
        .cs_n (y8950_req_n),         // strobe de escritura (patron OPLL)
        .wr_n (1'b0),
        .dout (jtopl2_dout),
        .irq_n( ),
        // combined output
        .snd  (y8950_wav),
        .sample ( )
    );

`ifdef ENABLE_Y8950_ADPCM
    // ===== ADPCM-B (_80): glue openMSX-exacto + decoder jt10 + 32KB BSRAM =====
    // Strobes de 1 ciclo (54M) con doble registro: el dato del Z80 lleva ya
    // decenas de ns estable cuando dispara el flanco detectado en d1&~d2.
    reg  y8950_wr_d1, y8950_wr_d2, y8950_rdc1_d1, y8950_rdc1_d2;
    wire y8950_wr_any = (bus_iorq_n == 1'b0 && bus_addr[7:1] == 7'b1100000 && bus_wr_n == 1'b0);
    wire y8950_rdc1_any = (bus_iorq_n == 1'b0 && bus_addr[7:0] == 8'hC1 && bus_rd_n == 1'b0 && bus_m1_n == 1'b1);
    always @(posedge clk_54m) begin
        y8950_wr_d1   <= y8950_wr_any;   y8950_wr_d2   <= y8950_wr_d1;
        y8950_rdc1_d1 <= y8950_rdc1_any; y8950_rdc1_d2 <= y8950_rdc1_d1;
    end
    wire y8950_wrc0_stb = y8950_wr_d1 & ~y8950_wr_d2 & ~bus_addr[0];
    wire y8950_wrc1_stb = y8950_wr_d1 & ~y8950_wr_d2 &  bus_addr[0];
    wire y8950_rdc1_stb = y8950_rdc1_d1 & ~y8950_rdc1_d2;

    wire [7:0] y8950_status_c0;
    wire [7:0] y8950_data_c1;
    wire signed [15:0] y8950_adpcm_wav;
    wire y8950_irq_w;

    // _159: puerto de la RAM de muestras (256KB fuera del chip)
    wire        adpcm_mem_req_t, adpcm_mem_we, adpcm_mem_done_t;
    wire [17:0] adpcm_mem_addr;
    wire [7:0]  adpcm_mem_wdata;
    wire [15:0] adpcm_mem_rword;
    wire [7:0]  adpcm_mem_diag;      // {wq_lost, wd_hits} — salud del camino

    y8950_adpcm uadpcm(
        .clk       (clk_54m),
        .cen3m6    (clk_enable_3m6_54),
        .rst_n     (bus_reset_n),
        .wr_c0     (y8950_wrc0_stb),
        .wr_c1     (y8950_wrc1_stb),
        .rd_c1     (y8950_rdc1_stb),
        .din       (cpu_dout),
        .ft1       (jtopl2_dout[6]),
        .ft2       (jtopl2_dout[5]),
        .status    (y8950_status_c0),
        .data_dout (y8950_data_c1),
        .irq       (y8950_irq_w),        // flags visibles (ya enmascarados)
        .pcm_out   (y8950_adpcm_wav),
        .mem_req_t (adpcm_mem_req_t),
        .mem_we    (adpcm_mem_we),
        .mem_addr  (adpcm_mem_addr),
        .mem_wdata (adpcm_mem_wdata),
        .mem_rword (adpcm_mem_rword),
        .mem_done_t(adpcm_mem_done_t),
        .mem_diag  (adpcm_mem_diag)
    );

    // _159: las muestras viven en la SDRAM (puerto wv2, filas 5120+). Con el
    // wv2 ocupado (linea de respaldo _137) el shim cae a los 32KB de BSRAM
    // de siempre — misma interfaz, cero cambios en el modulo de arriba.
`ifdef ENABLE_ADPCM_SDRAM
    adpcm_sdram #(.FALLBACK_BSRAM(0)) uadpcmmem (
        .clk_host   (clk_54m),
        .rst_n      (bus_reset_n),
        .req_toggle (adpcm_mem_req_t),
        .we         (adpcm_mem_we),
        .addr       (adpcm_mem_addr),
        .wdata      (adpcm_mem_wdata),
        .rword      (adpcm_mem_rword),
        .done_toggle(adpcm_mem_done_t),
        .clk_108m   (clk_108m),
        .wv_req     (wv2_req),
        .wv_we      (wv2_we),
        .wv_addr    (wv2_addr),
        .wv_wdata   (wv2_wdata),
        .wv_dout    (wv2_dout),
        .wv_done    (wv2_done)
    );
`else
    adpcm_sdram #(.FALLBACK_BSRAM(1)) uadpcmmem (
        .clk_host   (clk_54m),
        .rst_n      (bus_reset_n),
        .req_toggle (adpcm_mem_req_t),
        .we         (adpcm_mem_we),
        .addr       (adpcm_mem_addr),
        .wdata      (adpcm_mem_wdata),
        .rword      (adpcm_mem_rword),
        .done_toggle(adpcm_mem_done_t),
        .clk_108m   (clk_108m),
        .wv_req     ( ),
        .wv_we      ( ),
        .wv_addr    ( ),
        .wv_wdata   ( ),
        .wv_dout    (16'd0),
        .wv_done    (1'b0)
    );
`endif
    // C0 = status compuesto (timers+EOS+BUF_RDY+PCM_BSY); C1 = puerto de datos
    assign y8950_dout = bus_addr[0] ? y8950_data_c1 : y8950_status_c0;
    // _81: al /INT del Z80 como en el Music Module real (activo-bajo). La
    // mascara del reg 4 arranca toda tapada -> ni una IRQ hasta que el
    // software la pida explicitamente.
  `ifdef ENABLE_Y8950_IRQ
    assign y8950_int_n = ~y8950_irq_w;
  `else
    assign y8950_int_n = 1'b1;
  `endif
`else
    wire signed [15:0] y8950_adpcm_wav = 16'sd0;
    assign y8950_dout = jtopl2_dout;     // _79: status del jtopl en C0/C1
    assign y8950_int_n = 1'b1;
`endif

`else
    assign y8950_wav  = 16'd0;
    assign y8950_dout = 8'hFF;
    wire signed [15:0] y8950_adpcm_wav = 16'sd0;
    assign y8950_int_n = 1'b1;
`endif

    // ===== DDR3 wave memory (_86): bring-up + puerto debug 34h-37h =====
    // 34h=addr[7:0] 35h=addr[15:8] 36h=addr[21:16] (write dispara prefetch)
    // 37h: OUT=escribir byte (autoinc al completar) / IN=byte prefetchado
    //      (y dispara prefetch de addr+1 — patron readData del ADPCM)
    // IN 36h = status {6'b0, busy, ready}
    wire        wdbg_rd34_w;             // _95: IN 34h = diag DDR3
    wire        wdbg_rd35_w;             // _95: IN 35h = diag motor
    wire        wdbg_rd36_w;
    wire        wdbg_rd37_w;
    wire [7:0]  wdbg_status;
    wire [7:0]  wdbg_rdata;
    wire [7:0]  wdbg_diag_ddr3;          // {calib_drop, wd_fires[2:0], wd_ops[3:0]}
    wire [7:0]  wdbg_diag_eng;           // {ifw_hits[3:0], alive[3:0]}
    // _95: los weng_* van declarados AQUI, ANTES de la instancia que los usa
    // (Gowin declara implicitos de 1 bit si no — leccion EX3638).
    wire        weng_req, weng_we, weng_done;
    wire [21:0] weng_addr;
    wire [7:0]  weng_wdata, weng_rdata;
    wire [15:0] weng_rword;              // _104: palabra (cache de palabra)
    // _104: reloj del motor = clk_wave375 (37.5MHz, CLKOUT4 del PLLA — misma
    // familia/VCO que 54/108: paths sincronos cronometrados, cero CDC).
    // Margen del CE: 37.5/33.8688 = 10.7% (a 36MHz el credito crecia sin
    // freno en la sim de 7 slots: los stalls superaban el 6.3% de margen).
`ifdef ENABLE_WAVE_DDR3
    // _103: BUS REGISTRADO (regla de oro _91) — este decoder era de la _86,
    // ANTERIOR a la regla, y decodificaba el bus CRUDO del T80 (flanco de
    // bajada): la cadena de prefetch del IN 37h podia ver stbs DOBLES en
    // flancos sucios -> DESLIZAMIENTO de direccion -> el INTEG jamas paso
    // en HW (F2DF estable con TODO lo demas leyendo perfecto) y las sumas
    // 065B/01B9/D187/... eran en parte ESTE artefacto, no (solo) la DDR3.
    reg        wdbgb_iorq_n, wdbgb_rd_n, wdbgb_wr_n, wdbgb_m1_n;
    reg [7:0]  wdbgb_addr, wdbgb_din;
    always @(posedge clk_54m) begin
        wdbgb_iorq_n <= bus_iorq_n;
        wdbgb_rd_n   <= bus_rd_n;
        wdbgb_wr_n   <= bus_wr_n;
        wdbgb_m1_n   <= bus_m1_n;
        wdbgb_addr   <= bus_addr[7:0];
        wdbgb_din    <= cpu_dout;
    end
    wire wdbg_sel    = (wdbgb_iorq_n == 1'b0) && (wdbgb_m1_n == 1'b1) && (wdbgb_addr[7:2] == 6'b001101);
    wire wdbg_wr_any = wdbg_sel && (wdbgb_wr_n == 1'b0);
    wire wdbg_rd_any = wdbg_sel && (wdbgb_rd_n == 1'b0);
    assign wdbg_rd34_w = wdbg_rd_any && (wdbgb_addr[1:0] == 2'b00);
    assign wdbg_rd35_w = wdbg_rd_any && (wdbgb_addr[1:0] == 2'b01);
    assign wdbg_rd36_w = wdbg_rd_any && (wdbgb_addr[1:0] == 2'b10);
    assign wdbg_rd37_w = wdbg_rd_any && (wdbgb_addr[1:0] == 2'b11);

    reg wdbg_wr_d1, wdbg_wr_d2, wdbg_rd37_d1, wdbg_rd37_d2;
    always @(posedge clk_54m) begin
        wdbg_wr_d1   <= wdbg_wr_any;   wdbg_wr_d2   <= wdbg_wr_d1;
        wdbg_rd37_d1 <= wdbg_rd37_w;   wdbg_rd37_d2 <= wdbg_rd37_d1;
    end
    wire wdbg_wr_stb   = wdbg_wr_d1 & ~wdbg_wr_d2;
    // _88: prefetch encadenado en el flanco de BAJADA del IN (RD ya liberado,
    // Z80 ya latcheo). Con el flanco de subida la DDR3 actualizaba rdata ANTES
    // de que el Z80 latchease -> leia siempre 1 byte por delante (DIAG A/B del
    // HW: read(i)=write(i+1)). Las escrituras no tienen esta carrera.
    wire wdbg_rd37_stb = ~wdbg_rd37_d1 & wdbg_rd37_d2;

    reg  [21:0] wdbg_addr;
    reg         wdbg_req, wdbg_we, wdbg_inc_pend, wdbg_busy_d;
    reg  [7:0]  wdbg_wdata;
    wire        wdbg_done, wdbg_ready;
    wire        wdbg_busy = (wdbg_req != wdbg_done);

    // ---- _87: loader YRW801 flash(0x500000, 2MB) -> DDR3 en background ----
    reg         wl_active, wl_done, wl_primed;
    reg  [3:0]  wl_state;      // _100: 4 bits (estados de verificacion)
    reg  [23:0] wl_flash_addr;
    reg  [21:0] wl_count;
    reg         wl_flash_rd, wl_flash_term;
    reg  [21:0] wl_tcnt;       // _90: timeout del cierre; _95: 22 bits — el
                               // bit6 sigue siendo el timeout corto (64c) y
                               // el bit21 es el duro (~39ms) de los estados
    reg  [2:0]  wl_retries;    // _95/_100: intentos copia+verify
    reg         wl_err;        // _95: pegajoso — reintentos agotados
    // _100: VERIFICACION flash-vs-DDR3 — el MAL-FIJO por arranque (sumas
    // 065B/01B9/D187 estables dentro del boot, distintas entre boots) es el
    // OJO de la calibracion DDR3: cada calibracion aterriza distinto y a
    // veces corrompe fijo. Tras copiar, se re-streamea la flash (verdad
    // absoluta) comparando byte a byte contra la DDR3; si hay errores ->
    // recalibracion FORZADA + recopia (hasta 3 intentos). Resultados en la
    // PROPIA DDR3 @0x3FFFF8 (el ROM los imprime): V,intento,verr16,addr24,A5
    reg         wl_verify;     // 0=copiando, 1=verificando
    reg  [15:0] wl_verr;       // errores del verify (saturante)
    reg  [21:0] wl_vfirst;     // direccion del PRIMER error (sentinel=3FFFFF)
    reg  [2:0]  wl_vres_i;     // indice de escritura del bloque de resultados
    reg  [7:0]  wl_fb;         // byte de flash en comparacion
    reg         wl_recal_tgl;  // toggle -> wave_ddr3.recal_req
    // _101: SONDEO RAPIDO — la loteria del ojo dio ~1 bueno de 10 en HW;
    // verificar 2MB por billete (~5s) era demasiado caro. Ahora cada billete
    // se sondea con 64KB (copia+verify ~0.3s) y SOLO con sondeo limpio se
    // hace la copia+verificacion completa. Hasta 24 billetes; recal profunda
    // (PLL incluido) + retardo LFSR entre billetes para decorrelar.
    reg         wl_probe;      // 1=pasada de sondeo (64KB), 0=pasada completa
    reg  [4:0]  wl_att;        // billetes gastados (el acta lo publica)
    // _103: RECAL EN CALIENTE — la calibracion ocurre en t=0, el momento MAS
    // frio que existira jamas; el die sube 20-30C en los primeros 30-60s y
    // el ojo calibrado-en-frio queda desfasado (evidencia HW: fallo identico
    // desde la 1a vuelta y estable tras calentar = ojo rancio estable, no
    // deriva continua). A los 60s de terminar la carga, UNA recalibracion
    // completa con el die ya a temperatura de regimen + recopia + verify.
    reg  [31:0] wl_warm_cnt;
    reg         wl_warm_done;
    reg  [7:0]  wl_lfsr;       // retardo pseudoaleatorio entre billetes
    // _102: LECTURAS FRIAS — la evidencia HW de la _101 (VERIF LIMPIO try=0
    // + INTEG MAL-FIJO en el MISMO arranque, dos veces) demostro que el ojo
    // malo solo corrompe lecturas tras un HUECO de inactividad: el verify
    // leia a ritmo constante (~2us) y aprobaba ojos que el Z80 (pausas) y
    // el motor (rafagas) sufren. Ahora 1 de cada 8 lecturas del verify
    // espera 0-19us antes de disparar: solo aprueban ojos que aguantan
    // lecturas frias — los de los arranques que SONABAN bien.
    reg  [9:0]  wl_gap;        // hueco frio pendiente (ciclos)
    localparam  WL_FLASH_BASE = 24'h500000;
    localparam  WL_LEN        = 22'h200000;   // 2MB
    localparam  WL_PROBE_LEN  = 22'h010000;   // 64KB de sondeo
    localparam  WL_MAX_ATT    = 5'd24;
    localparam  WL_RES_ADDR   = 22'h3FFFF8;   // bloque de resultados en RAM
    // _95: status ampliado — el ROM lo imprime tal cual en el test 3
    assign wdbg_status = {wl_err, wl_retries, wl_done, wl_active, wdbg_busy, wdbg_ready};

    always @(posedge clk_54m or negedge bus_reset_n) begin
        if (!bus_reset_n) begin
            wdbg_addr <= 22'd0; wdbg_req <= 1'b0; wdbg_we <= 1'b0;
            wdbg_wdata <= 8'd0; wdbg_inc_pend <= 1'b0; wdbg_busy_d <= 1'b0;
            wl_active <= 1'b0; wl_done <= 1'b0; wl_primed <= 1'b0;
            wl_state <= 4'd0; wl_flash_addr <= 24'd0; wl_count <= 22'd0;
            wl_flash_rd <= 1'b0; wl_flash_term <= 1'b0; wl_tcnt <= 22'd0;
            wl_retries <= 3'd0; wl_err <= 1'b0;
            wl_verify <= 1'b0; wl_verr <= 16'd0; wl_vfirst <= 22'h3FFFFF;
            wl_vres_i <= 3'd0; wl_fb <= 8'd0; wl_recal_tgl <= 1'b0;
            wl_probe <= 1'b1; wl_att <= 5'd0; wl_lfsr <= 8'hC3;   // _108: semilla nueva = re-tirada de la loteria de placement
            wl_gap <= 10'd0; wl_warm_cnt <= 32'd0;
            wl_warm_done <= 1'b1;   // _104: SDRAM sin calibracion — recal caliente OFF
        end
        else begin
            wdbg_busy_d <= wdbg_busy;
            // autoinc diferido de las ESCRITURAS: al completar el handshake
            // (la direccion debe quedarse quieta mientras la op esta en vuelo)
            if (wdbg_busy_d && !wdbg_busy && wdbg_inc_pend) begin
                wdbg_addr <= wdbg_addr + 22'd1;
                wdbg_inc_pend <= 1'b0;
            end

`ifdef ENABLE_WAVE_LOADER
            // ---- loader en background: protocolo byte a byte del flash
            //      (calcado del stream del pack) + puerto wave reutilizado ----
            // _101: LFSR libre — fase impredecible al muestrearlo en el
            // retardo entre billetes (x^8+x^6+x^5+x^4, maximal)
            wl_lfsr <= {wl_lfsr[6:0], wl_lfsr[7]^wl_lfsr[5]^wl_lfsr[4]^wl_lfsr[3]};
            case (wl_state)
            4'd0:   // esperar: pack streameado + DDR3 calibrada
                if (flash_idle && wdbg_ready && !wl_done) begin
                    wl_active <= 1'b1;
                    wl_flash_addr <= WL_FLASH_BASE;
                    wl_probe <= 1'b1;                  // _101: sondeo primero
                    wl_count <= WL_PROBE_LEN;
                    wl_primed <= 1'b0;
                    wl_tcnt <= 22'd0;
                    wdbg_addr <= 22'd0;
                    wl_state <= 4'd4;
                end
            3'd4: begin // _90: CERRAR el stream rancio del pack ANTES de leer.
                // El FSM del pack pone su terminate en el MISMO ciclo en que
                // wl_active le roba el mux: el terminate se perdia, el stream
                // del pack quedaba ABIERTO y nuestras lecturas continuaban en
                // 0x480006 (zona borrada = FF) en vez de abrir en 0x500000.
                // La YRW801 acababa copiada desplazada +0x7FFFA. Bug desde la
                // _87, enmascarado porque la zona siempre habia estado vacia.
                //
                // _95: cierre INCONDICIONAL — term alto 256 ciclos seguidos
                // (mas que cualquier byte SPI en vuelo, ~35c) y SIN interpretar
                // busy. La version _90-_94 tomaba "busy=1" como "se esta
                // cerrando", pero busy tambien es 1 en mitad de un byte: en
                // esa carrera soltaba el term, el stream quedaba ABIERTO y la
                // copia salia de la direccion equivocada (= FF si era la cola
                // del pack). El flash atiende terminate solo en WAIT_NEXT
                // (entre bytes) y lo ignora cerrado: sujetarlo 256c cubre
                // abierto-parado, en-mitad-de-byte y ya-cerrado por igual.
                wl_flash_term <= 1'b1;
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[8]) begin
                    wl_flash_term <= 1'b0;
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd5;
                end
            end
            4'd5: begin // esperar el reposo del flash (LOAD_CMD: busy=0, CS alto)
                wl_tcnt <= wl_tcnt + 22'd1;
                if (!flash_busy) begin
                    wl_tcnt <= 22'd0;
                    wl_state <= wl_verify ? 4'd9 : 4'd1;  // _100: 2a pasada = verify
                end
                else if (wl_tcnt[21]) begin    // _95: cierre que no acaba (~39ms)
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd6;
                end
            end
            4'd1: begin // bucle: capturar byte y escribirlo en DDR3
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21]) begin         // _95: ~39ms sin aceptar un byte
                    wl_tcnt <= 22'd0;          // — sea lo que sea, reintentar
                    wl_state <= 4'd6;          // la copia entera desde cero
                end
                else if (flash_busy == 1'b0) begin
                    if (~wl_flash_rd) begin
                        if (!flash_write_busy && !wdbg_busy) begin
                            if (wl_primed) begin
                                wdbg_wdata <= flash_dout;   // byte de la lectura previa
                                wdbg_we <= 1'b1;
                                wdbg_req <= ~wdbg_req;
                                wdbg_inc_pend <= 1'b1;      // autoinc al completar
                            end
                            if (wl_count == 22'd0) begin
                                wl_tcnt <= 22'd0;
                                wl_state <= 4'd2;
                            end
                            else begin
                                // _90: NO incrementar antes de la 1a lectura — la
                                // flash latchea addr con el PRIMER rd (off-by-one:
                                // el stream abria en BASE+1)
                                if (wl_primed) wl_flash_addr <= wl_flash_addr + 24'd1;
                                wl_count <= wl_count - 22'd1;
                                wl_flash_rd <= 1'b1;
                                wl_primed <= 1'b1;
                                wl_tcnt <= 22'd0;           // _95: hay progreso
                            end
                        end
                    end
                end
                else wl_flash_rd <= 1'b0;
            end
            4'd2: begin // cerrar el stream del flash
                wl_flash_term <= 1'b1;
                wl_tcnt <= wl_tcnt + 22'd1;
                // _95: el timeout garantiza avanzar SIEMPRE — el reset del
                // motor (opl4pcm_rst_n) depende de wl_done
                if (!wdbg_busy || wl_tcnt[21]) begin
                    wl_flash_term <= 1'b0;
                    wl_tcnt <= 22'd0;
                    if (!wl_verify) begin
                        // _100: copia hecha -> pasada de VERIFICACION
                        wl_verify <= 1'b1;
                        wl_flash_addr <= WL_FLASH_BASE;
                        wl_count <= wl_probe ? WL_PROBE_LEN : WL_LEN;
                        wl_primed <= 1'b0;
                        wdbg_addr <= 22'd0;
                        wl_verr <= 16'd0;
                        wl_vfirst <= 22'h3FFFFF;
                        wl_state <= 4'd4;      // cerrar + reabrir en BASE
                    end
                    else wl_state <= 4'd12;    // verify cerrado -> decidir
                end
            end
            // ---- _100: VERIFY — flash (verdad) vs DDR3 (copia), byte a byte
            4'd9: begin // pedir el siguiente byte de flash (o terminar)
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21]) begin wl_tcnt <= 22'd0; wl_state <= 4'd6; end
                else if (!flash_busy && !wl_flash_rd && !flash_write_busy) begin
                    if (wl_count == 22'd0) begin
                        wdbg_addr <= WL_RES_ADDR;   // resultados a la RAM alta
                        wl_vres_i <= 3'd0;
                        wl_tcnt <= 22'd0;
                        wl_state <= 4'd11;
                    end
                    else begin
                        if (wl_primed) wl_flash_addr <= wl_flash_addr + 24'd1;
                        wl_count <= wl_count - 22'd1;
                        wl_flash_rd <= 1'b1;
                        wl_primed <= 1'b1;
                        wl_tcnt <= 22'd0;
                        wl_state <= 4'd13;
                    end
                end
            end
            4'd13: begin // esperar el byte de flash -> lanzar lectura DDR3
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21]) begin wl_tcnt <= 22'd0; wl_state <= 4'd6; end
                else if (flash_busy) wl_flash_rd <= 1'b0;
                else if (!wl_flash_rd) begin
                    wl_fb <= flash_dout;
                    if (wl_lfsr[2:0] == 3'b000) begin
                        // _102: lectura FRIA — hueco 0-19us antes de leer
                        wl_gap <= {wl_lfsr[7:2], 4'd0};
                        wl_tcnt <= 22'd0;
                        wl_state <= 4'd8;
                    end
                    else begin
                        wdbg_we <= 1'b0;
                        wdbg_req <= ~wdbg_req;  // lectura DDR3 en wdbg_addr
                        wl_tcnt <= 22'd0;
                        wl_state <= 4'd10;
                    end
                end
            end
            4'd8: begin // _102: hueco frio y despues la lectura
                if (wl_gap == 10'd0) begin
                    wdbg_we <= 1'b0;
                    wdbg_req <= ~wdbg_req;
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd10;
                end
                else wl_gap <= wl_gap - 10'd1;
            end
            4'd10: begin // esperar DDR3 y comparar
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21]) begin wl_tcnt <= 22'd0; wl_state <= 4'd6; end
                else if (!wdbg_busy) begin
                    if (wdbg_rdata != wl_fb) begin
                        if (wl_verr != 16'hFFFF) wl_verr <= wl_verr + 16'd1;
                        if (wl_vfirst == 22'h3FFFFF) wl_vfirst <= wdbg_addr;
                    end
                    wdbg_addr <= wdbg_addr + 22'd1;
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd9;
                end
            end
            4'd11: begin // volcar el bloque de resultados a DDR3 @3FFFF8
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21]) begin wl_tcnt <= 22'd0; wl_state <= 4'd12; end
                else if (!wdbg_busy) begin
                    wdbg_we <= 1'b1;
                    wdbg_wdata <= (wl_vres_i == 3'd0) ? 8'h56 :             // 'V'
                                  (wl_vres_i == 3'd1) ? {3'd0, wl_att} :    // billetes
                                  (wl_vres_i == 3'd2) ? wl_verr[7:0] :
                                  (wl_vres_i == 3'd3) ? wl_verr[15:8] :
                                  (wl_vres_i == 3'd4) ? wl_vfirst[7:0] :
                                  (wl_vres_i == 3'd5) ? wl_vfirst[15:8] :
                                  (wl_vres_i == 3'd6) ? {2'd0, wl_vfirst[21:16]} :
                                                        8'hA5;              // fin
                    wdbg_req <= ~wdbg_req;
                    wdbg_inc_pend <= 1'b1;
                    wl_tcnt <= 22'd0;
                    if (wl_vres_i == 3'd7) wl_state <= 4'd2;  // cerrar stream
                    else wl_vres_i <= wl_vres_i + 3'd1;
                end
            end
            4'd12: begin // decidir: limpio, mas billetes, o rendirse
                if (wl_verr == 16'd0) begin
                    if (wl_probe) begin
                        // _101: sondeo limpio -> ahora la copia COMPLETA
                        wl_probe <= 1'b0;
                        wl_verify <= 1'b0;
                        wl_flash_addr <= WL_FLASH_BASE;
                        wl_count <= WL_LEN;
                        wl_primed <= 1'b0;
                        wdbg_addr <= 22'd0;
                        wl_tcnt <= 22'd0;
                        wl_state <= 4'd4;
                    end
                    else begin                 // completa verificada: LIMPIO
                        wl_done   <= 1'b1;
                        wl_active <= 1'b0;
                        wl_state  <= 4'd3;
                    end
                end
                else if (wl_att >= WL_MAX_ATT) begin
                    wl_err    <= 1'b1;         // billetes agotados: sonara
                    wl_done   <= 1'b1;         // como pueda, y el acta lo dice
                    wl_active <= 1'b0;
                    wl_state  <= 4'd3;
                end
                else begin
                    // _100/_101: ojo malo — recal PROFUNDA y otro billete
                    wl_recal_tgl <= ~wl_recal_tgl;
                    wl_att <= wl_att + 5'd1;
                    if (wl_retries != 3'd7) wl_retries <= wl_retries + 3'd1;
                    wl_verify <= 1'b0;
                    wl_probe <= 1'b1;          // el fallo full tambien resondea
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd14;
                end
            end
            4'd14: begin // esperar a que la calibracion CAIGA (PLL+IP en reset)
                wl_tcnt <= wl_tcnt + 22'd1;
                if (!wdbg_ready) begin wl_tcnt <= 22'd0; wl_state <= 4'd15; end
                else if (wl_tcnt[21]) begin    // el pulso no llego: reintenta
                    wl_tcnt <= 22'd0; wl_state <= 4'd15;
                end
            end
            4'd15:  // esperar la calibracion NUEVA (el watchdog insiste solo)
                if (wdbg_ready) begin
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd7;          // _101: retardo decorrelador
                end
            4'd7: begin // _101: retardo LFSR (0.3-4.8ms) antes del sondeo
                wl_tcnt <= wl_tcnt + 22'd1;
                if (wl_tcnt[21:14] >= wl_lfsr) begin
                    wl_flash_addr <= WL_FLASH_BASE;
                    wl_count <= WL_PROBE_LEN;
                    wl_primed <= 1'b0;
                    wdbg_addr <= 22'd0;
                    wl_tcnt <= 22'd0;
                    wl_state <= 4'd4;
                end
            end
            4'd3:   // aparcado — _103: timer de RECAL EN CALIENTE (una vez)
                if (!wl_warm_done) begin
                    wl_warm_cnt <= wl_warm_cnt + 32'd1;
                    if (wl_warm_cnt == 32'd3239760000) begin   // 60s a 54MHz
                        wl_warm_done <= 1'b1;
                        wl_recal_tgl <= ~wl_recal_tgl;
                        wl_err    <= 1'b0;
                        wl_done   <= 1'b0;   // motor mudo durante el redo
                        wl_active <= 1'b1;
                        wl_probe  <= 1'b1;
                        wl_verify <= 1'b0;
                        wl_tcnt   <= 22'd0;
                        wl_state  <= 4'd14;
                    end
                end
            4'd6: begin // _95: REINTENTO — cerrar todo y copiar de cero
                wl_flash_term <= 1'b0;
                wl_flash_rd   <= 1'b0;
                wl_verify     <= 1'b0;         // _100: si venia del verify
                if (!wdbg_busy) begin          // (acotado: el watchdog de op
                    wdbg_inc_pend <= 1'b0;     //  de wave_ddr3 lo garantiza)
                    if (wl_retries == 3'd7) begin
                        wl_err    <= 1'b1;     // agotado: rendirse PERO soltar
                        wl_done   <= 1'b1;     // el motor igualmente
                        wl_active <= 1'b0;
                        wl_state  <= 4'd3;
                    end
                    else begin
                        wl_retries <= wl_retries + 3'd1;
                        wl_flash_addr <= WL_FLASH_BASE;
                        wl_count   <= wl_probe ? WL_PROBE_LEN : WL_LEN;
                        wl_primed  <= 1'b0;
                        wdbg_addr  <= 22'd0;
                        wl_tcnt    <= 22'd0;
                        wl_state   <= 4'd4;
                    end
                end
            end
            default: ;
            endcase
`endif

            if (wdbg_wr_stb && !wl_active) begin
                case (wdbgb_addr[1:0])               // _103: bus registrado
                2'b00: wdbg_addr[7:0]   <= wdbgb_din;
                2'b01: wdbg_addr[15:8]  <= wdbgb_din;
                2'b10: begin
                    wdbg_addr[21:16] <= wdbgb_din[5:0];
`ifdef ENABLE_WAVE_LOADER
                    // _103: OUT 36h con bit7 = RECALIBRAR EN CALIENTE a
                    // demanda (recal profunda + recopia + verify; el motor
                    // queda mudo durante el redo). Para el experimento del
                    // ojo-frio-vs-caliente sin esperar el timer.
                    if (wdbgb_din[7] && wl_done) begin
                        wl_recal_tgl <= ~wl_recal_tgl;
                        wl_err    <= 1'b0;
                        wl_done   <= 1'b0;
                        wl_active <= 1'b1;
                        wl_probe  <= 1'b1;
                        wl_verify <= 1'b0;
                        wl_tcnt   <= 22'd0;
                        wl_state  <= 4'd14;
                    end
`endif
                    if (!wdbg_busy) begin            // prefetch de la nueva dir
                        wdbg_we <= 1'b0;
                        wdbg_req <= ~wdbg_req;
                    end
                end
                2'b11: if (!wdbg_busy) begin         // escribir byte
                    wdbg_we <= 1'b1;
                    wdbg_wdata <= wdbgb_din;
                    wdbg_req <= ~wdbg_req;
                    wdbg_inc_pend <= 1'b1;
                end
                endcase
            end
            else if (wdbg_rd37_stb && !wdbg_busy && !wl_active) begin
                // devolvio el byte prefetchado: encadenar prefetch de addr+1
                wdbg_addr <= wdbg_addr + 22'd1;
                wdbg_we <= 1'b0;
                wdbg_req <= ~wdbg_req;
            end
        end
    end

    // _104: la wave vive en la SDRAM del dock (la DDR3 del SOM resulto
    // analogicamente marginal en esta placa — saga _94-_103). El shim
    // conserva la interfaz del wave_ddr3: el loader wl, el verify y el
    // puerto debug 34-37h funcionan SIN CAMBIOS.
    wave_sdram uwsdram (
        .clk_host   (clk_54m),
        .rst_n      (bus_reset_n),
        .req_toggle (wdbg_req),
        .we         (wdbg_we),
        .addr       (wdbg_addr),
        .wdata      (wdbg_wdata),
        .rdata      (wdbg_rdata),
        .done_toggle(wdbg_done),
        .ready      (wdbg_ready),
        .clk_eng    (clk_wave375),
        .eng_req    (weng_req),
        .eng_we     (weng_we),
        .eng_addr   (weng_addr),
        .eng_wdata  (weng_wdata),
        .eng_rdata  (weng_rdata),
        .eng_rword  (weng_rword),
        .eng_done_t (weng_done),
        .diag       (wdbg_diag_ddr3),
        .clk_108m   (clk_108m),
        .wv_req     (wv_req),
        .wv_we      (wv_we),
        .wv_addr    (wv_addr),
        .wv_wdata   (wv_wdata),
        .wv_dout    (wv_dout),
        .wv_done    (wv_done)
    );

`ifndef ENABLE_VRAM_DDR3
    // pines DDR3 del SOM en reposo seguro (la IP y su PLL fuera del build;
    // con _128X los conduce u_vddr3 — la VRAM del V9968 vive alli)
    assign ddr_addr = 15'd0;  assign ddr_bank = 3'd0;
    assign ddr_cs = 1'b1;     assign ddr_ras = 1'b1;
    assign ddr_cas = 1'b1;    assign ddr_we = 1'b1;
    assign ddr_ck = 1'b0;     assign ddr_ck_n = 1'b1;
    assign ddr_cke = 1'b0;    assign ddr_odt = 1'b0;
    assign ddr_reset_n = 1'b0; assign ddr_dm = 2'b11;
    assign ddr_dq = 16'hzzzz; assign ddr_dqs = 2'bzz; assign ddr_dqs_n = 2'bzz;
`endif
`else
    assign wdbg_rd34_w = 1'b0;
    assign wdbg_rd35_w = 1'b0;
    assign wdbg_rd36_w = 1'b0;
    assign wdbg_rd37_w = 1'b0;
    assign wdbg_status = 8'hFF;
    assign wdbg_rdata  = 8'hFF;
    assign wdbg_diag_ddr3 = 8'hFF;
`ifndef ENABLE_VRAM_DDR3
    // DDR3 en reposo seguro (con _128X los pines los conduce u_vddr3)
    assign ddr_addr = 15'd0;  assign ddr_bank = 3'd0;
    assign ddr_cs = 1'b1;     assign ddr_ras = 1'b1;
    assign ddr_cas = 1'b1;    assign ddr_we = 1'b1;
    assign ddr_ck = 1'b0;     assign ddr_ck_n = 1'b1;
    assign ddr_cke = 1'b0;    assign ddr_odt = 1'b0;
    assign ddr_reset_n = 1'b0; assign ddr_dm = 2'b11;
    assign ddr_dq = 16'hzzzz; assign ddr_dqs = 2'bzz; assign ddr_dqs_n = 2'bzz;
`endif
`endif

    // ===== MoonSound FM (_82): OPL3 en C4-C7 + stub wave 7E/7F =====
    wire        opl4fm_rd_w;
    wire        opl4wave_rd_w;
    wire [7:0]  opl4fm_dout;
    wire [7:0]  opl4wave_dout;
    wire signed [15:0] opl4fm_wav;
`ifdef ENABLE_OPL4FM
    opl4fm uopl4fm (
        .rst_n     (bus_reset_n),
        .clk_host  (clk_54m),
        .clk_opl3  (clk_27m),      // _84: reloj hermano (ver nota arriba)
        .iorq_n    (bus_iorq_n),
        .rd_n      (bus_rd_n),
        .wr_n      (bus_wr_n),
        .m1_n      (bus_m1_n),
        .addr      (bus_addr[7:0]),
        .din       (cpu_dout),
        .wave_status (opl4wave_status),  // _89: {LD,BUSY} del motor en C4/C6
        .fm_rd     (opl4fm_rd_w),
        .wave_rd   (opl4wave_rd_w),
        .dout      (opl4fm_dout),
        .wave_dout (opl4wave_dout),
        .pcm_out   (opl4fm_wav),
        .int_n     (opl4_int_n)
    );
`else
    assign opl4fm_rd_w   = 1'b0;
    assign opl4wave_rd_w = 1'b0;
    assign opl4_int_n    = 1'b1;   // _108: sin OPL4, sin IRQ
    assign opl4fm_dout   = 8'hFF;
    assign opl4wave_dout = 8'hFF;
    assign opl4fm_wav    = 16'sd0;
`endif

    // ===== MoonSound WAVE (_89): motor PCM 24 slots (srg320) en clk_x1 =====
    // El motor vive en el dominio clk_x1 de la propia DDR3 (74.25MHz) con CE
    // fraccionario 33.8688MHz medio -> 44.1kHz exactos; el fetch de onda va
    // directo al puerto eng_* de wave_ddr3 SIN CDC. Arranca en reset hasta
    // que la DDR3 calibra Y el loader ha copiado la YRW801.
    wire        opl4pcm_rd_w;
    wire [7:0]  opl4pcm_dout;
    wire [1:0]  opl4wave_status;
    wire signed [15:0] opl4pcm_l, opl4pcm_r;
    wire [5:0]  opl4_mixfm;    // _110: reg F8 del motor (via opl4_pcm)
    wire        opl4_dbg_tx;   // _111: telemetria UART (E22)
    // (_104: los weng_* estan declarados arriba, junto al bloque wdbg;
    //  el reloj del motor es clk_wave375 = CLKOUT4 del PLLA)
`ifdef ENABLE_OPL4_WAVE
    wire opl4pcm_rst_n = bus_reset_n & wdbg_ready & wl_done;

    opl4_pcm uopl4pcm (
        .rst_n       (bus_reset_n),
        .clk_host    (clk_54m),
        .iorq_n      (bus_iorq_n),
        .rd_n        (bus_rd_n),
        .wr_n        (bus_wr_n),
        .m1_n        (bus_m1_n),
        .addr        (bus_addr[7:0]),
        .din         (cpu_dout),
        .wave_rd     (opl4pcm_rd_w),
        .wave_dout   (opl4pcm_dout),
        .wave_wait_n (opl4pcm_wait_n),
        .wave_status (opl4wave_status),
        .mix_fm      (opl4_mixfm),
        .dbg_tx      (opl4_dbg_tx),
        .pcm_l       (opl4pcm_l),
        .pcm_r       (opl4pcm_r),
        .clk_eng     (clk_wave375),   // _104: 37.5MHz del PLLA (CLKOUT4)
        .eng_rst_n   (opl4pcm_rst_n),
        .mem_req     (weng_req),
        .mem_we      (weng_we),
        .mem_addr    (weng_addr),
        .mem_wdata   (weng_wdata),
        .mem_rdata   (weng_rdata),
        .mem_rword   (weng_rword),    // _104: palabra (cache de palabra)
        .mem_done_t  (weng_done),
        .diag        (wdbg_diag_eng),
        // _114diag: estado del video a la telemetria (COM11). {pll27_lock,
        // frame_cnt[2:0]} del modo activo; opl4_pcm lo cruza a clk_eng.
        .vid_diag    ({pll27_lock, dbg_video_w[0] ? dbg_fdiv_pal[2:0]
                                                  : dbg_fdiv_ntsc[2:0]})
    );
`else
    assign opl4pcm_rd_w   = 1'b0;
    assign opl4pcm_dout   = 8'hFF;
    assign opl4pcm_wait_n = 1'b1;
    assign opl4wave_status = 2'b00;
    assign opl4pcm_l = 16'sd0;
    assign opl4_mixfm = 6'd0;   // _110: sin motor, FM a 0dB
    assign opl4_dbg_tx = 1'b1;  // _111: sin motor, linea en reposo
    assign opl4pcm_r = 16'sd0;
    assign weng_req = 1'b0;  assign weng_we = 1'b0;
    assign weng_addr = 22'd0; assign weng_wdata = 8'd0;
    assign wdbg_diag_eng = 8'hFF;
`endif

    //scc & ghost scc
    wire [14:0] scc_wav;
    wire [7:0] scc_dout;
    wire scc_req;
    wire scc_req3_r;
    wire scc_wrt;
    wire x98h;
    wire xb8h;
    wire scc_rd_r;

    // SCC-I mode signals (from megaram1, declared here as they gate the sound window)
    wire scc_mode_plus;     // BFFE bit5: 1 = SCC+ layout active
    wire sccplus_win_en;    // SCC+ window enabled (mode bit5 + bank3 bit7)

    // Glue de ventana/banco/strobes EXTRAIDO VERBATIM a src/scc_glue.v (fix
    // SCC): mismo fichero compartido con tools/scc_tb, semantica identica al
    // bloque inline v2.6 que habia aqui (solo los terminos de config/slot
    // pasan como entradas). Siempre instanciado, como antes (con ENABLE_SCC
    // off el chip queda fuera pero la ventana sigue respondiendo FF).
    // v3.2 FIX REGRESION _40: los gates se DECLARAN aqui (antes del uso) y se
    // ASIGNAN tras el bloque de config (linea ~2420), donde todas sus señales
    // ya estan declaradas. En la _40 las expresiones iban directamente en los
    // puertos ANTES de las declaraciones y Gowin creaba config_megaram_slot
    // IMPLICITO DE 1 BIT (el real es [1:0]) -> comparacion de slot TRUNCADA ->
    // el SCC respondia en slots equivocados (distorsion al bootear la BIOS,
    // lecturas de CPU secuestradas) y callaba en el suyo (mudo). EX3638 en el
    // log fue el delator; solo es benigno con señales de 1 bit.
    wire scc_gate_bank2_wr3;
    wire scc_gate_bank2_wr12;
    wire scc_gate_req3;
    wire scc_gate_req12;
    wire scc_snd_dis_w;
    wire dbg_scc_enable_w;   // panel _42dbg (declarado ANTES del uso — leccion EX3638)
    wire scc_dbg_vol_nz, scc_dbg_sel_nz, scc_dbg_freq_nz;   // _46dbg (idem)
    wire scc_dbg_ptr_lsb, scc_dbg_scan_lsb, scc_dbg_mix_nz;  // _51dbg (idem)
    wire scc_dbg_wavlatch, scc_dbg_capnz, scc_dbg_wave_nz;   // _52/_53dbg (idem)
    wire scc_dbg_mix5_nz;                                    // _54dbg (idem)
    scc_glue sccglue1 (
        .clk (clk_54m),             // v2.6: glue SCC a 54M (bus mismo dominio)
        .reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_mreq_n (bus_mreq_n),
        .bus_wr_n (bus_wr_n),
        .bus_rd_n (bus_rd_n),
        .gate_bank2_wr3 (scc_gate_bank2_wr3),
        .gate_bank2_wr12 (scc_gate_bank2_wr12),
        .gate_req3 (scc_gate_req3),
        .gate_req12 (scc_gate_req12),
        .scc_mode_plus (scc_mode_plus),
        .sccplus_win_en (sccplus_win_en),
        .scc_sound_disable (scc_snd_dis_w),
        .scc_req (scc_req),
        .scc_wrt (scc_wrt),
        .scc_req3_r (scc_req3_r),
        .scc_rd_r (scc_rd_r),
        .x98h (x98h),
        .xb8h (xb8h),
        .dbg_scc_enable (dbg_scc_enable_w)
    );

`ifdef ENABLE_SCC
    // v3.3 (_43): VUELTA al chip VHDL probado del TN20K con el multiplicador
    // inline (fix del sweep DENTRO de scc_wave2.vhd). El scc_wave2v traducido
    // pasaba la sim pero NO sintetiza sonido en placa (panel _42dbg: LED4
    // apagado = chip sin oscilar, clase sim!=sintesis); queda como referencia
    // y para el TB.
    // (beeper de diagnostico _45-_54 ELIMINADO en la _55 final — historia en git;
    //  fue la herramienta que, con el panel de LEDs, acorralo el bug del silicio)
    scc_wave2 SccCh (
        .clk21m (clk_27m),          // v3.4 (_44): config EXACTA del TN20K (27M+cen27),
        .reset (~bus_reset_n),      //  segura desde v3.0 (27 EN FASE con 54, ya sin CLKDIV
        .clkena (clk_enable_3m6_27),// _50dbg: cen ORIGINAL con el PINFILTER ya sin z (fix de raiz)
        .req ( scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav),
        .sccplus (scc_mode_plus),
        .dbg_vol_nz (scc_dbg_vol_nz),
        .dbg_sel_nz (scc_dbg_sel_nz),
        .dbg_freq_nz (scc_dbg_freq_nz),
        .dbg_ptr_lsb (scc_dbg_ptr_lsb),
        .dbg_scan_lsb (scc_dbg_scan_lsb),
        .dbg_mix_nz (scc_dbg_mix_nz),
        .dbg_wavlatch (scc_dbg_wavlatch),
        .dbg_capnz (scc_dbg_capnz),
        .dbg_wave_nz (scc_dbg_wave_nz),
        .dbg_mix5_nz (scc_dbg_mix5_nz)
    );
`else
    assign scc_wav  = 15'd0;        // BASE MINIMA v3.0: SCC fuera (aparcado)
    assign scc_dout = 8'hFF;
`endif

    reg scc2_req3;
    reg scc2_req12;
    wire scc2_req;
    wire scc2_req_r;
    wire scc2_wrt;
    wire [7:0] scc2_dout;
    wire [14:0] scc2_wav;
    wire megaram_req;
    wire megaram_wrt;
    wire [20:0] megaram_addr;
    wire megaram_enabled;

    always @ (posedge clk_54m) begin
        // NOTE: config1_ff[2] ("ghost SCC", vestigial in standalone) is repurposed below
        // as the SECOND SCC+ enable; it no longer gates the megaram banking path.
        scc2_req3 <= ( config_enable_megaram3 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot && exp_slotx_num[3] == 1  && xffff == 0) ? 1 : 0;
        scc2_req12 <= ( config_enable_megaram12 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot ) ? 1 : 0;
        //scc2_req <= ( bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot_num[2] == 1 ) ? 1 : 0;
    end
    assign scc2_req = scc2_req3 | scc2_req12;
    assign scc2_req_r = ( scc2_req == 1 && bus_rd_n == 0 ) ? 1 : 0;
    assign scc2_wrt = ( scc2_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    wire [1:0] map_sel;
    wire map_linear;
    wire scc_sound_disable;
    assign map_sel = Slot2Mode;
    assign map_linear = iSlt2_linear;

    megaram_scc megaram1 (
        .clk_27m (clk_54m),
        .bus_reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_rd_n (bus_rd_n),
        .bus_wr_n (bus_wr_n),
        .scc_req (scc2_req),
        .scc_wrt (scc2_wrt),
        .map_sel (map_sel),
        .map_linear (map_linear),
        .sram_cfg (config3_ff),

        .megaram_req (megaram_req),
        .megaram_wrt (megaram_wrt),
        .megaram_addr (megaram_addr),
        .scc_sound_disable (scc_sound_disable),
        .scc_mode_plus (scc_mode_plus),
        .sccplus_win_en (sccplus_win_en)
    );


    // ===== Second SCC+ ("sound-only SCC-I cartridge" in the other free slot) =====
    // Enabled by config1_ff[2] (former "ghost SCC" bit, repurposed; menu toggle).
    // Lives in slot 1 if the megaram is in slot 2 and vice versa, so trackers that
    // drive two SCC carts in two slots find both. Own bank2/bank3/mode regs (SCC-I),
    // wave-RAM read-back included; no memory behind it (reads elsewhere return FF).
    wire [1:0] scc2x_slot;
    assign scc2x_slot = ( config_megaram_slot == 2'b01 ) ? 2'b10 : 2'b01;

    reg [7:0] scc2x_bank2;
    reg [7:0] scc2x_bank3;
    reg [7:0] scc2x_modeb;
    wire scc2x_slot_hit;
    assign scc2x_slot_hit = ( config_enable_ghost_scc == 1 && pri_slot == scc2x_slot ) ? 1 : 0;

    always @ (posedge clk_54m or negedge bus_reset_n) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        if (bus_reset_n == 0) begin
            scc2x_bank2 <= 8'h00;
            scc2x_bank3 <= 8'h00;
            scc2x_modeb <= 8'h00;
        end
        else if ( scc2x_slot_hit == 1 && bus_mreq_n == 0 && bus_wr_n == 0 ) begin
            if ( bus_addr[15:11] == 5'b10010 )
                scc2x_bank2 <= cpu_dout;                                    // 9000-97FF
            if ( bus_addr[15:11] == 5'b10110 && scc2x_modeb[4] == 0 )
                scc2x_bank3 <= cpu_dout;                                    // B000-B7FF
            if ( bus_addr[15:11] == 5'b10111 && bus_addr[10:1] == 10'b1111111111 )
                scc2x_modeb <= cpu_dout;                                    // BFFE-BFFF
        end
    end

    wire scc2x_win;
    assign scc2x_win = ( scc2x_modeb[5] == 0 ) ? ( (scc2x_bank2 == 8'h3f ? 1'b1 : 1'b0) & x98h )
                                               : ( scc2x_bank3[7] & xb8h & ~scc2x_modeb[4] );

    reg scc2x_req;
    always @ (posedge clk_54m) begin   // v2.6: glue SCC a 54M (bus mismo dominio)
        scc2x_req <= ( scc2x_slot_hit == 1 && scc2x_win == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0) ) ? 1 : 0;
    end
    wire scc2x_wrt;
    wire scc2x_rd_r;
    assign scc2x_wrt = ( scc2x_req == 1 && bus_wr_n == 0 ) ? 1 : 0;
    assign scc2x_rd_r = ( scc2x_req == 1 && bus_rd_n == 0 ) ? 1 : 0;

    wire [7:0] scc2x_dout;
    wire [14:0] scc2x_wav;

    // v4.2 (_57): SEGUNDO SCC RESTAURADO (F3.5 de las prioridades del usuario)
    // — se retiro en la _52 para limpiar el tablero durante la caza del bug;
    // vuelve con el chip CURADO (mismo scc_wave2 via GHDL con los fixes _52+
    // _54). Es el SCC-I "ghost": se habilita con config1_ff[2] (SWIO) y vive
    // en el slot OPUESTO a la megaram. En estereo suena por la DERECHA
    // (mixer: L=PSG1+SCC1+OPLL / R=PSG2+SCC2+OPLL). Test: SCCTEST2.ROM.
`ifdef ENABLE_SCC
    scc_wave2 SccCh2 (
        .clk21m (clk_27m),
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_27),
        .req ( scc2x_req),
        .ack (),
        .wrt (scc2x_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc2x_dout),
        .dbo (cpu_dout),
        .wave (scc2x_wav),
        .sccplus (scc2x_modeb[5]),
        .dbg_vol_nz (),
        .dbg_sel_nz (),
        .dbg_freq_nz (),
        .dbg_ptr_lsb (),
        .dbg_scan_lsb (),
        .dbg_mix_nz (),
        .dbg_wavlatch (),
        .dbg_capnz (),
        .dbg_wave_nz (),
        .dbg_mix5_nz ()
    );
`else
    assign scc2x_wav  = 15'd0;
    assign scc2x_dout = 8'hFF;
`endif

    //mixer (L = PSG1+SCC1+OPLL+Y8950, R = PSG2+SCC2+OPLL+Y8950; mono = everything on both sides)
    // Y8950 (MSX-Audio FM) se suma en ambos canales igual que el OPLL (mono).
	reg [15:0] audio_sample;
	reg [15:0] audio_sample_r;

    // ===== _161 BUG #10 (INFORME_NIQUELADO): los PSG entraban SIN SIGNO =====
    // {1'b0, psgSound3, 6'b0} es 0..+16320: un PEDESTAL DE CONTINUA que se comia
    // la mitad del recorrido positivo del sat16 (y en mono, con los DOS PSG, se
    // lo comia entero) => el mezclador recortaba SOLO el semiciclo positivo.
    // Bloqueador de continua de 1 polo por PSG: dc = acc>>>16; ac = x-dc; acc+=ac
    // A 3,579545 MHz con N=16 la esquina cae en 8,7 Hz (tau 18 ms): es el
    // condensador de acoplo que el hardware real tiene y nosotros no teniamos.
    // Aritmetica CERRADA (leccion _85/_115): $signed explicito y extension de
    // signo escrita a mano; ningun literal sin signo en el camino.
    reg  signed [31:0] psg1_dcacc = 32'sd0;
    reg  signed [31:0] psg2_dcacc = 32'sd0;
    wire signed [16:0] psg1_x  = $signed({2'b00, psgSound3,  6'b000000});   // 0..16320
    wire signed [16:0] psg2_x  = $signed({2'b00, psg2Sound3, 6'b000000});
    wire signed [16:0] psg1_dc = psg1_dcacc[31:16];
    wire signed [16:0] psg2_dc = psg2_dcacc[31:16];
    wire signed [16:0] psg1_ac = psg1_x - psg1_dc;                          // +-16320
    wire signed [16:0] psg2_ac = psg2_x - psg2_dc;
    always @(posedge clk_27m) begin
        if (~bus_reset_n) begin
            psg1_dcacc <= 32'sd0;
            psg2_dcacc <= 32'sd0;
        end
        else if (clk_enable_3m6_27) begin
            psg1_dcacc <= psg1_dcacc + {{15{psg1_ac[16]}}, psg1_ac};
            psg2_dcacc <= psg2_dcacc + {{15{psg2_ac[16]}}, psg2_ac};
        end
    end

    wire [15:0] scc_term;
    assign scc_term = (map_sel == 2'b10) ? { scc_wav, 1'b0 } : 16'd0;  // SCC solo en modo SCC (no Konami4/ASCII)


    // ADPCM-B del Y8950 (_80) y MoonSound FM (_82): mono en ambos canales
    // como el FM del Y8950.
    // _159b: BALANCE CANONICO. El ADPCM-B tiene que picar como UNA portadora
    // FM del propio Y8950. Aritmetica cerrada, cadena por cadena:
    //   MSXimus: decoder +-32767 -> volumen FF (pcm*255>>8) = +-32639
    //            con >>>1 al mixer = +-16320, contra los +-4095 de una
    //            portadora del jtopl_acc (INW=13)  =>  3,99x  =  +12,0 dB
    //   openMSX: pd.out +-32767 -> out*volume>>12 = +-2040, contra el
    //            dB2LinTab maximo de 2048 (getAmplificationFactorImpl=1/2048)
    //            =>  1,00x
    // El divisor canonico es >>>3: 32639/8 = 4080 frente a 4095 = 0,99x.
    // Escrito como CONCATENACION con extension de signo EXPLICITA, no como
    // >>>: la leccion _85/_115 (un literal unsigned envenena la signedness de
    // la expresion y el >>> degenera en shift logico) ya costo una build.
    // Si en placa suena demasiado apagado, el intermedio honesto es >>>2
    // ({{2{...[15]}}, ...[15:2]}, -6 dB): quita el 75% del exceso y deja el
    // ADPCM a 2x la portadora.
    wire [15:0] y8950_adpcm_term = {{3{y8950_adpcm_wav[15]}}, y8950_adpcm_wav[15:3]};
    // _83: OPL3 ya sale a nivel nativo (como jt2413_wav) — sin >>1
    // _110: atenuacion del reg F8 (MixCalc del motor: >>> 2*codigo). Hasta
    // ahora F8 se ignoraba y el FM entraba siempre a 0dB aunque el software
    // pidiera bajarlo (MBWave/VGMPlay balancean FM vs wave con F8/F9).
    // _114 canon: pasos de -3dB = {1,0.75,0.5,0.375,...,MUTE} (openMSX). El
    // atajo ">>>{code,1'b0}" (-12dB/paso) convertia el reset canon del F8
    // (3/3 = -8.5dB) en /64: el FM quedaba INAUDIBLE con software que nunca
    // escribe F8 (VGMPlay reproduciendo VGMs YMF262/OPL3 puros).
    // _115: ¡LECCION _85 OTRA VEZ! El 16'd0 UNSIGNED del ternario de la _114
    // envenenaba la signedness de la expresion entera -> el >>> degeneraba en
    // shift LOGICO -> negativos rectificados a positivos enormes = el
    // "horrible distorsionado" de los VGM OPL3 (F8=3 => shift 1 roto; juegos
    // con F8=0 => shift 0 inocuo, por eso sonaban bien). Probado en iverilog:
    // -1000 -> +32268 (bug) vs -500 (fix). El shift vive ahora en un wire
    // SIGNED propio (aritmetica autodeterminada); el ternario solo muxea bits.
    wire signed [15:0] o4fm_s    = $signed(opl4fm_wav);
    wire signed [15:0] o4fm_base = opl4_mixfm[0] ? (o4fm_s >>> 1) + (o4fm_s >>> 2)
                                                 : o4fm_s;
    wire signed [15:0] o4fm_att  = o4fm_base >>> opl4_mixfm[2:1];
    wire [15:0] opl4fm_term      = (opl4_mixfm[2:0] == 3'd7) ? 16'd0 : o4fm_att;

    // _161 BALANCE: openMSX pone la portadora del OPLL en 3915 LSB y la del
    // Y8950 en 5249 (medido) => el OPLL vale 0,746 de una portadora de
    // MSX-Audio. En el MSXimus las dos valen 4095 (mismo jtopl_acc, INW=13):
    // el OPLL entraba +2,6 dB de mas. x3/4 = -2,5 dB.
    wire signed [15:0] opll_s    = $signed(jt2413_wav);
    wire        [15:0] opll_term = (opll_s >>> 1) + (opll_s >>> 2);

    // _89: PCM del MoonSound (motor YMF278B). Mono = (L+R)/2 con extension de
    // signo EXPLICITA (leccion _85: las concatenaciones son unsigned) y >>1
    // de margen como el ADPCM; en estereo, L y R nativos a cada canal.
    wire signed [16:0] opl4pcm_sum = {opl4pcm_l[15], opl4pcm_l} + {opl4pcm_r[15], opl4pcm_r};
    wire [15:0] opl4pcm_term   = {opl4pcm_sum[16], opl4pcm_sum[16:2]};       // (L+R)/2 >>1
    wire [15:0] opl4pcm_term_l = {opl4pcm_l[15], opl4pcm_l[15:1]};           // L>>1
    wire [15:0] opl4pcm_term_r = {opl4pcm_r[15], opl4pcm_r[15:1]};           // R>>1

    // _110: MIXER CON SATURACION. La suma iba en 16 bits "sin saturacion"
    // (comentario historico): con VGMPlay/MBWave (20+ slots wave + FM a la
    // vez) el pico desborda y HACE WRAP al signo contrario = zumbido aspero
    // que en notas sostenidas se percibe como "vibracion" + "saturacion de
    // volumen" + "sonido sucio" (sintomas del usuario en la _109). Suma en
    // 19 bits (9 terminos de 16) y clamp simetrico a 16.
    // _161 GANANCIA MAESTRA: sin multiplicador, sumas de desplazamientos. La
    // entrada son los 19 bits de la suma (+-262143); x8 => cabe en 23 con signo.
    function signed [22:0] gmul(input signed [18:0] v);
        reg signed [22:0] x;
        begin
            x = {{4{v[18]}}, v};                   // extension de signo explicita
            case (snd_gain_ff)
                3'd0: gmul = x;                     // x1     0,0 dB
                3'd1: gmul = x + (x >>> 1);         // x1,5  +3,5 dB
                3'd2: gmul = x <<< 1;               // x2    +6,0 dB
                3'd3: gmul = (x <<< 1) + x;         // x3    +9,5 dB
                3'd4: gmul = x <<< 2;               // x4   +12,0 dB
                3'd5: gmul = (x <<< 2) + x;         // x5   +14,0 dB  <- defecto
                3'd6: gmul = (x <<< 2) + (x <<< 1); // x6   +15,6 dB
                3'd7: gmul = x <<< 3;               // x8   +18,1 dB
            endcase
        end
    endfunction

    // _161 LIMITADOR de rodilla suave: unidad por debajo de 0,75 de fondo de
    // escala y pendiente 1/2 por encima (compresion 2:1 del 25% superior), en
    // vez del recorte duro de antes. Simetrico.
    localparam signed [22:0] SND_KNEE = 23'sd24576;
    function [15:0] sat16k(input signed [22:0] v);
        reg               neg;
        reg signed [22:0] a, y;
        begin
            neg = v[22];
            a   = neg ? -v : v;
            y   = (a <= SND_KNEE) ? a : (SND_KNEE + ((a - SND_KNEE) >>> 1));
            if (y > 23'sd32767) y = 23'sd32767;
            sat16k = neg ? (~y[15:0] + 16'd1) : y[15:0];
        end
    endfunction
    // _180 (regresion de la rc7 cazada por Albert, 04/08: "la tabla de ondas
    // suena como con el volumen subido y distorsiona"; la v2.0 pre-_161 suena
    // limpia): la ganancia maestra _161d (x5, +14dB) multiplicaba TAMBIEN al
    // OPL4 — cuando su proposito declarado era subir los chips flojos "a la
    // altura del OPL4/MoonSound". El OPL4 ya estaba en su sitio: x5 lo metia
    // de lleno en la rodilla del limitador (knee 0,75 FS + techo) = mas
    // volumen y distorsion sostenida. FIX: el grupo CLASICO (PSG/SCC/OPLL/
    // Y8950/ADPCM) pasa por gmul; el OPL4 (FM + wave) entra x1 DESPUES de la
    // ganancia. El mando del puerto #44 vuelve a significar lo que Albert
    // ajusto a oido: el volumen de los clasicos RESPECTO al MoonSound.
    wire signed [18:0] mixL_st = {{2{psg1_ac[16]}}, psg1_ac}
        + {{3{scc_term[15]}}, scc_term} + {{3{opll_term[15]}}, opll_term}
        + {{3{y8950_wav[15]}}, y8950_wav} + {{3{y8950_adpcm_term[15]}}, y8950_adpcm_term};
    wire signed [18:0] mixR_st = {{2{psg2_ac[16]}}, psg2_ac}
        + {{3{scc2x_wav[14]}}, scc2x_wav, 1'b0} + {{3{opll_term[15]}}, opll_term}
        + {{3{y8950_wav[15]}}, y8950_wav} + {{3{y8950_adpcm_term[15]}}, y8950_adpcm_term};
    wire signed [18:0] mix_mono = {{2{psg1_ac[16]}}, psg1_ac}
        + {{2{psg2_ac[16]}}, psg2_ac}
        + {{3{scc_term[15]}}, scc_term} + {{3{scc2x_wav[14]}}, scc2x_wav, 1'b0}
        + {{3{opll_term[15]}}, opll_term} + {{3{y8950_wav[15]}}, y8950_wav}
        + {{3{y8950_adpcm_term[15]}}, y8950_adpcm_term};
    // _180: suma propia del OPL4 (FM + wave), fuera de la ganancia maestra
    wire signed [16:0] o4mix_l    = {opl4fm_term[15], opl4fm_term} + {opl4pcm_term_l[15], opl4pcm_term_l};
    wire signed [16:0] o4mix_r    = {opl4fm_term[15], opl4fm_term} + {opl4pcm_term_r[15], opl4pcm_term_r};
    wire signed [16:0] o4mix_mono = {opl4fm_term[15], opl4fm_term} + {opl4pcm_term[15], opl4pcm_term};
    // _127H: TONO DE TEST del bug #14 (440Hz cuadrada -12dB directa al puente,
    // puenteando el mezclador). DESARMADO en release (niquelado B, bug #4 del
    // informe): iba colgado del toggle "Sprite Limit" del menu (config2[3]) y
    // cualquier usuario lo pisaba — y persistia en flash. Para reactivarlo en
    // una build de diagnostico: `define DEBUG_TONE_440 (el discriminador
    // sigue siendo valido: tono limpio con musica cortada -> mezclador;
    // tono cortado tambien -> HDMI/receptor).
`ifdef DEBUG_TONE_440
    reg [14:0] tone_cnt = 15'd0;
    reg        tone_sq  = 1'b0;
    always @ (posedge clk_27m) begin
        if (tone_cnt == 15'd30681) begin      // 27e6/(2*440) - 1
            tone_cnt <= 15'd0;
            tone_sq  <= ~tone_sq;
        end else
            tone_cnt <= tone_cnt + 15'd1;
    end
    wire [15:0] tone_smp = tone_sq ? 16'd4096 : 16'hF000;   // +-4096 (-12dB)
`endif

    // _161b SEGMENTACION (el gate de la _161 dio 30 violaciones de setup, todas
    // en el camino uopl4fm/pcm_out -> audio_sample: el cono mezclador + ganancia
    // + valor absoluto + rodilla + saturacion no cabia en un ciclo de clk_27m).
    // Se parte en dos etapas, la variante que el propio INFORME_GANANCIA_AUDIO
    // dejaba preparada: etapa 1 = seleccion + ganancia (registrada), etapa 2 =
    // limitador. clk_enable_3m6_27 solo se activa 1 de cada ~7,5 ciclos de 27M,
    // asi que la muestra sigue lista MUCHO antes del siguiente pulso: el retardo
    // extra (37 ns) es inaudible y no cambia ni un bit del resultado.
    // _161e TRES etapas (la de dos seguia siendo MARGINAL: la _161b paso con
    // setup 0 pero la _161c, que solo anade telemetria, volvio a violar por
    // -1,66 ns en uopl4fm/pcm_out -> snd_g_r: el cono "arbol sumador de 9
    // terminos de 19 bits + ganancia de 23" gana o pierde segun la tirada de
    // placement = loteria). Ahora: (A) SUMA registrada, (B) ganancia, (C)
    // limitador. B y C corren libres a 27 MHz; como clk_enable_3m6_27 solo
    // pulsa 1 de cada ~7,5 ciclos, la muestra esta lista muchisimo antes del
    // siguiente pulso y el resultado no cambia ni un bit.
    reg signed [18:0] snd_mix_l, snd_mix_r;          // (A) suma (grupo clasico)
    reg signed [16:0] snd_o4_l,  snd_o4_r;           // (A) suma OPL4 (_180: x1)
    reg signed [22:0] snd_g_l,  snd_g_r;             // (B) con ganancia
    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27 == 1 ) begin
`ifdef DEBUG_TONE_440
            if (config_enable_8sprites == 1) begin
                snd_mix_l <= {{3{tone_smp[15]}}, tone_smp};
                snd_mix_r <= {{3{tone_smp[15]}}, tone_smp};
                snd_o4_l  <= 17'sd0;
                snd_o4_r  <= 17'sd0;
            end
            else
`endif
            if (config_enable_stereo == 1) begin
                snd_mix_l <= mixL_st;
                snd_mix_r <= mixR_st;
                snd_o4_l  <= o4mix_l;
                snd_o4_r  <= o4mix_r;
            end
            else begin
                snd_mix_l <= mix_mono;
                snd_mix_r <= mix_mono;
                snd_o4_l  <= o4mix_mono;
                snd_o4_r  <= o4mix_mono;
            end
        end
    end

    always @ (posedge clk_27m) begin
        // _180: gmul solo al grupo clasico; el OPL4 entra x1 (sin tocar).
        // Rango: gmul max +-2097144 + OPL4 +-131068 < 2^22: cabe en 23 bits.
        snd_g_l <= gmul(snd_mix_l) + {{6{snd_o4_l[16]}}, snd_o4_l};
        snd_g_r <= gmul(snd_mix_r) + {{6{snd_o4_r[16]}}, snd_o4_r};
    end

    always @ (posedge clk_27m) begin
        audio_sample   <= sat16k(snd_g_l);
        audio_sample_r <= sat16k(snd_g_r);
    end

`else

    wire scc2_req;
    wire [14:0] scc2_wav;
    wire megaram_req;
    wire [20:0] megaram_addr;
    wire megaram_enabled;
    wire [15:0] audio_sample;
    wire [15:0] audio_sample_r;
    wire megaram_wrt;
    wire y8950_int_n = 1'b1;   // _81: sin sonido no hay Y8950
    wire opl4_int_n  = 1'b1;   // niquelado B (bug #21): sin sonido no hay OPL4 —
                               // faltaba y quedaba una net implicita SIN DRIVER
                               // colgada del INT_n del Z80 (leccion EX3638)
    assign opl4pcm_wait_n = 1'b1;  // _89: sin sonido no hay motor PCM

`endif

    //kanji data
    // Strobes REGISTRADOS a clk_27m: el decode combinacional desde IORQ formaba la
    // ruta critica (IORQ -> decode kanji -> mux ram_addr) a 54MHz. El ciclo I/O del
    // Z80 dura decenas de ciclos, asi que 1 ciclo extra de latencia es inocuo.
    reg kanji_data_req_r;
    reg kanji_data_req_w;
    wire kanji_data_ram_req;
    reg [7:0] kanji_data_dout;
    wire [17:0] kanji_data_ram_addr;
    always @ (posedge clk_27m) begin
        kanji_data_req_w <= (bus_addr[7:2] == 6'b110110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:D8-DBh / Kanji-data
        kanji_data_req_r <= (bus_addr[7:2] == 6'b110110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // I/O:D8-DBh / Kanji-data
    end

    kanji kanji1(
        .clk21m(clk_27m),
        .reset(0),
        .req(kanji_data_req_w | kanji_data_req_r),
        .wrt(kanji_data_req_w),
        .adr(bus_addr),
        .dbo(cpu_dout),
        .ramreq(kanji_data_ram_req),
        .ramadr(kanji_data_ram_addr)
    );

`ifdef ENABLE_WIFI
    //f2 port
    wire f2_req_r;
    wire f2_req_w;
    reg [7:0] f2_port;

    assign f2_req_r = (bus_addr[7:0] == 8'hf2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign f2_req_w = (bus_addr[7:0] == 8'hf2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0)
            f2_port <= 8'h00;
        else begin
            if (f2_req_w == 1 ) begin
                f2_port <= cpu_dout;
            end
        end
    end
`endif

    localparam CONFIG1_DEFAULT = 8'hf3;  // bit3=0 -> Scanlines OFF by default (was 0xfb)
    localparam CONFIG2_DEFAULT = 8'h07;  // bit3=0 -> Compatible Mode (extra wait) OFF by default (was 0x0f)

`ifdef ENABLE_CONFIG
    //config
    reg [7:0] config0_ff = 8'h00;
    reg [7:0] config1_ff = CONFIG1_DEFAULT;
    reg [7:0] config1_temp_ff;
    reg [7:0] config2_ff = CONFIG2_DEFAULT;
    reg [7:0] config2_temp_ff;
    reg [1:0] config_mapper_slot_ff = 2'b11;
    reg [1:0] config_megaram_slot_ff = 2'b11;
    reg [1:0] config_sdcard_slot_ff = 2'b11;
    reg config_enable_mapper3;
    reg config_enable_mapper12;
    wire config_enable_megaram;
    wire config_enable_megaram3;
    wire config_enable_megaram12;
    wire config_enable_ghost_scc;
    reg config_enable_sdcard;
    wire config_enable_8sprites;
    wire config_enable_stereo;
    wire config_enable_16_9;
    reg config_reset_ff;
    reg config_flash_write_ff;
    reg config_update;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire [1:0] config_keyboard;
    wire config0_req;
    wire config1_req;
    wire config2_req;
    wire config3_req;
    wire config4_req;   // _161: puerto #44 = ganancia maestra de audio
    reg [7:0] config3_ff = 0;       // puerto #43: sram_cfg de la megaram (volatil)
    wire config5_req;
    reg config_turbo_boot_ff = 0;   // puerto #45 bit0: arrancar en turbo (PERSISTIDO en
                                    // flash byte[4] del bloque config: 'T'=0x54 -> on;
                                    // 0x00/0xFF legados -> off)
    wire config_reset_req;
    wire config_reset;
    wire config_ok;
    wire [7:0] config_dout;
    wire config_req;

    always @ (posedge clk_27m) begin
        config_reset_ff <= 0;
        config_flash_write_ff <= 0;
        config_update <= 0;
        if (clk_enable_3m6_27 == 1 ) begin
            if (config0_req == 1 ) begin
                config0_ff <= ~cpu_dout;
            end

            if (config1_req == 1 ) begin
                config_update <= 1;
                config1_temp_ff <= cpu_dout;
            end
            if (config3_req == 1 ) begin
                config3_ff <= cpu_dout;
            end
            if (config2_req == 1 ) begin
                config_update <= 1;
                config2_temp_ff <= cpu_dout[5:0];
                if ( cpu_dout[6] == 1) begin
                    config_flash_write_ff <= 1;
                end
                if ( cpu_dout[7] == 1) begin
                    config_reset_ff <= 1;
                end
            end
        end
    end

    reg [2:0] ocm_slot2_prev; //bit2 = linear ,bits 1,0 = mode
    reg ocm_update;
    always @ (posedge clk_27m) begin
        ocm_update <= 0;
        if ( { iSlt2_linear, Slot2Mode } != ocm_slot2_prev ) begin
            ocm_update <= 1;
        end
    end

    reg config_init_delay = 0;
    always @ (posedge clk_27m) begin
        config_init_delay <= config_init;
        if (config_init == 1 ) begin
            if (s2_press) begin
                config1_ff <= CONFIG1_DEFAULT;
                config2_ff <= CONFIG2_DEFAULT;
                config_turbo_boot_ff <= 0;      // rescate S2: boot turbo off
                snd_gain_ff <= 3'd5;            // rescate S2: ganancia por defecto x5
            end
            else begin
                config1_ff <= config_sig[2];
                config2_ff <= config_sig[3];
                config_turbo_boot_ff <= (config_sig[4] == 8'h54) ? 1'b1 : 1'b0;
                // byte[5] de la flash: 0xC0..0xC7 = ganancia valida; 0xFF/0x00
                // (bloques legados) => defecto x3. Mismo patron que 'T'=0x54.
                snd_gain_ff <= (config_sig[5][7:3] == 5'b11000) ? config_sig[5][2:0] : 3'd5;
            end
        end
        // escritura del puerto #45 (menu): mismo bloque que la carga init para un
        // unico driver; config5_req dura todo el ciclo OUT (re-latch inocuo) y no
        // puede coincidir con config_init (el CPU arranca tras el stream de flash)
        if (config5_req == 1 ) begin
            config_turbo_boot_ff <= cpu_dout[0];
        end
        if (config4_req == 1 ) begin
            snd_gain_ff <= cpu_dout[2:0];       // _161: ganancia de audio 0..7
        end
        if (config_update == 1) begin
            config1_ff <= config1_temp_ff;
            config2_ff <= config2_temp_ff;
        end
        if (ocm_update == 1) begin
            config1_ff[7:6] <= 2'b10;
            config1_ff[1] <= 1;
            ocm_slot2_prev <= { iSlt2_linear, Slot2Mode };
        end
    end

    monostable mono (
        .pulse_in(config_reset_ff),
        .clock(clk_27m),
        .pulse_out(config_reset_req)
    );
    assign config_reset = (config_reset_req == 1 && flash_write_busy == 0) ? 1 : 0;

    assign config_ok = (config0_ff == 8'hb7) ? 1 : 0;
    assign config0_req = (bus_addr[7:0] == 8'h40 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config1_req = (config_ok == 1 && bus_addr[7:0] == 8'h41 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config2_req = (config_ok == 1 && bus_addr[7:0] == 8'h42 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config3_req = (config_ok == 1 && bus_addr[7:0] == 8'h43 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config4_req = (config_ok == 1 && bus_addr[7:0] == 8'h44 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config5_req = (config_ok == 1 && bus_addr[7:0] == 8'h45 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config_enable_scanlines = config1_ff[3];
    //assign config_keyboard = config2_ff[4:3];
    assign config_enable_stereo = config2_ff[5];
    assign config_enable_16_9 = config2_ff[4];
    // Sprite Limit 8/linea (SPMAXSPR del VDP; fix parpadeo screen 2). En el
    // protocolo de #42 SOLO se almacenan los bits [5:0] (bit6=orden de guardar
    // en flash, bit7=orden de reset) -> el bit de config va en el [3], LIBRE
    // desde la P2 (era el Compatible Mode). En el MSXnano este toggle vive en
    // el bit4 (alli el 16:9 no existe); en MSXimus el bit4 SIGUE siendo 16:9.
    assign config_enable_8sprites = config2_ff[3];
    // ===== v1.9 Panasonic switched-I/O device 8 (T9769 turbo, estilo WSX) =====
    // Protocolo (ref. openMSX MSXMatsushita.cc): OUT &H40,8 selecciona el dispositivo;
    // leer $40 devuelve ~8 = 247 (deteccion). $41 write: SOLO bit0, activo-bajo
    // (0 = 5.37 MHz, 1 = 3.58; OUT &H41,154 enciende porque 154 es par). $41 read:
    // bit0 = estado turbo (0=on), bit2 = 0 (turbo disponible), bit7 = 1 (sin
    // firmware switch), resto 1 -> 0xFA turbo / 0xFB normal.
    // config0_ff guarda ~ID, asi que "dispositivo 8 seleccionado" == 0xF7 y el
    // readback de $40 ES config0_ff = 247. Convive con el config goauld (ID 0x48
    // -> config_ok, excluyentes) y con el fallback swio_dout del rango $40-$4F.
    // La escritura del turbo se latchea en el bloque F11 (clk_54m, un solo driver).
    wire pana_sel  = (config0_ff == 8'hf7) ? 1 : 0;
    wire pana41_wr = (pana_sel == 1 && bus_addr[7:0] == 8'h41 &&
                      bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) ? 1 : 0;
    wire [7:0] pana_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                           ( bus_addr[3:0] == 4'h1 ) ? ( turbo ? 8'hfa : 8'hfb ) : 8'hff;

    assign config_req = (bus_addr[7:4] == 4'h4 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign config_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                         ( bus_addr[3:0] == 4'h1 ) ? config1_ff :
                         ( bus_addr[3:0] == 4'h2 ) ? config2_ff :
                         ( bus_addr[3:0] == 4'h3 ) ? config3_ff :
                         ( bus_addr[3:0] == 4'h4 ) ? {5'b0, snd_gain_ff} :
                         ( bus_addr[3:0] == 4'h5 ) ? {7'b0, config_turbo_boot_ff} : 8'hff;


    always @ (posedge clk_54m) begin
        if (bus_reset_n == 0 || config_init_delay == 1 ) begin
            config_mapper_slot_ff <= config1_ff[5:4];
            config_enable_mapper3 <= (config1_ff[0] == 1 && config1_ff[5:4] == 2'b11);
            config_enable_mapper12 <= (config1_ff[0] == 1 && config1_ff[5:4] != 2'b11);
            //config_megaram_slot_ff <= config1_ff[7:6];
            config_enable_sdcard <= config2_ff[0];
            config_sdcard_slot_ff <= config2_ff[2:1];
        end
    end
    assign config_mapper_slot = config_mapper_slot_ff;
    assign config_megaram_slot = config1_ff[7:6];;
    assign config_sdcard_slot = config_sdcard_slot_ff;
    assign config_enable_megaram = config1_ff[1];
    assign config_enable_megaram3 = (config1_ff[1] == 1 && config1_ff[7:6] == 2'b11);
    assign config_enable_megaram12 = (config1_ff[1] == 1 && config1_ff[7:6] != 2'b11 );
    assign config_enable_ghost_scc = config1_ff[2];

`else

    wire config_enable_mapper3;
    wire config_enable_mapper12;
    wire config_enable_megaram;
    wire config_enable_megaram3;
    wire config_enable_megaram12;
    wire config_enable_ghost_scc;
    wire config_enable_sdcard;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire config_reset;
    assign config_enable_mapper3 = 1;
    assign config_enable_mapper12 = 0;
    assign config_enable_megaram = 1;
    assign config_enable_megaram3 = 1;
    assign config_enable_megaram12 = 0;
    assign config_enable_ghost_scc = 0;
    assign config_enable_sdcard = 0;
    assign config_enable_scanlines = 1;
    assign config_mapper_slot = 2'b11;
    assign config_megaram_slot = 2'b11;
    assign config_sdcard_slot= 2'b11;
    assign config_reset = 0;
    wire config_enable_stereo;
    wire config_enable_8sprites;
    assign config_enable_stereo = 0;
    assign config_enable_8sprites = 0;
    wire config_enable_16_9;
    assign config_enable_16_9 = 0;

`endif

    // v3.2 FIX REGRESION _40: gates del scc_glue calculados AQUI, con todas
    // sus señales ya declaradas (config_megaram_slot es [1:0] — ver el
    // comentario en la instancia sccglue1). Expresiones VERBATIM del glue
    // inline v2.6.
    assign scc_gate_bank2_wr3  = ( pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[3] == 1 );
    assign scc_gate_bank2_wr12 = ( config_enable_megaram12 == 1 && pri_slot == config_megaram_slot );
    assign scc_gate_req3       = ( config_enable_megaram3 == 1 && pri_slot == config_megaram_slot && exp_slotx_num[3] == 1 );
    assign scc_gate_req12      = ( config_enable_megaram12 == 1 && pri_slot == config_megaram_slot );
    assign scc_snd_dis_w       = scc_sound_disable;

    /// FLASH ROM LOADER - BIOS
    // ------------------------------------------------------------------
    //  LAYOUT DE FLASH DE LA CONSOLE 60K (W25Q64, 8 MB, compartida BL616):
    //    0x000000 - 0x3FFFFF  bitstream GW5AT-60 (.bin = ~2.26 MB; margen a 4 MB)
    //    0x400000 - 0x47FFFF  pack BIOS (512 KB)          <- antes 0x200000 (TN20K)
    //    0x480000 - 0x480005  config (6 bytes, cola del pack) <- antes 0x280000
    //    0x480006 - 0x7FFFFF  libre (~3.5 MB: futuro SRM/ROMs)
    //  El bitstream del GW5AT-60 PISA el 0x200000 del TN20K (aviso del audit
    //  §5.B confirmado). El pack se flashea ahora en 0x400000.
    // ------------------------------------------------------------------
    localparam FLASH_START_ADDRESS = 24'h400000;
    localparam FLASH_CONFIG_ADDRESS = 24'h480000;   // = FLASH_START + 512KB
    localparam RAM_START_ADDRESS = 23'h6fffff;
    localparam GOAULD_ROM_SIZE = 512*1024 + 6; //512KB + signature (AB) + config
    reg ff_rom_wr = 0;
    reg [24:0] ff_rom_addr;
    
    wire rom_write;
    wire [7:0] rom_dout;
    wire [24:0] rom_addr;
    assign rom_write = flash_busy;
    assign rom_dout = ff_rom_dout;
    assign rom_addr = ff_rom_addr;
    
    reg [31:0] ff_flash_counter;

//flash
    reg [23:0] ff_flash_addr = 24'd0;
    reg ff_flash_rd = 0;
    reg ff_flash_terminate = 0;
    reg [7:0] ff_rom_dout;
    reg flash_wait_n;
    wire[7:0] flash_dout;
    wire flash_data_ready;
    wire flash_busy;
    wire [7:0] flash_write_din;
    wire flash_write_busy;
    wire [7:0] flash_write_counter;
    wire flash_write_terminate;
    assign flash_write_din = (flash_write_counter == 8'd00) ? 8'h41 :
                             (flash_write_counter == 8'd01) ? 8'h42 :
                        `ifdef ENABLE_CONFIG
                             (flash_write_counter == 8'd02) ? config1_ff :
                             (flash_write_counter == 8'd03) ? config2_ff :
                             (flash_write_counter == 8'd04) ? (config_turbo_boot_ff ? 8'h54 : 8'h00) :
                             (flash_write_counter == 8'd05) ? {5'b11000, snd_gain_ff} : 8'hff;
                        `else
                             (flash_write_counter == 8'd02) ? CONFIG1_DEFAULT :
                             (flash_write_counter == 8'd03) ? CONFIG2_DEFAULT : 8'hff;
                        `endif
    assign flash_write_terminate = (flash_write_counter == 8'd6) ? 1 : 0;

    flash # (
        .STARTUP_WAIT(1)
    )
    flash1
    (
        .clk(clk_54m),
        .reset_n(bus_reset_n),
        .SCLK(mspi_sclk),
        .CS(mspi_cs),
        .MISO(mspi_miso),
        .MOSI(mspi_mosi),
`ifdef ENABLE_WAVE_LOADER
        // _87: el loader YRW801 toma el puerto de LECTURA cuando el pack ya
        // esta streameado (flash_idle) — el FSM del pack queda parado en
        // STATE_IDLE y el mux le devuelve el control al terminar
        .addr(wl_active ? wl_flash_addr : ff_flash_addr),
        .rd(wl_active ? wl_flash_rd : ff_flash_rd),
        .terminate(wl_active ? wl_flash_term : ff_flash_terminate),
`else
        .addr(ff_flash_addr),
        .rd(ff_flash_rd),
        .terminate(ff_flash_terminate),
`endif
        .dout(flash_dout),
        .data_ready(flash_data_ready),
        .busy(flash_busy),
        .write_enable(config_flash_write_ff),
        .write_din(flash_write_din),
        .write_busy(flash_write_busy),
        .write_counter(flash_write_counter),
        .write_terminate(flash_write_terminate),
        .write_addr(FLASH_CONFIG_ADDRESS)   // 60K: 0x480000 (antes 0x280000 en TN20K)
    );

    // /WP y /HOLD de la flash QSPI del 60K: desactivados (alto) permanentemente
    assign mspi_wp   = 1'b1;
    assign mspi_hold = 1'b1;

    reg [7:0] ff_flash_state = 8'd0;
    
    localparam STATE_RESET          = 8'd0;
    localparam STATE_READ_START     = 8'd1;
    localparam STATE_READ_LOOP      = 8'd2;
    localparam STATE_IDLE           = 8'd3;
    localparam STATE_INIT1          = 8'd4;
    localparam STATE_INIT2          = 8'd5;
    localparam STATE_INIT3          = 8'd6;
    localparam STATE_INIT4          = 8'd7;
    reg [31:0] nose = 0;
    wire flash_idle;
    assign flash_idle = (ff_flash_state == STATE_IDLE ) ? 1'b1 : 1'b0;
    
    always @(posedge clk_54m, negedge reset3_n) begin
    if (reset3_n == 0) begin
        ff_flash_state = STATE_RESET;
        ff_flash_rd <= 0;
        ff_rom_wr <= 0;
        nose <= 0;
    end else
        case (ff_flash_state)
    
            STATE_RESET: begin   // reset
                ff_flash_state <= STATE_READ_START;
                ff_flash_rd <= 0;
                ff_rom_wr <= 0;
                ff_flash_terminate <= 0;
            end
    
            STATE_INIT1: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= 24'h000000;
                    ff_flash_rd <= 1;
                    ff_flash_state = STATE_INIT2;
                end
            end
    
            STATE_INIT2: begin  // start read
                if (flash_busy == 1) begin
                    ff_flash_rd <= 0;
                    ff_flash_state = STATE_INIT3;
                end
            end
            
            STATE_INIT3: begin  // start read
                if (flash_busy == 0) begin
                    nose <= 0;
                    ff_flash_terminate <= 1;
                    ff_flash_state = STATE_INIT4;
                end
            end
    
            STATE_INIT4: begin  // start read
                nose <= nose + 1;
                if (nose > 10) begin
                    ff_flash_terminate <= 0;
                    ff_flash_state = STATE_READ_START;
                end
            end
    
            STATE_READ_START: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= FLASH_START_ADDRESS;
                    ff_rom_addr <= RAM_START_ADDRESS;
                    ff_flash_rd <= 1;
                    ff_flash_state = STATE_READ_LOOP;
                    ff_flash_counter <= GOAULD_ROM_SIZE;
                end
            end
    
            STATE_READ_LOOP: begin  // loop read
                if (flash_busy == 0) begin
    
                    if (ff_flash_counter > 0) begin
                        
                        if (~ff_flash_rd) begin
    
                            ff_flash_addr <= ff_flash_addr + 1;
                            ff_flash_counter <= ff_flash_counter - 1;
                            ff_flash_rd <= 1;
    
                            ff_rom_wr <= 1;
                            ff_rom_addr <= ff_rom_addr + 1;
                            ff_rom_dout <= flash_dout; 
    
                        end
                    end else begin    
                        ff_rom_wr <= 0;
                        ff_flash_rd <= 0;
                        ff_flash_state <= STATE_IDLE;
                    end
                end else begin
                    ff_rom_wr <= 0;
                    ff_flash_rd <= 0;
                end
            end
    
            STATE_IDLE: begin  // idle
                ff_flash_terminate <= 1;
            end
    
        endcase
    end

    // configuration + signature
    reg [7:0] config_sig [0:5];
    reg [2:0] last_bytes_cnt;
    wire new_byte;
    wire config_init;
    assign new_byte = (~ff_flash_rd && flash_busy == 0);
    assign config_init = (config_sig[0] == 8'h41 && config_sig[1] == 8'h42 && last_bytes_cnt == 3'd1) ? 1 : 0;

    always @(posedge clk_54m or negedge reset3_n) begin
        if (!reset3_n) begin
            last_bytes_cnt <= 3'd0;
            config_sig[0] <= 8'd0;
            config_sig[1] <= 8'd0;
            config_sig[2] <= 8'd0;
            config_sig[3] <= 8'd0;
            config_sig[4] <= 8'd0;
            config_sig[5] <= 8'd0;
        end else begin
            if (ff_flash_counter == 32'd6)
                last_bytes_cnt <= 3'd6;
            if (new_byte && last_bytes_cnt != 3'd0) begin
                case (last_bytes_cnt)
                    3'd6: config_sig[0] <= flash_dout;
                    3'd5: config_sig[1] <= flash_dout;
                    3'd4: config_sig[2] <= flash_dout;
                    3'd3: config_sig[3] <= flash_dout;
                    3'd2: config_sig[4] <= flash_dout;
                    3'd1: config_sig[5] <= flash_dout;
                endcase
                last_bytes_cnt <= last_bytes_cnt - 1;
            end
        end
    end


`ifdef ENABLE_SDCARD

    
   
    //megarom
    reg megarom_req;
    wire [16:0] megarom_addr;
    reg [2:0] megarom_page_ff;
    reg megarom_page_req;
    wire [2:0] megarom_page;

    always @ (posedge clk_54m) begin
        megarom_req <=     ( config_enable_sdcard == 1 && bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (page_num[1] == 1 || page_num[2] == 1) ) ? 1 : 0;
        megarom_page_req <= ( bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_wr_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && bus_addr == 16'h6000 ) ? 1 : 0;
    end
    assign megarom_page = megarom_page_ff;
    assign megarom_addr = { megarom_page, bus_addr[13:0] };

    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
           megarom_page_ff <= 3'b0;
        end 
        else begin
            if (bus_clk_3m6_27 == 1) begin
                if (megarom_page_req == 1) begin
                    megarom_page_ff <= cpu_dout[2:0]; // select page
                end
            end
        end
    end




    /*
    reg [7:0] ff_flash_state = 8'd0;

    localparam STATE_RESET          = 8'd0;
    localparam STATE_READ_START     = 8'd1;
    localparam STATE_READ_WAIT      = 8'd2;
    localparam STATE_READ_LOOP      = 8'd3;
    localparam STATE_IDLE           = 8'd4;

    always @(posedge clk_54m, negedge bus_reset_n) begin
    if (bus_reset_n == 0) begin
        ff_flash_state = STATE_RESET;
        ff_flash_rd <= 0;
        flash_wait_n <= 1;
    end else
        case (ff_flash_state)
            STATE_RESET: begin   // reset
                ff_flash_state <= STATE_READ_START;
                ff_flash_rd <= 0;
                ff_flash_terminate <= 1;
            end
            STATE_READ_START: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= 24'h100000;
                    ff_flash_state = STATE_READ_WAIT;
                end
            end
            STATE_READ_WAIT: begin  // start read
                if (megarom_req == 1) begin
                    flash_wait_n <= 0;
                    ff_flash_addr <= megarom_addr ;
                    ff_flash_rd <= 1;
                    ff_flash_terminate <= 0;
                    ff_flash_state = STATE_READ_LOOP;
                end
            end
            STATE_READ_LOOP: begin  // loop read
                if (flash_busy == 0 && ff_flash_rd <= 0) begin
                    ff_rom_dout <= flash_dout; 
                    ff_flash_state <= STATE_IDLE;
                end
                else begin
                    ff_flash_rd <= 0;
                end
            end
            STATE_IDLE: begin  // idle
                flash_wait_n <= 1;
                ff_flash_terminate <= 1;
                if (megarom_req == 0) begin
                    ff_flash_state <= STATE_READ_START;
                end
            end
        endcase
    end*/


    //sd card
    localparam int SDC_SDATA		=  16'h7C00;		 	// rw: 7C00h-7Dff - sector transfer area
    localparam int SDC_ENABLE  	    =  16'h7E00;		    // wo: 1: enable SDC register, 0: disable
    localparam int SDC_CMD			=  SDC_ENABLE+1; 		// wo: cmd to SDC fpga: 1=sd read, 2=sd write
    localparam int SDC_STATUS		=  SDC_CMD+1;	 		// ro: SDC status bits
    localparam int SDC_SADDR		=  SDC_STATUS+1;	 	// wo: 4 bytes: sector addr for read/write
    localparam int SDC_C_SIZE  	    =  SDC_SADDR+4;			// ro: 3 bytes: device size blocks
    localparam int SDC_C_SIZE_MULT	=  SDC_C_SIZE+3;		// ro: 3 bits size multiplier
    localparam int SDC_RD_BL_LEN	=  SDC_C_SIZE_MULT+1;	// ro: 4 bits block length
    localparam int SDC_CTYPE		=  SDC_RD_BL_LEN+1;		// ro: SDC Card type: 0=unknown, 1=SDv1, 2=SDv2, 3=SDHCv2 
    localparam int SDC_MID		    =  SDC_CTYPE+1;		    // ro: manufacture ID: 8 bits unsigned
    localparam int SDC_OID		    =  SDC_MID+1;		    // ro: oem id: 2 character
    localparam int SDC_PNM		    =  SDC_OID+2;		    // ro: product name: 5 character
    localparam int SDC_PSN		    =  SDC_PNM+5;		    // ro: serial number: 32 bits unsigned
    localparam int SCC_ENABLE       =  16'h7E80;            // wo: enable disable SCC+
    localparam int SDC_END          =  16'h7EFF; 
    
    wire [8:0] sram_addr_w;
    reg ff_sram_we = 0;
    reg [7:0] ff_sram_cdin;
    reg [7:0] ff_sram_cdout;
    //
    reg ff_sd_en = 0;
    reg sram_cs_w;
    wire sram_busreq_w;
    wire [7:0] sram_cd_w;
    
    wire [3:0] sd_card_stat_w;
    wire [1:0] sd_card_type_w;
    reg ff_sd_rstart;
    reg ff_sd_init;
    reg [31:0] ff_sd_sector;
    wire sd_busy_w;
    wire sd_done_w;
    wire sd_outen_w;
    wire [8:0] sd_outaddr_w;
    wire [7:0] sd_outbyte_w;
    reg ff_sd_wstart;
    wire [7:0] sd_inbyte_w;
    
    wire [21:0] sd_c_size_w;
    wire [2:0] sd_c_size_mult_w;
    wire [3:0] sd_read_bl_len_w;
    
    wire [7:0] sd_mid_w;
    wire [15:0] sd_oid_w;
    wire [39:0] sd_pnm_w;
    wire [31:0] sd_psn_w;
    wire sd_crc_error_w;
    wire sd_timeout_error_w;
    //reg ff_scc_enable;
    //wire scc_enable_w;
    //assign scc_enable_w = ff_scc_enable;
    always @ (posedge clk_27m) begin
        sram_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n == 1 && bus_m1_n == 1 && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && ( bus_addr >= SDC_SDATA && bus_addr < SDC_ENABLE) ? 1 : 0;
    end
    assign sram_busreq_w = sram_cs_w && ~bus_rd_n;
    
    dpram#(
        .widthad_a(9),
        .width_a(8)
    ) dpram1 (
        .clock_a(clk_27m),
        .wren_a(bus_clk_3m6_27 && sram_cs_w && ~bus_wr_n),
        .rden_a(bus_clk_3m6_27 && sram_cs_w && ~bus_rd_n),
        .address_a(bus_addr[8:0]),
        .data_a(cpu_dout),
        .q_a(sram_cd_w),
    
        .clock_b(clk_27m),
        .wren_b(ff_sd_rstart && sd_outen_w),
        .rden_b(ff_sd_wstart && sd_outen_w),
        .address_b(sd_outaddr_w),
        .data_b(sd_outbyte_w),
        .q_b(sd_inbyte_w)
    );
    
    sd_reader #(
        .CLK_DIV(3'd2),
        .SIMULATE(0)
    ) sd1 (
        .rstn(bus_reset_n),
        .clk(clk_27m),
        .sdclk(sd_sclk),
        .sdcmd(sd_cmd),
        .sddat0(sd_dat0),                  
        .card_stat(sd_card_stat_w),        // show the sdcard initialize status
        .card_type(sd_card_type_w),        // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
        .rstart(ff_sd_rstart), 
        .rsector(ff_sd_sector),
        .rbusy(sd_busy_w),
        .rdone(sd_done_w),
        .outen(sd_outen_w),                // when outen=1, a byte of sector content is read out from outbyte
        .outaddr(sd_outaddr_w),            // outaddr from 0 to 511, because the sector size is 512
        .outbyte(sd_outbyte_w),            // a byte of sector content
        .wstart(ff_sd_wstart), 
        .inbyte(sd_inbyte_w),
        .c_size(sd_c_size_w),
        .c_size_mult(sd_c_size_mult_w),
        .read_bl_len(sd_read_bl_len_w),
        .mid(sd_mid_w),
        .oid(sd_oid_w),
        .pnm(sd_pnm_w),
        .psn(sd_psn_w),
        .crc_error(sd_crc_error_w),
        .timeout_error(sd_timeout_error_w),
        .init(ff_sd_init)
    );
    
    assign sd_dat1 = 1;
    assign sd_dat2 = 1;
    assign sd_dat3 = 1; // Must set sddat1~3 to 1 to avoid SD card from entering SPI mode
    
    
    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (~bus_reset_n) begin
            ff_sd_en <= 0;
        end else begin
            if (config_enable_sdcard == 1 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && bus_addr == SDC_ENABLE && ~bus_wr_n && bus_iorq_n && bus_m1_n) 
                ff_sd_en <= cpu_dout[0];
        end
    end
    
    reg sd_cs_w;
    always @ (posedge clk_27m) begin
        sd_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n && bus_m1_n && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (bus_addr >= SDC_ENABLE && bus_addr <= SDC_END) ? 1 : 0;
    end
    wire sd_busreq_w;
    assign sd_busreq_w = sd_cs_w && ~bus_rd_n;
    reg [7:0] ff_sd_cd;
    wire [7:0] sd_cd_w;
    assign sd_cd_w = ff_sd_cd;
    
    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (~bus_reset_n) begin
            ff_sd_rstart <= '0;
            ff_sd_wstart <= '0;
            ff_sd_init <= '0;
        end else begin
            // FIX 60K (AUDIT §3, fila 3): un timeout tambien limpia rstart/wstart
            // (antes quedaban pegados y el sector se reintentaba eternamente).
            // timeout_error es sticky hasta el siguiente comando, pero el strobe de
            // escritura Z80 a SDC_CMD dura varios ciclos de clk_27m y el case de
            // abajo gana, asi que un reintento explicito sigue funcionando.
            if (sd_done_w || sd_timeout_error_w) begin
                ff_sd_rstart <= '0;
                ff_sd_wstart <= '0;
            end
    
            if (sd_cs_w) begin
                if (~bus_wr_n) begin
                    case(bus_addr) 
                        SDC_CMD: begin
                            ff_sd_rstart <= ff_sd_rstart | cpu_dout[0];
                            ff_sd_wstart <= ff_sd_wstart | cpu_dout[1];
                            ff_sd_init   <= ff_sd_init   | cpu_dout[7];
                            //ff_sms_init  <= ff_sms_init  | cdin_w[7];
                        end
                        SDC_SADDR+0:    ff_sd_sector[ 7: 0] <= cpu_dout;
                        SDC_SADDR+1:    ff_sd_sector[15: 8] <= cpu_dout;
                        SDC_SADDR+2:    ff_sd_sector[23:16] <= cpu_dout;
                        SDC_SADDR+3:    ff_sd_sector[31:24] <= cpu_dout;
                    endcase
                end else
                if (~bus_rd_n) begin
                    case(bus_addr) 
                        SDC_ENABLE:     ff_sd_cd <= { 7'b0, ff_sd_en };
                        SDC_STATUS:     ff_sd_cd <= { sd_busy_w, 5'b0, sd_timeout_error_w, sd_crc_error_w };
                        SDC_C_SIZE+0:   ff_sd_cd <= sd_c_size_w[7:0];
                        SDC_C_SIZE+1:   ff_sd_cd <= sd_c_size_w[15:8];
                        SDC_C_SIZE+2:   ff_sd_cd <= { 2'b0, sd_c_size_w[21:16] };
                        SDC_C_SIZE_MULT:ff_sd_cd <= { 5'b0, sd_c_size_mult_w };
                        SDC_RD_BL_LEN:  ff_sd_cd <= { 4'b0, sd_read_bl_len_w };
                        SDC_CTYPE:      ff_sd_cd <= { 6'b0, sd_card_type_w };
                        SDC_MID:        ff_sd_cd <= sd_mid_w;
                        SDC_OID+0:      ff_sd_cd <= sd_oid_w[7:0];
                        SDC_OID+1:      ff_sd_cd <= sd_oid_w[15:8];
                        SDC_PNM+0:      ff_sd_cd <= sd_pnm_w[7:0];
                        SDC_PNM+1:      ff_sd_cd <= sd_pnm_w[15:8];
                        SDC_PNM+2:      ff_sd_cd <= sd_pnm_w[23:16];
                        SDC_PNM+3:      ff_sd_cd <= sd_pnm_w[31:24];
                        SDC_PNM+4:      ff_sd_cd <= sd_pnm_w[39:32];
                        SDC_PSN+0:      ff_sd_cd <= sd_psn_w[7:0];
                        SDC_PSN+1:      ff_sd_cd <= sd_psn_w[15:8];
                        SDC_PSN+2:      ff_sd_cd <= sd_psn_w[23:16];
                        SDC_PSN+3:      ff_sd_cd <= sd_psn_w[31:24];
                        default:        ff_sd_cd <= '1;
                    endcase
                end
            end
        end
    end

`else

    wire sd_busreq_w;
    wire sram_busreq_w;
    wire megarom_req;
    wire megarom_page_req;
    wire sram_cs_w;
    wire sd_cs_w;

`endif

    // Switched I/O ports
    reg [1:0] Slot2Mode;
    wire  swio_req;
    wire [7:0] io42_id212;
    wire iSlt2_linear;
    wire swio_req;
    wire swio_req_r;
    wire swio_req_w;
    wire [7:0] swio_dout;
    assign swio_req_r = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign swio_req_w = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign swio_req = swio_req_r | swio_req_w;

    switched_io_ports ocm_ports (
            .clk21m        (clk_27m),
            .reset         (~bus_reset_n) ,
            .power_on_reset(1),
            .req           (swio_req   ),
            .ack           (           ),
            .wrt           (~bus_wr_n ),
            .adr           (bus_addr   ),
            .dbi           (swio_dout     ),
            .dbo           (cpu_dout      ),
            .io42_id212    (io42_id212    ),
            .iSlt2_linear  (iSlt2_linear  )
        );

    // virtual DIP-SW assignment (2/2)
    always @ ( posedge clk_27m )  begin
        Slot2Mode[1]    <=  io42_id212[4];
        Slot2Mode[0]    <=  io42_id212[5];
    end

    wire send;
    monostable mono2 (
        .pulse_in(s2_press),
        .clock(clk_27m),
        .pulse_out(send)
    );

//    msx2p_debug debug1 (
//        .clk_27m(clk_27m),
//        .clk (clk_27m),
//        .reset_n ( bus_reset_n ),
//        .clk_enable (clk_enable_3m6_27),
//        .bus_addr(bus_addr),
//        .bus_data(cpu_din),
//        .bus_iorq_n(bus_iorq_n),
//        .bus_mreq_n(bus_mreq_n),
//        .bus_wr_n(bus_wr_n),
//        .send(send),
//        .uart_tx(usb_uart_tx),
//        .boot_ok( )
//    );

    // timing_debug debug1 removed for production: it registered high-fanout bus
    // strobes + a UART, costing area/routing at 91% CLS for a dev-only feature.
    // Re-add temporarily if bus timing needs probing over the USB-C UART.
`ifdef ENABLE_V9968_VDP
    // _121diag: telemetria del shim V9968 (ASCII 115200): "D <miss>
    // <complA> <complB>" cada 200ms. Sale por E22 (dbg_pmod1[4], donde
    // vive el CH340 de COM11) — ver el mux junto a los assigns de PMOD.
    // _133 VUMETRO (bug #14): pico de |audio_sample| EN LA FUENTE (el
    // registro del mezclador, dominio clk_27m) por ventana de ~0.31s
    // (2^23 ciclos) con retencion. Junto con amp_hdmi (pico de lo que
    // consume el HDMI, desde msx2hdmi_v9968) discrimina durante un corte
    // audible: ambos picos altos = receptor; fuente alta y hdmi bajo =
    // CDC congelado; ambos bajos = el mezclador se calla de verdad.
    reg  [15:0] amp_src_acc = 16'd0, amp_src = 16'd0;
    reg  [22:0] amp_src_win = 23'd0;
    wire [15:0] asrc_abs = audio_sample[15] ? (~audio_sample + 16'd1)
                                            : audio_sample;
    always @(posedge clk_27m) begin
        amp_src_win <= amp_src_win + 23'd1;
        if (amp_src_win == 23'd0) begin
            amp_src     <= amp_src_acc;
            amp_src_acc <= 16'd0;
        end
        else if (asrc_abs > amp_src_acc) amp_src_acc <= asrc_abs;
    end

    wire usb_uart_tx_int;
    dbg_uart #(.CLK_HZ(53_996_000)) u_dbguart (
        .clk(clk_54m), .rst_n(bus_reset_n),
        // _148 FIX C: {miss de SPRITE[15:0], miss de FONDO[15:0]} — antes la
        // palabra entera era el miss de fondo. Los sprites tenian CERO
        // visibilidad en placa (el thrash del DEVCON paso desapercibido).
        // Lectura en dbg_audio_reader.py: spmiss = w0 >> 16, bgmiss = w0 & 0xFFFF.
        .cnt_a(v68dbg_miss),
        .cnt_b({aud_rst_cnt, aud_lock_cnt}),      // _127H: {resets HDMI, toggles lock}
`ifdef ENABLE_VRAM_DDR3
        // _128X: los 8 bits libres [23:16] llevan el diag de la DDR3
        // ({calib_drop, wd_fires[2:0], wd_ops[3:0]}); sano = 00
        .cnt_c({v68_dbg_apkt[31:24], vddr_diag, v68_dbg_apkt[15:0]}),
`else
        .cnt_c(v68_dbg_apkt),                     // _127I: {ovr, 0, paquetes_audio}
`endif
        // _134: los 11 bits libres llevan {tear[4:0], defer[5:0]} del yank
        .cnt_d({fan_en_o, v68_dbg_tear, v68_dbg_defer, fan_dbg_cnt}),
`ifdef ENABLE_VRAM_DDR3
        .cnt_e(vddr_ops),                         // _129b: ops DDR3 servidas
`else
        .cnt_e({amp_src, amp_hdmi}),              // _133: vumetro {fuente, hdmi}
`endif
        // _154: 6a palabra = drops del shim ({s1_pfq[15:0], wq_full[15:0]}).
        // SANO = 00000000. Cualquier valor distinto en placa = escrituras o
        // prefetches PERDIDOS de verdad — el sismografo del frente Aleste.
        // _161c: los 8 bits ALTOS (hoy siempre 0, el shim solo usa 16+16 en la
        // mitad baja... ojo: usa los 32) NO caben; el diagnostico del ADPCM va
        // en cnt_g, palabra NUEVA (7a) — ver abajo.
        .cnt_f(v68dbg_drops),
        // _161c CAZA DE LOS CRUJIDOS DE LA VOZ: salud del camino de samples
        // del MSX-Audio, que desde la _160 vive en la SDRAM. Nibble alto =
        // wq_lost (bytes de la subida PERDIDOS: el "imposible"), nibble bajo =
        // wd_hits (disparos del watchdog del handshake = lectura que no llego
        // a tiempo). SANO = 00. Si al cantar la voz esto sube, el crujido es
        // del camino de memoria; si se queda en 00, el camino esta impoluto y
        // el culpable es el remuestreador (alias 49,7k->44,1k).
        .cnt_g({24'd0, adpcm_mem_diag}),
        .tx(usb_uart_tx_int)
    );
    assign usb_uart_tx = usb_uart_tx_int;   // (por si el USB-C tambien escucha)
`else
    assign usb_uart_tx = 1'b1;      // UART idle
`endif

    // ===== STANDALONE MERGE: discrete status LEDs (active low) — from MSXnano =====
    // LED[5] TURBO: solid = turbo ON (~4.13MHz); blink (~1.8Hz) = real-MSX speed (also "alive"). LED[4] SD busy;
    // LED[3] joy0 fire B; LED[2] joy0 fire A; LED[1] joy0 any dir; LED[0] joy1 any input
    // _71: LED de TURBO en los LEDs VISIBLES del 60K. En esta placa solo
    // led[0] (G11) y led[1] (U12) tienen pin fisico; el indicador de turbo
    // del nano vivia en led[5] = aqui sin pin (nunca visible). Codificacion
    // AGNOSTICA a la polaridad (no confirmada en el 60K): parpadeo RAPIDO
    // ~6.8Hz = turbo ON, LENTO ~1.7Hz = velocidad real MSX (y "estoy vivo").
    // led[1] = actividad SD (transitoria: legible con cualquier polaridad).
    reg [20:0] led_cnt;
    always @(posedge clk_54m or negedge bus_reset_n) begin
        if (!bus_reset_n) led_cnt <= 0;
        else if (clk_enable_3m6_54) led_cnt <= led_cnt + 1'b1;
    end

    // _115: LEDs restaurados (el estado del video vive PERMANENTE en la
    // telemetria UART: byte15 nibble alto = {pll27_lock, frame_cnt[2:0]},
    // lector tools/dbg_video_reader.py — diagnostico de HDMI sin cables).
    assign led[0] = turbo ? led_cnt[18] : led_cnt[20];  // VISIBLE (G11): rapido=turbo, lento=normal
    assign led[1] = ~sd_busy_w;                         // VISIBLE (U12): actividad SD
    assign led[5] = turbo ? 1'b0 : led_cnt[20];         // sin pin en el 60K (semantica nano conservada)
    assign led[4] = ~sd_busy_w;
    assign led[3] = ~joystick0[5];
    assign led[2] = ~joystick0[4];

    // ---- DEBUG BRING-UP 60K, PMOD0 = vitales + sondas de VIDEO ----
    //  [0] fuera de reset · [1] pack cargado · [2] Z80 ejecutando (M1)
    //  [3] FRAME HDMI corriendo (~1Hz) · [4] hdmi_reset pulsando (stretcher)
    wire dbg_m1_led, dbg_vrst_led;
    led_stretch #(.HOLD(1350000)) dbg_st_m1 (
        .clk(clk_27m), .rst_n(bus_reset_n), .trig(~bus_m1_n), .active(dbg_m1_led));
    // ---- SONDAS DE VIDEO r2 (SOLO lo necesario encendido; resto APAGADO) ----
    //  PMOD0: [0]=vdp_hdmi_reset pulsando (stretch) · [1]=video_reset pulsando
    //         (stretch) · [2]=reset_w nivel · [3]=OFF · [4]=OFF
    //  PMOD1: [0]=pal_mode nivel · [1]=frame NTSC ~1Hz · [2]=frame PAL ~1Hz ·
    //         [3..5]=OFF
    wire dbg_vdprst_led, dbg_vidrst_led;
    led_stretch #(.HOLD(1350000)) dbg_st_vdprst (
        .clk(clk_27m), .rst_n(bus_reset_n), .trig(dbg_video_w[1]), .active(dbg_vdprst_led));
    led_stretch #(.HOLD(1350000)) dbg_st_vidrst (
        .clk(clk_27m), .rst_n(bus_reset_n), .trig(dbg_video_w[4]), .active(dbg_vidrst_led));
    reg [5:0] dbg_fdiv_ntsc = 0, dbg_fdiv_pal = 0;
    reg dbg_ftn_d = 0, dbg_ftp_d = 0;
    always @(posedge clk_27m) begin
        dbg_ftn_d <= dbg_video_w[2];
        if (dbg_video_w[2] && !dbg_ftn_d) dbg_fdiv_ntsc <= dbg_fdiv_ntsc + 1'b1;
        dbg_ftp_d <= dbg_video_w[3];
        if (dbg_video_w[3] && !dbg_ftp_d) dbg_fdiv_pal <= dbg_fdiv_pal + 1'b1;
    end
    // ⚠ Modulos PMOD-LED ACTIVOS A NIVEL BAJO (LED ON = pin 0): niveles invertidos
    //   para que "encendido" = "activo"; sobrantes a 1 (= apagados).
    //  r3: vitales del lado MSX (el video ya esta demostrado: señal + frames)
    wire dbg_rambusy_led;
    led_stretch #(.HOLD(1350000)) dbg_st_ram (
        .clk(clk_27m), .rst_n(bus_reset_n), .trig(ram_busy), .active(dbg_rambusy_led));
    // r4: ¿estan vivos los relojes INTERNOS que gobiernan memoria y bus?
    //  - VideoDHClk (strobe del VDP): sin el, mem1 NUNCA acepta peticiones
    //  - clk_enable_3m6_54 (enable del bus 3.58M): sin el, el Z80 no avanza
    reg dbg_dh_d = 0;  reg [22:0] dbg_dh_cnt = 0;
    always @(posedge clk_108m) begin
        dbg_dh_d <= VideoDHClk;
        if (VideoDHClk && !dbg_dh_d) dbg_dh_cnt <= dbg_dh_cnt + 1'b1;
    end
    reg [20:0] dbg_en36_cnt = 0;
    always @(posedge clk_54m) begin
        if (clk_enable_3m6_54) dbg_en36_cnt <= dbg_en36_cnt + 1'b1;
    end
    // r5: ¿bucle de soft-reset o recarga colgada? ¿el menu llega a dibujar?
    wire dbg_vdpwr_led, dbg_cfgrst_led;
    led_stretch #(.HOLD(1350000)) dbg_st_vdpwr (
        .clk(clk_27m), .rst_n(1'b1), .trig(~vdp_csw_n), .active(dbg_vdpwr_led));
    led_stretch #(.HOLD(2000000)) dbg_st_cfgrst (    // ~74ms (max del contador de 21b)
        .clk(clk_27m), .rst_n(1'b1), .trig(config_reset), .active(dbg_cfgrst_led));
    // r7 (_23dbg): FORENSE DE CUELGUES (SCREEN 3 / F11) — clasifica el cuelgue:
    //  wait clavado + ram_busy fijo = arbitro de memoria; INT muerto con CPU
    //  viva = interrupcion del VDP; todo vivo pero sin M1 = CPU en HALT.
    wire dbg_hid_strobe_w;   // (se mantiene conectado al companion)
    wire dbg_m1act_led;
    // sondas en el dominio de 54M: no cargar el arbol de 27M (hold de paleta)
    led_stretch #(.HOLD(2000000)) dbg_st_m1act (
        .clk(clk_54m), .rst_n(1'b1), .trig(~bus_m1_n), .active(dbg_m1act_led));
    reg [6:0] dbg_intdiv = 0;   // 7b: parpadeo ~0.5Hz (y nudge de placement)
    reg dbg_int_d = 0;
    always @(posedge clk_54m) begin
        dbg_int_d <= bus_int_n;
        if (!bus_int_n && dbg_int_d) dbg_intdiv <= dbg_intdiv + 1'b1;  // flanco INT
    end
`ifdef VIDEO720
    // POLITICA DE LEDs (v3.9, peticion del usuario): TODO apagado por defecto;
    // solo se enciende lo que el diagnostico ACTIVO necesita, y solo en UN
    // modulo (PMOD1). El panel de video del PMOD0 cumplio su mision (_37) y
    // queda APAGADO (activo-bajo: 1 = LED off). Para reactivarlo, restaurar
    // los assigns de dbg_bridge_w de la historia git (commit 1f36a67).
    assign dbg_pmod0[0] = 1'b1;
    assign dbg_pmod0[1] = 1'b1;
    assign dbg_pmod0[2] = 1'b1;
    assign dbg_pmod0[3] = 1'b1;
    assign dbg_pmod0[4] = 1'b1;
`else
    assign dbg_pmod0[0] = wait_io;            // LED ON = CPU RETENIDA EN WAIT (clavado=malo)
    assign dbg_pmod0[1] = ~ram_busy;          // LED ON = ram_busy activo (fijo=arbitro atascado)
    assign dbg_pmod0[2] = dbg_intdiv[6];      // PARPADEO ~0.5Hz = interrupciones VDP vivas
    assign dbg_pmod0[3] = ~dbg_m1act_led;     // LED ON = CPU ejecutando (M1); OFF = congelada
    assign dbg_pmod0[4] = bus_int_n;          // LED ON = LINEA INT ASERTADA (fijo=TORMENTA de int)
`endif

    // r10 (_30dbg): CADENA DEL PSG en PMOD1
    wire dbg_psgwr_led, dbg_psgout_led;
    led_stretch #(.HOLD(2000000)) dbg_st_psgwr (
        .clk(clk_54m), .rst_n(1'b1), .trig(psgBdir), .active(dbg_psgwr_led));
    led_stretch #(.HOLD(2000000)) dbg_st_psgout (
        .clk(clk_54m), .rst_n(1'b1), .trig(|psgSound1), .active(dbg_psgout_led));
    // ===== v4.0 (_55 FINAL): POLITICA DE LEDs — TODO APAGADO =====
    // El panel de diagnostico del SCC (_42.._54) cumplio su mision: el bug del
    // silicio quedo identificado y arreglado (ver scc_wave2 v_54). Paneles
    // anteriores (video _37, PSG r10, SCC _42-54, USB _39) disponibles en git.
    assign dbg_pmod1[0] = 1'b1;
    assign dbg_pmod1[1] = 1'b1;
    assign dbg_pmod1[2] = 1'b1;
    assign dbg_pmod1[3] = 1'b1;
`ifdef WIFI_TAP_BL616TX
    assign dbg_pmod1[4] = bl616_jtagsel;     // E22 = ESPEJO del TX del BL616 (V14) para pinchar con el CH340
`else
    // _111b: la telemetria GANA el pin E22. (La rama ENABLE_WIFI que sacaba
    // aqui el espejo de la UART del WiFi era un resto de diagnostico _77 y
    // le robaba el pin a la telemetria: el lector no veia NADA.)
`ifdef ENABLE_V9968_VDP
    // _121diag: E22 (el CH340 de COM11) pasa a llevar la telemetria del
    // SHIM (dbg_uart ASCII 115200) — la del motor wave (_111) cede el pin
    // en las builds V9968 de diagnostico; usb_uart_tx no llega al PC.
    assign dbg_pmod1[4] = usb_uart_tx_int;
`else
    assign dbg_pmod1[4] = opl4_dbg_tx;   // _111: telemetria del motor wave
`endif
`endif
    // dbg_pmod1[5]/D22 eliminado: pasa a uart_pmod_rx (input) para el modo PMOD test

    // ===== External WS2812B status strip (8 LEDs, e.g. CJMCU-2812-8) on the case =====
    // One data pin (ws2812_led) drives the whole chain; colours from internal state.
    wire caps_on  = ~ppi_port_c[6];                       // MSX CAPS LED (PPI port C bit6, active-low)
    wire kana_on  = keyboard[106];                        // CODE/KANA key held (Left Alt)
    wire joy_on   = (|joystick0[5:0]) | (|joystick1[5:0]);
    wire kbd_raw  = |keyboard;                            // any key held
`ifdef ENABLE_WIFI
`ifdef ENABLE_WIFI_ESP32
    wire wifi_raw = ~bl616_uart_tx_w | ~esp_rx_i;         // WiFi UART active (idle = high; _153: enlace ESP32-C6)
`else
    wire wifi_raw = ~bl616_uart_tx_w | ~bl616_jtagsel;    // WiFi UART active (idle = high; F1: enlace BL616)
`endif
`else
    wire wifi_raw = 1'b0;                                 // BASE MINIMA: WiFi fuera
`endif

    wire disk_act, wifi_act, kbd_act;
    led_stretch #(.HOLD(1350000)) st_disk (.clk(clk_27m), .rst_n(bus_reset_n), .trig(sd_busy_w), .active(disk_act)); // ~50ms
    led_stretch #(.HOLD( 540000)) st_wifi (.clk(clk_27m), .rst_n(bus_reset_n), .trig(wifi_raw),  .active(wifi_act)); // ~20ms
    led_stretch #(.HOLD(1350000)) st_kbd  (.clk(clk_27m), .rst_n(bus_reset_n), .trig(kbd_raw),   .active(kbd_act));  // ~50ms

    // 8 colours in GRB (dim). LED0 = first in the chain (DIN side).
    wire [23:0] ws_c0 = 24'h180000;                          // 0 POWER  : solid green
    wire [23:0] ws_c1 = caps_on  ? 24'h180018 : 24'h000000;  // 1 CAPS   : cyan
    wire [23:0] ws_c2 = kana_on  ? 24'h002020 : 24'h000000;  // 2 KANA   : magenta
    wire [23:0] ws_c3 = disk_act ? 24'h102800 : 24'h000000;  // 3 DISK   : amber
    wire [23:0] ws_c4 = turbo    ? 24'h003000 : 24'h040000;  // 4 CPU    : turbo=red / normal=dim green
    wire [23:0] ws_c5 = wifi_act ? 24'h000030 : 24'h000000;  // 5 WiFi   : blue
    wire [23:0] ws_c6 = joy_on   ? 24'h202000 : 24'h000000;  // 6 JOY    : yellow
    wire [23:0] ws_c7 = kbd_act  ? 24'h181818 : 24'h000000;  // 7 KBD    : white flash

    ws2812 #(.NUM_LEDS(8), .CLK_FRE(27)) ws_strip (
        .clk   (clk_27m),
        .rst_n (bus_reset_n),
        .rgb   ({ws_c0, ws_c1, ws_c2, ws_c3, ws_c4, ws_c5, ws_c6, ws_c7}),
        .dout  (ws2812_led)
    );

    // ===== STANDALONE MERGE: USB host (BL616 FPGA Companion) — from MSXnano =====
    wire [127:0] keyboard;
`ifdef ENABLE_USB_KBD
    // F3 (_39): teclado por USB-A directo (usb_hid_host de nand2mario, la
    // version 2025 de snestang/tangcore con retry). Un host por puerto A;
    // el bitmap resultante se OR-ea con el del companion BL616 (que sigue
    // funcionando por su USB-C+hub): las dos fuentes conviven, como en
    // gbatang. Solo teclado en esta pieza; gamepads USB-A = pieza futura.
    wire        clk_usb12;
    wire        pll12_lock;
    pll_12 pll12_usb (
        .clkin  (ex_clk_27m),       // pad 50 MHz
        .clkout0(clk_usb12),        // 12.000 MHz (VCO 900, generada para GW5AT-60)
        .lock   (pll12_lock)
    );
    wire [1:0] usb1_typ, usb2_typ;
    wire       usb1_report, usb2_report;
    wire       usb1_conerr, usb2_conerr;
    // era V3: raton MSX sobre raton USB de PC (ver fpga/src/msx_mouse.v)
    wire [7:0] usb1_mbtn, usb2_mbtn;
    wire signed [7:0] usb1_mdx, usb2_mdx, usb1_mdy, usb2_mdy;
    wire [7:0] usb1_mods, usb1_k1, usb1_k2, usb1_k3, usb1_k4;
    wire [7:0] usb2_mods, usb2_k1, usb2_k2, usb2_k3, usb2_k4;
    usb_hid_host usb_host1 (
        .usbclk (clk_usb12), .usbrst_n (pll12_lock),
        .usb_dm (usb1_dn), .usb_dp (usb1_dp),
        .typ (usb1_typ), .report (usb1_report), .conerr (usb1_conerr),
        .key_modifiers (usb1_mods),
        .key1 (usb1_k1), .key2 (usb1_k2), .key3 (usb1_k3), .key4 (usb1_k4),
        .mouse_btn (usb1_mbtn), .mouse_dx (usb1_mdx), .mouse_dy (usb1_mdy),
        .game_snes (), .game_l (), .game_r (), .game_u (), .game_d (),
        .game_a (), .game_b (), .game_x (), .game_y (), .game_sel (), .game_sta (),
        .game_lb (), .game_rb (),
        .dbg_hid_report ()
    );
    usb_hid_host usb_host2 (
        .usbclk (clk_usb12), .usbrst_n (pll12_lock),
        .usb_dm (usb2_dn), .usb_dp (usb2_dp),
        .typ (usb2_typ), .report (usb2_report), .conerr (usb2_conerr),
        .key_modifiers (usb2_mods),
        .key1 (usb2_k1), .key2 (usb2_k2), .key3 (usb2_k3), .key4 (usb2_k4),
        .mouse_btn (usb2_mbtn), .mouse_dx (usb2_mdx), .mouse_dy (usb2_mdy),
        .game_snes (), .game_l (), .game_r (), .game_u (), .game_d (),
        .game_a (), .game_b (), .game_x (), .game_y (), .game_sel (), .game_sta (),
        .game_lb (), .game_rb (),
        .dbg_hid_report ()
    );

    // =======================================================================
    //  RATON MSX sobre raton USB — cruce de dominios e instancia
    //
    //  usb_hid_host entrega mouse_dx/dy en el dominio de 12 MHz y los BORRA
    //  justo despues del pulso `report`, asi que no se pueden muestrear desde
    //  54 MHz: para cuando el pulso cruzase el sincronizador ya valdrian cero.
    //  Se capturan en su propio dominio a un registro cuasi-estatico (estable
    //  hasta el siguiente informe, milisegundos despues) y se avisa con un
    //  toggle, que es el patron que ya usa el resto del proyecto para esto.
    // =======================================================================
    wire usb1_mouse_rep = usb1_report && (usb1_typ == 2'd2);
    wire usb2_mouse_rep = usb2_report && (usb2_typ == 2'd2);

    reg signed [7:0] mo_dx_q = 8'sd0, mo_dy_q = 8'sd0;
    reg        [7:0] mo_btn_q = 8'd0;
    reg              mo_tog = 1'b0;
    reg              mo_seen = 1'b0;

    always @(posedge clk_usb12) begin
        if (!pll12_lock) begin
            mo_tog <= 1'b0;
            mo_seen <= 1'b0;
        end
        else if (usb1_mouse_rep || usb2_mouse_rep) begin
            mo_dx_q  <= usb1_mouse_rep ? usb1_mdx  : usb2_mdx;
            mo_dy_q  <= usb1_mouse_rep ? usb1_mdy  : usb2_mdy;
            mo_btn_q <= usb1_mouse_rep ? usb1_mbtn : usb2_mbtn;
            mo_tog   <= ~mo_tog;
            mo_seen  <= 1'b1;      // una vez visto, el puerto 2 es del raton
        end
    end

    // 2FF al dominio de 54 MHz + deteccion de cambio
    reg [2:0] mo_tog_s = 3'b000;
    reg       mo_seen_s0 = 1'b0, mo_seen_s1 = 1'b0;
    always @(posedge clk_54m) begin
        mo_tog_s   <= {mo_tog_s[1:0], mo_tog};
        mo_seen_s0 <= mo_seen;
        mo_seen_s1 <= mo_seen_s0;
    end
    wire mo_rep_54 = mo_tog_s[2] ^ mo_tog_s[1];

    assign msx_mouse_present = mo_seen_s1;

    // Sensibilidad: el delta se divide por 2^MOUSE_SENS. Un raton USB moderno
    // tiene MUCHO mas DPI que uno de MSX, asi que sin dividir el puntero se va
    // volando. 2 (=/4) es el punto de partida; el resto de la division NO se
    // pierde (se guarda en el acumulador), asi que los movimientos lentos
    // siguen moviendo el puntero. ⚠️ Es el numero que habra que ajustar en
    // placa a ojo.
    localparam [2:0] MOUSE_SENS = 3'd2;

    msx_mouse u_msx_mouse (
        .clk       (clk_54m),
        .rst_n     (bus_reset_n),
        .rep_pulse (mo_rep_54),
        .dx        (mo_dx_q),
        .dy        (mo_dy_q),
        .btn       ({mo_btn_q[1], mo_btn_q[0]}),   // {derecho, izquierdo}
        .sens      (MOUSE_SENS),
        .strobe    (psgPB[5]),                     // pin 8 del PUERTO 2
        .data      (msx_mouse_data)
    );

    wire [127:0] kbd_usb1, kbd_usb2;
    usb_kbd_decode dec_usb1 (
        .clk12 (clk_usb12), .rst_n (pll12_lock),
        .typ (usb1_typ), .report (usb1_report), .mods (usb1_mods),
        .k1 (usb1_k1), .k2 (usb1_k2), .k3 (usb1_k3), .k4 (usb1_k4),
        .bitmap (kbd_usb1)
    );
    usb_kbd_decode dec_usb2 (
        .clk12 (clk_usb12), .rst_n (pll12_lock),
        .typ (usb2_typ), .report (usb2_report), .mods (usb2_mods),
        .k1 (usb2_k1), .k2 (usb2_k2), .k3 (usb2_k3), .k4 (usb2_k4),
        .bitmap (kbd_usb2)
    );
    // cruce 12M -> 27M: bits cuasi-estaticos (pulsaciones de ms), 2FF por bit
    reg [127:0] kbd_usb_s1 = 128'd0, kbd_usb_s2 = 128'd0;
    always @(posedge clk_27m) begin
        kbd_usb_s1 <= kbd_usb1 | kbd_usb2;
        kbd_usb_s2 <= kbd_usb_s1;
    end
    wire [127:0] keyboard_spi;
    assign keyboard = keyboard_spi | kbd_usb_s2;
`else
    wire [127:0] keyboard_spi;
    assign keyboard = keyboard_spi;
`endif
    // F1 (_73): el pad U15 (spi_irqn) se entrega a la UART del BL616 cuando el
    // WiFi onboard esta activo; el companion (ya sin SPI: jtagseln=0) pierde su
    // IRQ — teclado por soft-host USB-A, joysticks USB del companion inertes.
    wire companion_irqn_w;
`ifdef ENABLE_WIFI
    assign spi_irqn = bl616_uart_tx_w;
`else
    assign spi_irqn = companion_irqn_w;
`endif
    // _153: el TX del wifi_lite tambien sale por el PMOD0 hacia el ESP32-C6.
    // Se emite SIEMPRE (broadcast inofensivo); sin ENABLE_WIFI queda en idle.
`ifdef ENABLE_WIFI
    assign esp_tx_o = bl616_uart_tx_w;
`else
    assign esp_tx_o = 1'b1;               // idle UART
`endif
    // _156: estado de turbo hacia el C6 (turbo_eff = el que consume el FSM de
    // waits; cuasi-estatico, sin CDC que valga la pena)
`ifdef ENABLE_TURBO
    assign esp_turbo_o = turbo_eff;
`else
    assign esp_turbo_o = 1'b0;
`endif
    fpga_companion fpga_companion_inst
    (
        .clk (clk_27m),
        .reset (~bus_reset_n),

        .spi_sclk (spi_sclk),
        .spi_csn (spi_csn),
        .spi_dir (spi_dir),
        .spi_dat (spi_dat),
        .spi_irqn (companion_irqn_w),

        .keyboard (keyboard_spi),
        .joystick0 (joystick0),
        .joystick0_console (),
        .joystick1 (joystick1),
        .ws2812_color (),   // LEDs are discrete; WS2812 not used
        .dbg_hid_strobe (dbg_hid_strobe_w)
    );

    usb_keyboard_msx usb_keyboard_msx
    (
        .CLK (clk_27m),
        .RESET (~bus_reset_n),

        .keyboard (keyboard),
        .A (keyboard_addr),
        .DO (keyboard_data),
        .FN (function_keys)
    );

endmodule