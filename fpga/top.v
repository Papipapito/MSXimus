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
//`define ENABLE_WIFI       // BASE MINIMA: WiFi/UART fuera
`define ENABLE_OPLL         // F3 (_38): OPLL de vuelta — 1a pieza re-añadida sobre la base validada
`define ENABLE_USB_KBD      // F3 (_39): teclado por USB-A DIRECTO al fabric (usb_hid_host, sin hub)
`define ENABLE_SCC          // F3 (_40): SCC de vuelta — scc_wave2v Verilog puro (el VHDL scc_wave_mul era BARRIDO por la sintesis GW5A)
//`define ENABLE_CONSOLE_SN // BASE MINIMA: SN76489 de consola fuera
//`define ENABLE_TURBO      // BASE MINIMA: turbo F11/WSX fuera (turbo=0 fijo)

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
    output wire [5:0] dbg_pmod1,
    output wire [4:0] dbg_pmod0,

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

`ifdef ENABLE_WIFI
    //uart
    output wire uart_tx,
    input wire uart_rx,
`endif 

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
    output wire [1:0] O_sdram_dqm // 16/2

    //output wire SLTSL3

);

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
    Gowin_PLL pll_main (
        .clkin  (ex_clk_27m),   // ⚠ en la Console 60K este pin lleva 50 MHz (V22)
        .clkout0(clk_108m),     // 108.000000 MHz (fraccional, exacto)
        .clkout1(clk_54m),      //  54.000000 MHz
        .clkout2(clk_27m),      // v3.0: 27M del PLLA (fase CONOCIDA vs 54/108, como el
                                //  rPLL del TN20K). Ya NO alimenta ningun OSER10 (el
                                //  TMDS vive a 74.25/371.25 en pll_74) -> la restriccion
                                //  que motivo el CLKDIV desaparece con el video 720p.
        .clkout3(clk_135),      // 135.000000 MHz (TMDS; sustituye al CLK_135 del tn_vdp)
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
    pll_27 pll27_video (
        .clkin  (ex_clk_27m),   // pad 50 MHz
        .clkout0(clk27_video)
    );
    pll_74 pll74_video (
        .clkin  (clk27_video),
        .clkout0(clk_hdmi),
        .clkout1(clk_hdmi5)
    );

    // JTAG→SPI del companion (estilo C64Nano): los pines JTAG se entregan al
    // fabric (SPI del BL616) solo con el PLL en lock y sin petición de JTAG del
    // BL616 (bl616_jtagsel, PULL_UP). Sin término de botón: s2 es el reset MSX
    // y no debe flapear el modo JTAG.
    assign jtagseln = clock_locked & ~bl616_jtagsel;

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
assign psg_req_r = (console_mode == 2'b00 && bus_addr[7:0] == 8'hA2 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0) ? 1 : 0;

// USB joystick data wires (driven by fpga_companion instance below)
wire [7:0] joystick0;
wire [7:0] joystick1;

// Track which PSG register was last latched via I/O A0h
reg [3:0] psg_addr_latch;
always @(posedge clk_54m or negedge bus_reset_n) begin
    if (!bus_reset_n)
        psg_addr_latch <= 4'd0;
    else if (console_mode == 2'b00 && bus_addr[7:0] == 8'hA0 && bus_iorq_n == 0 && bus_wr_n == 0 && bus_m1_n == 1)
        psg_addr_latch <= cpu_dout[3:0];
end

// Track PSG reg 15 (Port B) bits [7:6] which select joystick port
// bit6=0 selects joy1, bit7=0 selects joy2 (active low)
reg [1:0] psg_reg15_joy_sel;
always @(posedge clk_54m or negedge bus_reset_n) begin
    if (!bus_reset_n)
        psg_reg15_joy_sel <= 2'b11;
    else if (console_mode == 2'b00 && bus_addr[7:0] == 8'hA1 && bus_iorq_n == 0 && bus_wr_n == 0 && bus_m1_n == 1
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
wire [7:0] psg_joy_data = (!psg_reg15_joy_sel[0]) ? joy0_msx :
                          (!psg_reg15_joy_sel[1]) ? joy1_msx :
                          8'hFF;

// ===== STANDALONE MERGE: USB keyboard (PPI port B 0xA9 read / port C 0xAA latch) =====
wire ppi_portb_req_r = (console_mode == 2'b00 && bus_addr[7:0] == 8'hA9 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0) ? 1 : 0;
wire ppi_portc_req_w = (console_mode == 2'b00 && bus_addr[7:0] == 8'hAA && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0);

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

    // v1.9: FPGA/bitstream version readable on I/O port 0x2F. The boot menu reads it and
    // warns if you flashed mismatched .fs/.bin (e.g. a v1.8 bitstream + a v1.7 BIOS pack).
    // Encoding 0x1X = version 1.X. Bump FPGA_VERSION each release together with the pack.
    localparam [7:0] FPGA_VERSION = 8'h19;
    wire ver_req_r = (bus_iorq_n == 1'b0 && bus_m1_n == 1'b1 && bus_rd_n == 1'b0 && bus_addr[7:0] == 8'h2F);
    always @ (posedge clk_54m) begin
        cpu_din <=
                ( ver_req_r == 1 ) ? FPGA_VERSION :
                ( console_joy_r == 1 ) ? console_joy_data :
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
                     ( subrom_logo_req == 1 ) ? ram_dout :
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
                     ( logo_req == 1 ) ? ram_dout :
                     ( f2_req_r == 1 ) ? f2_port :
                     ( uart_req == 1 ) ? uart_dout :
                `endif
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
                    if ( ram_write == 1 || (ex_bus_iorq_n == 0 || ( config_enable_wait == 1 && ex_bus_mreq_n == 0 ) )&& (bus_rd_n == 0 || bus_wr_n == 0) ) begin
                        wait_io_ff <= 0;
                        state_wait <= WAIT_STATE1;
                    end
                end
                WAIT_STATE1: begin
                    if ( clk_enable_3m6_54 == 1 ) begin
                        state_wait <= WAIT_STATE2;
                    end
                end
                // NOTA v1.9: el wait sigue midiendo y liberando con los pulsos 3m6
                // fijos TAMBIEN en turbo (release 3m6-alineado con el CPU en tren
                // 5m4 swallowed). Validado en HW: juegos/DOS en turbo sin fallos.
                WAIT_STATE2: begin
                    if ( clk_falling_3m6_54 == 1 ) begin
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
    reg turbo_req = 1'b0;   // deseo de turbo; se COMMITEA solo en ventana segura
    reg f11_s0  = 1'b0;
    reg f11_s1  = 1'b0;
    reg f11_prev= 1'b0;
    always @ (posedge clk_54m) begin
        f11_s0   <= keyboard[68];   // sync HID F11 state into clk_54m domain
        f11_s1   <= f11_s0;
        f11_prev <= f11_s1;
        // FIX 60K (cuelgue F11): el mux de cadencia NO puede conmutar con un
        // acceso en vuelo — con la SDRAM externa el dato llega mas tarde que
        // en la interna del TN20K y el mis-latch pilla basura (menu sobrevivia
        // por probabilidad; BASIC moria). Los eventos escriben turbo_req y el
        // cambio se aplica SOLO con el bus Z80 y la memoria en reposo.
        if (turbo != turbo_req
            && bus_rd_n && bus_wr_n && bus_mreq_n && ex_bus_iorq_n
            && ram_busy == 0
`ifdef ENABLE_WAIT
            && state_wait == WAIT_IDLE
`endif
            )
            turbo <= turbo_req;
`ifdef ENABLE_TURBO
        if (f11_s1 & ~f11_prev)     // rising edge = F11 pressed
            turbo_req <= ~turbo_req; // toggle real-MSX <-> turbo
`endif
        // v1.9: control software Panasonic — OUT &H41,n con el dispositivo 8
        // seleccionado (decode pana41_wr junto al bloque config). bit0 activo-bajo:
        // 0 = turbo 5.37 MHz, 1 = 3.58. Puesto tras el F11: si coinciden en el
        // mismo ciclo gana el software (en el T9769 real el puerto es el unico control).
`ifdef ENABLE_TURBO
        if (pana41_wr)
            turbo_req <= ~cpu_dout[0];
`endif
        // v1.9: "Boot Turbo" persistido (ajuste del menu, puerto #45). Siembra el
        // turbo durante la ventana config_init del stream de flash: config_init y
        // config_sig son dominio clk_54m (sin CDC) y config_sig[4] ya esta cargado
        // cuando la ventana abre (se carga con last_bytes_cnt==2). Va el ULTIMO del
        // bloque: domina sobre F11/puerto durante el boot (no disparan ahi de todos
        // modos). Con S2 (rescate) arranca SIEMPRE a 3.58.
`ifdef ENABLE_TURBO
        if (config_init)
            turbo_req <= (!s2_press && config_sig[4] == 8'h54) ? 1'b1 : 1'b0;
`endif
    end

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
    // CPU cadence mux: turbo picks 5.37 MHz, else the untouched 3.6 MHz path.
    // (wires forward-declared above the M1-wait FSM)
    assign clk_enable_cpu_54  = turbo ? clk_enable_5m4_54  : clk_enable_3m6_54;
    assign clk_falling_cpu_54 = turbo ? clk_falling_5m4_54 : clk_falling_3m6_54;

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
        .WAIT_n    (bus_wait_n & wait_uart),
      `else
        .WAIT_n    (wait_uart),
      `endif
    `else
      `ifndef ENABLE_WAIT_ADAPTIVE
        .WAIT_n    (bus_wait_n),
      `else
        .WAIT_n    (1),
      `endif
    `endif
    `ifdef ENABLE_V9958
        .INT_n     ((console_mode == 2'b10) ? bus_int_n : (bus_int_n & vdp_int)),
    `else
        .INT_n     (bus_int_n),
    `endif
        .NMI_n     ((console_mode == 2'b10) ? vdp_int :
                    (console_mode == 2'b01) ? ~sg_pause_nmi : 1'b1),
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
    assign ppi_req_r = (console_mode == 2'b00 && bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign ppi_req_w = (console_mode == 2'b00 && bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

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
        exp_slot0_req_w <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slot0_req_r <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slotx_req_w <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
        exp_slotx_req_r <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[SD_SLOT] == 1 ) ? 1: 0;
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
        slot0_req_r <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
        slotx_req_r <= ( console_mode == 2'b00 && ( config_enable_mapper3 == 1 || config_enable_megaram3 == 1 || config_enable_sdcard == 1 ) && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 ) ? 1 : 0;
    end

`ifdef ENABLE_BIOS
    //bios
    reg bios_req;
    wire [7:0] bios_dout;
    always @ (posedge clk_54m) begin
        bios_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 && exp_slot0_num[0] == 1) ? 1 : 0;
    end

    //subrom
    reg subrom_req;
    wire [7:0] subrom_dout;
    always @ (posedge clk_54m) begin
        subrom_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && page_num[0] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //msx logo
    reg msx_logo_req;
    wire [7:0] msx_logo_dout;
    always @ (posedge clk_54m) begin
        msx_logo_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //subrom + logo
    reg subrom_logo_req;
    always @ (posedge clk_54m) begin
        subrom_logo_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[0] == 1 || page_num[1] == 1) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end

    //kanji driver
    reg kanji_driver_req;
    always @ (posedge clk_54m) begin
        kanji_driver_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && (page_num[1] == 1 || page_num[2] == 1) && pri_slot_num[0] == 1 && exp_slot0_num[1] == 1 ) ? 1 : 0;
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
        wifi_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[2] == 1 ) ? 1 : 0;
    end
`endif

    //logo ROM (FREE16KB del pack @0x7C000) en slot 0-3 pagina 1: pantalla de
    //marca del menu (rutina+imagen autocontenidas; el menu la llama con CALLF)
    reg logo_req;
    always @ (posedge clk_54m) begin
        logo_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rd_n == 0 && page_num[1] == 1 && pri_slot_num[0] == 1 && exp_slot0_num[3] == 1 ) ? 1 : 0;
    end

`ifdef ENABLE_WIFI
    //uart
    wire uart_req;
    wire wait_uart;
    wire [7:0] uart_dout;

    assign uart_req = (bus_addr[7:1] == 7'b0000011 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // ESP ports 06-07h

    wifi uwifi (
        .clk_i      (clk_27m),
        .wait_o     (wait_uart),
        .reset_i    (bus_reset_n),
        .iorq_i     (bus_iorq_n),
        .wrt_i      (bus_wr_n),
        .rd_i       (bus_rd_n),
        .rx_i       (uart_rx),
        .tx_o       (uart_tx),
        .adr_i      (bus_addr),
        .db_i       (cpu_dout),
        .db_o       (uart_dout)
    );

`endif 

    //rtc
    wire rtc_req_r;
    wire rtc_req_w;
    wire [7:0] rtc_dout;
    assign rtc_req_w = (console_mode == 2'b00 && bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC
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
    //decode del VDP por modo: MSX 98-9Bh; SG-1000 BE/BFh; ColecoVision A0-BFh
    wire vdp_io_hit;
    assign vdp_io_hit = ( console_mode == 2'b00 ) ? ( bus_addr[7:2] == 6'b100110 ) :
                        ( console_mode == 2'b01 ) ? ( bus_addr[7:1] == 7'b1011111 ) :
                                                    ( bus_addr[7:5] == 3'b101 );
    assign vdp_csw_n = (vdp_io_hit == 1 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 0:1; // VDP write
    assign vdp_csr_n = (vdp_io_hit == 1 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 0:1; // VDP read

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
        .mode    ((console_mode == 2'b00) ? bus_addr[1:0] : {1'b0, bus_addr[0]}),
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

        .maxspr_n    (1),
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
        mapper_req3 <= ( console_mode == 2'b00 && bus_rfsh_n == 1 && config_enable_mapper3 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[0] == 1 && xffff == 0) ? 1 : 0;
        mapper_req12 <= ( console_mode == 2'b00 && config_enable_mapper12 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_mapper_slot ) ? 1 : 0;
    end
    assign mapper_req = mapper_req3 | mapper_req12;
    assign mapper_read = mapper_req & ~bus_rd_n;
    assign mapper_write = mapper_req & ~bus_wr_n;
    assign mapper_reg_write = ( console_mode == 2'b00 && (bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) && (bus_addr [7:2] == 6'b111111) )?1:0;

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
    
    assign ram_read = (~flash_idle) ? 0 : 
                `ifdef ENABLE_MAPPER
                      (mapper_read == 1) ? ~bus_rd_n :
                `endif
                      (bios_req == 1) ? ~bus_rd_n :
                      (subrom_logo_req == 1) ? ~bus_rd_n :
                `ifdef ENABLE_SDCARD
                      (megarom_req == 1) ? ~bus_rd_n :
                `endif
                      (megaram_req == 1) ? ~bus_rd_n :
                      (kanji_driver_req == 1) ? ~bus_rd_n :
                      (kanji_data_ram_req == 1) ? ~bus_rd_n :
                `ifdef ENABLE_WIFI
                      (wifi_req == 1) ? ~bus_rd_n :
                      (logo_req == 1) ? ~bus_rd_n :
                `endif
                      0;
    
    assign ram_write = (~flash_idle) ? rom_write : 
                `ifdef ENABLE_MAPPER
                      (mapper_write == 1 ) ? ~bus_wr_n :
                `endif
                      (megaram_wrt == 1) ? ~bus_wr_n :
                      0; 

    assign ram_req = (~flash_idle) ? rom_write : 
                     (mapper_req == 1) ? mapper_req:
                     (bios_req == 1) ? bios_req:
                     (subrom_logo_req == 1) ? subrom_logo_req:
                `ifdef ENABLE_SDCARD
                     (megarom_req == 1) ? megarom_req:
                `endif
                     (megaram_req == 1) ? megaram_req:
                     (kanji_driver_req == 1) ? kanji_driver_req:
                     (kanji_data_ram_req == 1) ? kanji_data_ram_req:
                `ifdef ENABLE_WIFI
                     (wifi_req == 1) ? wifi_req:
                     (logo_req == 1) ? logo_req:
                `endif
                      0;

    assign ram_din = (~flash_idle) ? { rom_dout, rom_dout }  : { cpu_dout, cpu_dout };

// SDCLK_INVERT=1 CONFIRMADO EN HW (2026-07-08): con fase normal el auto-test
// da ROJO (errores CPU) y con 180 grados VERDE; el core arranca (serial _18inv).
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

    .ram_dout(ram_dout),
    .vram_dout(VrmDbi2),
    .ram_busy(ram_busy),

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
    reg psgPB = 8'hff;

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

    assign opll_req_n = ( bus_iorq_n == 1'b0 && bus_addr[7:1] == 7'b0111110  &&  bus_wr_n == 1'b0 )  ? 1'b0 : 1'b1;    // I/O:7C-7Dh   / OPLL (YM2413)
  
`ifdef ENABLE_OPLL
    jt2413 opll(
        .rst (~bus_reset_n),        // rst should be at least 6 clk&cen cycles long
        .clk (clk_54m),        // F3/_38: OPLL a 54M+cen (patron smstang con el MISMO chip:
        .cen (clk_enable_3m6_54),   //  bus mismo-dominio y fuera del arbol 27M — su carga
                                    //  re-sorteaba el hold de la paleta del VDP)
        .din (cpu_dout),
        .addr (bus_addr[0]),
        .cs_n (opll_req_n),
        .wr_n (1'b0),
        // combined output
        .snd (jt2413_wav),
        .sample   ( )
    );
`else
    assign jt2413_wav = 16'd0;      // BASE MINIMA v3.0: OPLL fuera
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
    scc_wave2 SccCh (
        .clk21m (clk_54m),          // v2.5: SCC en 54M (bus mismo dominio;
        .reset (~bus_reset_n),      //  a 27M la fase CLKDIV lo dejaba mudo)
        .clkena (clk_enable_3m6_54),
        .req ( scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav),
        .sccplus (scc_mode_plus)
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
    reg console_mem_req;
    always @ (posedge clk_54m) begin
        console_mem_req <= ( console_mode != 2'b00 && bus_mreq_n == 0 && bus_rfsh_n == 1 && (bus_rd_n == 0 || bus_wr_n == 0) ) ? 1 : 0;
    end
    assign scc2_req = ( console_mode != 2'b00 ) ? console_mem_req : (scc2_req3 | scc2_req12);
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
        .console_mode (console_mode),

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

`ifdef ENABLE_SCC
    scc_wave2 SccCh2 (   // v3.3: idem SccCh — chip VHDL con producto inline
        .clk21m (clk_54m),          // v2.5: idem SccCh
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_54),
        .req ( scc2x_req),
        .ack (),
        .wrt (scc2x_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc2x_dout),
        .dbo (cpu_dout),
        .wave (scc2x_wav),
        .sccplus (scc2x_modeb[5])
    );
`else
    assign scc2x_wav  = 15'd0;      // BASE MINIMA v3.0: SCC-I fuera
    assign scc2x_dout = 8'hFF;
`endif

    //mixer (L = PSG1+SCC1+OPLL, R = PSG2+SCC2+OPLL; mono = everything on both sides)
	reg [15:0] audio_sample;
	reg [15:0] audio_sample_r;

    wire [15:0] scc_term;
    assign scc_term = (map_sel == 2'b10) ? { scc_wav, 1'b0 } : 16'd0;  // SCC solo en modo SCC (no Konami4/ASCII)

    // ============== modo consola: PSG SN76489, mandos y pausa ==============
    //SN76489: SG-1000 escribe en 7E/7Fh; ColecoVision en E0-FFh
    wire sn_wr;
    assign sn_wr = ( bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0 && (
                     (console_mode == 2'b01 && bus_addr[7:1] == 7'b0111111) ||
                     (console_mode == 2'b10 && bus_addr[7:5] == 3'b111) ) ) ? 1 : 0;
    wire [13:0] sn_sound;
`ifdef ENABLE_CONSOLE_SN
    sn76489 sn1 (
        .clk        (clk_54m),      // v2.5: idem (Coleco/SG-1000)
        .clk_en_3m6 (clk_enable_3m6_54),
        .reset_n    (bus_reset_n),
        .wr         (sn_wr),
        .din        (cpu_dout),
        .sound      (sn_sound)
    );
`else
    assign sn_sound = 14'd0;        // BASE MINIMA v3.0: SN76489 consola fuera
`endif
    wire [15:0] sn_term;
    assign sn_term = (console_mode != 2'b00) ? { 1'b0, sn_sound, 1'b0 } : 16'd0;

    //mandos: SG-1000 lee DC/DDh; Coleco lee E0-FFh (A1 elige mando) con latch
    //de modo keypad (escritura 80-9F) / joystick (escritura C0-DF)
    reg coleco_kp;
    always @ (posedge clk_27m) begin
        if (bus_reset_n == 0) coleco_kp <= 0;
        else if (console_mode == 2'b10 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) begin
            if (bus_addr[7:5] == 3'b100) coleco_kp <= 1;    // 80-9Fh
            if (bus_addr[7:5] == 3'b110) coleco_kp <= 0;    // C0-DFh
        end
    end
    //keypad Coleco desde el teclado USB: digitos 1-9,0 + KP* ('*') y KP- ('#').
    //Codigo de 4 bits activo-bajo leido en D0-D3 (tabla clasica; VERIFICAR HW)
    reg [3:0] kp_code;
    always @ (posedge clk_27m) begin
        kp_code <= keyboard[30] ? 4'h2 :    // 1 -> ~0Dh? tabla: lectura directa
                   keyboard[31] ? 4'h8 :    // 2
                   keyboard[32] ? 4'h3 :    // 3
                   keyboard[33] ? 4'hD :    // 4
                   keyboard[34] ? 4'hC :    // 5
                   keyboard[35] ? 4'h1 :    // 6
                   keyboard[36] ? 4'hA :    // 7
                   keyboard[37] ? 4'hE :    // 8
                   keyboard[38] ? 4'h4 :    // 9
                   keyboard[39] ? 4'h5 :    // 0
                   keyboard[85] ? 4'h6 :    // KP* = '*'
                   keyboard[86] ? 4'h9 :    // KP- = '#'
                                  4'hF;     // nada pulsado
    end
    wire [7:0] sg_dc;
    wire [7:0] sg_dd;
    // bits crudos joystickN: [0]=Der [1]=Izq [2]=Abajo [3]=Arriba [4]=btn1 [5]=btn2
    // SG-1000 DC (activo bajo): D0=Arr D1=Aba D2=Izq D3=Der D4=btn1 D5=btn2 D6=P2Arr D7=P2Aba
    assign sg_dc = ~{ joystick1[2], joystick1[3], joystick0[5], joystick0[4],
                      joystick0[0], joystick0[1], joystick0[2], joystick0[3] };
    // SG-1000 DD: D0=P2Izq D1=P2Der D2=P2btn1 D3=P2btn2
    assign sg_dd = { 4'b1111, ~joystick1[5], ~joystick1[4], ~joystick1[0], ~joystick1[1] };
    wire [7:0] coleco_joy0;
    wire [7:0] coleco_joy1;
    //byte joystick Coleco (activo bajo): D0=arriba D1=derecha D2=abajo D3=izda D6=fuego
    assign coleco_joy0 = (coleco_kp == 1) ? { 1'b1, ~joystick0[5], 2'b11, kp_code }
                                          : { 1'b1, ~joystick0[4], 2'b11,
                                              ~joystick0[1], ~joystick0[2], ~joystick0[0], ~joystick0[3] };
    assign coleco_joy1 = (coleco_kp == 1) ? { 1'b1, ~joystick1[5], 2'b11, 4'hF }
                                          : { 1'b1, ~joystick1[4], 2'b11,
                                              ~joystick1[1], ~joystick1[2], ~joystick1[0], ~joystick1[3] };
    wire console_joy_r;
    assign console_joy_r = ( bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0 && (
                             (console_mode == 2'b01 && bus_addr[7:1] == 7'b1101110) ||
                             (console_mode == 2'b10 && bus_addr[7:5] == 3'b111) ) ) ? 1 : 0;
    wire [7:0] console_joy_data;
    assign console_joy_data = (console_mode == 2'b01)
                                ? ( (bus_addr[0] == 0) ? sg_dc : sg_dd )
                                : ( (bus_addr[1] == 0) ? coleco_joy0 : coleco_joy1 );
    //pausa SG-1000 (boton de consola = NMI): tecla F10
    reg sg_pause_d;
    reg sg_pause_nmi;
    always @ (posedge clk_27m) begin
        sg_pause_d <= keyboard[67];
        sg_pause_nmi <= (keyboard[67] == 1 && sg_pause_d == 0) ? 1 : 0;
    end
    // ========================================================================

    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27 == 1 ) begin
            if (config_enable_stereo == 1) begin
                audio_sample   <= { 2'b0 , psgSound3 , 6'b000000 } + scc_term + jt2413_wav + sn_term;
                audio_sample_r <= { 2'b0 , psg2Sound3 , 6'b000000 } + { scc2x_wav, 1'b0 } + jt2413_wav + sn_term;
            end
            else begin
                audio_sample   <= { 2'b0 , psgSound3 , 6'b000000 } + { 2'b0 , psg2Sound3 , 6'b000000 } + scc_term + { scc2x_wav, 1'b0 } + jt2413_wav + sn_term;
                audio_sample_r <= { 2'b0 , psgSound3 , 6'b000000 } + { 2'b0 , psg2Sound3 , 6'b000000 } + scc_term + { scc2x_wav, 1'b0 } + jt2413_wav + sn_term;
            end
        end
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
    wire config_enable_wait;
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
    reg [7:0] config3_ff = 0;       // puerto #43: sram_cfg de la megaram (volatil)
    wire config4_req;
    reg [7:0] config4_ff = 0;       // puerto #44: modo consola (volatil; reset -> MSX)
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
            if (config4_req == 1 ) begin
                config4_ff <= cpu_dout;
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
            end
            else begin
                config1_ff <= config_sig[2];
                config2_ff <= config_sig[3];
                config_turbo_boot_ff <= (config_sig[4] == 8'h54) ? 1'b1 : 1'b0;
            end
        end
        // escritura del puerto #45 (menu): mismo bloque que la carga init para un
        // unico driver; config5_req dura todo el ciclo OUT (re-latch inocuo) y no
        // puede coincidir con config_init (el CPU arranca tras el stream de flash)
        if (config5_req == 1 ) begin
            config_turbo_boot_ff <= cpu_dout[0];
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
    assign config0_req = (console_mode == 2'b00 && bus_addr[7:0] == 8'h40 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config1_req = (config_ok == 1 && bus_addr[7:0] == 8'h41 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config2_req = (config_ok == 1 && bus_addr[7:0] == 8'h42 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config3_req = (config_ok == 1 && console_mode == 2'b00 && bus_addr[7:0] == 8'h43 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config4_req = (config_ok == 1 && console_mode == 2'b00 && bus_addr[7:0] == 8'h44 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config5_req = (config_ok == 1 && bus_addr[7:0] == 8'h45 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    //modo consola (SG-1000 / ColecoVision): en consola se apagan los responders
    //MSX (memoria e I/O conflictiva); salida = reset fisico (config4 -> 0)
    //el cambio de mapa es atomico: la escritura a #44 solo ARMA el modo; se
    //activa en el fetch M1 de 0000h (el "jp 0" del menu aterriza ya en consola)
    reg [1:0] console_live = 0;
    always @ (posedge clk_27m) begin
        if (bus_reset_n == 0) console_live <= 0;
        else if (bus_addr == 16'h0000 && bus_mreq_n == 0 && bus_rd_n == 0)
            console_live <= config4_ff[1:0];
    end
    wire [1:0] console_mode;
    assign console_mode = console_live;
    assign config_enable_scanlines = config1_ff[3];
    //assign config_keyboard = config2_ff[4:3];
    assign config_enable_wait = config2_ff[3];
    assign config_enable_stereo = config2_ff[5];
    assign config_enable_16_9 = config2_ff[4];
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
    wire pana41_wr = (pana_sel == 1 && console_mode == 2'b00 && bus_addr[7:0] == 8'h41 &&
                      bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) ? 1 : 0;
    wire [7:0] pana_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                           ( bus_addr[3:0] == 4'h1 ) ? ( turbo ? 8'hfa : 8'hfb ) : 8'hff;

    assign config_req = (console_mode == 2'b00 && bus_addr[7:4] == 4'h4 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign config_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                         ( bus_addr[3:0] == 4'h1 ) ? config1_ff :
                         ( bus_addr[3:0] == 4'h2 ) ? config2_ff :
                         ( bus_addr[3:0] == 4'h3 ) ? config3_ff :
                         ( bus_addr[3:0] == 4'h4 ) ? config4_ff :
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
    wire config_enable_wait;
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
    assign config_enable_wait = 0;
    wire config_enable_stereo;
    assign config_enable_stereo = 0;
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
                             (flash_write_counter == 8'd04) ? (config_turbo_boot_ff ? 8'h54 : 8'h00) : 8'hff;
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
        .addr(ff_flash_addr),
        .rd(ff_flash_rd),
        .dout(flash_dout),
        .data_ready(flash_data_ready),
        .busy(flash_busy),
        .terminate(ff_flash_terminate),
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
        megarom_req <=     ( console_mode == 2'b00 && config_enable_sdcard == 1 && bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_rd_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (page_num[1] == 1 || page_num[2] == 1) ) ? 1 : 0;
        megarom_page_req <= ( console_mode == 2'b00 && bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_wr_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && bus_addr == 16'h6000 ) ? 1 : 0;
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
        sram_cs_w <= console_mode == 2'b00 && config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n == 1 && bus_m1_n == 1 && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && ( bus_addr >= SDC_SDATA && bus_addr < SDC_ENABLE) ? 1 : 0;
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
        sd_cs_w <= console_mode == 2'b00 && config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n && bus_m1_n && bus_mreq_n == 0 && pri_slot_num[SD_SLOT] == 1 && exp_slotx_num[2] == 1 && (bus_addr >= SDC_ENABLE && bus_addr <= SDC_END) ? 1 : 0;
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
    assign swio_req_r = (console_mode == 2'b00 && config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign swio_req_w = (console_mode == 2'b00 && config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
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
    assign usb_uart_tx = 1'b1;      // UART idle

    // ===== STANDALONE MERGE: discrete status LEDs (active low) — from MSXnano =====
    // LED[5] TURBO: solid = turbo ON (~4.13MHz); blink (~1.8Hz) = real-MSX speed (also "alive"). LED[4] SD busy;
    // LED[3] joy0 fire B; LED[2] joy0 fire A; LED[1] joy0 any dir; LED[0] joy1 any input
    reg led_heartbeat = 1'b1;
    reg [19:0] led_cnt;
    always @(posedge clk_54m or negedge bus_reset_n) begin
        if (!bus_reset_n) begin
            led_cnt       <= 0;
            led_heartbeat <= 1'b1;
        end else if (clk_enable_3m6_54) begin
            if (led_cnt == 20'd999999) begin
                led_cnt       <= 0;
                led_heartbeat <= ~led_heartbeat;
            end else begin
                led_cnt <= led_cnt + 1;
            end
        end
    end

    assign led[5] = turbo ? 1'b0 : led_heartbeat;  // active-low: 0=solid lit (turbo ON), else heartbeat blink (real-MSX)
    assign led[4] = ~sd_busy_w;
    assign led[3] = ~joystick0[5];
    assign led[2] = ~joystick0[4];
    assign led[1] = ~(|joystick0[3:0]);
    assign led[0] = ~(|joystick1[5:0]);

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
    // v3.1: PMOD0 = diagnostico del puente de video (LEDs activo-bajo: ON=activo)
    assign dbg_pmod0[0] = ~dbg_bridge_w[0];   // LED1 parpadeo = VS del VDP vivo (frames saliendo)
    assign dbg_pmod0[1] = ~dbg_bridge_w[1];   // LED2 ON = el puente CAPTURA pixeles (ventana activa)
    assign dbg_pmod0[2] = ~dbg_bridge_w[2];   // LED3 ON = contenido NO-negro capturado (imagen real)
    assign dbg_pmod0[3] = ~dbg_bridge_w[4];   // LED4 ON = hdmi_rst llegando al lado 74.25 (lock OK)
    assign dbg_pmod0[4] = ~dbg_bridge_w[5];   // LED5 ON = ventana de lectura activa en el 720p
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
`define SCC_DEBUG_PANEL   // _42dbg: PMOD1 = cadena del SCC (quitar al resolver)
`ifdef SCC_DEBUG_PANEL
    // ===== PANEL SCC (_42dbg) — cada LED un eslabon; el primero APAGADO
    // señala el corte (LEDs activo-bajo: ON = eslabon vivo) =====
    wire scc_dbg_req_act, scc_dbg_wrtreg_act, scc_dbg_wav_act, scc_dbg_term_act;
    led_stretch #(.HOLD(27000000)) st_sccreq  (.clk(clk_54m), .rst_n(bus_reset_n),
        .trig(scc_req), .active(scc_dbg_req_act));                       // ~0.5s
    led_stretch #(.HOLD(27000000)) st_sccwrtr (.clk(clk_54m), .rst_n(bus_reset_n),
        .trig(scc_wrt && bus_addr[7]), .active(scc_dbg_wrtreg_act));     // escrituras 9880+ (regs freq/vol)
    led_stretch #(.HOLD(27000000)) st_sccwav  (.clk(clk_54m), .rst_n(bus_reset_n),
        .trig(scc_wav != 15'd0), .active(scc_dbg_wav_act));              // el chip oscila
    led_stretch #(.HOLD(27000000)) st_sccterm (.clk(clk_27m), .rst_n(bus_reset_n),
        .trig(scc_term != 16'd0), .active(scc_dbg_term_act));            // señal en el mixer
    assign dbg_pmod1[0] = ~dbg_scc_enable_w;      // LED1 ON = ventana SCC abierta (bank2==3F)
    assign dbg_pmod1[1] = ~scc_dbg_req_act;       // LED2 ON = accesos llegando a la ventana
    assign dbg_pmod1[2] = ~scc_dbg_wrtreg_act;    // LED3 ON = escrituras de REGISTROS (freq/vol)
    assign dbg_pmod1[3] = ~scc_dbg_wav_act;       // LED4 ON = EL CHIP OSCILA (scc_wav != 0)
`else
    assign dbg_pmod1[0] = ~dbg_psgwr_led;     // LED ON = la CPU esta ESCRIBIENDO al PSG
    assign dbg_pmod1[1] = ~clk_1m8;           // parpadeo rapido (se ve medio-encendido) = ENA vivo
    assign dbg_pmod1[2] = ~dbg_psgout_led;    // LED ON = el PSG SACA amplitud != 0
    assign dbg_pmod1[3] = psgtest_win ? 1'b0 : 1'b1;  // ON = ventana de beep (1s-3s tras reset)
`endif
`ifdef SCC_DEBUG_PANEL
    assign dbg_pmod1[4] = ~(map_sel == 2'b10);    // LED5 ON = gate del mixer abierto (modo SCC)
    assign dbg_pmod1[5] = ~scc_dbg_term_act;      // LED6 ON = scc_term != 0 (señal EN el mixer)
`elsif ENABLE_USB_KBD
    assign dbg_pmod1[4] = ~(usb1_typ == 2'd1 || usb2_typ == 2'd1); // LED ON = teclado USB-A enumerado
    // v3.2: conerr solo con dispositivo enumerado — el puerto VACIO reintenta
    // cada 200ms y parpadeaba el LED sin que fuera un error (veredicto _39)
    assign dbg_pmod1[5] = ~((usb1_conerr && usb1_typ != 2'd0) | (usb2_conerr && usb2_typ != 2'd0));
`else
    assign dbg_pmod1[4] = 1'b1;
    assign dbg_pmod1[5] = 1'b1;
`endif

    // ===== External WS2812B status strip (8 LEDs, e.g. CJMCU-2812-8) on the case =====
    // One data pin (ws2812_led) drives the whole chain; colours from internal state.
    wire caps_on  = ~ppi_port_c[6];                       // MSX CAPS LED (PPI port C bit6, active-low)
    wire kana_on  = keyboard[106];                        // CODE/KANA key held (Left Alt)
    wire joy_on   = (|joystick0[5:0]) | (|joystick1[5:0]);
    wire kbd_raw  = |keyboard;                            // any key held
`ifdef ENABLE_WIFI
    wire wifi_raw = ~uart_tx | ~uart_rx;                  // WiFi UART active (idle = high)
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
    wire [7:0] usb1_mods, usb1_k1, usb1_k2, usb1_k3, usb1_k4;
    wire [7:0] usb2_mods, usb2_k1, usb2_k2, usb2_k3, usb2_k4;
    usb_hid_host usb_host1 (
        .usbclk (clk_usb12), .usbrst_n (pll12_lock),
        .usb_dm (usb1_dn), .usb_dp (usb1_dp),
        .typ (usb1_typ), .report (usb1_report), .conerr (usb1_conerr),
        .key_modifiers (usb1_mods),
        .key1 (usb1_k1), .key2 (usb1_k2), .key3 (usb1_k3), .key4 (usb1_k4),
        .mouse_btn (), .mouse_dx (), .mouse_dy (),
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
        .mouse_btn (), .mouse_dx (), .mouse_dy (),
        .game_snes (), .game_l (), .game_r (), .game_u (), .game_d (),
        .game_a (), .game_b (), .game_x (), .game_y (), .game_sel (), .game_sta (),
        .game_lb (), .game_rb (),
        .dbg_hid_report ()
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
    fpga_companion fpga_companion_inst
    (
        .clk (clk_27m),
        .reset (~bus_reset_n),

        .spi_sclk (spi_sclk),
        .spi_csn (spi_csn),
        .spi_dir (spi_dir),
        .spi_dat (spi_dat),
        .spi_irqn (spi_irqn),

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