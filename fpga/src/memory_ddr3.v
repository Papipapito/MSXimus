// ============================================================================
//  memory_ddr3.v — Wrapper DDR3 del port a la Tang Console 60K (GW5AT-60)
// ----------------------------------------------------------------------------
//  SKELETON (P2). Sustituye a memory.v (secuenciador SDR del GW2AR) preservando
//  la interfaz ram_*/vram_* hacia el core. Ver docs/DDR3_WRAPPER.md y
//  docs/MEMORY_CONTRACT.md. NO buildeable aún: faltan la IP DDR3 generada
//  (DDR3_Memory_Interface_Top), el dpram de VRAM y el top.v portado. Los cuerpos
//  de FSM/CDC/pack van como TODO; se iteran en simulación (patrón megaram_equiv).
//
//  ARQUITECTURA (docs/DDR3_WRAPPER §0):
//    - VRAM (128KB) -> BRAM dual-port: latencia fija, escritura VDP NUNCA se
//      descarta => requisito MG2 satisfecho por construcción.
//    - CPU/mapper/megaram/ROM -> DDR3 via la IP, con handshake ram_busy real
//      (requisito ENABLE_WAIT_ADAPTIVE) + CDC 54<->clk_out + pack byte<->128b.
// ============================================================================
`default_nettype none

module memory_ddr3 #(
    parameter APP_DATA_WIDTH = 128,   // 1:4 + DQ16 (confirmar en params generados)
    parameter APP_MASK_WIDTH = 16,    // APP_DATA_WIDTH/8
    parameter ADDR_WIDTH     = 28     // dir de la IP (rank+bank+row+col) — confirmar
)(
    // ---- Relojes / reset del core (nombres preservados de memory_ctrl) ----
    input  wire        clk_27m,        // OJO: top.v lo alimenta con clk_54m (dominio ram_*)
    input  wire        clk_108m,       // ya no se usa para memoria; referencia
    input  wire        bus_reset_n,

    // ---- Strobes de fase de vídeo (solo para el path VRAM/BRAM ahora) ----
    input  wire        video_dhclk,
    input  wire        video_dlclk,

    // ---- Interfaz CPU (a DDR3) — handshake @clk_54m ----
    input  wire [7:0]  ram_din,
    input  wire        ram_req,
    input  wire        ram_write,
    input  wire [22:0] ram_addr,       // espacio de 8 MB; banco por [22:21]
    output wire [7:0]  ram_dout,
    output wire        ram_busy,       // AHORA sí se usa (requisito 2)
    input  wire        bus_rfsh_n,     // la IP hace su refresh; no arma refresh aqui

    // ---- Interfaz VRAM (a BRAM) — dominio clk_w del VDP ----
    input  wire [7:0]  vram_din,
    input  wire        vram_write,
    input  wire [16:0] vram_addr,      // 17 bits (NO 16)
    output wire [15:0] vram_dout,      // palabra

    // ---- Relojes de la DDR3 IP ----
    input  wire        memory_clk,     // PHY DDR3 (de un PLL; freq segun chip)
    input  wire        pll_lock,       // lock del PLL de memory_clk
    output wire        init_calib_complete,  // gatea el arranque del core

    // ---- Pines físicos DDR3 (hard-IP; SIN IO_LOC en el .cst) ----
    output wire [13:0] O_ddr_addr,
    output wire [2:0]  O_ddr_ba,
    output wire        O_ddr_cs_n,
    output wire        O_ddr_ras_n,
    output wire        O_ddr_cas_n,
    output wire        O_ddr_we_n,
    output wire        O_ddr_clk,
    output wire        O_ddr_clk_n,
    output wire        O_ddr_cke,
    output wire        O_ddr_odt,
    output wire        O_ddr_reset_n,
    output wire [1:0]  O_ddr_dqm,
    inout  wire [15:0] IO_ddr_dq,
    inout  wire [1:0]  IO_ddr_dqs,
    inout  wire [1:0]  IO_ddr_dqs_n
);

    // clk_54m es el nombre real del dominio del handshake CPU
    wire clk_54m = clk_27m;

    // ========================================================================
    //  (A) VRAM en BRAM dual-port  — requisito MG2 GRATIS
    //  TODO: dpram 128KB. Mapeo byte/palabra EXACTO segun memory.v:304-305,
    //  340,437-443 (vram_addr[16]=byte alto/bajo; vram_dout = palabra). Puerto
    //  A: escritura VDP (clk_w, vram_din/vram_write/vram_addr). Puerto B: lectura
    //  palabra -> vram_dout. Latencia fija; vram_write SIEMPRE se acepta.
    // ========================================================================
    // vram_dpram u_vram (
    //     .clk    (video pixel clk / clk_54m),
    //     .we     (vram_write), .waddr(vram_addr), .wdata(vram_din),
    //     .raddr  (vram_addr),  .rdata(vram_dout) );
    assign vram_dout = 16'h0000;   // TODO: BRAM real

    // ========================================================================
    //  (B) IP DDR3 (interfaz de usuario "Controller" — DDR3_PHY_MC)
    //  Puertos reales de DDR3_TOP.v (toolchain). clk_out = dominio de la app.
    // ========================================================================
    wire                        clk_out;        // reloj de la app DDR3 (memory_clk/4)
    wire                        ddr_rst;
    wire                        cmd_ready;
    wire [2:0]                  cmd;             // 0=WRITE / 1=READ (confirmar DDR3_define.v)
    wire                        cmd_en;
    wire [ADDR_WIDTH-1:0]       app_addr;
    wire                        wr_data_rdy;
    wire [APP_DATA_WIDTH-1:0]   wr_data;
    wire                        wr_data_en;
    wire                        wr_data_end;
    wire [APP_MASK_WIDTH-1:0]   wr_data_mask;
    wire [APP_DATA_WIDTH-1:0]   rd_data;
    wire                        rd_data_valid;
    wire                        rd_data_end;

    /* --- descomentar cuando la IP DDR3 este generada ---
    DDR3_Memory_Interface_Top u_ddr3 (
        .clk                (clk_54m),          // reloj de usuario de referencia
        .memory_clk         (memory_clk),
        .pll_lock           (pll_lock),
        .rst_n              (bus_reset_n),
        .clk_out            (clk_out),          // -> dominio de la FSM DDR3-side
        .ddr_rst            (ddr_rst),
        .init_calib_complete(init_calib_complete),
        // comando
        .cmd_ready          (cmd_ready),
        .cmd                (cmd),
        .cmd_en             (cmd_en),
        .addr               (app_addr),
        // escritura
        .wr_data_rdy        (wr_data_rdy),
        .wr_data            (wr_data),
        .wr_data_en         (wr_data_en),
        .wr_data_end        (wr_data_end),
        .wr_data_mask       (wr_data_mask),
        // lectura
        .rd_data            (rd_data),
        .rd_data_valid      (rd_data_valid),
        .rd_data_end        (rd_data_end),
        // refresh (auto por defecto)
        .sr_req(1'b0), .ref_req(1'b0), .burst(1'b1),
        // pines DDR3
        .O_ddr_addr(O_ddr_addr), .O_ddr_ba(O_ddr_ba), .O_ddr_cs_n(O_ddr_cs_n),
        .O_ddr_ras_n(O_ddr_ras_n), .O_ddr_cas_n(O_ddr_cas_n), .O_ddr_we_n(O_ddr_we_n),
        .O_ddr_clk(O_ddr_clk), .O_ddr_clk_n(O_ddr_clk_n), .O_ddr_cke(O_ddr_cke),
        .O_ddr_odt(O_ddr_odt), .O_ddr_reset_n(O_ddr_reset_n), .O_ddr_dqm(O_ddr_dqm),
        .IO_ddr_dq(IO_ddr_dq), .IO_ddr_dqs(IO_ddr_dqs), .IO_ddr_dqs_n(IO_ddr_dqs_n)
    );
    */

    // ========================================================================
    //  (C) CDC 54 <-> clk_out  +  FSM CPU  +  pack/unpack byte<->128b
    //  TODO (docs/DDR3_WRAPPER §5):
    //   - CDC: handshake req/ack 2FF (o FIFO async) entre el dominio ram_* (54)
    //     y clk_out. El path CPU tolera la latencia via ram_busy.
    //   - FSM @clk_out: al recibir petición cruzada, emitir cmd/addr con
    //     cmd_en/cmd_ready; si escritura, wr_data = byte replicado en su lane +
    //     wr_data_mask con SOLO ese byte (evita read-modify-write), wr_data_end;
    //     si lectura, esperar rd_data_valid y capturar el byte de rd_data segun
    //     ram_addr[3:0] (16 bytes/palabra).
    //   - ram_busy: sube al aceptar ram_req; baja SOLO con dato leido cruzado el
    //     CDC (o escritura comprometida). Antes de init_calib_complete: no
    //     aceptar ram_req (retener el core).
    //   - Mapa de bancos ram_addr[22:0] -> app_addr (top.v:1389-1418; VRAM fuera).
    // ========================================================================
    assign ram_dout     = 8'h00;   // TODO: byte de rd_data
    assign ram_busy     = 1'b0;    // TODO: handshake real (requisito 2)
    assign cmd          = 3'b000;
    assign cmd_en       = 1'b0;
    assign app_addr     = {ADDR_WIDTH{1'b0}};
    assign wr_data      = {APP_DATA_WIDTH{1'b0}};
    assign wr_data_en   = 1'b0;
    assign wr_data_end  = 1'b0;
    assign wr_data_mask = {APP_MASK_WIDTH{1'b1}};   // todo enmascarado = no escribe

`ifndef DDR3_IP_PRESENT
    // Sin la IP generada, expon un init "listo" para que el resto compile en sim.
    assign init_calib_complete = 1'b1;
    assign clk_out             = clk_54m;
    assign {O_ddr_addr,O_ddr_ba,O_ddr_cs_n,O_ddr_ras_n,O_ddr_cas_n,O_ddr_we_n,
            O_ddr_clk,O_ddr_clk_n,O_ddr_cke,O_ddr_odt,O_ddr_reset_n,O_ddr_dqm} = 0;
`endif

endmodule

`default_nettype wire
