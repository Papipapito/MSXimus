// ============================================================================
// v9968_ddr3_backend.v — VRAM del V9968 en la DDR3 del SOM (EXPERIMENTO _128X)
//
// Encargo: mover la VRAM de la SDRAM compartida del dock a la DDR3 del SOM.
// ADVERTENCIA HISTORICA (saga _94-_103): la DDR3 de esta placa es
// ANALOGICAMENTE MARGINAL — ojo de lectura mal-fijo por arranque (loteria de
// calibracion), corrupcion en lecturas frias. La wave OPL4 huyo de aqui a la
// SDRAM (_104) tras 8 builds de blindajes digitales. Este cliente hereda
// TODAS las vacunas de aquella guerra:
//   _87  watchdog de calibracion (~42ms, reintentos con reset de IP)
//   _95  watchdog de operacion (~0.9ms: completa EN FALSO con FF y cuenta)
//   _95  deteccion pegajosa de caida de calibracion (calib_drop)
//   _100/_101 recalibracion forzada con reset de PLL (billete nuevo del ojo)
//   _93/_97 disciplina de payloads: asentado 1 ciclo tras el flanco
//
// Cliente: DOS canales con el protocolo wv2 de memory.v (req NIVEL +
// done PULSO + dout[15:0]) en el dominio clk_x1 (74.25MHz, lo genera la IP).
// Los v9968_sdram_bridge existentes (CDC toggle 85.9<->far) se conectan tal
// cual con su lado far a clk_x1: el shim NO se toca.
//   canal A = bk del shim (lecturas palabra baja + TODAS las escrituras byte)
//   canal B = bk2 (solo lecturas, palabra alta)
// COMBO DE LINEA: bk y bk2 piden las dos mitades de la MISMA palabra de 32
// bits => misma linea de 128 bits => si ambos estan pendientes y comparten
// addr[21:4], UNA sola rafaga de lectura sirve a los dos (~175ns la palabra
// entera vs ~800ns de la danza SDRAM en serie).
//
// Escrituras byte: rafaga de escritura con mascara DM (1=NO escribir) — un
// byte por operacion, fire&forget (como la wave).
//
// Mapa: mismo mapeo de la wave ({7'd0, addr[21:4], 3'b000}, ventana de 4MB
// en la base del chip). La VRAM ocupa VRAM_BASE 0x280000..0x2BFFFF como en
// la SDRAM (la wave YA NO vive en la DDR3: el chip entero es nuestro).
//
// Dominios: clk_x1 (FSM + canales), clk_g50 (mdclk/watchdogs), clk_27
// (refclk del PLL). Receta PLL 297MHz + danza mDRP calcada de wave_ddr3
// (nand2mario ddr3_framebuffer, Apache-2.0).
// ============================================================================

module v9968_ddr3_backend (
    // ---- canales VRAM (dominio clk_x1_out; protocolo wv2 nivel/pulso) ----
    input  wire        a_req,         // NIVEL: se mantiene hasta ver a_done
    input  wire        a_we,
    input  wire [21:0] a_addr,        // direccion de BYTE
    input  wire [7:0]  a_wdata,
    output reg  [15:0] a_dout,        // palabra 16b (addr[0] ignorado)
    output reg         a_done,        // PULSO 1 ciclo clk_x1

    input  wire        b_req,         // NIVEL (solo lecturas)
    input  wire [21:0] b_addr,
    output reg  [15:0] b_dout,
    output reg         b_done,        // PULSO 1 ciclo clk_x1

    output wire        clk_x1_out,    // 74.25MHz de la IP: reloj de los canales
    output wire        ready,         // calibracion completada (dominio x1)

    // ---- telemetria (_95): {calib_drop, wd_fires[2:0], wd_ops[3:0]} ----
    output wire [7:0]  diag,

    // ---- recalibracion forzada (_100; toggle, dominio libre) ----
    input  wire        recal_req,

    // ---- relojes ----
    input  wire        clk_27,        // 27MHz (cascada de video, refclk PLL)
    input  wire        clk_g50,       // pad 50MHz (ex_clk_27m, mal llamado)
    input  wire        pll27_lock,    // _87: no soltar el PLL sin el 27 vivo

    // ---- pines DDR3 (del SOM) ----
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
    inout  wire [1:0]  ddr_dqs_n
);

// ---------------------------------------------------------------------------
// POR + lock del arbol de 27 (_87) — verbatim de wave_ddr3
// ---------------------------------------------------------------------------
reg [15:0] por_cnt = 16'd0;
reg        por_done = 1'b0;
always @(posedge clk_g50) begin
    if (!por_done) begin
        if (pll27_lock) begin
            por_cnt <= por_cnt + 16'd1;
            if (&por_cnt) por_done <= 1'b1;
        end
        else por_cnt <= 16'd0;
    end
end

// _100: recalibracion forzada (toggle -> pulso de 256 ciclos)
reg  rc_s1 = 1'b0, rc_s2 = 1'b0, rc_s3 = 1'b0;
reg  [8:0] rc_cnt = 9'd0;
wire rc_pulse = (rc_cnt != 9'd0);
always @(posedge clk_g50) begin
    rc_s1 <= recal_req; rc_s2 <= rc_s1; rc_s3 <= rc_s2;
    if (rc_s3 != rc_s2)          rc_cnt <= 9'd256;
    else if (rc_cnt != 9'd0)     rc_cnt <= rc_cnt - 9'd1;
end

// _87: watchdog de calibracion (~42ms)
reg [21:0] wd_cnt = 22'd0;
reg        wd_rst = 1'b0;
wire       init_calib_complete;
wire       ip_rst_n = ~(wd_rst | rc_pulse);
always @(posedge clk_g50) begin
    if (init_calib_complete || !por_done) begin
        wd_cnt <= 22'd0;
        wd_rst <= 1'b0;
    end
    else begin
        wd_cnt <= wd_cnt + 22'd1;
        wd_rst <= (wd_cnt[21] && (wd_cnt[20:8] == 13'd0));
    end
end

// _95: contar reintentos de calibracion
reg        wd_rst_d  = 1'b0;
reg [2:0]  wd_fires  = 3'd0;
always @(posedge clk_g50) begin
    wd_rst_d <= wd_rst;
    if (wd_rst && !wd_rst_d && wd_fires != 3'd7) wd_fires <= wd_fires + 3'd1;
end

// ---------------------------------------------------------------------------
// PLL 297MHz + danza mDRP — verbatim de wave_ddr3 (_101: la recal resetea
// TAMBIEN el PLL: re-lock con fase nueva = billete de ojo INDEPENDIENTE)
// ---------------------------------------------------------------------------
wire memory_clk;
wire pll_lock;
wire pll_stop;
wire        mdrp_inc;
wire [1:0]  mdrp_op;
wire [7:0]  mdrp_wdata;
wire [7:0]  mdrp_rdata;

pll_ddr3 pll_ddr3_inst (
    .lock   (pll_lock),
    .clkout0(),
    .clkout2(memory_clk),
    .clkin  (clk_27),
    .reset  (~por_done | rc_pulse),
    .mdclk  (clk_g50),
    .mdopc  (mdrp_op),
    .mdainc (mdrp_inc),
    .mdwdi  (mdrp_wdata),
    .mdrdo  (mdrp_rdata)
);

reg mdrp_wr;
reg pll_stop_r;
pll_mDRP_intf u_pll_mDRP_intf (
    .clk       (clk_g50),
    .rst_n     (1'b1),
    .pll_lock  (pll_lock),
    .wr        (mdrp_wr),
    .mdrp_inc  (mdrp_inc),
    .mdrp_op   (mdrp_op),
    .mdrp_wdata(mdrp_wdata),
    .mdrp_rdata(mdrp_rdata)
);

always @(posedge clk_g50) begin
    pll_stop_r <= pll_stop;
    mdrp_wr    <= pll_stop ^ pll_stop_r;
end

// ---------------------------------------------------------------------------
// IP DDR3 (cmd/128b en clk_x1, que la propia IP genera)
// ---------------------------------------------------------------------------
wire         clk_x1;
wire         ddr_rst;

wire         app_rdy;
reg          app_en;
reg  [2:0]   app_cmd;
reg  [27:0]  app_addr;
wire         app_wdf_rdy;
reg          app_wdf_wren;
reg  [15:0]  app_wdf_mask;
wire         app_wdf_end = 1'b1;
reg  [127:0] app_wdf_data;
wire         app_rd_data_valid;
wire         app_rd_data_end;
wire [127:0] app_rd_data;

DDR3_Memory_Interface_Top u_ddr3 (
    .memory_clk      (memory_clk),
    .pll_stop        (pll_stop),
    .clk             (clk_g50),
    .rst_n           (ip_rst_n),
    .cmd_ready       (app_rdy),
    .cmd             (app_cmd),
    .cmd_en          (app_en),
    .addr            (app_addr),
    .wr_data_rdy     (app_wdf_rdy),
    .wr_data         (app_wdf_data),
    .wr_data_en      (app_wdf_wren),
    .wr_data_end     (app_wdf_end),
    .wr_data_mask    (app_wdf_mask),
    .rd_data         (app_rd_data),
    .rd_data_valid   (app_rd_data_valid),
    .rd_data_end     (app_rd_data_end),
    .sr_req          (1'b0),
    .ref_req         (1'b0),
    .sr_ack          (),
    .ref_ack         (),
    .init_calib_complete(init_calib_complete),
    .clk_out         (clk_x1),
    .pll_lock        (pll_lock),
    .burst           (1'b1),
    .ddr_rst         (ddr_rst),
    .O_ddr_addr      (ddr_addr),
    .O_ddr_ba        (ddr_bank),
    .O_ddr_cs_n      (ddr_cs),
    .O_ddr_ras_n     (ddr_ras),
    .O_ddr_cas_n     (ddr_cas),
    .O_ddr_we_n      (ddr_we),
    .O_ddr_clk       (ddr_ck),
    .O_ddr_clk_n     (ddr_ck_n),
    .O_ddr_cke      (ddr_cke),
    .O_ddr_odt       (ddr_odt),
    .O_ddr_reset_n   (ddr_reset_n),
    .O_ddr_dqm       (ddr_dm),
    .IO_ddr_dq       (ddr_dq),
    .IO_ddr_dqs      (ddr_dqs),
    .IO_ddr_dqs_n    (ddr_dqs_n)
);

assign clk_x1_out = clk_x1;

// ---------------------------------------------------------------------------
// FSM de los dos canales (clk_x1). Protocolo wv2: req NIVEL, servir UNA vez
// por flanco de subida (flag *_srv), done PULSO, dout estable tras done.
// Prioridad A > B (A lleva las escrituras y es el canal primario del shim).
// COMBO: si A(lectura) y B pendientes con la misma linea addr[21:4], una
// sola rafaga responde a ambos.
// ---------------------------------------------------------------------------
reg a_srv, b_srv;                      // ya servido (hasta que baje el req)
reg op_b;                              // op en curso: canal B
reg op_combo;                          // esta lectura responde a A y B
reg op_we;
reg [21:0] op_addr;
reg [21:0] op_baddr;                   // addr de B en un combo
reg [7:0]  op_wdata;

reg [1:0] st;
localparam ST_IDLE = 2'd0, ST_ISSUE = 2'd1, ST_WAITRD = 2'd2;

// _95: watchdog de operacion
reg [16:0] op_wd;
reg [3:0]  wd_ops;

// _95: caida de calibracion pegajosa
reg calib_seen = 1'b0, calib_drop = 1'b0;
always @(posedge clk_x1) begin
    if (init_calib_complete) calib_seen <= 1'b1;
    if (calib_seen && !init_calib_complete) calib_drop <= 1'b1;
end
assign diag = {calib_drop, wd_fires, wd_ops};
assign ready = init_calib_complete;    // mismo dominio que los canales

always @(posedge clk_x1 or posedge ddr_rst) begin
    if (ddr_rst) begin
        app_en <= 1'b0; app_wdf_wren <= 1'b0;
        app_cmd <= 3'd0; app_addr <= 28'd0;
        app_wdf_data <= 128'd0; app_wdf_mask <= 16'hFFFF;
        st <= ST_IDLE;
        a_srv <= 1'b0; b_srv <= 1'b0;
        a_done <= 1'b0; b_done <= 1'b0;
        a_dout <= 16'd0; b_dout <= 16'd0;
        op_b <= 1'b0; op_combo <= 1'b0; op_we <= 1'b0;
        op_addr <= 22'd0; op_baddr <= 22'd0; op_wdata <= 8'd0;
        op_wd <= 17'd0; wd_ops <= 4'd0;
    end
    else begin
        app_en <= 1'b0;
        app_wdf_wren <= 1'b0;
        a_done <= 1'b0;                          // pulsos de 1 ciclo
        b_done <= 1'b0;
        if (st == ST_IDLE) op_wd <= 17'd0;
        else               op_wd <= op_wd + 17'd1;
        if (!a_req) a_srv <= 1'b0;               // rearme por bajada del nivel
        if (!b_req) b_srv <= 1'b0;

        case (st)
        ST_IDLE:
            if (init_calib_complete) begin
                if (a_req && !a_srv) begin
                    op_b    <= 1'b0;
                    op_we   <= a_we;
                    op_addr <= a_addr;           // payload estable: el bridge
                    op_wdata <= a_wdata;         // lo mantiene hasta el done
                    // combo: B pendiente, lectura, misma linea de 128b
                    op_combo <= (!a_we && b_req && !b_srv
                                 && b_addr[21:4] == a_addr[21:4]);
                    op_baddr <= b_addr;
                    st <= ST_ISSUE;
                end
                else if (b_req && !b_srv) begin
                    op_b    <= 1'b1;
                    op_we   <= 1'b0;
                    op_addr <= b_addr;
                    op_combo <= 1'b0;
                    st <= ST_ISSUE;
                end
            end
        ST_ISSUE:
            if (op_wd[16]) begin                 // _95: rdy atascado — rescate
                if (op_combo) begin
                    a_dout <= 16'hFFFF; a_done <= 1'b1; a_srv <= 1'b1;
                    b_dout <= 16'hFFFF; b_done <= 1'b1; b_srv <= 1'b1;
                end
                else if (op_b) begin
                    b_dout <= 16'hFFFF; b_done <= 1'b1; b_srv <= 1'b1;
                end
                else begin
                    a_dout <= 16'hFFFF; a_done <= 1'b1; a_srv <= 1'b1;
                end
                if (wd_ops != 4'd15) wd_ops <= wd_ops + 4'd1;
                st <= ST_IDLE;
            end
            else if (app_rdy && app_wdf_rdy) begin
                app_addr <= {7'd0, op_addr[21:4], 3'b000};
                if (op_we) begin
                    app_cmd <= 3'b000;
                    app_en <= 1'b1;
                    app_wdf_wren <= 1'b1;
                    app_wdf_data <= {16{op_wdata}};
                    app_wdf_mask <= ~(16'h0001 << op_addr[3:0]);
                    a_done <= 1'b1; a_srv <= 1'b1;   // write = fire&forget
                    st <= ST_IDLE;
                end
                else begin
                    app_cmd <= 3'b001;
                    app_en <= 1'b1;
                    st <= ST_WAITRD;
                end
            end
        ST_WAITRD:
            if (app_rd_data_valid) begin
                if (op_combo) begin
                    a_dout <= app_rd_data[op_addr[3:1]*16 +: 16];
                    b_dout <= app_rd_data[op_baddr[3:1]*16 +: 16];
                    a_done <= 1'b1; a_srv <= 1'b1;
                    b_done <= 1'b1; b_srv <= 1'b1;
                end
                else if (op_b) begin
                    b_dout <= app_rd_data[op_addr[3:1]*16 +: 16];
                    b_done <= 1'b1; b_srv <= 1'b1;
                end
                else begin
                    a_dout <= app_rd_data[op_addr[3:1]*16 +: 16];
                    a_done <= 1'b1; a_srv <= 1'b1;
                end
                st <= ST_IDLE;
            end
            else if (op_wd[16]) begin            // _95: lectura que nunca vuelve
                if (op_combo) begin
                    a_dout <= 16'hFFFF; a_done <= 1'b1; a_srv <= 1'b1;
                    b_dout <= 16'hFFFF; b_done <= 1'b1; b_srv <= 1'b1;
                end
                else if (op_b) begin
                    b_dout <= 16'hFFFF; b_done <= 1'b1; b_srv <= 1'b1;
                end
                else begin
                    a_dout <= 16'hFFFF; a_done <= 1'b1; a_srv <= 1'b1;
                end
                if (wd_ops != 4'd15) wd_ops <= wd_ops + 4'd1;
                st <= ST_IDLE;
            end
        default: st <= ST_IDLE;
        endcase
    end
end

endmodule
