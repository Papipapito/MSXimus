// ============================================================================
// tb_smoke.sv — F0 del V9968 (hra1129/V9968_Cartridge @ 5978d18): smoke test
// del core en NUESTRO toolchain (iverilog). Comprueba:
//   1. reset + relojes: el VDP arranca y genera sincronismos
//   2. bus CPU valid/ready: escritura de registros (R#7 borde)
//   3. VRAM 32-bit valid/rdata_en con LATENCIA (modelo 3 ciclos, como sera
//      el shim SDRAM del 60K)
//   4. volcado de 1 frame a PPM -> prueba VISUAL de que renderiza
// Uso: bash run_smoke.sh   (compila el core del repo clonado + este tb)
// ============================================================================
`timescale 1ns/1ps

module tb_smoke;

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
    .force_highspeed(1'b0),
    .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// ---- VRAM 256KB con latencia de 3 ciclos (ensayo del shim SDRAM) ----
logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
integer vi;
initial for (vi = 0; vi < 65536; vi = vi + 1) vram_mem[vi] = 32'h00000000;
always @(posedge clk) begin
    vram_rdata_en <= 1'b0;
    if (vram_valid && vram_write) begin
        if (vram_wdata_mask[0]) vram_mem[vram_address][ 7: 0] <= vram_wdata[ 7: 0];
        if (vram_wdata_mask[1]) vram_mem[vram_address][15: 8] <= vram_wdata[15: 8];
        if (vram_wdata_mask[2]) vram_mem[vram_address][23:16] <= vram_wdata[23:16];
        if (vram_wdata_mask[3]) vram_mem[vram_address][31:24] <= vram_wdata[31:24];
    end
    else if (vram_valid && !vram_write && !p_pend) begin
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

// ---- bus CPU: escritura con handshake valid/ready ----
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(posedge clk);
    bus_address <= a; bus_wdata <= d;
    bus_ioreq <= 1; bus_write <= 1; bus_valid <= 1;
    @(posedge clk);
    while (!bus_ready) @(posedge clk);
    bus_ioreq <= 0; bus_write <= 0; bus_valid <= 0;
    repeat (20) @(posedge clk);   // ritmo Z80-ish
end
endtask

// puerto 1 (mode=1): registro; secuencia dato,reg|0x80
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

// ---- contadores de vida ----
integer vs_count = 0, hs_count = 0, en_count = 0, int_count = 0;
logic vs_d = 0, hs_d = 0, int_d = 1;
always @(posedge clk) begin
    vs_d <= display_vs; hs_d <= display_hs; int_d <= int_n;
    if (display_vs && !vs_d) vs_count = vs_count + 1;
    if (display_hs && !hs_d) hs_count = hs_count + 1;
    if (display_en) en_count = en_count + 1;
    if (!int_n && int_d) int_count = int_count + 1;
end

// ---- volcado de UN frame a PPM (arranca en el vsync N) ----
integer fppm = 0, px = 0, dumping = 0, frame_to_dump = 4;
always @(posedge clk) begin
    if (display_vs && !vs_d && vs_count == frame_to_dump && !dumping) begin
        dumping = 1;
        fppm = $fopen("v9968_frame.ppm.raw", "wb");
        px = 0;
    end
    if (dumping == 1 && fppm != 0 && display_en) begin
        $fwrite(fppm, "%c%c%c", display_r, display_g, display_b);
        px = px + 1;
    end
    if (dumping == 1 && display_vs && !vs_d && vs_count == frame_to_dump + 1) begin
        $fclose(fppm);
        dumping = 2;
        $display("FRAME VOLCADO: %0d pixeles activos", px);
    end
end

initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    // dejar arrancar un par de frames
    wait (vs_count >= 2);
    $display("VIVO: %0d vsync tras reset (hs=%0d, en=%0d)", vs_count, hs_count, en_count);
    // borde ROJO: R#7 = color de borde (bits 3:0 en modo texto/borde)
    vdp_reg(6'd7, 8'h08);          // borde = rojo (paleta MSX: 8)
    // habilitar pantalla + interrupciones: R#1 bit6 (BL) + bit5 (IE0)
    vdp_reg(6'd1, 8'h60);
    wait (vs_count >= frame_to_dump + 1);
    #1000;
    $display("RESULTADO: vsync=%0d hsync=%0d en_pix=%0d int=%0d", vs_count, hs_count, en_count, int_count);
    if (vs_count >= 5 && en_count > 100000)
        $display("*** V9968 SMOKE: PASA (sincronismos + pixels + bus vivos) ***");
    else
        $display("*** V9968 SMOKE: FALLO (revisar interfaz) ***");
    $finish;
end

initial begin
    #120000000;   // 120ms guardia (7 frames)
    $display("TIMEOUT vs=%0d hs=%0d", vs_count, hs_count);
    $finish;
end

endmodule
