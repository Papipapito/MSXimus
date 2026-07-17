// ============================================================================
// tb_screen5.sv — F0 del V9968: render de SCREEN 5 (G4, 256x212 4bpp) con
// contenido REAL en VRAM + paleta escrita por el bus. Vuelca 1 frame con
// marcadores de linea -> tools/v9968_sim/png_from_dump.py lo convierte a PNG.
// La prueba visual de que el V9968 renderiza graficos en nuestro toolchain.
// ============================================================================
`timescale 1ns/1ps

module tb_screen5;

localparam real CLK_HALF = 5.8207;   // 85.90908 MHz
logic reset_n = 0;
logic clk = 0;
always #(CLK_HALF) clk = ~clk;

logic        initial_busy = 0;
logic [2:0]  bus_address = 0;
logic        bus_ioreq = 0, bus_write = 0, bus_valid = 0;
logic [7:0]  bus_wdata = 0;
wire  [7:0]  bus_rdata;
wire         bus_rdata_en, bus_ready, int_n;
wire  [17:2] vram_address;
wire         vram_write, vram_valid, vram_refresh;
wire  [31:0] vram_wdata;
wire  [3:0]  vram_wdata_mask;
logic [31:0] vram_rdata = 0;
logic        vram_rdata_en = 0;
wire         display_hs, display_vs, display_en;
wire  [7:0]  display_r, display_g, display_b;

vdp u_vdp (
    .reset_n(reset_n), .clk(clk), .initial_busy(initial_busy),
    .bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
    .bus_valid(bus_valid), .bus_ready(bus_ready),
    .bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
    .int_n(int_n),
    .vram_address(vram_address), .vram_write(vram_write),
    .vram_valid(vram_valid), .vram_wdata(vram_wdata),
    .vram_wdata_mask(vram_wdata_mask),
    .vram_rdata(vram_rdata), .vram_rdata_en(vram_rdata_en),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// ---- VRAM 256KB, latencia 3 ciclos; contadores de ancho de banda ----
logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
integer      rd_count = 0, wr_count = 0;
always @(posedge clk) begin
    vram_rdata_en <= 1'b0;
    if (vram_valid && vram_write) begin
        wr_count <= wr_count + 1;
        if (vram_wdata_mask[0]) vram_mem[vram_address][ 7: 0] <= vram_wdata[ 7: 0];
        if (vram_wdata_mask[1]) vram_mem[vram_address][15: 8] <= vram_wdata[15: 8];
        if (vram_wdata_mask[2]) vram_mem[vram_address][23:16] <= vram_wdata[23:16];
        if (vram_wdata_mask[3]) vram_mem[vram_address][31:24] <= vram_wdata[31:24];
    end
    else if (vram_valid && !vram_write && !p_pend) begin
        rd_count <= rd_count + 1;
        p_pend <= 1'b1; p_addr <= vram_address; p_cnt <= 0;
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == 2) begin
            vram_rdata    <= vram_mem[p_addr];
            vram_rdata_en <= 1'b1;
            p_pend        <= 1'b0;
        end
    end
end

// ---- bus ----
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
// paleta: R#16 = indice; puerto 2 = dos bytes {0,R[2:0],0,B[2:0]} {0,0,0,0,0,G[2:0]}
task vdp_pal(input [3:0] idx, input [2:0] r, input [2:0] g, input [2:0] b);
begin
    vdp_reg(6'd16, {4'd0, idx});
    bus_wr(3'd2, {1'b0, r, 1'b0, b});
    bus_wr(3'd2, {5'd0, g});
end
endtask

// ---- vida + volcado con marcadores ----
integer vs_count = 0;
logic vs_d = 0, hs_d = 0;
integer fd = 0;
integer dump_state = 0;          // 0=espera 1=volcando 2=hecho
always @(posedge clk) begin
    vs_d <= display_vs;
    hs_d <= display_hs;
    if (display_vs && !vs_d) begin
        vs_count <= vs_count + 1;
        if (dump_state == 1) begin
            $fclose(fd);
            dump_state <= 2;
            $display("FRAME SCREEN5 VOLCADO (lecturas VRAM/frame ~%0d, escrituras %0d)",
                     rd_count / (vs_count > 0 ? vs_count : 1), wr_count);
        end
        else if (dump_state == 0 && vs_count == 6) begin
            fd = $fopen("s5_frame.txt", "w");
            dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

integer x, y;
initial begin
    // VRAM: SCREEN5 lineal desde 0x0000, 128 bytes/linea, 4bpp.
    // Patron: franjas verticales de 16px con los 16 colores + degradado
    // vertical (cambia el color base cada 16 lineas) => tablero colorido.
    for (x = 0; x < 65536; x = x + 1) vram_mem[x] = 32'h00000000;
    for (y = 0; y < 212; y = y + 1)
        for (x = 0; x < 128; x = x + 1) begin : fill
            logic [3:0] c0, c1;
            logic [16:0] baddr;
            c0 = ((x*2) >> 4) ^ (y >> 4);
            c1 = ((x*2+1) >> 4) ^ (y >> 4);
            baddr = y * 128 + x;
            case (baddr[1:0])
                2'd0: vram_mem[baddr >> 2][ 7: 0] = {c0, c1};
                2'd1: vram_mem[baddr >> 2][15: 8] = {c0, c1};
                2'd2: vram_mem[baddr >> 2][23:16] = {c0, c1};
                2'd3: vram_mem[baddr >> 2][31:24] = {c0, c1};
            endcase
        end

    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    // paleta: 16 colores distinguibles (rueda RGB simple)
    vdp_pal(4'd0,  3'd0, 3'd0, 3'd0);
    vdp_pal(4'd1,  3'd7, 3'd0, 3'd0);
    vdp_pal(4'd2,  3'd0, 3'd7, 3'd0);
    vdp_pal(4'd3,  3'd0, 3'd0, 3'd7);
    vdp_pal(4'd4,  3'd7, 3'd7, 3'd0);
    vdp_pal(4'd5,  3'd7, 3'd0, 3'd7);
    vdp_pal(4'd6,  3'd0, 3'd7, 3'd7);
    vdp_pal(4'd7,  3'd7, 3'd7, 3'd7);
    vdp_pal(4'd8,  3'd3, 3'd0, 3'd0);
    vdp_pal(4'd9,  3'd0, 3'd3, 3'd0);
    vdp_pal(4'd10, 3'd0, 3'd0, 3'd3);
    vdp_pal(4'd11, 3'd3, 3'd3, 3'd0);
    vdp_pal(4'd12, 3'd3, 3'd0, 3'd3);
    vdp_pal(4'd13, 3'd0, 3'd3, 3'd3);
    vdp_pal(4'd14, 3'd3, 3'd3, 3'd3);
    vdp_pal(4'd15, 3'd7, 3'd4, 3'd0);
    // SCREEN 5 (G4): R#0=0x06, R#2 tabla en 0x0000 (0x1F), borde gris
    vdp_reg(6'd0, 8'h06);
    vdp_reg(6'd2, 8'h1F);
    vdp_reg(6'd7, 8'h0E);
    vdp_reg(6'd1, 8'h60);        // BL=1 IE0=1
    wait (dump_state == 2);
    #1000;
    $display("*** SCREEN5: RENDER COMPLETO (vs=%0d) ***", vs_count);
    $finish;
end

initial begin
    #200000000;   // 200ms guardia
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
