// ============================================================================
// tb_upfix_s2vr.sv — Alineamiento del bit VR de S#2 con el interrupt de frame.
//
// Port del bugfix upstream eebc87f ("Bugfix VR bit on S#2"): en el arbol viejo
// el VR (status_vsync) subia al FINAL de la linea 211/191 (rama propia dentro
// de w_h_count_end), es decir ~56 us DESPUES del pulso intr_frame (que dispara
// en half_count==c_left_pos de esa misma linea). La MSX Diagnostics Cartridge
// lee S#2 nada mas atender la INT de frame y, si VR aun vale 0, concluye que
// el chip es un TMS9918. El fix upstream hace que ff_vsync se ponga a 1 en el
// MISMO evento w_intr_frame_timing (VR visible 1 ciclo despues del pulso) y
// mueve el clear de 3FE a 3FF.
//
// Solo instancia vdp_timing_control_ssg (como tb_ssgblink). Medidas por frame:
//   - delta_rise = ciclos entre el pulso intr_frame y el flanco de subida de
//     status_vsync (ANTES: ~4832 con 212 lineas / ~4832 con 192; DESPUES: 1).
//   - screen_pos_y en el flanco de bajada de VR (ANTES: 0x3FE+1 ciclo tarde;
//     DESPUES: linea 0x3FF).
// Barrido: 192/212 lineas x 60/50 Hz via plusargs +L212= +HZ50=.
// Actividad: exige n_frames>=4 y n_rises>=3 por configuracion (banco que no
// ejercita nada NO puede salir verde).
// ============================================================================
`timescale 1ns/1ps

module tb_upfix_s2vr;

localparam real CLK_HALF = 5.8207;      // 85.90908 MHz
logic clk = 0;
always #(CLK_HALF) clk = ~clk;
logic reset_n = 0;

integer l212 = 0;
integer hz50 = 0;

wire [11:0] h_count;
wire [ 9:0] v_count;
wire [13:0] screen_pos_x, screen_pos_x_clone, screen_pos_x_sprite;
wire [ 9:0] screen_pos_y;
wire [ 8:0] pixel_pos_x;
wire [ 7:0] pixel_pos_y;
wire        screen_v_active, intr_line, intr_frame, clear_line_interrupt;
wire        pre_vram_refresh;
wire [2:0]  horizontal_offset_l;
wire [8:3]  horizontal_offset_h;
wire        interleaving_page, blink, status_field, status_hsync, status_vsync;

logic       r_212 = 0, r_50 = 0;

vdp_timing_control_ssg u_ssg (
    .reset_n(reset_n), .clk(clk),
    .h_count(h_count), .v_count(v_count),
    .screen_pos_x(screen_pos_x),
    .screen_pos_x_clone(screen_pos_x_clone),
    .screen_pos_x_sprite(screen_pos_x_sprite),
    .screen_pos_y(screen_pos_y),
    .pixel_pos_x(pixel_pos_x), .pixel_pos_y(pixel_pos_y),
    .screen_v_active(screen_v_active),
    .intr_line(intr_line), .intr_frame(intr_frame),
    .clear_line_interrupt(clear_line_interrupt),
    .pre_vram_refresh(pre_vram_refresh),
    .reg_display_on(1'b1),
    .reg_50hz_mode(r_50),
    .reg_212lines_mode(r_212),
    .reg_interlace_mode(1'b0),
    .reg_display_adjust(8'h00),
    .reg_interrupt_line(8'd0),
    .reg_vertical_offset(8'd0),
    .reg_horizontal_offset_l(3'd0),
    .reg_horizontal_offset_h(6'd0),
    .reg_interleaving_mode(1'b0),
    .reg_flat_interlace_mode(1'b0),
    .reg_blink_period(8'h00),
    .reg_interrupt_line_nonR23_mode(1'b0),
    .horizontal_offset_l(horizontal_offset_l),
    .horizontal_offset_h(horizontal_offset_h),
    .interleaving_page(interleaving_page),
    .blink(blink),
    .status_field(status_field),
    .status_hsync(status_hsync),
    .status_vsync(status_vsync)
);

integer cyc = 0;
integer t_intr = -1;
integer n_frames = 0, n_rises = 0, n_falls = 0;
integer d, dmin, dmax;
integer errs = 0;
logic   prev_vs = 1'b1;
logic [9:0] posy_rise, posy_fall;
integer pending;                 // hay un intr_frame sin VR-rise emparejado

task run_cfg(input integer c212, input integer c50, input integer frames_max);
    integer budget;
    begin
        r_212 = c212[0]; r_50 = c50[0];
        reset_n = 0; repeat (20) @(posedge clk); reset_n = 1;
        cyc = 0; t_intr = -1; n_frames = 0; n_rises = 0; n_falls = 0;
        dmin = 999999999; dmax = -1; prev_vs = 1'b1; pending = 0;
        budget = frames_max * (c50 ? 1750000 : 1500000);
        $display("---- config: %0d lineas, %0s ----", c212 ? 212 : 192, c50 ? "50Hz" : "60Hz");
        while (n_frames < frames_max && budget > 0) begin
            @(posedge clk);
            cyc = cyc + 1; budget = budget - 1;
            if (intr_frame) begin
                t_intr = cyc; n_frames = n_frames + 1; pending = 1;
                $display("  frame %0d: intr_frame en cyc=%0d (pos_y=%0d, VR=%0d)",
                         n_frames, cyc, $signed({{22{screen_pos_y[9]}}, screen_pos_y}), status_vsync);
            end
            if (status_vsync && !prev_vs) begin
                n_rises = n_rises + 1;
                posy_rise = screen_pos_y;
                if (pending) begin
                    d = cyc - t_intr;
                    if (d < dmin) dmin = d;
                    if (d > dmax) dmax = d;
                    $display("    VR SUBE en cyc=%0d: delta intr->VR = %0d ciclos (pos_y=0x%03h)",
                             cyc, d, posy_rise);
                    pending = 0;
                end
                else begin
                    $display("    VR SUBE en cyc=%0d SIN intr_frame previo (pos_y=0x%03h)", cyc, posy_rise);
                end
            end
            if (!status_vsync && prev_vs) begin
                n_falls = n_falls + 1;
                posy_fall = screen_pos_y;
                $display("    VR BAJA en cyc=%0d (pos_y=0x%03h)", cyc, posy_fall);
            end
            prev_vs = status_vsync;
        end
        // actividad: sin frames o sin flancos el banco NO vale
        if (n_frames < 4) begin errs = errs + 1; $display("  *** ACTIVIDAD INSUFICIENTE: n_frames=%0d ***", n_frames); end
        if (n_rises  < 3) begin errs = errs + 1; $display("  *** ACTIVIDAD INSUFICIENTE: n_rises=%0d ***",  n_rises);  end
        if (n_falls  < 3) begin errs = errs + 1; $display("  *** ACTIVIDAD INSUFICIENTE: n_falls=%0d ***",  n_falls);  end
        $display("  RESUMEN cfg %0d/%0s: frames=%0d rises=%0d falls=%0d delta_min=%0d delta_max=%0d",
                 c212 ? 212 : 192, c50 ? "50" : "60", n_frames, n_rises, n_falls, dmin, dmax);
    end
endtask

initial begin
    run_cfg(0, 0, 5);
    run_cfg(1, 0, 5);
    run_cfg(0, 1, 5);
    run_cfg(1, 1, 5);
    if (errs == 0) $display("BANCO tb_upfix_s2vr: MEDIDA COMPLETA (0 problemas de actividad)");
    else           $display("BANCO tb_upfix_s2vr: %0d PROBLEMAS", errs);
    $finish;
end

endmodule
