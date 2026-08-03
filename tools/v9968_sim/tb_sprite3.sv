// ============================================================================
// tb_sprite3.sv — REPRODUCTOR del thrashing de la cache de sprites mode3 del
// DEVCON (23/07, HW: cuerpos limpios / cabezas con rayas verticales). Pila
// COMPLETA: core V9968 + v9968_vram_shim + SDRAM lenta. Vuelca el frame a
// s3_frame.txt. Se compara contra tb_sprite3r (VRAM perfecta, s3r_frame.txt):
// diffs = glitches inducidos por el shim (thrash de la cache de sprites).
// ============================================================================
`timescale 1ns/1ps

module tb_sprite3;

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

// ---- SDRAM compartida modelada (300-500ns aleatoria) ----
logic [7:0] sdram [0:4194303];
logic        m_pend = 0, m_we;
logic [21:0] m_addr;
logic [31:0] m_dat;
logic [3:0]  m_msk;
integer      m_cnt, m_lat;
integer vi;
initial for (vi = 0; vi < 4194304; vi = vi + 1) sdram[vi] = 8'h00;
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

// ---- bus + helpers ----
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (18) @(posedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask
task set_wr_ptr(input [3:0] bank, input [13:0] a14);
begin
    vdp_reg(6'd14, {4'd0, bank});
    bus_wr(3'd1, a14[7:0]);
    bus_wr(3'd1, {2'b01, a14[13:8]});
end
endtask
task vram_stream_b(input [7:0] d);
begin
    bus_wr(3'd0, d);
    repeat (28) @(posedge clk);
end
endtask

// ============================================================================
// _164 -DCMDTRAF — TRAFICO DEL MOTOR DE COMANDOS CONTRA LA TABLA DE PATRONES.
//
// QUE SE MIDE Y POR QUE. En el shim, el relleno de la sc-cache NO esta
// filtrado: v9968_vram_shim.v:1549-1557 dice literalmente "TODO consumidor de
// lectura rellena — bg/sprite/CPU/comando". El victim buffer SI se filtro a
// sprites en la _150 (fill_sp), pero la cache no. Hipotesis: cuando un comando
// LEE su destino y ese destino ES la tabla de patrones, inunda la cache y
// desaloja los patrones que los sprites necesitan ese mismo scanline.
//
// De donde sale la sospecha: en placa, con el V9968DM, spMISS/s salta de 3.840
// (con el LRMM MUERTO, porque la demo no escribia R#21) a 25.000-55.000 (con el
// LRMM VIVO). El LRMM lee su destino antes de cada escritura y su destino es la
// SPT. Eso es ~667 fallos/frame; a ~20 px de churro por fallo son ~13.300 px
// sobre 54.272 = ~25% de pantalla, que es la densidad de rayas observada.
//
// POR QUE SOBRE EL BANCO ru66 Y NO SOBRE UNO NUEVO DEL V9968DM: porque el ru66
// YA TIENE LINEA BASE VALIDADA (DIFFS=0 contra la referencia dorada). Montar
// una escena nueva cambiaria dos variables a la vez. Aqui se cambia UNA.
//
// EL TRUCO PARA NO CONTAMINAR LA MEDIDA: LMMM con operacion logica OR
// (CMD=0x92) desde una region de VRAM que esta a CEROS. El motor SE VE OBLIGADO
// A LEER EL DESTINO (lo exige cualquier op distinta de IMP) — que es justo el
// trafico que se quiere inyectar — pero x OR 0 = x, asi que LOS DATOS NO
// CAMBIAN y la imagen de sprites sigue siendo comparable pixel a pixel. Con
// XOR o con IMP el experimento se destruiria a si mismo.
//
// Destino: DY=256 => byte 256*128 = 0x8000 = la SPT del ru66; NY=128 cubre
// 0x8000-0xC000 (16 KB), o sea la tabla de patrones entera.
// Fuente: SY=800 (byte 0x19000), region nunca precargada => ceros.
// ============================================================================
`ifdef CMDLIVE
// _176 CMDLIVE — el reproductor DEVCON de verdad: LMMM|XOR con FUENTE EN EL
// BG (SY=0, no-ceros). El OR de CMDTRAF deja los DATOS ESTATICOS: un miss con
// deadline perdido latchea dato viejo == dato nuevo y NO se ve en el diff
// (por eso julio "convergia" en sim con la placa rallada). Con XOR el destino
// ALTERNA con periodo 2 barridos — determinista e identico en la dorada, asi
// que todo pixel distinto ES un fallo del shim (el latch a fase fija del
// colector pillando la SPT a medio cambiar: la raya de la DEVCON).
`define CMDTRAF
task cmd_or_spt;
begin
    vdp_reg(6'd32, 8'd0);    vdp_reg(6'd33, 8'd0);        // SX = 0
    vdp_reg(6'd34, 8'd0);    vdp_reg(6'd35, 8'd0);        // SY = 0 (bg, NO ceros)
    vdp_reg(6'd36, 8'd0);    vdp_reg(6'd37, 8'd0);        // DX = 0
    vdp_reg(6'd38, 8'd0);    vdp_reg(6'd39, 8'd1);        // DY = 256 -> 0x8000
    vdp_reg(6'd40, 8'd0);    vdp_reg(6'd41, 8'd1);        // NX = 256
    vdp_reg(6'd42, 8'd128);  vdp_reg(6'd43, 8'd0);        // NY = 128
    vdp_reg(6'd44, 8'd0);                                  // CLR (no usado)
    vdp_reg(6'd45, 8'd0);                                  // ARG
    vdp_reg(6'd46, 8'h94);                                 // LMMM | XOR
end
endtask
`elsif CMDTRAF
task cmd_or_spt;
begin
    vdp_reg(6'd32, 8'd0);    vdp_reg(6'd33, 8'd0);        // SX = 0
    vdp_reg(6'd34, 8'd800 % 256); vdp_reg(6'd35, 8'd800 / 256); // SY = 800 (ceros)
    vdp_reg(6'd36, 8'd0);    vdp_reg(6'd37, 8'd0);        // DX = 0
    vdp_reg(6'd38, 8'd0);    vdp_reg(6'd39, 8'd1);        // DY = 256 -> 0x8000
    vdp_reg(6'd40, 8'd0);    vdp_reg(6'd41, 8'd1);        // NX = 256
    vdp_reg(6'd42, 8'd128);  vdp_reg(6'd43, 8'd0);        // NY = 128
    vdp_reg(6'd44, 8'd0);                                  // CLR (no usado)
    vdp_reg(6'd45, 8'd0);                                  // ARG
    vdp_reg(6'd46, 8'h92);                                 // LMMM | OR
end
endtask
`endif

`ifdef CMDTRAF
integer n_cmds = 0;
initial begin
    wait (setup_done);
    forever begin
        // sin sondeo de CE (este banco no tiene tarea de lectura de bus): se
        // espera a que el motor quede OCIOSO mirando su estado por jerarquia,
        // que es lo que ya hace tb_sc8cmd para su comprobacion de coherencia.
        wait (u_vdp.u_command.ff_state == 0);
        cmd_or_spt();
        n_cmds = n_cmds + 1;
        repeat (200) @(posedge clk);
    end
end
`endif
reg setup_done = 0;

// ---- volcado de frame ----
integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
            $display("FRAME VOLCADO (diag=%0d)", shim_diag);
        end
        else if (dump_state == 0 && vs_count == 12) begin
            fd = $fopen("s3_frame.txt", "w");
            dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

// ============================================================================
// _148 FIX 0 — INSTRUMENTACION DE SPRITE (antes el TB era CIEGO: sin esto la
// unica salida era el volcado de pixeles y no habia forma de ver si el core
// pedia sprites siquiera). Dos taps:
//   * TOP: clasifica los vram_valid por consumidor (vram_tag[4:2]).
//   * XMR al shim: cuenta fetch de SPRITE y su acierto de la sc-cache
//     (mismo comparador que usa el RTL: scq_v && scq_tag == spr_addr1[15:12]).
// Se imprime por frame en el flanco de vs. Criterio del FIX A: miss/sp < 0.1%.
// ============================================================================
integer f_bg=0, f_sp=0, f_cpu=0, f_cmd=0, f_wr=0;
integer x_sp=0, x_chit=0, x_miss=0;
integer npix=0, nnz=0;
wire        x_is_sp  = u_shim.spr_p1 && (u_shim.spr_tag1[4:2] == 3'd2);
wire        x_sp_hit = x_is_sp && u_shim.scq_v &&
                       (u_shim.scq_tag == u_shim.spr_addr1[15:12]);
// _150: el tap de arriba mide SOLO la sc-cache (etapa 1). Con el VICTIM BUFFER
// el miss REAL (el que va al backend) se decide en la etapa 2, asi que hace
// falta un segundo par de taps o la cifra de miss "no se mueve" aunque el
// rescate funcione. x_vbh = rescates del VB; x_real = miss que SI van al
// backend. Ambos son de SOLO LECTURA sobre el DUT.
integer x_vbh=0, x_real=0;
wire        x_vb_hit = u_shim.vb_p2 &&  u_shim.vb_hit2 && (u_shim.vb_tag2[4:2] == 3'd2);
wire        x_vb_mis = u_shim.vb_p2 && !u_shim.vb_hit2 && (u_shim.vb_tag2[4:2] == 3'd2);
// CLASIFICACION por region de VRAM del setup de sprite3: bg = palabras
// 0x0000-0x1FFF (SCREEN5 pagina 0), SPT = 0x2000-0x3FFF (0x8000 en bytes),
// SAT = 0x4000+ (0x10000 en bytes). Sirve para ver QUIEN llena la sc-cache y
// QUIEN falla, en vez de suponerlo.
integer x_f_bg=0, x_f_spt=0, x_f_sat=0, x_f_otro=0;
integer x_m_spt=0, x_m_sat=0;
always @(posedge clk) begin
    if (x_vb_hit) x_vbh  <= x_vbh  + 1;
    if (x_vb_mis) x_real <= x_real + 1;
    if (u_shim.fill_now) begin
        if      (u_shim.fill_addr < 16'h2000) x_f_bg   <= x_f_bg + 1;
        else if (u_shim.fill_addr < 16'h4000) x_f_spt  <= x_f_spt + 1;
        else if (u_shim.fill_addr < 16'h4020) x_f_sat  <= x_f_sat + 1;
        else                                  x_f_otro <= x_f_otro + 1;
    end
    if (x_vb_mis) begin
        if (u_shim.vb_addr2 < 16'h4000) x_m_spt <= x_m_spt + 1;
        else                            x_m_sat <= x_m_sat + 1;
    end
    if (vram_valid) begin
        if (vram_write) f_wr <= f_wr + 1;
        else case (vram_tag[4:2])
            3'd1: f_bg  <= f_bg + 1;
            3'd2: f_sp  <= f_sp + 1;
            3'd3: f_cpu <= f_cpu + 1;
            3'd4: f_cmd <= f_cmd + 1;
        endcase
    end
    if (x_is_sp) begin
        x_sp <= x_sp + 1;
        if (x_sp_hit) x_chit <= x_chit + 1; else x_miss <= x_miss + 1;
    end
    if (display_en) begin
        npix <= npix + 1;
        if ({display_r, display_g, display_b} != 24'd0) nnz <= nnz + 1;
    end
    if (display_vs && !vs_d) begin
        $display("SPDIAG vs=%0d | TOP bg=%0d sp=%0d cpu=%0d cmd=%0d wr=%0d | XMR sp=%0d chit=%0d miss=%0d (%0d.%02d%%) | pix=%0d nonzero=%0d",
                 vs_count, f_bg, f_sp, f_cpu, f_cmd, f_wr, x_sp, x_chit, x_miss,
                 (x_sp>0)? (x_miss*100)/x_sp : 0,
                 (x_sp>0)? ((x_miss*10000)/x_sp) % 100 : 0,
                 npix, nnz);
        // _148 FIX C: los CONTADORES DEL RTL que salen por COM11, para
        // comprobar que dicen lo mismo que el tap del TB (deltas por frame) y
        // que el empaquetado de dbg_miss es el documentado.
        $display("SPTEL vs=%0d | c_spfet=%0d (+%0d) c_spmiss=%0d (+%0d) c_miss=%0d | dbg_miss=%08x -> sp=%0d bg=%0d",
                 vs_count, u_shim.c_spfet, u_shim.c_spfet - t_spfet,
                 u_shim.c_spmiss, u_shim.c_spmiss - t_spmiss, u_shim.c_miss,
                 u_shim.dbg_miss, u_shim.dbg_miss[31:16], u_shim.dbg_miss[15:0]);
        // _150 VICTIM BUFFER: rescates y miss REAL (el que llega al backend).
        $display("SPVB  vs=%0d | sp=%0d | scmiss=%0d (%0d.%02d%%) vbhit=%0d REAL=%0d (%0d.%02d%%) | c_vbhit=%0d",
                 vs_count, x_sp, x_miss,
                 (x_sp>0)? (x_miss*100)/x_sp : 0,
                 (x_sp>0)? ((x_miss*10000)/x_sp) % 100 : 0,
                 x_vbh, x_real,
                 (x_sp>0)? (x_real*100)/x_sp : 0,
                 (x_sp>0)? ((x_real*10000)/x_sp) % 100 : 0,
                 u_shim.c_vbhit);
        $display("SPCLS vs=%0d | FILLS bg=%0d spt=%0d sat=%0d otro=%0d | MISS_REAL spt=%0d sat=%0d",
                 vs_count, x_f_bg, x_f_spt, x_f_sat, x_f_otro, x_m_spt, x_m_sat);
        x_f_bg<=0; x_f_spt<=0; x_f_sat<=0; x_f_otro<=0; x_m_spt<=0; x_m_sat<=0;
        t_spfet  <= u_shim.c_spfet;
        t_spmiss <= u_shim.c_spmiss;
        f_bg<=0; f_sp<=0; f_cpu<=0; f_cmd<=0; f_wr<=0;
        x_sp<=0; x_chit<=0; x_miss<=0; npix<=0; nnz<=0;
        x_vbh<=0; x_real<=0;
    end
end
reg [31:0] t_spfet = 0, t_spmiss = 0;

// ---- LAYOUT REAL DE LA DEMO ru66 (-DRU66): datos por poke en t=0 ----
`ifdef RU66
task vram_poke(input [17:0] a, input [7:0] d);
begin sdram[22'h280000 + a] = d; end
endtask
`include "ru66_preload.svh"
initial ru66_preload();
`endif

integer yi_s, yj_s;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
`ifdef RU66
    `include "sprite3_ru66_setup.svh"
`else
    `include "sprite3_setup.svh"
`endif
    $display("SETUP mode3 cargado en vs=%0d", vs_count);
    setup_done = 1;
    wait (dump_state == 2);
    #1000;
`ifdef CMDTRAF
    $display("*** CMDTRAF: %0d comandos LMMM|OR lanzados contra la SPT ***", n_cmds);
`endif
    $display("*** SPRITE3 CON SHIM: COMPLETO (vs=%0d) ***", vs_count);
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
