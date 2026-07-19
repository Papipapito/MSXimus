// ============================================================================
// tb_screen8.sv — HW _119: SCREEN 8 (G7, VRAM ENTRELAZADA) con el shim y la
// SDRAM lenta. En SC7/8/12 el interface transforma TODAS las direcciones con
// {a[17], a[0], a[16:1]} (dos streams alternando mitades de VRAM): la
// hipotesis del glitch masivo es que ambos streams COLISIONAN en los indices
// de la ventana y la cache del shim (thrash total). Se compara contra
// tb_screen8r (VRAM perfecta): dumps identicos = shim correcto.
// Parametro de mando: +definir NADA — el TB es identico al 8r salvo la pila.
// ============================================================================
`timescale 1ns/1ps

module tb_screen8d;

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

// ---- VRAM PERFECTA (8 ciclos exactos + eco de tag; stall=0) ----
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
integer n_log = 0;
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
        if (vs_count >= 4 && n_log < 300) begin
            $display("FETCH t=%0d tag=%0d addr=%04x", $time/1000, vram_tag[4:2], vram_address);
            n_log <= n_log + 1;
        end
        if (n_log == 300) begin
            $display("LOG_COMPLETO");
            $finish;
        end
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
            $display("FRAME VOLCADO (referencia)");
        end
        else if (dump_state == 0 && vs_count == 12) begin
            fd = $fopen("s8r_frame.txt", "w");
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
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    // SCREEN 8 = G7: R#0 = 0x0E, sin paleta (RGB332 directo)
    vdp_reg(6'd0,  8'h0E);
    vdp_reg(6'd1,  8'h40);
    vdp_reg(6'd2,  8'h1F);
    vdp_reg(6'd8,  8'h2A);
    vdp_reg(6'd20, 8'h01);
    vdp_reg(6'd7,  8'h0F);
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, 8'h40);
    $display("VRAM cargada en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("*** SCREEN8 REFERENCIA: COMPLETO (vs=%0d) ***", vs_count);
    $finish;
end

initial begin
    #700000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
