// ============================================================================
// tb_palette_yjk_ab.sv - A/B de vdp_color_palette.v: el RTL nuevo (sprites en SCREEN 10/11/12, Z1.3.2b10) frente al anterior
// (`vdp_color_palette_old`, el de la b9 = ea53294) con el mismo estimulo aleatorio, ciclo a ciclo, en TODOS los modos de pantalla
// (G1..G7, texto, mosaico), con y sin YJK/YAE, paleta ampliada, color 0 opaco, sprite mode 3 y paleta escrita a mitad de linea.
//
// Debe salir IDENTICO (vdp_r/g/b) cuando:
//   - reg_yjk_mode = 0, con o sin sprites (SCREEN 8 con su tabla fija de 256 colores, G4-G7, ...), y
//   - reg_yjk_mode = 1 y no hay ningun sprite en las ultimas celdas (SCREEN 12 / 10-11 sin sprites; tambien el bit YJK suelto en un modo
//     que no es G7: el punto (c) de la revision, que NO se toca).
// Solo puede y debe cambiar con reg_yjk_mode = 1 y un sprite en curso: el cambio de este arreglo (se cuenta, para ver que el banco lo ve).
// Los registros cambian solo en la celda 8 (lejos de la carga del RGB) y no se compara hasta 8 celdas despues de cualquier cambio.
// Uso: bash run_palette_yjk_ab.sh [dir con el vdp_color_palette.v ANTERIOR]   (Icarus, WSL; por defecto, git show ea53294)
// ============================================================================
`timescale 1ns/1ps
module tb_palette_yjk_ab;
    reg clk = 0;
    always #5.8207 clk = ~clk;
    reg reset_n = 0;
    reg [5:0] pos = 6'd0;
    always @(posedge clk) pos <= pos + 6'd1;
    wire [1:0] phase = pos[5:4];

    reg  [7:0] pix = 8'd0;
    reg        pix_en = 1'b0;
    reg        pal_v = 1'b0;
    reg  [7:0] pal_n = 8'd0;
    reg  [4:0] pal_r = 5'd0, pal_g = 5'd0, pal_b = 5'd0;
    reg  [7:0] spr = 8'd0;
    reg  [1:0] spr_t = 2'd0;
    reg        spr_en = 1'b0;
    reg  [4:0] smode = 5'b11100;
    reg        yjk = 1'b0, yae = 1'b0, c0op = 1'b0, extpal = 1'b0, m3 = 1'b0;
    reg  [7:0] bdrop = 8'd0;
    wire [7:0] nr, ng, nb, or_, og, ob;

    vdp_color_palette dut_new (
        .reset_n(reset_n), .clk(clk), .screen_pos_x(pos), .pixel_phase_x(phase),
        .palette_valid(pal_v), .palette_num(pal_n), .palette_r(pal_r), .palette_g(pal_g), .palette_b(pal_b),
        .display_color_screen_mode(pix), .display_color_screen_mode_en(pix_en),
        .display_color_sprite(spr), .display_color_sprite_transparent(spr_t), .display_color_sprite_en(spr_en),
        .vdp_r(nr), .vdp_g(ng), .vdp_b(nb),
        .reg_screen_mode(smode), .reg_yjk_mode(yjk), .reg_yae_mode(yae), .reg_color0_opaque(c0op),
        .reg_backdrop_color(bdrop), .reg_ext_palette_mode(extpal), .reg_sprite_mode3(m3)
    );
    vdp_color_palette_old dut_old (
        .reset_n(reset_n), .clk(clk), .screen_pos_x(pos), .pixel_phase_x(phase),
        .palette_valid(pal_v), .palette_num(pal_n), .palette_r(pal_r), .palette_g(pal_g), .palette_b(pal_b),
        .display_color_screen_mode(pix), .display_color_screen_mode_en(pix_en),
        .display_color_sprite(spr), .display_color_sprite_transparent(spr_t), .display_color_sprite_en(spr_en),
        .vdp_r(or_), .vdp_g(og), .vdp_b(ob),
        .reg_screen_mode(smode), .reg_yjk_mode(yjk), .reg_yae_mode(yae), .reg_color0_opaque(c0op),
        .reg_backdrop_color(bdrop), .reg_ext_palette_mode(extpal), .reg_sprite_mode3(m3)
    );

    // xorshift32: todos los bits valen (el LCG de $urandom tiene los bajos con periodo corto y correlaciona los campos)
    reg [31:0] xs = 32'h2545F491;
    function [31:0] rnd(input integer dummy);
        begin
            xs = xs ^ (xs << 13);
            xs = xs ^ (xs >> 17);
            xs = xs ^ (xs << 5);
            rnd = xs;
        end
    endfunction

    reg [4:0] modes [0:9];
    initial begin
        modes[0] = 5'b00000; modes[1] = 5'b00100; modes[2] = 5'b01000; modes[3] = 5'b01100; modes[4] = 5'b10000;
        modes[5] = 5'b10100; modes[6] = 5'b11100; modes[7] = 5'b00001; modes[8] = 5'b01001; modes[9] = 5'b00010;
    end

    integer ncell = 0, since_flags = 0, since_spr = 99;
    integer ncmp = 0, nbad = 0, ncmp_yjk0 = 0, ncmp_yjk0_spr = 0, ncmp_yjk1 = 0, ncmp_g7yjk = 0, ndiff_expected = 0, ncells_yjk_spr = 0;
    integer ncmp_mode [0:9];
    integer ii;
    initial for (ii = 0; ii < 10; ii = ii + 1) ncmp_mode[ii] = 0;
    reg [31:0] r, r2;
    reg        spr_on = 1'b0;
    integer mi = 6;
    reg run = 1'b0;

    // estimulo: una celda de 16 ciclos; los registros solo cambian en la celda 8, la paleta a mitad de celda
    always @(posedge clk) if (run) begin
        if (pos[3:0] == 4'd15) begin
            r = rnd(0);
            pix    <= r[7:0];
            pix_en <= (r[15:8] % 100) < 88;
            // sprites en rachas (media 5 celdas con sprite, 25 sin): hacen falta tramos largos sin sprite para comparar YJK
            r2 = rnd(0);
            spr_on = spr_on ? ((r2[7:0] % 100) < 80) : ((r2[7:0] % 100) < 4);
            spr_en <= spr_on;
            spr    <= r[23:16];
            spr_t  <= r[25:24];
            ncell  <= ncell + 1;
            since_flags <= since_flags + 1;
            since_spr   <= spr_on ? 0 : since_spr + 1;
        end
        if (pos[3:0] == 4'd8 && (rnd(0) % 48) == 0) begin
            r2 = rnd(0);
            mi    = r2[27:24] % 10;
            smode <= modes[mi];
            yjk   <= (r2[3:0] < 9);                       // mas tiempo en YJK
            yae   <= r2[4];
            c0op  <= r2[5];
            extpal<= (r2[10:6] == 5'd0);                  // rara
            m3    <= r2[11];
            bdrop <= r2[23:16];
            since_flags <= 0;
        end
        if (pos[3:0] == 4'd5) begin
            r2 = rnd(0);
            pal_v <= (r2[31:29] == 3'd0);
            pal_n <= r2[7:0]; pal_r <= r2[12:8]; pal_g <= r2[17:13]; pal_b <= r2[22:18];
        end
        else if (pos[3:0] == 4'd6) pal_v <= 1'b0;
    end

    // comparacion ciclo a ciclo
    always @(posedge clk) if (run) begin
        if (since_flags >= 8) begin
            if (!yjk || since_spr >= 8) begin
                ncmp = ncmp + 1;
                ncmp_mode[mi] = ncmp_mode[mi] + 1;
                if (!yjk) begin ncmp_yjk0 = ncmp_yjk0 + 1; if (since_spr < 8) ncmp_yjk0_spr = ncmp_yjk0_spr + 1; end
                else begin ncmp_yjk1 = ncmp_yjk1 + 1; if (smode == 5'b11100) ncmp_g7yjk = ncmp_g7yjk + 1; end
                if ({nr, ng, nb} !== {or_, og, ob}) begin
                    nbad = nbad + 1;
                    if (nbad <= 5) $display("  DIFF celda %0d modo %b yjk %b yae %b ext %b m3 %b: nuevo %02h%02h%02h anterior %02h%02h%02h",
                                            ncell, smode, yjk, yae, extpal, m3, nr, ng, nb, or_, og, ob);
                end
            end
            else begin
                ncells_yjk_spr = ncells_yjk_spr + 1;
                if ({nr, ng, nb} !== {or_, og, ob}) ndiff_expected = ndiff_expected + 1;
            end
        end
    end

    integer k;
    initial begin
        repeat (8) @(posedge clk);
        reset_n = 1'b1;
        repeat (600) @(posedge clk);
        // rellena la paleta de 256 entradas, para que no haya X
        for (k = 0; k < 256; k = k + 1) begin
            @(posedge clk); pal_v <= 1'b1; pal_n <= k[7:0]; pal_r <= k[4:0] ^ 5'h15; pal_g <= k[7:3] ^ 5'h0A; pal_b <= k[6:2] + 5'd3;
        end
        @(posedge clk); pal_v <= 1'b0;
        repeat (40) @(posedge clk);
        @(posedge clk); while (pos != 6'd62) @(posedge clk);
        run = 1'b1;
        repeat (16 * 40000) @(posedge clk);
        run = 1'b0;
        $display("  comparados %0d ciclos: %0d con reg_yjk_mode = 0 (%0d de ellos con sprites en curso), %0d con YJK sin sprites (%0d en G7)",
                 ncmp, ncmp_yjk0, ncmp_yjk0_spr, ncmp_yjk1, ncmp_g7yjk);
        $display("  por modo (G1 G2 G3 G4 G5 G6 G7 T1 T2 GM): %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                 ncmp_mode[0], ncmp_mode[1], ncmp_mode[2], ncmp_mode[3], ncmp_mode[4], ncmp_mode[5], ncmp_mode[6], ncmp_mode[7], ncmp_mode[8], ncmp_mode[9]);
        $display("  ciclos con YJK y sprite en curso (el cambio esperado): %0d, de ellos distintos del anterior: %0d", ncells_yjk_spr, ndiff_expected);
        if (nbad == 0 && ncmp_yjk0 > 100000 && ncmp_yjk0_spr > 20000 && ncmp_g7yjk > 10000 && ncmp_yjk1 > 30000 && ndiff_expected > 1000)
            $display("TB_OK: %0d ciclos identicos a la b9 donde no debe cambiar nada", ncmp);
        else
            $display("TB_FAIL: %0d ciclos distintos de la b9 donde no debian cambiar", nbad);
        $finish;
    end
    initial begin #900000000 $display("TB_TIMEOUT"); $finish; end
endmodule
