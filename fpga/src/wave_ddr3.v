// ============================================================================
// wave_ddr3.v — memoria de ondas del OPL4 en la DDR3 del SOM (MSXimus _86)
//
// Cliente MINIMO e INDEPENDIENTE de la DDR3 (la memory.v/SDRAM del core no
// se toca: contrato VDP/CPU intacto). Receta de la IP calcada del
// ddr3_framebuffer_gowin de nand2mario (Apache-2.0, probado en ESTA placa):
// pll_ddr3 297MHz con la danza mDRP del 60K + DDR3_Memory_Interface_Top
// (cmd 000=write/001=read, addr en palabras de 16 bits, rafagas de 128 bits
// = 8 palabras, mascara DM estandar 1=no-escribir). AUTO-REFRESH ON (la IP
// trae tREFI=7.8us): imprescindible — la wave ROM es DATO ESTATICO (el
// framebuffer de nand2mario podia permitirse ignorarlo; nosotros NO).
//
// _86 = bring-up: un puerto de acceso por bytes con handshake de toggle
// (cuasi-estatico, 2FF en ambos sentidos — leccion CDC: nada de atributos
// de vendor, sincronizacion a mano). El motor PCM (fase _88) colgara su
// puerto de fetch de aqui mismo.
//
// Dominios:
//  - clk_host (clk_54m): lado MSX (puerto de acceso).
//  - clk_x1 (74.25MHz, LO GENERA LA IP): FSM del cliente.
//  - clk_g50: cristal 50MHz (mdclk del PLL + clk de la IP).
// ============================================================================

module wave_ddr3 (
    // ---- lado MSX (clk_host) ----
    input  wire        clk_host,
    input  wire        rst_n,
    input  wire        req_toggle,    // flip = nueva operacion
    input  wire        we,            // 1=escritura (estable durante el handshake)
    input  wire [21:0] addr,          // direccion de BYTE (4MB)
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,         // valido tras done_toggle
    output reg         done_toggle,   // flip = operacion completada
    output wire        ready,         // calibracion DDR3 completada (sync)

    // ---- relojes ----
    input  wire        clk_27,        // 27MHz (cascada de video, como el ref)
    input  wire        clk_g50,       // pad 50MHz (ex_clk_27m)
    input  wire        pll27_lock,    // _87: lock del arbol de 27 (como el ref)

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
// reset del PLL DDR3: power-on delay Y ADEMAS lock real del arbol de 27 (_87)
// — el retardo fijo a secas de la _86 daba CALIBRACION DE LOTERIA entre
// arranques (a veces soltaba el PLL con el 27 aun asentandose)
// ---------------------------------------------------------------------------
reg [15:0] por_cnt = 16'd0;
reg        por_done = 1'b0;
always @(posedge clk_g50) begin
    if (!por_done) begin
        if (pll27_lock) begin              // no contar hasta que el 27 este vivo
            por_cnt <= por_cnt + 16'd1;
            if (&por_cnt) por_done <= 1'b1;
        end
        else por_cnt <= 16'd0;
    end
end

// _87: WATCHDOG de calibracion — si el PHY no calibra en ~42ms, pulso de
// reset a la IP y reintento (cada ~42ms hasta conseguirlo)
reg [21:0] wd_cnt = 22'd0;
reg        wd_rst = 1'b0;
wire       ip_rst_n = ~wd_rst;
always @(posedge clk_g50) begin
    if (init_calib_complete || !por_done) begin
        wd_cnt <= 22'd0;
        wd_rst <= 1'b0;
    end
    else begin
        wd_cnt <= wd_cnt + 22'd1;
        wd_rst <= (wd_cnt[21] && (wd_cnt[20:8] == 13'd0));  // pulso 256 ciclos/42ms
    end
end

// ---------------------------------------------------------------------------
// PLL 297MHz + danza mDRP (verbatim del ref, variante 60K)
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
    .reset  (~por_done),
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
wire         init_calib_complete;

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
    .rst_n           (ip_rst_n),     // _87: watchdog de recalibracion
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
    // pines
    .ddr_rst         (ddr_rst),
    .O_ddr_addr      (ddr_addr),
    .O_ddr_ba        (ddr_bank),
    .O_ddr_cs_n     (ddr_cs),
    .O_ddr_ras_n     (ddr_ras),
    .O_ddr_cas_n     (ddr_cas),
    .O_ddr_we_n      (ddr_we),
    .O_ddr_clk       (ddr_ck),
    .O_ddr_clk_n     (ddr_ck_n),
    .O_ddr_cke       (ddr_cke),
    .O_ddr_odt       (ddr_odt),
    .O_ddr_reset_n   (ddr_reset_n),
    .O_ddr_dqm       (ddr_dm),
    .IO_ddr_dq       (ddr_dq),
    .IO_ddr_dqs      (ddr_dqs),
    .IO_ddr_dqs_n    (ddr_dqs_n)
);

// ---------------------------------------------------------------------------
// FSM del puerto de bytes (clk_x1): toggle-handshake 2FF con el lado MSX
// ---------------------------------------------------------------------------
reg req_s1, req_s2, req_ack;      // sync del toggle de peticion
reg [7:0] rdata_x1;
reg done_x1;                       // toggle de completado (dominio x1)

// entrada cuasi-estatica: addr/we/wdata estables mientras dura el handshake
reg [1:0] st;
localparam ST_IDLE = 2'd0, ST_ISSUE = 2'd1, ST_WAITRD = 2'd2;

always @(posedge clk_x1 or posedge ddr_rst) begin
    if (ddr_rst) begin
        req_s1 <= 1'b0; req_s2 <= 1'b0; req_ack <= 1'b0;
        app_en <= 1'b0; app_wdf_wren <= 1'b0;
        app_cmd <= 3'd0; app_addr <= 28'd0;
        app_wdf_data <= 128'd0; app_wdf_mask <= 16'hFFFF;
        st <= ST_IDLE; done_x1 <= 1'b0; rdata_x1 <= 8'd0;
    end
    else begin
        req_s1 <= req_toggle;
        req_s2 <= req_s1;
        app_en <= 1'b0;
        app_wdf_wren <= 1'b0;

        case (st)
        ST_IDLE:
            if ((req_s2 != req_ack) && init_calib_complete) begin
                req_ack <= req_s2;
                st <= ST_ISSUE;
            end
        ST_ISSUE:
            if (app_rdy && app_wdf_rdy) begin
                app_addr <= {7'd0, addr[21:4], 3'b000};  // rafaga alineada (unidades = palabras de 16b)
                if (we) begin
                    app_cmd <= 3'b000;
                    app_en <= 1'b1;
                    app_wdf_wren <= 1'b1;
                    app_wdf_data <= {16{wdata}};
                    app_wdf_mask <= ~(16'h0001 << addr[3:0]);   // DM: 1=no escribir
                    done_x1 <= ~done_x1;                         // write = fire&forget
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
                rdata_x1 <= app_rd_data[addr[3:0]*8 +: 8];
                done_x1 <= ~done_x1;
                st <= ST_IDLE;
            end
        default: st <= ST_IDLE;
        endcase
    end
end

// ---------------------------------------------------------------------------
// vuelta al dominio MSX: done + rdata (cuasi-estatico tras el toggle) + ready
// ---------------------------------------------------------------------------
reg done_h1, done_h2;
reg calib_h1, calib_h2;
always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        done_h1 <= 1'b0; done_h2 <= 1'b0; done_toggle <= 1'b0;
        calib_h1 <= 1'b0; calib_h2 <= 1'b0; rdata <= 8'd0;
    end
    else begin
        done_h1 <= done_x1;
        done_h2 <= done_h1;
        if (done_h2 != done_toggle) begin
            done_toggle <= done_h2;
            rdata <= rdata_x1;     // estable: done_x1 cambio hace >=2 ciclos
        end
        calib_h1 <= init_calib_complete;
        calib_h2 <= calib_h1;
    end
end
assign ready = calib_h2;

endmodule
