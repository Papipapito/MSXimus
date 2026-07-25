// ============================================================================
// tb_sprite3r.sv — referencia PERFECTA del reproductor de sprites mode3.
// Core V9968 + VRAM perfecta (respuesta 8 ciclos, sin shim). MISMO setup que
// tb_sprite3 (sprite3_setup.svh). Vuelca s3r_frame.txt. diff s3_frame vs
// s3r_frame = glitches del shim.
// ============================================================================
`timescale 1ns/1ps

module tb_sprite3r;

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
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// ---- VRAM PERFECTA: 256KB (65536 palabras de 32b), respuesta 8 ciclos ----
logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
logic [31:0] vram_rdata_r = 0;
logic        vram_rdata_en_r = 0;
logic [4:0]  vram_rtag_r = 0;
assign vram_rdata = vram_rdata_r;
assign vram_rdata_en = vram_rdata_en_r;
assign vram_rtag = vram_rtag_r;
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

// ---- bus + helpers (identicos a tb_sprite3) ----
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
            $display("FRAME VOLCADO (referencia perfecta)");
        end
        else if (dump_state == 0 && vs_count == 12) begin
            fd = $fopen("s3r_frame.txt", "w");
            dump_state <= 1;
        end
    end
    if (dump_state == 1 && fd != 0) begin
        if (display_hs && !hs_d) $fdisplay(fd, "L");
        if (display_en) $fdisplay(fd, "%02x%02x%02x", display_r, display_g, display_b);
    end
end

integer yi_s, yj_s;
initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vs_count >= 1);
    `include "sprite3_setup.svh"
    $display("SETUP mode3 cargado en vs=%0d", vs_count);
    wait (dump_state == 2);
    #1000;
    $display("*** SPRITE3 REFERENCIA: COMPLETO (vs=%0d) ***", vs_count);
    $finish;
end

initial begin
    #900000000;
    $display("TIMEOUT vs=%0d dump=%0d", vs_count, dump_state);
    $finish;
end

endmodule
