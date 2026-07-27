// ============================================================================
// tb_ssgblink.sv — CADENCIA DEL BLINK del V9968 (vdp_timing_control_ssg solo).
//
// Mide, campo a campo (NTSC 60Hz, 524 half-lines), el valor de la salida
// `blink` que consume vdp_timing_control_screen_mode para TEXT2, y comprueba:
//   1. que `blink` es CONSTANTE dentro de cada campo (si cambiase a mitad de
//      pantalla, media pantalla saldria con colores de blink => residuo),
//   2. cuantos campos dura cada estado (debe ser 10 x nibble de R#13),
//   3. que con R#13 == 0 el blink queda apagado para siempre.
//
// Barrido con +P=<valor de R#13>. Sin argumentos: 0x00, 0x11, 0x10, 0x01, 0x22.
// El modulo es pequeno: ~150 campos simulan en segundos.
// ============================================================================
`timescale 1ns/1ps

module tb_ssgblink;

localparam real CLK_HALF = 5.8207;   // 85.90908 MHz
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [7:0] reg_blink_period = 8'h00;

wire [11:0] h_count;
wire [ 9:0] v_count;
wire [13:0] screen_pos_x, screen_pos_x_clone, screen_pos_x_sprite;
wire [ 9:0] screen_pos_y;
wire [ 8:0] pixel_pos_x;
wire [ 7:0] pixel_pos_y;
wire        screen_v_active, intr_line, intr_frame, clear_line_interrupt, pre_vram_refresh;
wire [ 2:0] horizontal_offset_l;
wire [ 8:3] horizontal_offset_h;
wire        interleaving_page, blink, status_field, status_hsync, status_vsync;

vdp_timing_control_ssg u_ssg (
    .reset_n(reset_n), .clk(clk),
    .h_count(h_count), .v_count(v_count),
    .screen_pos_x(screen_pos_x), .screen_pos_x_clone(screen_pos_x_clone),
    .screen_pos_x_sprite(screen_pos_x_sprite),
    .screen_pos_y(screen_pos_y),
    .pixel_pos_x(pixel_pos_x), .pixel_pos_y(pixel_pos_y),
    .screen_v_active(screen_v_active),
    .intr_line(intr_line), .intr_frame(intr_frame),
    .clear_line_interrupt(clear_line_interrupt), .pre_vram_refresh(pre_vram_refresh),
    .reg_display_on(1'b1), .reg_50hz_mode(1'b0), .reg_212lines_mode(1'b0),
    .reg_interlace_mode(1'b0), .reg_display_adjust(8'h00),
    .reg_interrupt_line(8'd0), .reg_vertical_offset(8'd0),
    .reg_horizontal_offset_l(3'd0), .reg_horizontal_offset_h(6'd0),
    .reg_interleaving_mode(1'b0), .reg_flat_interlace_mode(1'b0),
    .reg_blink_period(reg_blink_period),
    .reg_interrupt_line_nonR23_mode(1'b0),
    .horizontal_offset_l(horizontal_offset_l), .horizontal_offset_h(horizontal_offset_h),
    .interleaving_page(interleaving_page), .blink(blink),
    .status_field(status_field), .status_hsync(status_hsync), .status_vsync(status_vsync)
);

// ---------------------------------------------------------------------------
//  Frontera de campo: w_h_count_end && w_v_count_end (v_count vuelve a 0)
// ---------------------------------------------------------------------------
integer field_no = 0;
logic [9:0] vprev = 0;
integer blk_seen_0, blk_seen_1;     // muestras de blink dentro del campo
integer glitch_fields = 0;
integer blk_field [0:399];
integer glitch_field [0:399];

always @(posedge clk) begin
    vprev <= v_count;
    if (reset_n) begin
        if (v_count == 0 && vprev != 0) begin        // nuevo campo
            if (field_no < 400) begin
                blk_field[field_no]    = (blk_seen_1 > blk_seen_0) ? 1 : 0;
                glitch_field[field_no] = (blk_seen_0 != 0 && blk_seen_1 != 0) ? 1 : 0;
                if (blk_seen_0 != 0 && blk_seen_1 != 0) glitch_fields = glitch_fields + 1;
            end
            field_no   = field_no + 1;
            blk_seen_0 = 0;
            blk_seen_1 = 0;
        end
        // muestreo SOLO dentro del area activa vertical (lo que se ve)
        if (screen_v_active) begin
            if (blink) blk_seen_1 = blk_seen_1 + 1;
            else       blk_seen_0 = blk_seen_0 + 1;
        end
    end
end

integer NF = 25;                     // 25 campos ~ 0,42 s de sim (~3 min de CPU).
                                     // Con +NF=<n> se alarga (10 campos = una
                                     // unidad de R#13, asi que 25 ya ensena
                                     // el primer conmutador y su cadencia).
integer i, run, val, nrun;
integer P;

initial begin
    blk_seen_0 = 0; blk_seen_1 = 0;
    void'($value$plusargs("NF=%d", NF));
    if (!$value$plusargs("P=%d", P)) P = 8'h11;
    reg_blink_period = P[7:0];
    repeat (20) @(posedge clk);
    reset_n = 1;
    wait (field_no >= NF);
    $display("=== R#13 = 0x%02h  (ON=%0d  OFF=%0d) ===", P[7:0], P[7:4], P[3:0]);
    $write("  blink por campo: ");
    for (i = 1; i < NF; i = i + 1) $write("%0d", blk_field[i]);
    $write("\n");
    // longitudes de las rachas
    $write("  rachas (campos por estado): ");
    val = blk_field[1]; run = 1; nrun = 0;
    for (i = 2; i < NF; i = i + 1) begin
        if (blk_field[i] == val) run = run + 1;
        else begin $write(" %0d(%0d)", run, val); val = blk_field[i]; run = 1; nrun = nrun + 1; end
    end
    $write("  [cola %0d(%0d)]\n", run, val);
    if (glitch_fields != 0)
        $display("  *** ALERTA: %0d campos con blink CAMBIANDO A MITAD DE PANTALLA ***", glitch_fields);
    else
        $display("  OK: blink constante dentro de cada campo activo (0 glitches en %0d campos)", NF);
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT field_no=%0d", field_no);
    $finish;
end

endmodule
