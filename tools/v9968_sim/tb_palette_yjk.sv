// ============================================================================
// tb_palette_yjk.sv - vdp_color_palette.v A SOLAS en los modos de 256 colores: SCREEN 8 (RGB 3-3-2), SCREEN 10/11 (YJK + paleta con A)
// y SCREEN 12 (YJK), contra un modelo escrito aparte (libro de datos del V9958).
//
// Motivo (01/11/2026, upstream HRA bee8f7e "v0.93"): en SCREEN 10/11 un pixel con A = 1 lleva en los 4 bits altos del byte el numero de
// paleta; el RTL anterior lo trataba como un color de 256 (GRB 3-3-2) y, con delay3 en vez de delay4, lo colocaba una celda antes que
// los pixeles YJK de al lado. Bien: la celda del pixel A = 1 sale con el color de la paleta, en su sitio.
//
// El pixel de cada celda de 16 ciclos se presenta como lo hace el generador de modos (estable en la celda); se captura el RGB de 5 bits
// (w_display_r/g/b) en el ciclo en que ff_rgb_load lo manda al gamma. La alineacion del grupo de 4 pixeles YJK con pixel_phase_x y la
// latencia se BUSCAN (4 x 16): hay que encontrar una pareja que case TODA la fila YJK pura (A = 0), y la fila mezclada con A = 1 ha de
// casar con LA MISMA pareja. Las filas se repiten con el RTL viejo y el nuevo (A/B): el viejo falla en las filas con A = 1.
//
// SPRITES (02/11/2026, Z1.3.2b10): ademas de los pixeles de fondo, cada celda lleva (en la misma celda de 16 ciclos, como el generador de
// sprites) el color del sprite, su mezcla (TP, sprite mode 3) y el permiso de pantalla. El sprite ha de salir EN LA CELDA DEL FONDO de
// su pixel, sobre cualquier pixel (YJK, A = 0, A = 1), con la paleta de 16 colores (la fija de 256 colores en SCREEN 8), y no en el borde.
// Cada prueba presenta el MISMO flujo dos veces, sin sprite y con sprite, y exige que la salida con sprite sea la de sin sprite salvo en
// las celdas de sprite (color del sprite, o su mezcla con el fondo ya capturado: openMSX SpriteConverter::pixel_transparent), con
// el borde incluido; asi tambien se comprueba que sin sprite nada cambia.
// Uso: bash run_palette_yjk.sh [dir con vdp_color_palette.v y vdp_color_palette_ram.v]   (Icarus, WSL)
// ============================================================================
`timescale 1ns/1ps
module tb_palette_yjk;
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
    reg        yjk = 1'b1, yae = 1'b1;
    reg  [7:0] spr = 8'd0;                     // sprite: color (con numero de paleta en el modo 3), mezcla y permiso
    reg  [1:0] spr_t = 2'd0;
    reg        spr_en = 1'b0;
    reg        m3 = 1'b0;                      // reg_sprite_mode3
    reg  [7:0] bdrop = 8'd0;                   // color de borde
    wire [7:0] vr, vg, vb;

    vdp_color_palette dut (
        .reset_n(reset_n), .clk(clk), .screen_pos_x(pos), .pixel_phase_x(phase),
        .palette_valid(pal_v), .palette_num(pal_n), .palette_r(pal_r), .palette_g(pal_g), .palette_b(pal_b),
        .display_color_screen_mode(pix), .display_color_screen_mode_en(pix_en),
        .display_color_sprite(spr), .display_color_sprite_transparent(spr_t), .display_color_sprite_en(spr_en),
        .vdp_r(vr), .vdp_g(vg), .vdp_b(vb),
        .reg_screen_mode(5'b11100), .reg_yjk_mode(yjk), .reg_yae_mode(yae), .reg_color0_opaque(1'b0),
        .reg_backdrop_color(bdrop), .reg_ext_palette_mode(1'b0), .reg_sprite_mode3(m3)
    );

    localparam integer N = 96;                 // pixeles de datos de cada fila
    localparam integer PRE = 4;                // celdas de relleno por delante (alineacion)
    // El sprite del pixel i se presenta SO celdas DESPUES que el fondo del pixel i: el generador de sprites ya trae su retardo hecho y
    // en SCREEN 8 (sin YJK) el sprite se busca en la paleta en la celda n y el fondo en la n + 1 (el fondo tarda una celda mas). En YJK el
    // fondo tarda 4 mas (delay4) y el sprite ha de tardar otras 4: la relacion sprite/fondo es la MISMA en los tres modos.
    localparam integer SO = 1;
    reg  [7:0]  sb  [0:PRE + N + 40];          // el flujo presentado
    reg  [7:0]  sc  [0:PRE + N + 40];          // color del sprite de cada celda del flujo (0 = sin sprite)
    reg  [1:0]  stp [0:PRE + N + 40];          // su mezcla (TP)
    reg         sdis[0:PRE + N + 40];          // 1 = celda en el area visible (0 = borde)
    reg  [14:0] cap [0:PRE + N + 40];          // RGB de 5 bits capturado por celda
    reg  [14:0] cap0[0:PRE + N + 40];          // copia de la captura sin sprite
    reg  [14:0] pal_rgb [0:47];                // paleta 0..15 (sprite mode 2) y 16..47 (numeros de paleta 1 y 2 del sprite mode 3)
    integer     cel = 0, ncap = 0, nstream = 0;
    reg         run = 1'b0;

    always @(posedge clk) begin
        if (run && pos[3:0] == 4'd15) begin
            pix    <= (cel < nstream) ? sb[cel] : 8'd0;
            pix_en <= (cel < nstream) ? sdis[cel] : 1'b1;
            spr    <= (cel < nstream) ? sc[cel] : 8'd0;
            spr_t  <= (cel < nstream) ? stp[cel] : 2'd0;
            spr_en <= (cel < nstream) ? (sc[cel][3:0] != 4'd0) : 1'b0;
            cel   <= cel + 1;
        end
        if (run && dut.ff_rgb_load) begin
            cap[ncap] <= {dut.w_display_r, dut.w_display_g, dut.w_display_b};
            ncap      <= ncap + 1;
        end
    end

    // ---- modelo ----
    function integer clamp5(input integer v);
        clamp5 = (v < 0) ? 0 : (v > 31) ? 31 : v;
    endfunction
    function integer sx6(input integer v);      // 6 bits con signo
        sx6 = (v >= 32) ? v - 64 : v;
    endfunction
    // RGB 5 bits esperado del pixel i de los datos (d[] = datos), mode: 0 = SCREEN 8, 1 = SCREEN 10/11, 2 = SCREEN 12
    reg [7:0] d [0:N + 7];
    reg [7:0] sp  [0:N + 7];                    // color de sprite de cada pixel de datos (0 = sin sprite); en el modo 3, {paleta, color}
    reg [1:0] tp  [0:N + 7];                    // su mezcla (TP)
    reg       dis [0:N + 7];                    // 1 = pixel en el area visible (0 = borde)
    function [14:0] model(input integer i, input integer mode);
        integer g, y, j, k, r, gg, b, t, by;
        reg [7:0] p;
        begin
            p = d[i];
            if (mode == 0) begin
                r  = {p[4:2], p[4:3]};
                gg = {p[7:5], p[7:6]};
                b  = {p[1:0], p[1] & p[0], p[1:0]};
                model = {r[4:0], gg[4:0], b[4:0]};
            end else if (mode == 1 && p[3]) begin
                model = pal_rgb[p[7:4]];
            end else begin
                g = i - (i % 4);
                k = sx6({d[g + 1][2:0], d[g][2:0]});
                j = sx6({d[g + 3][2:0], d[g + 2][2:0]});
                y = (mode == 1) ? {p[7:4], 1'b0} : p[7:3];
                r  = clamp5(y + j);
                gg = clamp5(y + k);
                t  = 5 * y - (2 * j + k) + 2;
                b  = clamp5(t >>> 2);
                model = {r[4:0], gg[4:0], b[4:0]};
            end
        end
    endfunction

    // ---- una fila: presenta PRE + N celdas (con `al` celdas de relleno al principio) y captura ----
    task present(input integer al);
        integer i;
        begin
            for (i = 0; i < PRE + N + 40; i = i + 1) begin sb[i] = 8'h00; sc[i] = 8'h00; stp[i] = 2'd0; sdis[i] = 1'b1; end
            for (i = 0; i < N + 8; i = i + 1) begin sb[al + i] = d[i]; sc[al + i + SO] = sp[i]; stp[al + i + SO] = tp[i]; sdis[al + i] = dis[i]; end
            nstream = al + N + 8;
            cel = 0; ncap = 0;
            @(posedge clk); while (pos != 6'd62) @(posedge clk);       // siempre en la misma fase: la celda k tiene pixel_phase_x = k mod 4
            run = 1'b1;
            while (cel < nstream + 14) @(posedge clk);
            run = 1'b0;
            repeat (40) @(posedge clk);
            pix_en = 1'b0; spr_en = 1'b0;
        end
    endtask

    // numero de pixeles de d[8 .. N-9] cuya captura, con alineacion `al` y latencia `lat`, coincide con el modelo
    function integer ncasan(input integer al, input integer lat, input integer mode);
        integer i, n;
        begin
            n = 0;
            for (i = 8; i < N - 8; i = i + 1)
                if (cap[al + i + lat] === model(i, mode)) n = n + 1;
            ncasan = n;
        end
    endfunction

    integer seed = 32'h1234ABCD;
    function [7:0] rnd8(input integer dummy);
        begin seed = seed * 1103515245 + 12345; rnd8 = seed[23:16]; end
    endfunction

    integer bad = 0;
    integer best, i, ta, tl;
    integer al0 [0:2], lat0 [0:2];

    // genera la fila de datos del `mode`; apal = 0: sin pixeles A = 1 en SCREEN 10/11
    task gen(input integer mode, input integer apal);
        integer i2;
        begin
            for (i2 = 0; i2 < N + 8; i2 = i2 + 1) begin
                d[i2] = rnd8(0);
                sp[i2] = 8'd0; tp[i2] = 2'd0; dis[i2] = 1'b1;
                if (mode == 1) begin
                    if (apal && (d[i2][1:0] == 2'b00) && d[i2][7:4] != 4'd0) d[i2][3] = 1'b1;     // A = 1 en 1 de cada 4 con paleta distinta de 0
                    else d[i2][3] = 1'b0;
                end
            end
        end
    endtask

    // busca (al, lat) que case la fila entera; devuelve la mejor
    task search(input integer mode, output integer bal, output integer blat, output integer bn);
        integer al2, l2, n2;
        begin
            bn = -1; bal = 0; blat = 0;
            for (al2 = 0; al2 < 4; al2 = al2 + 1) begin
                present(al2);
                for (l2 = 0; l2 < 14; l2 = l2 + 1) begin
                    n2 = ncasan(al2, l2, mode);
                    if (n2 > bn) begin bn = n2; bal = al2; blat = l2; end
                end
            end
        end
    endtask

    task row(input integer mode, input integer apal, input [8*40-1:0] what);
        integer bn, fin;
        begin
            gen(mode, apal);
            // la alineacion buena es la de la fila SIN A = 1 del mismo modo (esa ya se busco): se presenta con ella y se cuentan aciertos
            present(al0[mode]);
            bn = ncasan(al0[mode], lat0[mode], mode);
            if (bn == N - 16) $display("  PASS %0s: %0d/%0d pixeles (alineacion %0d, latencia %0d celdas)", what, bn, N - 16, al0[mode], lat0[mode]);
            else begin
                bad = bad + 1;
                $display("  FAIL %0s: %0d/%0d pixeles (alineacion %0d, latencia %0d celdas)", what, bn, N - 16, al0[mode], lat0[mode]);
                // el primero que no casa
                for (fin = 8; fin < N - 8; fin = fin + 1)
                    if (cap[al0[mode] + fin + lat0[mode]] !== model(fin, mode)) begin
                        $display("       pixel %0d (byte %02h): salio %h, esperado %h", fin, d[fin], cap[al0[mode] + fin + lat0[mode]], model(fin, mode));
                        fin = N;
                    end
            end
        end
    endtask

    // ---- sprites ----
    // color fijo de los sprites en SCREEN 8 (libro del V9938/V9958, byte GGGRRRBB), escrito aparte del RTL
    function [7:0] byte8(input [3:0] c);
        case (c)
            4'd1:  byte8 = 8'h01;  4'd2:  byte8 = 8'h0C;  4'd3:  byte8 = 8'h0D;  4'd4:  byte8 = 8'h60;
            4'd5:  byte8 = 8'h61;  4'd6:  byte8 = 8'h6C;  4'd7:  byte8 = 8'h6D;  4'd8:  byte8 = 8'h9D;
            4'd9:  byte8 = 8'h03;  4'd10: byte8 = 8'h1C;  4'd11: byte8 = 8'h1F;  4'd12: byte8 = 8'hE0;
            4'd13: byte8 = 8'hE3;  4'd14: byte8 = 8'hFC;  4'd15: byte8 = 8'hFF;
            default: byte8 = 8'h00;
        endcase
    endfunction
    function [14:0] rgb332(input [7:0] p);
        reg [4:0] r, g, b;
        begin r = {p[4:2], p[4:3]}; g = {p[7:5], p[7:6]}; b = {p[1:0], p[1] & p[0], p[1:0]}; rgb332 = {r, g, b}; end
    endfunction
    // RGB de 5 bits del sprite de byte `c`: SCREEN 8 = tabla fija; resto = paleta de 16 colores (de 48 en el modo 3)
    function [14:0] sprgb(input integer mode, input [7:0] c);
        sprgb = (mode == 0) ? rgb332(byte8(c[3:0])) : pal_rgb[c];
    endfunction
    // mezcla del sprite con el fondo (openMSX SpriteConverter::calc_tp): 0 = sprite, 1 = (3s + d) / 4, 2 = (s + d) / 2, 3 = (3d + s) / 4
    function [4:0] mix5(input [4:0] bg, input [4:0] sp5, input [1:0] t);
        integer v;
        begin
            case (t)
                2'd0: v = sp5;
                2'd1: v = (3 * sp5 + bg) / 4;
                2'd2: v = (sp5 + bg) / 2;
                default: v = (3 * bg + sp5) / 4;
            endcase
            mix5 = v[4:0];
        end
    endfunction
    function [14:0] mixrgb(input [14:0] bg, input [14:0] sp15, input [1:0] t);
        mixrgb = {mix5(bg[14:10], sp15[14:10], t), mix5(bg[9:5], sp15[9:5], t), mix5(bg[4:0], sp15[4:0], t)};
    endfunction

    task spclear;
        integer q;
        begin for (q = 0; q < N + 8; q = q + 1) begin sp[q] = 8'd0; tp[q] = 2'd0; dis[q] = 1'b1; end end
    endtask
    // tandas de 1..6 celdas, la mitad con sprite (color 1..15; con `nset` > 1, {numero de paleta 0..nset-1, color}); `usetp`: TP al azar;
    // `bord`: tres tramos de 3..6 celdas fuera del area visible (el sprite se dibuja si SU celda esta dentro: dis[i + SO])
    task gen_sp(input integer nset, input integer usetp, input integer bord);
        integer q, ln, k, c, st, b0, bl;
        begin
            spclear;
            q = 4;
            while (q < N + 4) begin
                ln = 1 + (rnd8(0) % 6);
                if (rnd8(0) < 128) begin
                    c = 1 + (rnd8(0) % 15);
                    if (nset > 1) c = c + 16 * (rnd8(0) % nset);
                    for (k = 0; k < ln && q + k < N + 8; k = k + 1) begin
                        sp[q + k] = c[7:0];
                        tp[q + k] = usetp ? rnd8(0) : 2'd0;
                    end
                end
                q = q + ln;
            end
            if (bord) begin
                for (st = 0; st < 3; st = st + 1) begin
                    b0 = 14 + st * 26 + (rnd8(0) % 8);
                    bl = 3 + (rnd8(0) % 4);
                    for (k = 0; k < bl; k = k + 1) begin dis[b0 + k] = 1'b0; sp[b0 + k] = 8'd1 + (rnd8(0) % 15); end   // sprites sobre el borde
                    sp[b0 - 1] = 8'd7; sp[b0 + bl] = 8'd9;                                                          // sprites pegados a los dos lados del borde
                end
            end
        end
    endtask

    // presenta el flujo sin sprite y con el: la salida con sprite ha de ser la de sin sprite salvo en las celdas de sprite
    task check_sp(input integer mode, input integer m3on, input [8*52-1:0] what);
        reg [7:0]  ssp [0:N + 7];
        reg [1:0]  stp2 [0:N + 7];
        integer q, k, nbad, nspr, nbord, nmix, first;
        reg [14:0] ex;
        begin
            for (q = 0; q < N + 8; q = q + 1) begin ssp[q] = sp[q]; stp2[q] = tp[q]; sp[q] = 8'd0; tp[q] = 2'd0; end
            m3 = m3on;
            present(al0[mode]);
            for (q = 0; q < PRE + N + 40; q = q + 1) cap0[q] = cap[q];
            for (q = 0; q < N + 8; q = q + 1) begin sp[q] = ssp[q]; tp[q] = stp2[q]; end
            present(al0[mode]);
            m3 = 1'b0;
            nbad = 0; nspr = 0; nbord = 0; nmix = 0; first = -1;
            for (q = 8; q < N - 8; q = q + 1) begin
                k  = al0[mode] + q + lat0[mode];
                ex = cap0[k];
                // SCREEN 8: el color de sprite de la tabla fija usa el permiso del generador SIN la ventana visible (como antes de este cambio)
                if (sp[q][3:0] != 4'd0 && (mode == 0 || dis[q + SO])) begin
                    ex = (m3on && tp[q] != 2'd0) ? mixrgb(cap0[k], sprgb(mode, sp[q]), tp[q]) : sprgb(mode, sp[q]);
                    nspr = nspr + 1;
                    if (m3on && tp[q] != 2'd0) nmix = nmix + 1;
                end
                else if (sp[q][3:0] != 4'd0) nbord = nbord + 1;
                if (cap[k] !== ex) begin nbad = nbad + 1; if (first < 0) first = q; end
            end
            if (nbad == 0 && nspr > 0) $display("  PASS %0s: %0d celdas de sprite en su sitio (%0d mezcladas, %0d sobre el borde sin dibujar), el resto igual que sin sprite", what, nspr, nmix, nbord);
            else begin
                bad = bad + 1;
                $display("  FAIL %0s: %0d celdas mal de %0d con sprite (%0d mezcladas, %0d en el borde)", what, nbad, nspr, nmix, nbord);
                if (first >= 0) $display("       pixel %0d (sprite %02h, TP %0d, fondo %h): salio %h", first, sp[first], tp[first],
                                         cap0[al0[mode] + first + lat0[mode]], cap[al0[mode] + first + lat0[mode]]);
            end
            spclear;
        end
    endtask

    initial begin
        spclear;
        // la paleta de pruebas: 15 entradas distintas
        for (i = 0; i < 48; i = i + 1) pal_rgb[i] = {5'((i * 2 + 1) & 31), 5'((31 - i * 2) & 31), 5'((i * 5) & 31)};
        repeat (8) @(posedge clk);
        reset_n = 1'b1;
        repeat (600) @(posedge clk);                         // la paleta inicial se carga en 256 ciclos
        for (i = 0; i < 48; i = i + 1) begin
            @(posedge clk); pal_v <= 1'b1; pal_n <= i[7:0]; pal_r <= pal_rgb[i][14:10]; pal_g <= pal_rgb[i][9:5]; pal_b <= pal_rgb[i][4:0];
        end
        @(posedge clk); pal_v <= 1'b0;
        repeat (40) @(posedge clk);

        // ---- SCREEN 8 (sin YJK): el RGB de 256 colores no cambia ----
        yjk = 1'b0; yae = 1'b0;
        gen(0, 0); search(0, ta, tl, best); al0[0] = ta; lat0[0] = tl;
        if (best == N - 16) $display("  PASS SCREEN 8: %0d/%0d pixeles (alineacion %0d, latencia %0d celdas)", best, N - 16, al0[0], lat0[0]);
        else begin bad = bad + 1; $display("  FAIL SCREEN 8: solo %0d/%0d pixeles", best, N - 16); end
        gen(0, 0); row(0, 0, "SCREEN 8, otra fila");
        // sprites en SCREEN 8: la tabla fija de 256 colores, en su celda y sin tocar el resto
        gen(0, 0); gen_sp(1, 0, 0); check_sp(0, 0, "SCREEN 8 + sprites (tabla fija de 256 colores)");
        gen(0, 0); gen_sp(1, 0, 1); check_sp(0, 0, "SCREEN 8 + sprites, con borde");
        gen(0, 0); sp[40] = 8'd5; check_sp(0, 0, "SCREEN 8 + un sprite de una celda");

        // ---- SCREEN 12 (YJK sin YAE) ----
        yjk = 1'b1; yae = 1'b0;
        gen(2, 0); search(2, ta, tl, best); al0[2] = ta; lat0[2] = tl;
        if (best == N - 16) $display("  PASS SCREEN 12: %0d/%0d pixeles (alineacion %0d, latencia %0d celdas)", best, N - 16, al0[2], lat0[2]);
        else begin bad = bad + 1; $display("  FAIL SCREEN 12: solo %0d/%0d pixeles", best, N - 16); end
        gen(2, 0); row(2, 0, "SCREEN 12, otra fila");
        // sprites en SCREEN 12: sobre cualquier pixel YJK, en la celda del fondo (4 celdas mas tarde que en SCREEN 8, igual que el fondo)
        gen(2, 0); gen_sp(1, 0, 0); check_sp(2, 0, "SCREEN 12 + sprites sobre pixeles YJK");
        gen(2, 0); gen_sp(1, 0, 1); check_sp(2, 0, "SCREEN 12 + sprites, con borde");
        gen(2, 0); sp[40] = 8'd5; check_sp(2, 0, "SCREEN 12 + un sprite de una celda");

        // ---- SCREEN 10/11 (YJK + YAE) ----
        yjk = 1'b1; yae = 1'b1;
        gen(1, 0); search(1, ta, tl, best); al0[1] = ta; lat0[1] = tl;
        if (best == N - 16) $display("  PASS SCREEN 10/11 sin A = 1: %0d/%0d pixeles (alineacion %0d, latencia %0d celdas)", best, N - 16, al0[1], lat0[1]);
        else begin bad = bad + 1; $display("  FAIL SCREEN 10/11 sin A = 1: solo %0d/%0d pixeles", best, N - 16); end
        row(1, 1, "SCREEN 10/11 con A = 1 (paleta)");
        row(1, 1, "SCREEN 10/11 con A = 1, otra fila");
        // sprites en SCREEN 10/11: sobre pixeles A = 0 (YJK) y A = 1 (paleta), en la celda del fondo, y el borde
        gen(1, 1); gen_sp(1, 0, 0); check_sp(1, 0, "SCREEN 10/11 + sprites sobre A = 0 y A = 1");
        gen(1, 1); gen_sp(1, 0, 1); check_sp(1, 0, "SCREEN 10/11 + sprites, con borde");
        gen(1, 0); gen_sp(1, 0, 0); check_sp(1, 0, "SCREEN 10/11 + sprites sobre A = 0");
        gen(1, 1); sp[40] = 8'd5; check_sp(1, 0, "SCREEN 10/11 + un sprite de una celda");
        // un solo punto A = 1 (paleta 12) entre pixeles YJK
        for (i = 0; i < N + 8; i = i + 1) d[i] = rnd8(0) & 8'hF7;
        d[40] = 8'hC8; d[41] = 8'h50; d[42] = 8'h31; d[43] = 8'h62;
        present(al0[1]);
        if (cap[al0[1] + 40 + lat0[1]] === pal_rgb[12] && ncasan(al0[1], lat0[1], 1) == N - 16)
            $display("  PASS un punto A = 1 (paleta 12) entre pixeles YJK: sale %h en su celda, los vecinos YJK intactos", pal_rgb[12]);
        else begin bad = bad + 1; $display("  FAIL un punto A = 1 entre pixeles YJK: celda %h (esperado %h), %0d/%0d pixeles",
                                            cap[al0[1] + 40 + lat0[1]], pal_rgb[12], ncasan(al0[1], lat0[1], 1), N - 16); end

        // sprite mode 3 (V9968): numero de paleta en los 4 bits altos del color y mezcla con el fondo (TP) tambien sobre el RGB YJK
        yjk = 1'b1; yae = 1'b0;
        gen(2, 0); gen_sp(3, 1, 0); check_sp(2, 1, "SCREEN 12 + sprites modo 3 (TP y paletas 0-2)");
        yae = 1'b1;
        gen(1, 1); gen_sp(3, 1, 1); check_sp(1, 1, "SCREEN 10/11 + sprites modo 3 (TP, paletas, borde)");

        $display("== FIN: %0d fallos", bad);
        if (bad == 0) $display("TB_OK"); else $display("TB_FAIL");
        $finish;
    end
    initial begin #50000000 $display("TB_TIMEOUT"); $finish; end
endmodule
