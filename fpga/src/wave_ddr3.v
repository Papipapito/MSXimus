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

    // ---- puerto del motor PCM OPL4 (_89) ----
    // El motor vive en eng_clk = clk_x1/2 = 37.125MHz (a 74.25 la cadena de
    // envolvente del YMF278B necesita ~19ns y solo hay 13.5; a 37.125 tiene
    // 27). Reloj GENERADO sincrono con clk_x1: los cruces son paths normales
    // analizados por STA, no CDC. La FSM de este modulo sigue a clk_x1;
    // eng_req dura 2 ciclos x1 (inofensivo: el latch de pendiente es
    // idempotente) y la vuelta es un TOGGLE para que el dominio lento no
    // pierda pulsos.
    output wire        clk_x1_out,    // clk_x1 crudo: top hace el /2 (el net
                                      // del divisor debe ser TOP-LEVEL para
                                      // que el get_nets del .sdc lo encuentre,
                                      // como VideoDHClk)
    input  wire        eng_req,       // pulso 1 ciclo eng_clk = nueva operacion
    input  wire        eng_we,
    input  wire [21:0] eng_addr,
    input  wire [7:0]  eng_wdata,
    output reg  [7:0]  eng_rdata,     // registrado, estable hasta la proxima
    output reg [127:0] eng_rline,     // _94: la LINEA entera de la ultima
                                      // lectura del motor (latch pasivo; la
                                      // cache vive en opl4_pcm, en clk_eng)
    output reg         eng_done_t,    // TOGGLE = operacion completada

    // ---- telemetria de diagnostico (_95) ----
    // {calib_drop, wd_fires[2:0], wd_ops[3:0]} — contadores cuasi-estaticos
    // (dominios g50/x1); el lado MSX los muestrea en crudo: son para leerlos
    // UN humano en pantalla, un tearing puntual es irrelevante.
    output wire [7:0]  diag,

    // ---- _100: recalibracion FORZADA (toggle, dominio clk_host) ----
    // El verify del loader la dispara cuando la copia no coincide con la
    // flash: el ojo de lectura/escritura de ESTA calibracion salio malo
    // (MAL-FIJO por arranque: 065B/01B9/D187 en 3 boots del usuario).
    // Pulso de reset a la IP -> calibracion nueva -> otro billete de la
    // loteria del ojo.
    input  wire        recal_req,

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

// _100: recalibracion FORZADA — toggle de clk_host sincronizado a g50;
// cada flanco = pulso de 256 ciclos a la IP (como el watchdog). Declarado
// ANTES de su uso en ip_rst_n (leccion _95: Gowin declara implicitos).
reg  rc_s1 = 1'b0, rc_s2 = 1'b0, rc_s3 = 1'b0;
reg  [8:0] rc_cnt = 9'd0;
wire rc_pulse = (rc_cnt != 9'd0);
always @(posedge clk_g50) begin
    rc_s1 <= recal_req; rc_s2 <= rc_s1; rc_s3 <= rc_s2;
    if (rc_s3 != rc_s2)          rc_cnt <= 9'd256;
    else if (rc_cnt != 9'd0)     rc_cnt <= rc_cnt - 9'd1;
end

// _87: WATCHDOG de calibracion — si el PHY no calibra en ~42ms, pulso de
// reset a la IP y reintento (cada ~42ms hasta conseguirlo)
reg [21:0] wd_cnt = 22'd0;
reg        wd_rst = 1'b0;
wire       ip_rst_n = ~(wd_rst | rc_pulse);   // _100: tambien recal forzada
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

// _95: contar los disparos del watchdog de calibracion de ESTE arranque
// (saturante a 7) — telemetria: cuantos reintentos costo calibrar
reg        wd_rst_d  = 1'b0;
reg [2:0]  wd_fires  = 3'd0;
always @(posedge clk_g50) begin
    wd_rst_d <= wd_rst;
    if (wd_rst && !wd_rst_d && wd_fires != 3'd7) wd_fires <= wd_fires + 3'd1;
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
    .reset  (~por_done | rc_pulse),   // _101: la recal forzada resetea TAMBIEN
                                      // el PLL — re-lock completo con fase
                                      // nueva = billete de ojo INDEPENDIENTE
                                      // (solo resetear la IP daba ojos
                                      // correlacionados: la misma corrupcion
                                      // 18D6C2 en boots distintos)
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
// + puerto del motor PCM (_89, mismo dominio, PRIORIDAD sobre el host: el
//   motor tiene deadline duro — su CE esta congelado mientras espera)
// ---------------------------------------------------------------------------
assign clk_x1_out = clk_x1;

// _93: los payloads del puerto host (addr/we/wdata, dominio clk_54m) van
// junto al toggle de peticion por rutas que el router NO vigila (grupos
// asincronos) — la MISMA clase de bug que mato el motor en la _91, aqui en
// el puerto del loader: el placement de la _92 alargo la ruta del payload,
// el FSM consumia direcciones corruptas y la YRW801 acababa dispersa por
// la DDR3 (HW: _91 ok / _92 FF con la misma flash). Medicina probada:
// consumir el toggle UNA etapa mas tarde (3FF) en AMBOS sentidos.
reg req_s1, req_s2, req_s3, req_ack;   // sync del toggle de peticion (host)
reg [7:0] rdata_x1;
reg done_x1;                       // toggle de completado (dominio x1)

reg        eng_pend;               // peticion del motor latcheada
reg        eng_req_d;              // el pulso eng_req dura 2 ciclos x1: FLANCO
reg        eng_lat;                // _97: etapa de asentado del payload
reg        eng_we_l;
reg [21:0] eng_addr_l;
reg [7:0]  eng_wdata_l;


reg        op_eng;                 // op en curso: 1=motor, 0=host
reg        op_we;
reg [21:0] op_addr;
reg [7:0]  op_wdata;

reg [1:0] st;
localparam ST_IDLE = 2'd0, ST_ISSUE = 2'd1, ST_WAITRD = 2'd2;

// _95: WATCHDOG DE OPERACION — la _94 murio en HW con sintomas de "una
// transaccion que nunca vuelve" (motor congelado leyendo 0000, con STA y
// sims limpios). Si la IP se come un app_rdy o un rd_data_valid, este FSM
// se quedaba clavado PARA SIEMPRE y arrastraba: mem_inflight del motor ->
// CE congelada -> /WAIT timeout -> todo lee 00. Ahora: a ~0.9ms se completa
// la operacion EN FALSO (FF) por el camino normal del toggle (las fases del
// handshake se conservan) y se cuenta en wd_ops. Un byte corrupto y un
// contador visible > un motor muerto. OJO: tras un rescate en ST_WAITRD un
// rd_data_valid tardio puede completar la SIGUIENTE lectura con dato viejo
// — asumido: wd_ops delata que paso.
reg [16:0] op_wd;
reg [3:0]  wd_ops;

// _95: deteccion de caida de calibracion post-exito (pegajosa; fuera del
// reset del FSM para sobrevivir a recalibraciones)
reg calib_seen = 1'b0, calib_drop = 1'b0;
always @(posedge clk_x1) begin
    if (init_calib_complete) calib_seen <= 1'b1;
    if (calib_seen && !init_calib_complete) calib_drop <= 1'b1;
end
assign diag = {calib_drop, wd_fires, wd_ops};

always @(posedge clk_x1 or posedge ddr_rst) begin
    if (ddr_rst) begin
        req_s1 <= 1'b0; req_s2 <= 1'b0; req_s3 <= 1'b0; req_ack <= 1'b0;
        app_en <= 1'b0; app_wdf_wren <= 1'b0;
        app_cmd <= 3'd0; app_addr <= 28'd0;
        app_wdf_data <= 128'd0; app_wdf_mask <= 16'hFFFF;
        st <= ST_IDLE; done_x1 <= 1'b0; rdata_x1 <= 8'd0;
        eng_pend <= 1'b0; eng_req_d <= 1'b0; eng_lat <= 1'b0; eng_we_l <= 1'b0;
        eng_addr_l <= 22'd0; eng_wdata_l <= 8'd0;
        eng_rline <= 128'd0;
        op_eng <= 1'b0; op_we <= 1'b0; op_addr <= 22'd0; op_wdata <= 8'd0;
        eng_rdata <= 8'd0; eng_done_t <= 1'b0;
        op_wd <= 17'd0; wd_ops <= 4'd0;
    end
    else begin
        req_s1 <= req_toggle;
        req_s2 <= req_s1;
        req_s3 <= req_s2;
        if (st == ST_IDLE) op_wd <= 17'd0;
        else               op_wd <= op_wd + 17'd1;
        app_en <= 1'b0;
        app_wdf_wren <= 1'b0;

        eng_req_d <= eng_req;
        // _97: el PAYLOAD (addr/we/wdata) se captura UN ciclo x1 DESPUES del
        // flanco — la misma disciplina de asentado que curo el fill (_96),
        // aplicada al sentido de IDA. El motor lanza eng_req y el payload en
        // el MISMO flanco eng (que coincide con un flanco x1): capturar el
        // payload en el primer x1 del pulso es la carrera same-edge otra vez
        // (22 bits de direccion en la loteria de hold -> fetches de
        // direcciones equivocadas = crujidos + drone de la _96 en HW, con
        // telemetria LIMPIA). Un ciclo despues el payload lleva >=13.5ns
        // quieto (opl4_pcm mantiene mem_addr/we/wdata estables hasta el
        // done). El pulso dura 2 ciclos x1: el flanco sigue detectandose
        // igual (sin el edge-detect la peticion se ejecutaba DOS veces y el
        // toggle de done quedaba en contrafase).
        eng_lat <= (eng_req && !eng_req_d);
        if (eng_lat) begin
            eng_pend   <= 1'b1;
            eng_we_l   <= eng_we;          // asentado: captura limpia
            eng_addr_l <= eng_addr;
            eng_wdata_l <= eng_wdata;
        end

        case (st)
        ST_IDLE:
            if (init_calib_complete) begin
                if (eng_pend) begin              // motor primero (deadline)
                    eng_pend <= 1'b0;
                    op_eng  <= 1'b1;
                    op_we   <= eng_we_l;
                    op_addr <= eng_addr_l;
                    op_wdata <= eng_wdata_l;
                    st <= ST_ISSUE;
                end
                else if (req_s3 != req_ack) begin
                    req_ack <= req_s3;
                    op_eng  <= 1'b0;
                    op_we   <= we;              // host: cuasi-estatico
                    op_addr <= addr;
                    op_wdata <= wdata;
                    st <= ST_ISSUE;
                end
            end
        ST_ISSUE:
            if (op_wd[16]) begin           // _95: rdy atascado — rescate
                if (op_eng) begin
                    eng_rdata <= 8'hFF; eng_rline <= {128{1'b1}};
                    eng_done_t <= ~eng_done_t;
                end
                else begin
                    rdata_x1 <= 8'hFF; done_x1 <= ~done_x1;
                end
                if (wd_ops != 4'd15) wd_ops <= wd_ops + 4'd1;
                st <= ST_IDLE;
            end
            else if (app_rdy && app_wdf_rdy) begin
                app_addr <= {7'd0, op_addr[21:4], 3'b000};  // rafaga alineada (palabras de 16b)
                if (op_we) begin
                    app_cmd <= 3'b000;
                    app_en <= 1'b1;
                    app_wdf_wren <= 1'b1;
                    app_wdf_data <= {16{op_wdata}};
                    app_wdf_mask <= ~(16'h0001 << op_addr[3:0]);   // DM: 1=no escribir
                    if (op_eng) eng_done_t <= ~eng_done_t;         // write = fire&forget
                    else        done_x1 <= ~done_x1;
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
                if (op_eng) begin
                    eng_rdata <= app_rd_data[op_addr[3:0]*8 +: 8];
                    eng_rline <= app_rd_data;      // _94: linea entera (latch
                    eng_done_t <= ~eng_done_t;     // pasivo para la cache de
                end                                // opl4_pcm, en clk_eng)
                else begin
                    rdata_x1 <= app_rd_data[op_addr[3:0]*8 +: 8];
                    done_x1 <= ~done_x1;
                end
                st <= ST_IDLE;
            end
            else if (op_wd[16]) begin      // _95: lectura que nunca vuelve
                if (op_eng) begin
                    eng_rdata <= 8'hFF; eng_rline <= {128{1'b1}};
                    eng_done_t <= ~eng_done_t;
                end
                else begin
                    rdata_x1 <= 8'hFF; done_x1 <= ~done_x1;
                end
                if (wd_ops != 4'd15) wd_ops <= wd_ops + 4'd1;
                st <= ST_IDLE;
            end
        default: st <= ST_IDLE;
        endcase
    end
end

// ---------------------------------------------------------------------------
// vuelta al dominio MSX: done + rdata (cuasi-estatico tras el toggle) + ready
// ---------------------------------------------------------------------------
reg done_h1, done_h2, done_h3;   // _93: 3FF (el payload rdata_x1 viaja con el toggle)
reg calib_h1, calib_h2;
always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        done_h1 <= 1'b0; done_h2 <= 1'b0; done_h3 <= 1'b0; done_toggle <= 1'b0;
        calib_h1 <= 1'b0; calib_h2 <= 1'b0; rdata <= 8'd0;
    end
    else begin
        done_h1 <= done_x1;
        done_h2 <= done_h1;
        done_h3 <= done_h2;
        if (done_h3 != done_toggle) begin
            done_toggle <= done_h3;
            rdata <= rdata_x1;     // estable: done_x1 cambio hace >=2 ciclos
        end
        calib_h1 <= init_calib_complete;
        calib_h2 <= calib_h1;
    end
end
assign ready = calib_h2;

endmodule
