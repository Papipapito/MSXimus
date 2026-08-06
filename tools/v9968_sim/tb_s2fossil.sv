// ============================================================================
// tb_s2fossil.sv — reproduccion del "S#2 FOSIL" de Fleet Commander (05/08).
//
// EL SINTOMA EN PLACA (radiografia s020 por COM11): tras la secuencia
// lecturas-0x98 -> STOP -> pantalla OFF, TODAS las lecturas de status (0x99)
// devuelven el MISMO byte (0x1C = un S#2 viejo: TR=0, BD=1) mientras el VDP
// interno tiene TR=1 y VR alternando — el Z80 consume un dato FOSIL. Los
// clears de F siguen ocurriendo (las transacciones LLEGAN al VDP): la
// divergencia esta en el CAMINO DE VUELTA del dato (glue/cdi_r).
//
// SOSPECHOSO (bug #1 del INFORME_NIQUELADO, cabecera de tb_cpuif_dbl): el
// latch del cpu_interface acepta con ff_bus_ready CRUDO mientras el glue
// espera el ready GATEADO (& ~ff_busy & ~ff_pf_inflight). Si un prefetch del
// puerto 0 queda EN VUELO (ff_pf_inflight=1) al entrar el tren de polls de
// status, el glue puede no ver ready / no recibir rdata_en -> su timeout
// fail-open (~12us) libera al Z80 con cdi_r VIEJO — una vez por IN, para
// siempre = el fosil.
//
// GUION (calcado de la muerte real):
//   FASE 1  trafico sano de registros + polls de referencia (deben VARIAR).
//   FASE 2  era-0x98: SETRD + INs del puerto 0 con LAT alta (prefetch vivo);
//           el ultimo IN se lanza y NO se espera a que el prefetch aterrice.
//   FASE 3  el tren de la BIOS: K iteraciones de
//              OUT(1,02) OUT(1,8F) IN(1) OUT(1,00) OUT(1,8F)
//           con status_vsync (VR) CONMUTANDO desde el TB: una lectura viva
//           tiene que ver VR moverse; un fosil se queda clavado.
// VEREDICTO:
//   *** FOSIL REPRODUCIDO ***  si >=10 INs seguidos devuelven el MISMO byte
//       habiendo conmutado VR >=4 veces entre medias, o si el fail-open del
//       glue (wtmo_hit) dispara de forma sostenida.
//   Ademas: contabilidad n_exec/n_glue (la cuenta que no puede mentir) y
//   ff_pf_inflight pegado.
//
// Uso: vvp sim [+LAT=n] [+K=n] [+VCD=1]
// ============================================================================
`timescale 1ns/1ps

module tb_s2fossil;

localparam real CLK_HALF  = 5.8207;      // 85.909 MHz
localparam real TSTATE    = 279.33;      // Z80 3.58 MHz

logic clk = 0;
logic reset_n = 0;
always #(CLK_HALF) clk = ~clk;

// --- glue real ---
wire [2:0]  bus_address;
wire        bus_ioreq, bus_write, bus_valid;
wire [7:0]  bus_wdata;
wire [7:0]  bus_rdata;
wire        bus_rdata_en, bus_ready;

logic       csw_n = 1'b1, csr_n = 1'b1;
logic [1:0] z_mode = 2'd0;
logic [7:0] z_cdo  = 8'd0;
wire  [7:0] z_cdi;
wire        g_wait_n;

v9968_cpu_glue u_glue (
    .clk_86(clk), .rst_n(reset_n),
    .csw_n(csw_n), .csr_n(csr_n), .mode(z_mode), .cdo(z_cdo), .cdi_r(z_cdi),
    .wait_n(g_wait_n),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en)
);

// --- cpu_interface real, con VR VIVO desde el TB ---
wire [17:0] vram_address;
wire        vram_write, vram_valid;
wire [7:0]  vram_wdata;
logic       vram_ready    = 1'b0;
logic [7:0] vram_rdata    = 8'd0;
logic       vram_rdata_en = 1'b0;

logic vr_ff = 1'b0;                  // "VR": conmuta cada VR_HALF ciclos
integer vr_cnt = 0, vr_toggles = 0;
localparam integer VR_HALF = 2000;   // ~23us por semiperiodo (rapido para sim)
always @(posedge clk) begin
    vr_cnt <= vr_cnt + 1;
    if( vr_cnt == VR_HALF ) begin
        vr_cnt <= 0; vr_ff <= ~vr_ff; vr_toggles <= vr_toggles + 1;
    end
end

// "vsync" para la F: pulso de intr_frame en cada subida de vr_ff — asi la
// F se arma periodicamente y podemos VER quien la limpia (o si se pega)
wire dut_int_n;
logic frame_pulse = 1'b0;
logic vr_d = 1'b0;
always @(posedge clk) begin
    vr_d <= vr_ff;
    frame_pulse <= (vr_ff && !vr_d);
end

vdp_cpu_interface u_dut (
    .reset_n(reset_n), .clk(clk),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_ready(vram_ready), .vram_wdata(vram_wdata),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .palette_valid(), .palette_num(), .palette_r(), .palette_g(), .palette_b(),
    .int_n(dut_int_n),
    .intr_line(1'b0), .intr_frame(frame_pulse), .intr_command_end(1'b0),
    .clear_line_interrupt(1'b0),
    .clear_sprite_collision(), .sprite_collision(1'b0),
    .clear_sprite_collision_xy(), .sprite_collision_x(9'd0),
    .sprite_collision_y(10'd0), .sprite_overmap(1'b0),
    .sprite_overmap_id(5'd0), .clear_border_detect(), .read_color(),
    .register_write(), .register_num(), .register_data(),
    .status_command_execute(1'b0), .status_field(1'b0),
    .status_border_detect(1'b0), .status_hsync(1'b0), .status_vsync(vr_ff),
    .status_transfer_ready(1'b1), .status_color(8'd0),
    .status_border_position(9'd0),
    .vram_access_mask(1'b0), .force_highspeed(1'b0),
    .reg_screen_mode(), .reg_sprite_magify(), .reg_sprite_16x16(),
    .reg_display_on(), .reg_pattern_name_table_base(), .reg_color_table_base(),
    .reg_pattern_generator_table_base(), .reg_sprite_attribute_table_base(),
    .reg_sprite_pattern_generator_table_base(), .reg_backdrop_color(),
    .reg_sprite_disable(), .reg_color0_opaque(), .reg_50hz_mode(),
    .reg_interleaving_mode(), .reg_interlace_mode(), .reg_212lines_mode(),
    .reg_text_back_color(), .reg_blink_period(), .reg_display_adjust(),
    .reg_interrupt_line(), .reg_vertical_offset(), .reg_scroll_planes(),
    .reg_left_mask(), .reg_yjk_mode(), .reg_yae_mode(), .reg_command_enable(),
    .reg_sprite_priority_shuffle(), .reg_horizontal_offset_l(),
    .reg_horizontal_offset_h(), .reg_command_high_speed_mode(),
    .reg_sprite_nonR23_mode(), .reg_interrupt_line_nonR23_mode(),
    .reg_sprite_mode3(), .reg_ext_palette_mode(), .reg_ext_command_mode(),
    .reg_vram256k_mode(), .reg_sprite16_mode(), .reg_flat_interlace_mode(),
    .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// --- VRAM con latencia programable (como en tb_cpuif_dbl) + modo ALEATORIO
// (la DDR3 real varia ~14..190 ciclos con la contencion; RNDLAT=1 sortea
// una latencia por operacion en [LATMIN..LAT] — la paridad de las ventanas
// busy depende de ella y el fosil puede ser cuestion de fase) ---
integer LAT = 120;
integer LATMIN = 14;
integer RNDLAT = 0;
logic [7:0] vram [0:262143];
logic        v_pend = 1'b0, v_we;
logic [17:0] v_addr;
logic [7:0]  v_data;
integer      v_cnt, v_lat;
always @(posedge clk) begin
    vram_ready    <= 1'b0;
    vram_rdata_en <= 1'b0;
    if( !reset_n ) v_pend <= 1'b0;
    else if( vram_valid && !v_pend ) begin
        v_pend <= 1'b1; v_we <= vram_write; v_addr <= vram_address;
        v_data <= vram_wdata; v_cnt <= 0;
        v_lat  <= RNDLAT ? (LATMIN + ({$random} % (LAT - LATMIN + 1))) : LAT;
        vram_ready <= 1'b1;
    end
    else if( v_pend ) begin
        v_cnt <= v_cnt + 1;
        if( v_cnt >= v_lat ) begin
            v_pend <= 1'b0;
            if( v_we ) vram[v_addr] <= v_data;
            else begin
                vram_rdata <= vram[v_addr]; vram_rdata_en <= 1'b1;
            end
        end
    end
end

// --- sondas ---
// s022/_185: el puntero de status EN el momento de cada lectura (no en el
// snapshot) — el discriminante del par desincronizado
reg [3:0] tb_ptr_rd = 4'd0;
always @(posedge clk)
    if (u_dut.w_read && u_dut.ff_port1)
        tb_ptr_rd <= u_dut.ff_status_register_pointer;

integer n_glue = 0, n_exec = 0, n_tmo = 0;
wire p_exec = u_dut.ff_bus_valid & ~u_dut.ff_busy & ~u_dut.ff_pf_inflight;
reg  tmo_d = 1'b0;
always @(posedge clk) if( reset_n ) begin
    if( bus_valid && bus_ready ) n_glue = n_glue + 1;
    if( p_exec )                 n_exec = n_exec + 1;
    tmo_d <= u_glue.wtmo_hit;
    if( u_glue.wtmo_hit && !tmo_d ) n_tmo = n_tmo + 1;   // fail-opens
end

// --- ciclo Z80 con /WAIT (WAITEN=1 siempre: la config real) ---
task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.5*TSTATE);
    csw_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task z80_in(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(TSTATE);
    csr_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.0*TSTATE);
    d = z_cdi;
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task vdp_reg(input [5:0] r, input [7:0] d);
begin z80_out(2'd1, d); z80_out(2'd1, {2'b10, r}); end
endtask

task vram_set_rd(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b00, a[13:8]});
end
endtask

task vram_set_wr(input [17:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    z80_out(2'd1, a[7:0]);
    z80_out(2'd1, {2'b01, a[13:8]});
end
endtask

// OUT a ritmo OTIR (21T por byte): cola recortada respecto a z80_out
task z80_out_otir(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(1.5*TSTATE);
    while (g_wait_n == 1'b0) #(TSTATE);
    #(1.5*TSTATE);
    csw_n = 1'b1;
    #(4.0*TSTATE);
end
endtask

// el tren de la BIOS: select S#2 / IN / restore S#0 (bytes exactos de 2bef+)
task bios_poll(output [7:0] v);
begin
    z80_out(2'd1, 8'h02); z80_out(2'd1, 8'h8F);
    z80_in (2'd1, v);
    z80_out(2'd1, 8'h00); z80_out(2'd1, 8'h8F);
end
endtask

// ---------------------------------------------------------------------------
integer K = 120;
integer SCEN = 2;
integer i, j;
logic [7:0] v, v_prev, v2junk;
integer same_run, max_same_run, tgl_at_runstart, run_tgl;
integer n_reads_98;
integer fossil;

initial begin
    if( !$value$plusargs("LAT=%d", LAT) ) LAT = 120;
    if( !$value$plusargs("K=%d",   K)   ) K   = 120;
    if( !$value$plusargs("SCEN=%d", SCEN) ) SCEN = 2;
    if( $test$plusargs("RNDLAT") ) RNDLAT = 1;
    if( $test$plusargs("VCD") ) begin
        $dumpfile("s2fossil.vcd"); $dumpvars(0, tb_s2fossil);
    end
    for (i = 0; i < 262144; i = i + 1) vram[i] = i[7:0] ^ 8'h5A;

    repeat (24) @(posedge clk);
    reset_n = 1;
    repeat (24) @(posedge clk);
    $display("=== tb_s2fossil: LAT=%0d  K=%0d ===", LAT, K);

    // FASE 1 — referencia sana: 20 polls sin prefetch por medio
    max_same_run = 0; same_run = 0; v_prev = 8'hXX;
    for (i = 0; i < 20; i = i + 1) begin
        bios_poll(v);
        if (i == 0 || v !== v_prev) same_run = 1; else same_run = same_run + 1;
        if (same_run > max_same_run) max_same_run = same_run;
        v_prev = v;
    end
    $display("FASE1 polls sanos: ultimo=%02x  racha_max_identicos=%0d (VR conmuta cada ~%0dns)",
             v_prev, max_same_run, VR_HALF*12);

    // FASE 2 — la muerte real de Fleet (radiografia 19.6-20.9s): rafagas
    // OTIR de ESCRITURA al puerto 0 (wr/s~40k) ENTREMEZCLADAS con polls de
    // status y lecturas 0x98 sueltas — las ventanas de busy de escritura
    // golpeando el camino de vuelta de las lecturas. Con SCEN=1, solo el
    // guion viejo (prefetch + tren limpio).
    if (SCEN == 2) begin
        vram_set_rd(18'h00100);
        for (i = 0; i < 4; i = i + 1) z80_in(2'd0, v);   // prefetch caliente
        vram_set_wr(18'h08000);
    end
    else begin
        vram_set_rd(18'h00100);
        for (i = 0; i < 6; i = i + 1) z80_in(2'd0, v);
    end
    $display("FASE2 (SCEN=%0d) lista; pf_inflight=%b antes del tren",
             SCEN, u_dut.ff_pf_inflight);

    // FASE 3 — el tren: [rafaga OTIR de 16 escrituras + poll + 2 lecturas
    // 0x98 + poll] x K/2 (SCEN=2) o polls puros (SCEN=1)
    fossil = 0; max_same_run = 0; same_run = 0; run_tgl = 0;
    tgl_at_runstart = vr_toggles; v_prev = 8'hXX;
    for (i = 0; i < K; i = i + 1) begin
        if (SCEN == 2) begin
            for (j = 0; j < 16; j = j + 1) z80_out_otir(2'd0, 8'hA5 ^ i[7:0] ^ j[7:0]);
        end
        bios_poll(v);
        if (i == 0 || v !== v_prev) begin
            same_run = 1; tgl_at_runstart = vr_toggles;
        end
        else same_run = same_run + 1;
        if (same_run > max_same_run) begin
            max_same_run = same_run;
            run_tgl = vr_toggles - tgl_at_runstart;
        end
        if (SCEN == 2 && (i % 3) == 2) begin
            z80_in(2'd0, v2junk); z80_in(2'd0, v2junk);
        end
        if ((i % 20) == 19)
            $display("  tren %0d/%0d: v=%02x  pf_inflight=%b  fail-opens=%0d  F=%b",
                     i+1, K, v, u_dut.ff_pf_inflight, n_tmo, u_dut.ff_frame_interrupt);
        v_prev = v;
    end

    $display("RESULTADO: racha_max_identicos=%0d (con %0d conmutaciones de VR dentro)  fail-opens=%0d  n_glue=%0d n_exec=%0d  pf_inflight_final=%b",
             max_same_run, run_tgl, n_tmo, n_glue, n_exec, u_dut.ff_pf_inflight);
    if (max_same_run >= 10 && run_tgl >= 4) begin
        $display("*** FOSIL REPRODUCIDO: %0d lecturas identicas con VR moviendose ***", max_same_run);
        fossil = 1;
    end
    if (n_tmo > 5)
        $display("*** FAIL-OPEN SOSTENIDO: %0d timeouts del glue ***", n_tmo);
    if (!fossil && n_tmo <= 5)
        $display("*** SIN FOSIL en esta configuracion ***");

    // ------------------------------------------------------------------
    // FASE 4 — LA HERENCIA DEL TMS9918 (la intuicion de Albert, 05/08):
    // en el TMS9918/V9938 real, LEER el status RESETEA el latch del par
    // del puerto 1; el software MSX1/old-school depende de ello. Aqui:
    // un byte HUERFANO (lo que deja un par roto por interrupcion) y a
    // poleaar. Con el RTL sin _185: los selects de R#15 se comen el
    // huerfano como pareja, el puntero JAMAS vale 2 en las lecturas y
    // cada iteracion mete puestas de direccion VRAM espurias = el S#2
    // FOSIL de Fleet + la corrupcion de DQ2, PARA SIEMPRE. Con _185: el
    // primer IN resetea la fase y el siguiente select aterriza.
    // ------------------------------------------------------------------
    $display("FASE4 — byte huerfano al puerto 1 y tren de polls:");
    z80_out(2'd1, 8'hAA);
    j = 0;   // polls con el puntero MAL en la lectura
    for (i = 0; i < 8; i = i + 1) begin
        bios_poll(v);
        if (tb_ptr_rd != 4'd2) j = j + 1;
        $display("  poll %0d: v=%02x  ptr_en_lectura=%0d  fase_par=%b",
                 i, v, tb_ptr_rd, u_dut.ff_2nd_access);
    end
    if (j >= 6)
        $display("*** DESYNC ETERNO: %0d/8 lecturas con el puntero MAL — la herencia TMS9918 FALTA (el fosil de Fleet) ***", j);
    else if (j <= 1)
        $display("*** SELF-HEALING OK (_185): el par se re-sincroniza leyendo status, %0d/8 mal ***", j);
    else
        $display("*** AMBIGUO: %0d/8 mal ***", j);
    $finish;
end

endmodule
