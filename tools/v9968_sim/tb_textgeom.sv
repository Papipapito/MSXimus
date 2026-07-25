// ============================================================================
// tb_textgeom.sv — GEOMETRIA HORIZONTAL POR MODO del V9968 (regresion _144).
//
// Mide, con la PILA COMPLETA (vdp.v real + shim + backend), cuantas columnas
// NATIVAS (de las 768 que saca el core) y cuantos pixeles de PANTALLA (de los
// 1280 del escalador HDMI msx2hdmi_v9968: xcnt+=768, umbral 1280 =>
// xx = floor(3*cx/5)) ocupa CADA PIXEL MSX en:
//
//   +MODE=0  SCREEN1 (Graphic1, 256 px, 2 muestras/pixel)   [NO DEBE REGRESIONAR]
//   +MODE=1  SCREEN0 W40 (Text1, 240 px, 2 muestras/pixel)
//   +MODE=2  SCREEN0 W80 (Text2, 480 px, 1 muestra/pixel)
//
// Estimulo: patron de PCG 0xAA (pixeles alternos fg/bg => cada run del volcado
// = UN pixel MSX) y caracteres marcadores 0xFF en la primera y ultima columna
// (delimitan el contenido sin ambiguedad contra el borde/backdrop).
//
// La VRAM se PRECARGA directamente en el array de respaldo (nada de escrituras
// por el puerto CPU): la sim tarda segundos en vez de minutos.
// ============================================================================
`timescale 1ns/1ps

module tb_textgeom;

localparam real CLK_HALF = 5.8207;
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic [2:0]  bus_address = 0;
logic        bus_ioreq = 0, bus_write = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;
wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vram_address;
wire         vram_write, vram_valid, vram_refresh;
wire  [31:0] vram_wdata;
wire  [3:0]  vram_wdata_mask;
wire  [4:0]  vram_tag;
wire  [31:0] vram_rdata;
wire         vram_rdata_en;
wire  [4:0]  vram_rtag;
wire         vram_stall;
wire         display_hs, display_vs, display_en;
wire  [7:0]  display_r, display_g, display_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_tag(vram_tag), .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

wire        bk_req, bk_we;
wire [21:0] bk_addr;
wire [31:0] bk_wdata;      // _148 FIX B: escritura de PALABRA
wire [3:0]  bk_wmask;      // _148 FIX B: 1 = escribir ese byte
logic [15:0] bk_rword = 0;
logic        bk_done_t = 0;
wire [7:0]  shim_diag;
wire        bk2_req;
wire [21:0] bk2_addr;
logic [15:0] bk2_rword = 0;
logic        bk2_done_t = 0;

v9968_vram_shim #(.VRAM_BASE(22'h280000)) u_shim (
    .clk_vdp(clk), .rst_n(reset_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask), .vram_tag(vram_tag),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_rtag(vram_rtag),
    .vram_stall(vram_stall),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr), .bk_wdata(bk_wdata),
    .bk_wmask(bk_wmask),
    .bk_rword(bk_rword), .bk_done_t(bk_done_t),
    .bk2_req(bk2_req), .bk2_addr(bk2_addr),
    .bk2_rword(bk2_rword), .bk2_done_t(bk2_done_t),
    .diag(shim_diag)
);

logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
integer vi;
always @(posedge clk) begin
    if (bk_req && !m_pend) begin
        m_pend <= 1; m_we <= bk_we; m_addr <= bk_addr; m_dat <= bk_wdata;
        m_msk <= bk_wmask;
        m_cnt <= 0; m_lat <= 26 + ({$random} % 18);
    end
    else if (m_pend) begin
        m_cnt <= m_cnt + 1;
        if (m_cnt == m_lat) begin
            // _148 FIX B: escritura de PALABRA con mascara de bytes
            if (m_we) begin
                if (m_msk[0]) sdram[{m_addr[21:2],2'b00}] <= m_dat[ 7: 0];
                if (m_msk[1]) sdram[{m_addr[21:2],2'b01}] <= m_dat[15: 8];
                if (m_msk[2]) sdram[{m_addr[21:2],2'b10}] <= m_dat[23:16];
                if (m_msk[3]) sdram[{m_addr[21:2],2'b11}] <= m_dat[31:24];
            end
            else begin
                bk_rword[7:0]  <= sdram[{m_addr[21:1],1'b0}];
                bk_rword[15:8] <= sdram[{m_addr[21:1],1'b1}];
            end
            bk_done_t <= ~bk_done_t;
            m_pend <= 0;
        end
    end
end

logic        m2_pend = 0;
logic [21:0] m2_addr;
integer      m2_cnt, m2_lat;
always @(posedge clk) begin
    if (bk2_req && !m2_pend) begin
        m2_pend <= 1; m2_addr <= bk2_addr;
        m2_cnt <= 0; m2_lat <= 26 + ({$random} % 18);
    end
    else if (m2_pend) begin
        m2_cnt <= m2_cnt + 1;
        if (m2_cnt == m2_lat) begin
            bk2_rword[7:0]  <= sdram[{m2_addr[21:1],1'b0}];
            bk2_rword[15:8] <= sdram[{m2_addr[21:1],1'b1}];
            bk2_done_t <= ~bk2_done_t;
            m2_pend <= 0;
        end
    end
end

task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (20) @(posedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask
task vdp_pal(input [3:0] idx, input [2:0] r, input [2:0] g, input [2:0] b);
begin
    vdp_reg(6'd16, {4'd0, idx});
    bus_wr(3'd2, {1'b0, r, 1'b0, b});
    bus_wr(3'd2, {5'd0, g});
end
endtask

// ---------------------------------------------------------------------------
//  Captura de UNA linea activa
// ---------------------------------------------------------------------------
localparam CAPLINE = 100;
integer vs_cnt = 0, oline = 0;
logic vs_d = 0, hs_d = 0;
integer raw [0:2047];          // muestras por CICLO mientras display_en
integer nraw = 0;
integer cap_done = 0;
integer cap_frame = 3;

always @(posedge clk) begin
    vs_d <= display_vs; hs_d <= display_hs;
    if (display_vs && !vs_d) begin vs_cnt <= vs_cnt + 1; oline <= 0; end
    else if (display_hs && !hs_d) oline <= oline + 1;
    if (!cap_done && vs_cnt >= cap_frame && oline == CAPLINE && display_en) begin
        raw[nraw] = {display_r, display_g, display_b};
        nraw = nraw + 1;
        if (nraw >= 2047) cap_done = 1;
    end
    else if (!cap_done && nraw > 0 && !display_en) cap_done = 1;
end

// ---------------------------------------------------------------------------
//  Sonda del LINE BUFFER del upscan: direccion de escritura real vs dato.
//  El primer/ultimo caracter de la linea es 0xFF (fg solido) => el minimo y
//  el maximo de las direcciones escritas con fg = content_start/content_end
//  EXACTOS en muestras del line buffer.
// ---------------------------------------------------------------------------
wire [10:0] wpos  = u_vdp.u_upscan.w_write_pos;
wire        wwe   = u_vdp.u_upscan.w_even_we | u_vdp.u_upscan.w_odd_we;
wire [23:0] wdat  = {u_vdp.w_vdp_r, u_vdp.w_vdp_g, u_vdp.w_vdp_b};
integer wmin = 99999, wmax = 0, wnfg = 0, wntot = 0;
integer probe_lo = CAPLINE - 4, probe_hi = CAPLINE - 3;

always @(posedge clk) begin
    if (vs_cnt >= cap_frame && oline >= probe_lo && oline <= probe_hi && wwe) begin
        wntot = wntot + 1;
        if (wdat == 24'hFFFFFF) begin
            wnfg = wnfg + 1;
            if (wpos < wmin) wmin = wpos;
            if (wpos > wmax) wmax = wpos;
        end
    end
end

// ---------------------------------------------------------------------------
//  Analisis
// ---------------------------------------------------------------------------
integer col [0:1023];          // 768 columnas NATIVAS del core
integer ncol = 0;
integer ws  [0:1023];          // px de PANTALLA (1280) por columna nativa
integer histN [0:63];
integer histS [0:63];

task build_ws;
    integer cx, n;
    begin
        for (n = 0; n < 1024; n = n + 1) ws[n] = 0;
        for (cx = 0; cx < 1280; cx = cx + 1) begin
            n = (3 * cx) / 5;          // xcnt+=768, umbral 1280
            ws[n] = ws[n] + 1;
        end
    end
endtask

// El core saca un pixel cada 2 ciclos y el ring de msx2hdmi_v9968 lo muestrea
// con `ce86` (toggle LIBRE de top.v, fase arbitraria): la columna nativa 0 del
// ring puede ser la del h_count IMPAR (fase A, raw pares) o la del PAR
// (fase B, raw impares). Se analizan LAS DOS.
task decimate(input integer off);
    integer i;
    begin
        ncol = 0;
        for (i = off; i < nraw; i = i + 2) begin
            col[ncol] = raw[i]; ncol = ncol + 1;
        end
    end
endtask

integer MODE;
integer i, j, h;

initial begin
    if (!$value$plusargs("MODE=%d", MODE)) MODE = 0;
    for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
    // ---- PGT en 0x0800: char1 = 0xAA (pixeles alternos), char2 = 0xFF ----
    for (i = 0; i < 8; i = i + 1) begin
        sdram[22'h280000 + 18'h0800 + 1*8 + i] = 8'hAA;
        sdram[22'h280000 + 18'h0800 + 2*8 + i] = 8'hFF;
    end
    // ---- NT en 0x0000 ----
    case (MODE)
    0: for (j = 0; j < 24; j = j + 1)                       // G1: 32 col
           for (i = 0; i < 32; i = i + 1)
               sdram[22'h280000 + j*32 + i] = (i==0 || i==31) ? 8'd2 : 8'd1;
    1: for (j = 0; j < 24; j = j + 1)                       // T1: 40 col
           for (i = 0; i < 40; i = i + 1)
               sdram[22'h280000 + j*40 + i] = (i==0 || i==39) ? 8'd2 : 8'd1;
    2: for (j = 0; j < 24; j = j + 1)                       // T2: 80 col
           for (i = 0; i < 80; i = i + 1)
               sdram[22'h280000 + j*80 + i] = (i==0 || i==79) ? 8'd2 : 8'd1;
    endcase
    // ---- CT (solo G1) en 0x1000: fg=15 bg=4 ----
    for (i = 0; i < 32; i = i + 1) sdram[22'h280000 + 18'h1000 + i] = 8'hF4;

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_cnt >= 1);
    vdp_pal(4'd4,  3'd0, 3'd0, 3'd7);   // bg  = azul
    vdp_pal(4'd15, 3'd7, 3'd7, 3'd7);   // fg  = blanco
    case (MODE)
    0: begin vdp_reg(6'd0, 8'h00); vdp_reg(6'd1, 8'h40); vdp_reg(6'd2, 8'h00);
             vdp_reg(6'd3, 8'h40); vdp_reg(6'd4, 8'h01);
             $display("=== MODE=0  SCREEN1 (Graphic1, 256 px) ==="); end
    1: begin vdp_reg(6'd0, 8'h00); vdp_reg(6'd1, 8'h50); vdp_reg(6'd2, 8'h00);
             vdp_reg(6'd4, 8'h01);
             $display("=== MODE=1  SCREEN0 W40 (Text1, 240 px) ==="); end
    2: begin vdp_reg(6'd0, 8'h04); vdp_reg(6'd1, 8'h50); vdp_reg(6'd2, 8'h03);
             vdp_reg(6'd3, 8'h40); vdp_reg(6'd4, 8'h01); vdp_reg(6'd13, 8'h00);
             $display("=== MODE=2  SCREEN0 W80 (Text2, 480 px) ==="); end
    endcase
    vdp_reg(6'd7,  8'hF4);              // fg=15 / backdrop=4
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd18, 8'h00);              // display adjust NEUTRO
    vdp_reg(6'd20, 8'h01);

    wait (cap_done == 1);
    #100;
    build_ws;
    $display("  LINE BUFFER: escrituras=%0d  con fg=%0d  addr_fg_min=%0d addr_fg_max=%0d",
             wntot, wnfg, wmin, wmax);
    $display("  => content_start=%0d  content_end=%0d  ancho_contenido=%0d muestras",
             wmin, wmax, wmax-wmin+1);
    $display("  => ventana de lectura del magnificador = [16, 527] (c_read_start=16, 512 muestras)");
    $display("  captura: %0d ciclos de display_en", nraw);
    analyze(0);
    analyze(1);
    #1000;
    $finish;
end

task analyze(input integer ph);
    integer i, k, fgc, bgc, first, last, val, len, scr, nruns;
    integer runN [0:1023];
    integer runS [0:1023];
    integer runV [0:1023];
    integer inner_n_min, inner_n_max, inner_s_min, inner_s_max;
    begin
        decimate(ph);
        $display("  ---- FASE DE CAPTURA DEL RING %s : %0d columnas nativas ----",
                 ph ? "B (h_count par)" : "A (h_count impar)", ncol);
        bgc = col[0];                                  // borde = backdrop
        // color de contenido = el primero distinto del borde
        first = -1;
        for (i = 0; i < ncol; i = i + 1)
            if (first < 0 && col[i] != bgc) first = i;
        last = -1;
        for (i = ncol-1; i >= 0; i = i - 1)
            if (last < 0 && col[i] != bgc) last = i;
        fgc = (first >= 0) ? col[first] : bgc;
        $display("  borde=%06x  contenido(fg)=%06x", bgc, fgc);
        $display("  primera col nativa con fg = %0d, ultima = %0d  (borde izq=%0d, der=%0d)",
                 first, last, first, ncol-1-last);

        // runs sobre [first,last]
        nruns = 0; i = first;
        while (i <= last) begin
            val = col[i]; len = 0; scr = 0;
            while (i <= last && col[i] == val) begin
                len = len + 1; scr = scr + ws[i]; i = i + 1;
            end
            runN[nruns] = len; runS[nruns] = scr; runV[nruns] = val;
            nruns = nruns + 1;
        end
        $display("  runs de color en el contenido: %0d", nruns);
        if (nruns >= 3) begin
            $display("  marcador izq (char 0xFF): %0d col nativas / %0d px pantalla",
                     runN[0], runS[0]);
            $display("  marcador der (char 0xFF): %0d col nativas / %0d px pantalla",
                     runN[nruns-1], runS[nruns-1]);
        end
        // histogramas SOLO de los runs interiores (= 1 pixel MSX cada uno)
        for (h = 0; h < 64; h = h + 1) begin histN[h]=0; histS[h]=0; end
        inner_n_min=999; inner_n_max=-1; inner_s_min=999; inner_s_max=-1;
        for (k = 1; k < nruns-1; k = k + 1) begin
            if (runN[k] < 64) histN[runN[k]] = histN[runN[k]] + 1;
            if (runS[k] < 64) histS[runS[k]] = histS[runS[k]] + 1;
            if (runN[k] < inner_n_min) inner_n_min = runN[k];
            if (runN[k] > inner_n_max) inner_n_max = runN[k];
            if (runS[k] < inner_s_min) inner_s_min = runS[k];
            if (runS[k] > inner_s_max) inner_s_max = runS[k];
        end
        $write("  HISTOGRAMA columnas NATIVAS por pixel MSX (768): {");
        for (h = 0; h < 64; h = h + 1) if (histN[h] > 0) $write(" %0d:%0d", h, histN[h]);
        $write(" }   min=%0d max=%0d\n", inner_n_min, inner_n_max);
        $write("  HISTOGRAMA px de PANTALLA por pixel MSX (1280): {");
        for (h = 0; h < 64; h = h + 1) if (histS[h] > 0) $write(" %0d:%0d", h, histS[h]);
        $write(" }   min=%0d max=%0d\n", inner_s_min, inner_s_max);
        $write("  secuencia px pantalla (primeros 40 pixeles interiores):");
        for (k = 1; k < nruns-1 && k <= 40; k = k + 1) $write(" %0d", runS[k]);
        $write("\n");
        $display("  ancho total del contenido: %0d col nativas de 768", last-first+1);
    end
endtask

initial begin
    #400000000;
    $display("TIMEOUT vs=%0d nraw=%0d cap_done=%0d", vs_cnt, nraw, cap_done);
    $finish;
end

endmodule
