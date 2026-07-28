// ============================================================================
// tb_cpuif_dbl.sv — BANCO DIRIGIDO DEL BUG #1 (INFORME_NIQUELADO 26/07):
// "una transaccion de I/O que cae dentro de una ventana busy / pre-lectura se
// ejecuta DOS VECES en vdp_cpu_interface".
//
// MECANISMO (ciclo a ciclo, sobre el RTL de la _161):
//   El latch del bus aceptaba con `bus_valid && ff_bus_ready` (ff_bus_ready
//   CRUDO) mientras el maestro real (fpga/src/v9968_cpu_glue.v) solo da la
//   transferencia por hecha cuando ve el bus_ready GATEADO
//   (ff_bus_ready & ~ff_busy & ~ff_pf_inflight).
//     ciclo B   : ultimo ciclo de la ventana busy/inflight, ff_bus_ready=1 y
//                 bus_valid=1 -> el latch acepta (ff_bus_valid<=1,
//                 ff_bus_ready<=0) pero el maestro NO lo ve (bus_ready=0)
//     ciclo B+1 : la ventana ha caido -> w_read/w_write   << 1a ejecucion >>
//     ciclo B+2 : ff_bus_ready vuelve a 1 y bus_valid SIGUE alto (el maestro
//                 nunca vio ready) -> el latch acepta LA MISMA transaccion,
//                 y ahora si la ve tambien el maestro   << 2a ejecucion >>
//   En un OUT al puerto 0 eso escribe DOS bytes en VRAM y adelanta DOS veces
//   el contador de direccion; en un OUT al puerto 1, ff_2nd_access se toggla
//   dos veces y el par de bytes de la puesta de direccion se desincroniza.
//   Es el candidato al residuo del "salto +-1 del puerto CPU".
//
//   PEOR CASO — LIVELOCK (medido en este banco, MODE=3 LAT=120): no siempre son
//   DOS ejecuciones. Si la ejecucion vuelve a levantar ff_busy (escritura en
//   VRAM) y la PARIDAD de la ventana hace que ff_bus_ready este a 1 en su
//   ultimo ciclo, el ciclo se repite: aceptar -> ejecutar -> busy -> aceptar...
//   con el maestro sin ver NUNCA ready. Con la latencia CONSTANTE del modelo
//   eso no termina (bus atascado + VRAM machacada byte a byte); con la latencia
//   variable de la DDR3 real degenera en rafagas de N escrituras espurias.
//
// EL BANCO: vdp_cpu_interface REAL + v9968_cpu_glue REAL + modelo de Z80 con
// tiempos + modelo de VRAM de LATENCIA PROGRAMABLE (+LAT). Con latencias
// grandes (las medidas en placa llegan a 2,2 us = ~190 ciclos, ORIGEN.txt
// _149, y la contencion de la DDR3 con comandos+sprites puede pasar de ahi)
// las ventanas busy/pre-lectura solapan con el siguiente ciclo de I/O del Z80.
//
// MODOS (+MODE):
//   0 = lecturas encadenadas del puerto 0 (una sola puesta de direccion)
//   1 = SETRD + IN alternados (el OUT del puerto 1 cae en la ventana de la
//       pre-lectura que armo el IN anterior)
//   2 = ESCRITURAS encadenadas en VRAM (el OUT cae en la ventana busy de la
//       escritura anterior) -> la corrupcion es VISIBLE en la memoria
//
// QUE MIDE (y por que un "verde" sin actividad no cuela: si n_win==0 el banco
// dice EXPRESAMENTE que el caso no prueba nada, y ademas publica los accesos
// reales a VRAM y las entregas de dato):
//   n_glue   = transferencias que el maestro da por hechas (bus_valid&&ready)
//   n_exec   = ejecuciones efectivas dentro del DUT
//              => n_exec - n_glue = EJECUCIONES DE MAS  << el bug >>
//   n_latch  = aceptaciones del latch interno (con el bug, cientos: el latch
//              re-acepta cada 2 ciclos durante toda la ventana)
//   n_win    = ciclos con peticion presentada dentro de una ventana
//   n_edgelost = flancos que descarta el GLUE (bug #26, ajeno a este fix)
//   + comprobacion FUNCIONAL: secuencia de bytes leidos / contenido de VRAM
//   + watchdog de bus atascado (el bug puede LIVELOCKear: ver abajo)
//
// Uso:  vvp sim +LAT=<ciclos> [+MODE=0|1|2] [+N=<accesos>] [+FCPU=<kHz>]
//
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================
`timescale 1ns/1ps

module tb_cpuif_dbl;

localparam real CLK_HALF  = 5.8207;      // 85.909 MHz
localparam real NS_PER_CY = 11.6414;

logic clk = 0;
logic reset_n = 0;
always #(CLK_HALF) clk = ~clk;

// --- bus del V9968, movido por el GLUE REAL ---
wire [2:0]  bus_address;
wire        bus_ioreq, bus_write, bus_valid;
wire [7:0]  bus_wdata;
wire [7:0]  bus_rdata;
wire        bus_rdata_en, bus_ready;

// --- lado Z80 ---
logic       csw_n = 1'b1, csr_n = 1'b1;
logic [1:0] z_mode = 2'd0;
logic [7:0] z_cdo  = 8'd0;
wire  [7:0] z_cdi;

v9968_cpu_glue u_glue (
    .clk_86(clk), .rst_n(reset_n),
    .csw_n(csw_n), .csr_n(csr_n), .mode(z_mode), .cdo(z_cdo), .cdi_r(z_cdi),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en)
);

// --- interfaz de VRAM ---
wire [17:0] vram_address;
wire        vram_write, vram_valid;
wire [7:0]  vram_wdata;
logic       vram_ready    = 1'b0;
logic [7:0] vram_rdata    = 8'd0;
logic       vram_rdata_en = 1'b0;

vdp_cpu_interface u_dut (
    .reset_n(reset_n), .clk(clk),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
    .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_ready(vram_ready), .vram_wdata(vram_wdata),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .palette_valid(), .palette_num(), .palette_r(), .palette_g(), .palette_b(),
    .int_n(),
    .intr_line(1'b0), .intr_frame(1'b0), .intr_command_end(1'b0),
    .clear_line_interrupt(1'b0),
    .clear_sprite_collision(), .sprite_collision(1'b0),
    .clear_sprite_collision_xy(), .sprite_collision_x(9'd0),
    .sprite_collision_y(10'd0), .sprite_overmap(1'b0),
    .sprite_overmap_id(5'd0), .clear_border_detect(), .read_color(),
    .register_write(), .register_num(), .register_data(),
    .status_command_execute(1'b0), .status_field(1'b0),
    .status_border_detect(1'b0), .status_hsync(1'b0), .status_vsync(1'b0),
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

// ---------------------------------------------------------------------------
//  Modelo de VRAM con latencia programable (el shim + DDR3 del MSXimus tarda
//  entre ~14 y ~190 ciclos segun contencion, ORIGEN.txt _149)
// ---------------------------------------------------------------------------
integer LAT = 40;
logic [7:0] vram [0:262143];
logic        v_pend = 1'b0, v_we;
logic [17:0] v_addr;
logic [7:0]  v_data;
integer      v_cnt;
integer      n_vram_rd = 0, n_vram_wr = 0;

always @(posedge clk) begin
    vram_ready    <= 1'b0;
    vram_rdata_en <= 1'b0;
    if( !reset_n ) begin
        v_pend <= 1'b0;
    end
    else if( vram_valid && !v_pend ) begin
        v_pend     <= 1'b1;
        v_we       <= vram_write;
        v_addr     <= vram_address;
        v_data     <= vram_wdata;
        v_cnt      <= 0;
        vram_ready <= 1'b1;              // aceptacion (1 ciclo despues de valid)
    end
    else if( v_pend ) begin
        v_cnt <= v_cnt + 1;
        if( v_cnt >= LAT ) begin
            v_pend <= 1'b0;
            if( v_we ) begin
                vram[v_addr] <= v_data;
                n_vram_wr     = n_vram_wr + 1;
            end
            else begin
                vram_rdata    <= vram[v_addr];
                vram_rdata_en <= 1'b1;
                n_vram_rd      = n_vram_rd + 1;
            end
        end
    end
end

// ---------------------------------------------------------------------------
//  Sondas: contabilidad POR TRANSACCION del Z80.
//  Una transaccion empieza cuando el glue levanta bus_valid y se cierra 8
//  ciclos despues de que lo baje (la 2a ejecucion del bug llega DESPUES de que
//  el maestro de la transferencia por hecha).
// ---------------------------------------------------------------------------
wire p_busy   = u_dut.ff_busy;
wire p_infl   = u_dut.ff_pf_inflight;
wire p_bready = u_dut.ff_bus_ready;
wire p_bvalid = u_dut.ff_bus_valid;
wire p_exec   = p_bvalid & ~p_busy & ~p_infl;      // == (w_read | w_write)

integer n_exec = 0, n_win = 0, n_deliv = 0;
integer n_latch = 0, n_glue = 0, n_edgelost = 0;

//	La cuenta que NO puede mentir: cada transferencia que el maestro da por
//	hecha (bus_valid && bus_ready, y el glue baja bus_valid acto seguido) tiene
//	que producir UNA ejecucion y solo una. n_exec - n_glue = ejecuciones de mas.
always @(posedge clk) if( reset_n ) begin
    if( bus_valid && p_bready )              n_latch = n_latch + 1;
    if( bus_valid && bus_ready )             n_glue  = n_glue  + 1;
    if( bus_valid && ( p_busy || p_infl ) )  n_win   = n_win   + 1;
    if( bus_rdata_en )                       n_deliv = n_deliv + 1;
    if( p_exec )                             n_exec  = n_exec  + 1;
    //	flancos de csw_n/csr_n que el GLUE descarta por tener otra transaccion en
    //	vuelo (bug #26 del informe — AJENO a este fix, se cuenta para no
    //	atribuirle a este bug la corrupcion que causa)
    if( u_glue.bus_valid && ( u_glue.wr_start || u_glue.rd_start ) )
        n_edgelost = n_edgelost + 1;
end

// ---------------------------------------------------------------------------
//  Modelo del ciclo de I/O del Z80 (identico al de tb_t2cpuread)
// ---------------------------------------------------------------------------
real TSTATE = 279.33;
integer FCPU_KHZ;

task z80_out(input [1:0] m, input [7:0] d);
begin
    z_mode = m; z_cdo = d;
    #(TSTATE);
    csw_n = 1'b0;
    #(3.0*TSTATE);
    csw_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

task z80_in(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(TSTATE);
    csr_n = 1'b0;
    #(2.5*TSTATE);
    d = z_cdi;
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(8.0*TSTATE);
end
endtask

//	MODO 3 — MAESTRO IDEAL (el aislador del bug #1): espera a que el glue quede
//	libre (bus_valid bajo => la transaccion anterior YA la acepto el maestro) y
//	emite el siguiente ciclo de I/O de inmediato, con la cola de la instruccion
//	recortada a 4 T. Asi:
//	  - NINGUN flanco se pierde en el glue (bug #26 del informe fuera de juego),
//	  - y el nuevo acceso cae DENTRO de la ventana ff_busy que abre la escritura
//	    anterior (ff_busy sube DESPUES de que el maestro de por hecha la
//	    transferencia), que es exactamente el disparador del bug #1.
//	Es el patron de un OTIR/LDIRVM con la VRAM lenta por contencion.
task z80_out_wait(input [1:0] m, input [7:0] d);
begin
    wait( !bus_valid );
    z_mode = m; z_cdo = d;
    #(0.5*TSTATE);
    csw_n = 1'b0;
    #(3.0*TSTATE);
    csw_n = 1'b1;
    #(0.5*TSTATE);
end
endtask

//	IN con la cola de la instruccion recortada (para el barrido de fase del
//	MODO 4: hay que llegar al OUT siguiente con la pre-lectura AUN EN VUELO)
task z80_in_fast(input [1:0] m, output [7:0] d);
begin
    z_mode = m;
    #(0.5*TSTATE);
    csr_n = 1'b0;
    #(2.5*TSTATE);
    d = z_cdi;
    #(0.5*TSTATE);
    csr_n = 1'b1;
    #(0.5*TSTATE);
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

// ---------------------------------------------------------------------------
integer NACC = 40;
integer MODE = 0;
integer i, bad, exp_addr;
logic [7:0] got;
localparam [17:0] BASE = 18'h00100;

initial begin
    if( !$value$plusargs("LAT=%d",  LAT     ) ) LAT      = 40;
    if( !$value$plusargs("N=%d",    NACC    ) ) NACC     = 40;
    if( !$value$plusargs("MODE=%d", MODE    ) ) MODE     = 0;
    if( !$value$plusargs("FCPU=%d", FCPU_KHZ) ) FCPU_KHZ = 3580;
    TSTATE = 1000000.0 / FCPU_KHZ;

    for( i = 0; i < 262144; i = i + 1 ) vram[i] = ( i * 8'd37 + ( i >> 3 ) ) & 8'hFF;

    repeat (20) @(posedge clk);
    reset_n = 1;
    repeat (20) @(posedge clk);

    $display("=== tb_cpuif_dbl: MODE=%0d  LAT=%0d ciclos (%.0f ns)  Z80=%0d kHz  N=%0d ===",
             MODE, LAT, LAT*NS_PER_CY, FCPU_KHZ, NACC);

    bad = 0;

    if( MODE == 0 ) begin
        //	lecturas ENCADENADAS: la secuencia de bytes tiene que ser
        //	VRAM[BASE], VRAM[BASE+1], ... (el contador avanza UNO por IN)
        $display("  (lecturas encadenadas del puerto 0)");
        vram_set_rd(BASE);
        exp_addr = BASE;
        for( i = 0; i < NACC; i = i + 1 ) begin
            z80_in(2'd0, got);
            if( got !== vram[exp_addr] ) begin
                if( bad < 8 )
                    $display("  SECUENCIA ROTA en el IN #%0d: 0x%02h, tocaba 0x%02h (VRAM[0x%05h])",
                             i, got, vram[exp_addr], exp_addr);
                bad = bad + 1;
            end
            exp_addr = exp_addr + 1;
        end
    end
    else if( MODE == 1 ) begin
        //	SETRD + IN alternados: el OUT del puerto 1 cae dentro de la ventana
        //	de la pre-lectura que armo el IN anterior
        $display("  (SETRD + IN alternados)");
        for( i = 0; i < NACC; i = i + 1 ) begin
            exp_addr = BASE + i*7;
            vram_set_rd(exp_addr[17:0]);
            z80_in(2'd0, got);
            if( got !== vram[exp_addr] ) begin
                if( bad < 8 )
                    $display("  LECTURA MALA #%0d: 0x%02h, tocaba 0x%02h (VRAM[0x%05h])",
                             i, got, vram[exp_addr], exp_addr);
                bad = bad + 1;
            end
        end
    end
    else if( MODE == 4 ) begin
        //	BARRIDO DE FASE: el OUT al puerto 1 (escritura de R#7) se emite i
        //	CICLOS DE clk_86 despues del IN que arma la pre-lectura, con i =
        //	0..NACC-1. Busca el agujero HERMANO del bug #1: una transaccion que
        //	el maestro da por aceptada en el mismo ciclo en que se lanza la
        //	pre-lectura queda con ff_pf_inflight alto cuando le toca ejecutarse
        //	y NO se ejecuta nunca (n_exec < n_glue).
        $display("  (barrido de fase IN -> OUT de registro, 1 ciclo de clk_86 por paso)");
        for( i = 0; i < NACC; i = i + 1 ) begin
            vram_set_rd(BASE);
            z80_in_fast(2'd0, got);
            repeat (i) @(posedge clk);
            vdp_reg(6'd7, 8'h10 + i[7:0]);
            //	el registro TIENE que haber cogido el valor
            if( u_dut.ff_backdrop_color !== (8'h10 + i[7:0]) ) begin
                if( bad < 8 )
                    $display("  ESCRITURA DE REGISTRO PERDIDA con fase %0d: R#7=0x%02h, tocaba 0x%02h",
                             i, u_dut.ff_backdrop_color, 8'h10 + i[7:0]);
                bad = bad + 1;
            end
        end
    end
    else begin
        //	ESCRITURAS encadenadas: cada OUT al puerto 0 cae dentro de la
        //	ventana busy de la escritura anterior. La corrupcion queda EN LA
        //	MEMORIA: VRAM[BASE+i] debe valer 0x80+i y VRAM[BASE+NACC] NO debe
        //	haberse tocado.
        if( MODE == 3 ) $display("  (escrituras encadenadas en VRAM, Z80 CON /WAIT: el glue no pierde flancos)");
        else            $display("  (escrituras encadenadas en VRAM por el puerto 0)");
        vram_set_wr(BASE);
        for( i = 0; i < NACC; i = i + 1 ) begin
            if( MODE == 3 ) z80_out_wait(2'd0, 8'h80 + i[7:0]);
            else            z80_out     (2'd0, 8'h80 + i[7:0]);
        end
        //	esperar a que drene la ultima escritura
        repeat (4*LAT + 200) @(posedge clk);
        for( i = 0; i < NACC; i = i + 1 ) begin
            if( vram[BASE+i] !== (8'h80 + i[7:0]) ) begin
                if( bad < 8 )
                    $display("  VRAM CORRUPTA en 0x%05h: 0x%02h, tocaba 0x%02h",
                             BASE+i, vram[BASE+i], 8'h80 + i[7:0]);
                bad = bad + 1;
            end
        end
        if( vram[BASE+NACC] !== ((( BASE+NACC ) * 8'd37 + (( BASE+NACC ) >> 3)) & 8'hFF) ) begin
            $display("  DESBORDE: VRAM[0x%05h] (una celda MAS ALLA del bloque) ha sido escrita: 0x%02h",
                     BASE+NACC, vram[BASE+NACC]);
            bad = bad + 1;
        end
    end

    repeat (200) @(posedge clk);

    $display("");
    $display("  --- handshake del bus ---");
    $display("    transferencias valid&&ready (maestro)   : %0d", n_glue);
    $display("    ciclos con la condicion VIEJA del latch  : %0d", n_latch);
    $display("      (bus_valid && ff_bus_ready CRUDO; antes del fix CADA UNO de");
    $display("       esos ciclos era una aceptacion de la MISMA transaccion)");
    $display("    ejecuciones efectivas (w_read|w_write)  : %0d", n_exec);
    $display("    ciclos con peticion DENTRO de la ventana: %0d", n_win);
    $display("  --- actividad (si esto es 0, el banco NO esta ejerciendo nada) ---");
    $display("    accesos reales a VRAM: %0d lecturas / %0d escrituras", n_vram_rd, n_vram_wr);
    $display("    entregas de dato al bus (bus_rdata_en)  : %0d", n_deliv);
    $display("    flancos descartados por el GLUE (bug #26, ajeno): %0d", n_edgelost);
    $display("  --- VEREDICTO ---");
    $display("    *** EJECUCIONES DE MAS (n_exec - n_glue): %0d ***", n_exec - n_glue);
    $display("    *** FALLOS FUNCIONALES                  : %0d ***", bad);
    if( n_win == 0 )
        $display("    (!) ninguna peticion cayo en la ventana: sube +LAT, este caso NO prueba nada");
    else if( (bad == 0) && (n_exec == n_glue) )
        $display("    => SANO: 1 ejecucion por transaccion, sin corrupcion");
    else
        $display("    => BUG REPRODUCIDO");
    #1000;
    $finish;
end

//	watchdog: si el bus se queda atascado (bus_valid alto sin transferencia
//	durante 20000 ciclos) volcamos el estado — un cuelgue es tan interesante
//	como un doble disparo, pero hay que verlo, no adivinarlo.
integer stuck = 0;
always @(posedge clk) if( reset_n ) begin
    if( bus_valid && !bus_ready ) stuck = stuck + 1;
    else                          stuck = 0;
    if( stuck == 20000 ) begin
        $display("  *** BUS ATASCADO: bus_valid alto %0d ciclos sin ready", stuck);
        $display("      ff_bus_ready=%b ff_bus_valid=%b ff_busy=%b ff_pf_inflight=%b ff_pf_req=%b ff_pf_valid=%b",
                 p_bready, p_bvalid, p_busy, p_infl, u_dut.ff_pf_req, u_dut.ff_pf_valid);
        $display("      ff_vram_valid=%b ff_vram_address_inc=%b vram_valid=%b v_pend=%b vram_ready=%b v_cnt=%0d LAT=%0d v_we=%b",
                 u_dut.ff_vram_valid, u_dut.ff_vram_address_inc, vram_valid, v_pend, vram_ready, v_cnt, LAT, v_we);
        $finish;
    end
end

initial begin
    #300000000;
    $display("TIMEOUT");
    $finish;
end

endmodule
