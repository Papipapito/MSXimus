// ============================================================================
// tb_upfix_s10.sv — Leer S#10 NO debe borrar el interrupt de fin de comando.
//
// Port del bugfix upstream 7298638: quedaba una rama legada que, al leer el
// status register con el puntero en 10 (S#10), hacia
// ff_command_end_interrupt <= 0. El camino LEGITIMO de clear es la escritura
// en el puerto 4 con bit2=1. En NUESTRA generacion de registros el CEIE es
// R#21[7] (no confundir con la generacion post-0683e7e del upstream).
//
// Solo instancia vdp_cpu_interface. Secuencia:
//   1. R#21 = 0x80 (CEIE=1).
//   2. Pulso intr_command_end -> flag=1, int_n debe BAJAR.
//   3. R#15 = 10 (puntero de status en S#10) y LECTURA del puerto 1.
//      ANTES (bug): flag se borra, int_n vuelve a 1.
//      DESPUES:     flag sobrevive, int_n sigue a 0.        <== EL FIX
//   4. Lectura de S#2 (puntero 2): no debe tocar el flag (regresion).
//   5. Escritura puerto 4 con bit2=1: SI debe borrarlo (camino legitimo).
//   6. Regresion de los otros flags: S#0 borra frame-int, S#1 borra line-int,
//      y sus caminos por el puerto 4 (bit0/bit1) siguen vivos.
// Actividad: cuenta transacciones de bus y comprobaciones; exige >0.
// ============================================================================
`timescale 1ns/1ps

module tb_upfix_s10;

localparam real CLK_HALF = 5.8207;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;
logic reset_n = 0;

logic [2:0] bus_address = 0;
logic       bus_ioreq = 0, bus_write = 0, bus_valid = 0;
logic [7:0] bus_wdata = 0;
wire        bus_ready, bus_rdata_en;
wire [7:0]  bus_rdata;
wire        int_n;

logic intr_line = 0, intr_frame = 0, intr_command_end = 0;

vdp_cpu_interface u_dut (
    .reset_n(reset_n), .clk(clk),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .vram_address(), .vram_write(), .vram_valid(),
    .vram_ready(1'b1), .vram_wdata(),
    .vram_rdata(8'h00), .vram_rdata_en(1'b0),
    .palette_valid(), .palette_num(), .palette_r(), .palette_g(), .palette_b(),
    .int_n(int_n),
    .intr_line(intr_line), .intr_frame(intr_frame),
    .intr_command_end(intr_command_end),
    .clear_line_interrupt(1'b0),
    .clear_sprite_collision(), .sprite_collision(1'b0),
    .clear_sprite_collision_xy(),
    .sprite_collision_x(9'd0), .sprite_collision_y(10'd0),
    .sprite_overmap(1'b0), .sprite_overmap_id(5'd0),
    .clear_border_detect(), .read_color(),
    .register_write(), .register_num(), .register_data(),
    .status_command_execute(1'b0), .status_field(1'b0),
    .status_border_detect(1'b0), .status_hsync(1'b0), .status_vsync(1'b0),
    .status_transfer_ready(1'b0),
    .status_color(8'd0), .status_border_position(9'd0),
    .vram_access_mask(1'b0), .force_highspeed(1'b0),
    .reg_screen_mode(), .reg_sprite_magify(), .reg_sprite_16x16(),
    .reg_display_on(),
    .reg_pattern_name_table_base(), .reg_color_table_base(),
    .reg_pattern_generator_table_base(), .reg_sprite_attribute_table_base(),
    .reg_sprite_pattern_generator_table_base(),
    .reg_backdrop_color(), .reg_sprite_disable(), .reg_color0_opaque(),
    .reg_50hz_mode(), .reg_interleaving_mode(), .reg_interlace_mode(),
    .reg_212lines_mode(), .reg_text_back_color(), .reg_blink_period(),
    .reg_display_adjust(), .reg_interrupt_line(), .reg_vertical_offset(),
    .reg_scroll_planes(), .reg_left_mask(), .reg_yjk_mode(), .reg_yae_mode(),
    .reg_command_enable(), .reg_sprite_priority_shuffle(),
    .reg_horizontal_offset_l(), .reg_horizontal_offset_h(),
    .reg_command_high_speed_mode(), .reg_sprite_nonR23_mode(),
    .reg_interrupt_line_nonR23_mode(), .reg_sprite_mode3(),
    .reg_ext_palette_mode(), .reg_ext_command_mode(), .reg_vram256k_mode(),
    .reg_sprite16_mode(), .reg_flat_interlace_mode(),
    .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

integer n_bus = 0, n_checks = 0, errs = 0;
logic [7:0] rd_last;

task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    n_bus = n_bus + 1;
    repeat (20) @(posedge clk);
end
endtask

task bus_rd(input [2:0] a);
    integer k;
begin : rd_body
    @(posedge clk);
    bus_address <= a; bus_wdata <= 0;
    bus_ioreq <= 1; bus_write <= 0; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_valid <= 0;
    //	el dato es valido el ciclo en que bus_rdata_en=1: muestrear en negedge
    //	(todos los NBA ya asentados) para no correr contra el latch del DUT
    rd_last = 8'hXX;
    for (k = 0; k < 12; k = k + 1) begin
        @(negedge clk);
        if (bus_rdata_en) begin
            rd_last = bus_rdata;
            k = 12;
        end
    end
    n_bus = n_bus + 1;
    repeat (20) @(posedge clk);
end
endtask

task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

task pulse_cmd_end; begin @(posedge clk); intr_command_end <= 1; @(posedge clk); intr_command_end <= 0; repeat (5) @(posedge clk); end endtask
task pulse_frame;   begin @(posedge clk); intr_frame       <= 1; @(posedge clk); intr_frame       <= 0; repeat (5) @(posedge clk); end endtask
task pulse_line;    begin @(posedge clk); intr_line        <= 1; @(posedge clk); intr_line        <= 0; repeat (5) @(posedge clk); end endtask

task check(input cond, input [400*8:1] msg);
begin
    n_checks = n_checks + 1;
    if (cond) $display("  OK  : %0s", msg);
    else begin errs = errs + 1; $display("  MAL : %0s", msg); end
end
endtask

initial begin
    repeat (30) @(posedge clk);
    reset_n = 1;
    repeat (30) @(posedge clk);

    // 1. CEIE = R#21[7] (generacion vieja del arbol MSXimus)
    vdp_reg(6'd21, 8'h80);
    check(u_dut.ff_command_end_interrupt_enable === 1'b1, "R#21[7] arma el CEIE");

    // 2. fin de comando -> flag + INT
    pulse_cmd_end;
    check(u_dut.ff_command_end_interrupt === 1'b1, "intr_command_end pone el flag");
    check(int_n === 1'b0, "int_n BAJA con el flag armado y CEIE=1");

    // 3. leer S#10 (el caso del bug)
    vdp_reg(6'd15, 8'd10);
    bus_rd(3'd1);
    $display("  (S#10 leido = 0x%02h)", rd_last);
    check(u_dut.ff_command_end_interrupt === 1'b1, "leer S#10 NO borra el flag de fin de comando  <== EL FIX");
    check(int_n === 1'b0, "int_n sigue BAJO tras leer S#10                <== EL FIX");

    // 4. leer S#2 tampoco lo toca
    vdp_reg(6'd15, 8'd2);
    bus_rd(3'd1);
    check(u_dut.ff_command_end_interrupt === 1'b1, "leer S#2 no toca el flag (regresion)");

    // 5. el camino legitimo: puerto 4, bit2
    bus_wr(3'd4, 8'h04);
    check(u_dut.ff_command_end_interrupt === 1'b0, "escribir puerto4 bit2 SI borra el flag");
    check(int_n === 1'b1, "int_n vuelve a 1 tras el clear legitimo");

    // 6. regresion de los otros dos flags
    pulse_frame;
    check(u_dut.ff_frame_interrupt === 1'b1, "intr_frame pone su flag");
    vdp_reg(6'd15, 8'd0);
    bus_rd(3'd1);
    check(u_dut.ff_frame_interrupt === 1'b0, "leer S#0 borra el flag de frame (regresion)");

    pulse_line;
    check(u_dut.ff_line_interrupt === 1'b1, "intr_line pone su flag");
    vdp_reg(6'd15, 8'd1);
    bus_rd(3'd1);
    check(u_dut.ff_line_interrupt === 1'b0, "leer S#1 borra el flag de linea (regresion)");

    pulse_frame; pulse_line;
    bus_wr(3'd4, 8'h03);
    check(u_dut.ff_frame_interrupt === 1'b0 && u_dut.ff_line_interrupt === 1'b0,
          "puerto4 bits0/1 borran frame/linea (regresion)");

    // actividad
    if (n_bus < 15)   begin errs = errs + 1; $display("  *** ACTIVIDAD INSUFICIENTE: n_bus=%0d ***", n_bus); end
    if (n_checks < 12) begin errs = errs + 1; $display("  *** ACTIVIDAD INSUFICIENTE: n_checks=%0d ***", n_checks); end

    if (errs == 0) $display("BANCO tb_upfix_s10: TODO OK (%0d transacciones, %0d comprobaciones)", n_bus, n_checks);
    else           $display("BANCO tb_upfix_s10: %0d FALLOS (%0d transacciones, %0d comprobaciones)", errs, n_bus, n_checks);
    $finish;
end

endmodule
