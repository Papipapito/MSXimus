// ============================================================================
// tb_sprite_yjk_vdp.sv - Z1.3.2b10: sprites en SCREEN 10/11/12 con el VDP COMPLETO (generador de sprites y de modos reales, VRAM perfecta).
// Un frame de G7 con el mismo fondo (columnas de 4 pixeles con otro Y en x = 64 y x = 192, J = K = 0, region izquierda con A = 0 y
// derecha con A = 1 para SCREEN 10/11) y dos sprites de 8x8 en x = 64 y x = 192 (lineas 40..47), en el modo del plusarg:
//   +MODE=8   SCREEN 8 (R#25 = 0: RGB 3-3-2, sprite con la tabla fija de 256 colores): la REFERENCIA de alineacion
//   +MODE=11  SCREEN 10/11 (R#25 = 18h: YJK + YAE)
//   +MODE=12  SCREEN 12 (R#25 = 08h: YJK)
// Vuelca el frame 3 en forma de transiciones de color por linea ("L" = linea nueva; "<reloj> <rrggbb>" = cambio de color en ese
// reloj de pantalla desde el primer display_en de la linea) a sprite_<MODE>.txt; analiza_sprite_yjk.py lo compara entre modos.
// Uso: bash run_sprite_yjk.sh [dir con fpga/v9968]     (Icarus o Verilator, WSL)
// MSXimus 60K/138K: copiado de la Zynq (Z1.3.2b10); sin los puertos ext_cmd_* (geo3d), que este vdp.v no tiene.
// ============================================================================
`timescale 1ns/1ps

module tb_sprite_yjk_vdp;

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

// ---- VRAM PERFECTA (como tb_screen8r: 8 ciclos exactos + eco de tag; stall = 0; mascara de escritura activa a 0) ----
logic [31:0] vram_rdata_r = 0;
logic        vram_rdata_en_r = 0;
logic [4:0]  vram_rtag_r = 0;
assign vram_rdata = vram_rdata_r;
assign vram_rdata_en = vram_rdata_en_r;
assign vram_rtag = vram_rtag_r;
assign vram_stall = 1'b0;
logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
integer vj;
initial for (vj = 0; vj < 65536; vj = vj + 1) vram_mem[vj] = 32'h0;
always @(posedge clk) begin
    vram_rdata_en_r <= 1'b0;
    if (vram_valid && vram_write) begin
        if (!vram_wdata_mask[0]) vram_mem[vram_address][ 7: 0] <= vram_wdata[ 7: 0];
        if (!vram_wdata_mask[1]) vram_mem[vram_address][15: 8] <= vram_wdata[15: 8];
        if (!vram_wdata_mask[2]) vram_mem[vram_address][23:16] <= vram_wdata[23:16];
        if (!vram_wdata_mask[3]) vram_mem[vram_address][31:24] <= vram_wdata[31:24];
    end
    else if (vram_valid && !vram_write && !p_pend) begin
        p_pend <= 1'b1; p_addr <= vram_address; p_tag <= vram_tag; p_cnt <= 0;
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == 6) begin
            vram_rdata_r    <= vram_mem[p_addr];
            vram_rtag_r     <= p_tag;
            vram_rdata_en_r <= 1'b1;
            p_pend          <= 1'b0;
        end
    end
end

// ---- bus ----
task bus_wr(input [2:0] a, input [7:0] d);
begin
    // asignaciones BLOQUEANTES tras el flanco (como tb_sprite3): con las no bloqueantes Verilator no mueve el bus del VDP (cero trafico de VRAM)
    @(posedge clk); #1;
    bus_address = a; bus_wdata = d;
    bus_ioreq = 1; bus_write = 1; bus_valid = 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    #1; bus_ioreq = 0; bus_write = 0; bus_valid = 0;
    repeat (20) @(posedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask
// dato de VRAM (puerto 0) con el ritmo de tb_screen8r: la VDP pierde los datos que llegan mas seguidos
task vwr(input [7:0] d);
begin bus_wr(3'd0, d); repeat (40) @(posedge clk); end
endtask
// direccion de escritura de VRAM (17 bits)
task vram_at(input [16:0] a);
begin
    vdp_reg(6'd14, {5'd0, a[16:14]});
    bus_wr(3'd1, a[7:0]);
    bus_wr(3'd1, {2'b01, a[13:8]});
end
endtask

// ---- volcado de un frame completo (el siguiente a la carga) en transiciones de color ----
reg ready = 0;
integer first_dump_vs = 0;
integer mode = 8;
integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;
integer nlines = 0, ntrans = 0;
reg [9:0] cur_y = 10'h3FF;
logic [24:0] prev_rgb = 25'h1FFFFFF;     // el bit 24 a 1 = sin color anterior
string fname;
always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
            $display("FRAME VOLCADO a %0s: %0d lineas, %0d transiciones", fname, nlines, ntrans);
        end
        else if (dump_state == 0 && ready && vs_count >= first_dump_vs) begin
            fd = $fopen(fname, "w");
            dump_state <= 1;
        end
    end
    // el volcado sale de la paleta, ANTES del escalador de salida (que interpola lineas y pixeles): una muestra por pixel (celda de 16 relojes),
    // en la fase 8 de la celda, con el numero de pixel de la linea (screen_pos_x / 16) y la linea (screen_pos_y) del propio VDP
    if (dump_state == 1 && fd != 0 && u_vdp.w_screen_pos_x[3:0] == 4'd8) begin
        if (u_vdp.w_screen_pos_y != cur_y) begin
            cur_y <= u_vdp.w_screen_pos_y;
            $fdisplay(fd, "L %0d", u_vdp.w_screen_pos_y);
            prev_rgb <= 25'h1FFFFFF;
            nlines <= nlines + 1;
        end
        else if ({1'b0, u_vdp.w_vdp_r, u_vdp.w_vdp_g, u_vdp.w_vdp_b} != prev_rgb) begin
            $fdisplay(fd, "%0d %02x%02x%02x", u_vdp.w_screen_pos_x[13:4], u_vdp.w_vdp_r, u_vdp.w_vdp_g, u_vdp.w_vdp_b);
            prev_rgb <= {1'b0, u_vdp.w_vdp_r, u_vdp.w_vdp_g, u_vdp.w_vdp_b};
            ntrans <= ntrans + 1;
        end
    end
end

integer x, y;
reg [7:0] b;
initial begin
    if (!$value$plusargs("MODE=%d", mode)) mode = 8;
    fname = $sformatf("sprite_%0d.txt", mode);
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    // G7: R#0 = 0Eh. R#1 = 40h (pantalla, sprites 8x8). R#8 = 08h (VR; sprites ACTIVOS). R#7 = 0 (borde negro)
    vdp_reg(6'd0,  8'h0E);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd5,  8'hF7);        // tabla de atributos de sprites en F A00h (convencion de la BIOS de SCREEN 8: bits 1-0 a 1)
    vdp_reg(6'd6,  8'h1E);        // patrones de sprites en F000h
    vdp_reg(6'd7,  8'h00);
    vdp_reg(6'd8,  8'h08);
    vdp_reg(6'd11, 8'h01);        // A15 de la tabla de atributos
    vdp_reg(6'd20, 8'h01);
    case (mode)
        11:      vdp_reg(6'd25, 8'h18);   // YAE + YJK
        12:      vdp_reg(6'd25, 8'h08);   // YJK
        default: vdp_reg(6'd25, 8'h00);
    endcase
    // fondo: 24 lineas (32..55) de 256 bytes, iguales; los sprites caen en las lineas 40..47 (el resto de VRAM queda a 0 = negro)
    vram_at(17'h02000);
    for (y = 0; y < 24; y = y + 1)
        for (x = 0; x < 256; x = x + 1) begin
            if (x < 128) b = (x >= 64 && x < 68) ? 8'hF0 : 8'h40;          // A = 0: Y mayor en la columna de 4
            else         b = (x >= 192 && x < 196) ? 8'h58 : 8'h28;         // A = 1 en SCREEN 10/11: paleta 5 en la columna, 2 fuera
            vwr(b);
        end
    // patron 0 de sprite (8x8 lleno) en F000h
    vram_at(17'h0F000);
    for (x = 0; x < 8; x = x + 1) vwr(8'hFF);
    // tabla de colores de los sprites (F800h): sprite 0 = color 13, sprite 1 = color 14 (16 lineas cada uno)
    vram_at(17'h0F800);
    for (x = 0; x < 16; x = x + 1) vwr(8'h0D);
    for (x = 0; x < 16; x = x + 1) vwr(8'h0E);
    // atributos (FA00h): Y, X, patron, 0; el sprite 2 con Y = D8h cierra la lista
    vram_at(17'h0FA00);
    vwr(8'd39); vwr(8'd64);  vwr(8'd0); vwr(8'd0);
    vwr(8'd39); vwr(8'd192); vwr(8'd0); vwr(8'd0);
    vwr(8'hD8);
    $display("VRAM cargada en vs=%0d (modo %0d)", vs_count, mode);
    begin : cnt integer nz, q; nz = 0; for (q = 0; q < 65536; q = q + 1) if (vram_mem[q] != 0) nz = nz + 1; $display("palabras de VRAM no nulas: %0d (la 0: %h, la 1: %h)", nz, vram_mem[0], vram_mem[1]); end
    first_dump_vs = vs_count + 1;      // el frame siguiente a la carga ya tiene todo
    ready = 1;
    wait (dump_state == 2);
    #1000;
    $display("*** FIN modo %0d ***", mode);
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
