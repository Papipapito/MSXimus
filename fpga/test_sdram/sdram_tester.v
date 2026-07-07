// ============================================================================
//  sdram_tester.v — AUTO-TEST de la SDRAM externa (W9825) via memory_ctrl REAL
// ----------------------------------------------------------------------------
//  Ejercita EL MISMO controlador del core (memory_ctrl, 16 bits) con los
//  mismos strobes de fase que genera el VDP (dh=13.5MHz, dl=6.75MHz):
//   - Puerto CPU  (ram_*): 2 barridos (consecutivo + saltos de fila/banco),
//     escribir patron -> leer y comparar.
//   - Puerto VRAM (vram_*): barrido de bytes por ambas lanes -> leer words.
//  En bucle infinito acumulando errores. Simulable (sin PLL dentro).
//  status: 0=corriendo, 1=PASS (>=1 pasada, 0 errores), 2=FALLO CPU, 3=FALLO VRAM
// ============================================================================
`default_nettype none

module sdram_tester #(
    parameter SDCLK_INVERT = 1'b0,
    parameter SWEEP_BITS   = 12,         // 4096 accesos por barrido
    parameter INIT_CYCLES  = 25'h1000000 // ~310ms @54M (la sim lo acorta)
)(
    input  wire clk_108m,
    input  wire clk_54m,
    input  wire rst_n,

    // SDRAM fisica (pasa-through a memory_ctrl)
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

    // resultado
    output reg  [1:0]  status = 2'd0,
    output reg         pass_tick = 1'b0,      // pulso al completar cada pasada
    output reg  [15:0] err_cpu  = 16'd0,
    output reg  [15:0] err_vram = 16'd0
);

    // ---- strobes de fase como los del VDP (dh 13.5MHz, dl 6.75MHz) ----
    reg [3:0] phc = 0;
    always @(posedge clk_108m) phc <= phc + 1'b1;
    wire video_dhclk = ~phc[2];
    wire video_dlclk = ~phc[3];

    // refresh periodico (como el RFSH del Z80): ventana 1 de cada 32 ciclos de 54
    reg [7:0] rfsh_cnt = 0;
    always @(posedge clk_54m) rfsh_cnt <= rfsh_cnt + 1'b1;
    wire rfsh_n = (rfsh_cnt != 8'd0);   // 1/256: cadencia realista de RFSH Z80

    // ---- memory_ctrl real ----
    reg  [7:0]  ram_din = 0;
    reg         ram_req = 0;
    reg         ram_write = 0;
    reg  [22:0] ram_addr = 0;
    reg  [7:0]  vram_din = 0;
    reg         vram_write = 0;
    reg  [16:0] vram_addr = 0;
    wire [7:0]  ram_dout;
    wire [15:0] vram_dout;
    wire        ram_busy;

    memory_ctrl #(.SDCLK_INVERT(SDCLK_INVERT)) mem1 (
        .clk_27m     (clk_54m),      // como en top.v: el puerto lleva 54
        .clk_108m    (clk_108m),
        .bus_reset_n (rst_n),
        .video_dhclk (video_dhclk),
        .video_dlclk (video_dlclk),
        .ram_din     (ram_din),
        .ram_req     (ram_req),
        .ram_write   (ram_write),
        .ram_addr    (ram_addr),
        .vram_din    (vram_din),
        .vram_write  (vram_write),
        .vram_addr   (vram_addr),
        .bus_rfsh_n  (rfsh_n),
        .ram_dout    (ram_dout),
        .vram_dout   (vram_dout),
        .ram_busy    (ram_busy),
        .O_sdram_clk (O_sdram_clk),
        .O_sdram_cke (O_sdram_cke),
        .O_sdram_cs_n(O_sdram_cs_n),
        .O_sdram_cas_n(O_sdram_cas_n),
        .O_sdram_ras_n(O_sdram_ras_n),
        .O_sdram_wen_n(O_sdram_wen_n),
        .IO_sdram_dq (IO_sdram_dq),
        .O_sdram_addr(O_sdram_addr),
        .O_sdram_ba  (O_sdram_ba),
        .O_sdram_dqm (O_sdram_dqm)
    );

    // ---- patrones ----
    function [7:0] pat_cpu(input [22:0] a);
        pat_cpu = a[7:0] ^ a[15:8] ^ {1'b0, a[22:16]} ^ 8'h5A;
    endfunction
    function [7:0] pat_vram(input [16:0] a);
        pat_vram = a[7:0] ^ {1'b0, a[16:10]} ^ 8'hC3;
    endfunction

    // barrido 2: saltos grandes (cruza filas y bancos)
    function [22:0] addr_stride(input [SWEEP_BITS-1:0] i);
        addr_stride = {i[1:0], i[SWEEP_BITS-1:2], 11'h2B5};  // banco=i[1:0], resto arriba
    endfunction

    // ---- FSM del test @clk_54m ----
    localparam T_INIT       = 4'd0;   // esperar init SDRAM (RstSeq) ~200ms
    localparam T_W1_ISSUE   = 4'd1;   // barrido 1 consecutivo: escribir
    localparam T_W1_WAITB   = 4'd2;
    localparam T_W1_WAITE   = 4'd3;
    localparam T_R1_ISSUE   = 4'd4;   // leer + comparar
    localparam T_R1_WAITB   = 4'd5;
    localparam T_R1_WAITE   = 4'd6;
    localparam T_VW_SET     = 4'd7;   // VRAM write (mantener ventana)
    localparam T_VW_HOLD    = 4'd8;
    localparam T_VR_SET     = 4'd9;   // VRAM read
    localparam T_VR_HOLD    = 4'd10;
    localparam T_VR_CHECK   = 4'd11;
    localparam T_PASS       = 4'd12;
    localparam T_VW_GAP     = 4'd13;  // señales viejas estables tras soltar write
    localparam T_VW_PRE     = 4'd14;  // addr/din nuevos con write=0 una ventana:
                                      //  la fila se muestrea en fase 0 y el write
                                      //  se decide en fase 1 — subir write sin
                                      //  pre-espera escribe con FILA VIEJA (el
                                      //  VDP real cambia sincronizado a sus fases)

    reg [3:0]  tst = T_INIT;
    reg [24:0] init_cnt = 0;
    reg [SWEEP_BITS-1:0] idx = 0;
    reg        sweep2 = 0;            // 0 = consecutivo, 1 = strides
    reg [5:0]  hold_cnt = 0;
    reg        vlane = 0;             // lane del barrido VRAM
    reg [9:0]  vidx = 0;              // 1024 words de VRAM
    reg        pass_done_once = 0;

    wire [22:0] cur_addr = sweep2 ? addr_stride(idx) : {11'h001, idx};
    wire [16:0] cur_vaddr = {vlane, 6'h15, vidx};

    always @(posedge clk_54m or negedge rst_n) begin
        if (!rst_n) begin
            tst <= T_INIT; init_cnt <= 0; idx <= 0; sweep2 <= 0;
            ram_req <= 0; ram_write <= 0; vram_write <= 0;
            err_cpu <= 0; err_vram <= 0; status <= 2'd0;
            pass_tick <= 0; pass_done_once <= 0; vidx <= 0; vlane <= 0;
        end else begin
            pass_tick <= 1'b0;
            case (tst)
                T_INIT: begin                    // esperar el init de la SDRAM
                    init_cnt <= init_cnt + 1'b1;
                    if (init_cnt == INIT_CYCLES) tst <= T_W1_ISSUE;
                end

                // ---------- escribir barrido ----------
                T_W1_ISSUE: begin
                    ram_addr  <= cur_addr;
                    ram_din   <= pat_cpu(cur_addr);
                    ram_write <= 1'b1;
                    ram_req   <= 1'b1;
                    tst <= T_W1_WAITB;
                end
                T_W1_WAITB: if (ram_busy) tst <= T_W1_WAITE;
                T_W1_WAITE: if (!ram_busy) begin
                    ram_req <= 1'b0; ram_write <= 1'b0;
                    idx <= idx + 1'b1;
                    if (&idx) tst <= T_R1_ISSUE;
                    else      tst <= T_W1_ISSUE;
                end

                // ---------- leer y comparar ----------
                T_R1_ISSUE: begin
                    ram_addr  <= cur_addr;
                    ram_write <= 1'b0;
                    ram_req   <= 1'b1;
                    tst <= T_R1_WAITB;
                end
                T_R1_WAITB: if (ram_busy) tst <= T_R1_WAITE;
                T_R1_WAITE: if (!ram_busy) begin
                    ram_req <= 1'b0;
                    if (ram_dout != pat_cpu(cur_addr) && !(&err_cpu))
                        err_cpu <= err_cpu + 1'b1;
                    idx <= idx + 1'b1;
                    if (&idx) begin
                        if (!sweep2) begin sweep2 <= 1'b1; tst <= T_W1_ISSUE; end
                        else begin sweep2 <= 1'b0; vidx <= 0; vlane <= 0; tst <= T_VW_SET; end
                    end else
                        tst <= T_R1_ISSUE;
                end

                // ---------- VRAM: escribir byte (mantener toda la ventana) ----------
                T_VW_SET: begin
                    vram_addr  <= cur_vaddr;
                    vram_din   <= pat_vram(cur_vaddr);
                    vram_write <= 1'b0;         // aun NO: primero estabilizar addr
                    hold_cnt   <= 0;
                    tst <= T_VW_PRE;
                end
                T_VW_PRE: begin                 // una ventana entera con addr nuevo
                    hold_cnt <= hold_cnt + 1'b1;
                    if (hold_cnt == 6'd15) begin
                        vram_write <= 1'b1;
                        hold_cnt   <= 0;
                        tst <= T_VW_HOLD;
                    end
                end
                T_VW_HOLD: begin
                    hold_cnt <= hold_cnt + 1'b1;
                    if (&hold_cnt) begin        // ventanas de escritura completadas
                        vram_write <= 1'b0;     // soltar write; addr/din SIGUEN estables
                        hold_cnt <= 0;
                        tst <= T_VW_GAP;
                    end
                end
                T_VW_GAP: begin                 // dejar terminar la ventana en vuelo
                    hold_cnt <= hold_cnt + 1'b1;
                    if (hold_cnt == 6'd15) begin
                        {vlane, vidx} <= {vlane, vidx} + 1'b1;
                        if (vlane && &vidx) begin vidx <= 0; vlane <= 0; tst <= T_VR_SET; end
                        else tst <= T_VW_SET;
                    end
                end

                // ---------- VRAM: leer word y comparar ambas lanes ----------
                T_VR_SET: begin
                    vram_addr  <= {1'b0, cur_vaddr[15:0]};   // lane no importa al leer
                    vram_write <= 1'b0;
                    hold_cnt   <= 0;
                    tst <= T_VR_HOLD;
                end
                T_VR_HOLD: begin
                    hold_cnt <= hold_cnt + 1'b1;
                    if (&hold_cnt) tst <= T_VR_CHECK;
                end
                T_VR_CHECK: begin
                    if (vram_dout[7:0]  != pat_vram({1'b0, cur_vaddr[15:0]}) && !(&err_vram))
                        err_vram <= err_vram + 1'b1;
                    if (vram_dout[15:8] != pat_vram({1'b1, cur_vaddr[15:0]}) && !(&err_vram))
                        err_vram <= err_vram + 1'b1;
                    vidx <= vidx + 1'b1;
                    if (&vidx) tst <= T_PASS;
                    else       tst <= T_VR_SET;
                end

                T_PASS: begin
                    pass_done_once <= 1'b1;
                    pass_tick <= 1'b1;
                    idx <= 0; sweep2 <= 0; vidx <= 0; vlane <= 0;
                    tst <= T_W1_ISSUE;          // bucle infinito
                end
                default: tst <= T_INIT;
            endcase

            // status
            if (err_cpu != 0)       status <= 2'd2;
            else if (err_vram != 0) status <= 2'd3;
            else if (pass_done_once) status <= 2'd1;
            else                    status <= 2'd0;
        end
    end

endmodule

`default_nettype wire
