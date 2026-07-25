// ============================================================================
// tb_geomfast.sv — geometria horizontal del V9968 por FAMILIA DE MODO y por
// FASE DE CAPTURA del ring HDMI.
//
// vdp_upscan REAL -> vdp_video_out REAL, con un patron sintetico que replica
// la ventana activa de cada familia:
//   MODE=0  graficos 256 px : 16 clk/px (2 muestras de line-buffer por pixel)
//   MODE=1  TEXT1  240 px   : 16 clk/px (2 muestras/pixel)
//   MODE=2  TEXT2  480 px   :  8 clk/px (1 muestra/pixel)
//   MODE=3  graficos 512 px :  8 clk/px (1 muestra/pixel)  SCREEN6/7
//
// CLAVE (_147): el core saca un pixel nuevo cada 2 ciclos (w_enable=h_count[0])
// y el ring de msx2hdmi_v9968 lo muestrea con `ce86`, un TOGGLE LIBRE de top.v
// SIN reset ("la fase da igual" — no da igual). Segun la fase, la columna
// nativa 0 del ring es la del h_count IMPAR (fase A) o la del PAR (fase B):
// un desplazamiento de UNA columna nativa. Como el escalador HDMI reparte
// 768->1280 con el patron 2,2,1 (xx=floor(3*cx/5)), ese +-1 cambia el reparto
// de los modos de 1 muestra/pixel entre 4,1 (catastrofico) y 2,3 (optimo).
// Este banco mide AMBAS fases para varias combinaciones de
// (c_active_start, c_start_numerator) y busca la que es buena en LAS DOS.
// ============================================================================
`timescale 1ns/1ps

module tb_geomfast;

localparam NV = 6;                      // variantes (c_active_start, numerador)

reg         clk = 1'b0;
reg         reset_n = 1'b0;
reg  [11:0] h_count = 12'd0;
reg  [12:0] half_count = 13'd0;
reg  [ 9:0] v_count = 10'd0;
wire [13:0] screen_pos_x = {1'b0, half_count} - 14'd640;

integer MODE;
reg [13:0] c_start, c_end;
reg [ 4:0] c_shift;
reg [ 9:0] c_npix;
reg [ 3:0] c_cw;

wire        in_win = (screen_pos_x >= c_start) && (screen_pos_x < c_end);
wire [13:0] rel    = screen_pos_x - c_start;
wire [ 9:0] pidx   = rel >> c_shift;
wire        is_mark = (pidx < {6'd0, c_cw}) || (pidx >= c_npix - {6'd0, c_cw});
wire        fg     = in_win && (is_mark || (pidx[0] == 1'b0));
wire [ 7:0] pix_r  = fg ? 8'hFF : 8'h20;
wire [ 7:0] pix_g  = fg ? 8'hFF : 8'h20;
wire [ 7:0] pix_b  = fg ? 8'hFF : 8'hE0;

wire [7:0] up_r, up_g, up_b;

vdp_upscan u_up (
    .clk(clk), .screen_pos_x(screen_pos_x), .screen_pos_y(10'd0),
    .h_count(h_count), .v_count(v_count), .field(1'b0),
    .reg_display_adjust(4'd0),
    .reg_interleaving_mode(1'b0), .reg_flat_interlace_mode(1'b0),
    .vdp_r(pix_r), .vdp_g(pix_g), .vdp_b(pix_b),
    .upscan_r(up_r), .upscan_g(up_g), .upscan_b(up_b)
);

function [11:0] v_act(input integer i);
    case (i)
        0: v_act = 12'd731;   1: v_act = 12'd731;
        2: v_act = 12'd729;   3: v_act = 12'd729;
        4: v_act = 12'd733;   5: v_act = 12'd733;
        default: v_act = 12'd731;
    endcase
endfunction
function [7:0] v_num(input integer i);
    case (i)
        0: v_num = 8'd0;      1: v_num = 8'd64;
        2: v_num = 8'd0;      3: v_num = 8'd64;
        4: v_num = 8'd0;      5: v_num = 8'd64;
        default: v_num = 8'd0;
    endcase
endfunction

wire       den [0:NV-1];
wire [7:0] dr  [0:NV-1], dg [0:NV-1], db [0:NV-1];
wire       dhs [0:NV-1], dvs [0:NV-1];

genvar gi;
generate
    for (gi = 0; gi < NV; gi = gi + 1) begin: duts
        vdp_video_out #(.c_active_start(v_act(gi)), .c_start_numerator(v_num(gi))) u_vo (
            .clk(clk), .reset_n(reset_n), .h_count(h_count), .v_count(v_count),
            .has_scanline(1'b0), .field(1'b0),
            .vdp_r(up_r), .vdp_g(up_g), .vdp_b(up_b),
            .display_hs(dhs[gi]), .display_vs(dvs[gi]), .display_en(den[gi]),
            .display_r(dr[gi]), .display_g(dg[gi]), .display_b(db[gi]),
            .reg_interlace_mode(1'b0), .reg_flat_interlace_mode(1'b0),
            .reg_denominator(8'd192), .reg_normalize(8'd43), .reg_50hz_mode(1'b0)
        );
    end
endgenerate

always #1 clk = ~clk;

always @(posedge clk) begin
    if (h_count == 12'd2735) begin
        h_count <= 12'd0;
        v_count <= v_count + 10'd1;
        if (v_count[0]) half_count <= 13'd0;
        else            half_count <= half_count + 13'd1;
    end
    else begin
        h_count    <= h_count + 12'd1;
        half_count <= half_count + 13'd1;
    end
end

// capture[variante][fase][columna]
integer cap [0:NV-1][0:1][0:1023];
integer ncap [0:NV-1][0:1];
integer ws  [0:1023];
integer histS [0:63];

task build_ws;
    integer cx, n;
    begin
        for (n = 0; n < 1024; n = n + 1) ws[n] = 0;
        for (cx = 0; cx < 1280; cx = cx + 1) begin
            n = (3 * cx) / 5;
            ws[n] = ws[n] + 1;
        end
    end
endtask

task analyze(input integer v, input integer ph);
    integer i, k, bgc, first, last, val, len, scr, nruns, n;
    integer runS [0:1023];
    integer smin, smax, h;
    begin
        n = ncap[v][ph];
        bgc = cap[v][ph][0];
        first = -1; last = -1;
        for (i = 0; i < n; i = i + 1) if (first < 0 && cap[v][ph][i] != bgc) first = i;
        for (i = n-1; i >= 0; i = i - 1) if (last < 0 && cap[v][ph][i] != bgc) last = i;
        nruns = 0; i = first;
        while (i <= last) begin
            val = cap[v][ph][i]; len = 0; scr = 0;
            while (i <= last && cap[v][ph][i] == val) begin
                len = len + 1; scr = scr + ws[i]; i = i + 1;
            end
            runS[nruns] = scr; nruns = nruns + 1;
        end
        for (h=0;h<64;h=h+1) histS[h]=0;
        smin=999; smax=-1;
        for (k = 1; k < nruns-1; k = k + 1) begin
            if (runS[k]<64) histS[runS[k]] = histS[runS[k]]+1;
            if (runS[k]<smin) smin=runS[k];
            if (runS[k]>smax) smax=runS[k];
        end
        $write("   act=%0d num=%0d  fase %s : cols=%0d  PANTALLA/px {",
               v_act(v), v_num(v), ph ? "B(par) " : "A(impar)", n);
        for (h=0;h<64;h=h+1) if (histS[h]>0) $write(" %0d:%0d", h, histS[h]);
        $write(" }  min=%0d max=%0d", smin, smax);
        if (smax - smin <= 1) $write("   <-- OK\n");
        else                  $write("   <-- MALO (variacion %0d)\n", smax-smin);
    end
endtask

integer v, ph;
initial begin
    if (!$value$plusargs("MODE=%d", MODE)) MODE = 0;
    case (MODE)
    0: begin c_start=14'd0;   c_end=14'd4096; c_shift=5'd4; c_npix=10'd256; c_cw=4'd8;
             $display("=== MODE=0  graficos 256 px (SCREEN1/2/4/5/8) ==="); end
    1: begin c_start=14'd128; c_end=14'd3968; c_shift=5'd4; c_npix=10'd240; c_cw=4'd6;
             $display("=== MODE=1  TEXT1  240 px (SCREEN0 W40) ==="); end
    2: begin c_start=14'd128; c_end=14'd3968; c_shift=5'd3; c_npix=10'd480; c_cw=4'd6;
             $display("=== MODE=2  TEXT2  480 px (SCREEN0 W80) ==="); end
    3: begin c_start=14'd0;   c_end=14'd4096; c_shift=5'd3; c_npix=10'd512; c_cw=4'd8;
             $display("=== MODE=3  graficos 512 px (SCREEN6/7) ==="); end
    endcase
    build_ws;
    for (v=0;v<NV;v=v+1) for (ph=0;ph<2;ph=ph+1) ncap[v][ph]=0;
    reset_n = 1'b0;
    repeat (20) @(posedge clk);
    reset_n = 1'b1;
    wait (v_count == 10'd40);
    @(negedge clk);
    while (v_count == 10'd40) begin
        @(posedge clk);
        for (v=0;v<NV;v=v+1) begin
            if (den[v]) begin
                ph = h_count[0] ? 0 : 1;
                cap[v][ph][ncap[v][ph]] = {dr[v], dg[v], db[v]};
                ncap[v][ph] = ncap[v][ph] + 1;
            end
        end
    end
    for (v=0;v<NV;v=v+1) begin
        analyze(v, 0);
        analyze(v, 1);
    end
    $finish;
end

endmodule
