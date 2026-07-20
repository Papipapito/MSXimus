// ============================================================================
// tb_cpu_bulk.sv — _125: escritura MASIVA por puerto CPU cruzando bancos de
// 16KB con VR=0 (R#8 bit3), el caso de soft_vdp_test2 de HRA (HW _124:
// "media pantalla" — el ruido/los colores solo llegaban a la linea 128).
// En silicio real y openMSX el contador de direcciones ACARREA al banco
// R#14 en modos V9938+ aunque VR=0 (VR solo elige el tipo de DRAM para
// el refresh); el core envolvia a 14 bits => las escrituras >16KB
// re-pintaban el banco 0 y las lineas 128-211 quedaban virgenes.
// PASA si: tras streamear 24576 bytes desde 0x0000 en SC5 con VR=0, los
// bytes del banco 1 (0x4000-0x5FFF) contienen el patron esperado, y una
// pasada de LECTURA por puerto los devuelve igual (acarreo tambien en read).
// ============================================================================
`timescale 1ns/1ps

module tb_cpu_bulk;

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
logic [31:0] vram_rdata_r = 0;
logic        vram_rdata_en_r = 0;
logic [4:0]  vram_rtag_r = 0;
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
    .vram_rdata(vram_rdata_r), .vram_rdata_en(vram_rdata_en_r),
    .vram_tag(vram_tag), .vram_rtag(vram_rtag_r),
    .vram_stall(1'b0),
    .vram_refresh(vram_refresh),
    .display_hs(display_hs), .display_vs(display_vs), .display_en(display_en),
    .display_r(display_r), .display_g(display_g), .display_b(display_b),
    .force_highspeed(1'b0), .button(2'b00),
    .pulse0(), .pulse1(), .pulse2(), .pulse3(),
    .pulse4(), .pulse5(), .pulse6(), .pulse7()
);

// modelo perfecto de VRAM (8 ciclos)
logic [31:0] vram_mem [0:65535];
logic [15:0] p_addr;
logic [4:0]  p_tag;
logic [2:0]  p_cnt = 0;
logic        p_pend = 0;
integer vi;
initial for (vi = 0; vi < 65536; vi = vi + 1) vram_mem[vi] = 32'd0;
integer wr_b0 = 0, wr_b1 = 0;
// sondas jerarquicas: donde muere la peticion
integer cif_req = 0, vif_val = 0, vif_acc = 0, slotb = 0;
always @(posedge clk) begin
    if (u_vdp.u_cpu_interface.ff_vram_valid) cif_req <= cif_req + 1;
    if (u_vdp.u_vram_interface.cpu_vram_valid) vif_val <= vif_val + 1;
    if (u_vdp.u_vram_interface.is_access_timming_b) slotb <= slotb + 1;
    if (u_vdp.u_vram_interface.cpu_vram_valid &&
        u_vdp.u_vram_interface.is_access_timming_b) vif_acc <= vif_acc + 1;
end
integer p0wr = 0, bval = 0;
always @(posedge clk) begin
    if (u_vdp.u_cpu_interface.w_write && u_vdp.u_cpu_interface.ff_port0) begin
        p0wr <= p0wr + 1;
        if (p0wr < 4)
            $display("P0WR n=%0d mask=%b busy=%b t=%0t",
                     p0wr, u_vdp.u_cpu_interface.vram_access_mask,
                     u_vdp.u_cpu_interface.ff_busy, $time);
    end
    if (u_vdp.u_cpu_interface.ff_bus_valid) begin
        bval <= bval + 1;
        if (bval >= 20 && bval < 27)
            $display("BVAL n=%0d p0=%b p1=%b wr=%b busy=%b addr_tb=%b t=%0t",
                     bval, u_vdp.u_cpu_interface.ff_port0,
                     u_vdp.u_cpu_interface.ff_port1,
                     u_vdp.u_cpu_interface.ff_bus_write,
                     u_vdp.u_cpu_interface.ff_busy, bus_address, $time);
    end
end
logic [15:0] max_waddr = 0;
always @(posedge clk) begin
    vram_rdata_en_r <= 1'b0;
    if (vram_valid && vram_write) begin
        if (vram_address >= 16'h1000) wr_b1 = wr_b1 + 1;   // byte >= 0x4000
        else                          wr_b0 = wr_b0 + 1;
        if (vram_address > max_waddr) max_waddr = vram_address;
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

// _125: tareas de bus con disciplina de NEGEDGE — el ready del interface se
// ARMA desde ioreq un ciclo despues (ff_bus_ready <= bus_ioreq) y el estilo
// posedge del arnés 5g corria una carrera de scheduler con la captura
// (funcionaba de chiripa segun simulador/ritmo). Conduciendo y muestreando a
// mitad de ciclo, cada posedge ve valores estables: imposible la carrera.
// Contrato real del interface (como lo usa cpu_glue): ioreq ARMA el ready;
// valid es un PULSO DE UN CICLO exactamente cuando ready=1 (mantenerlo alto
// provoca RE-CAPTURAS del mismo byte cada 2 ciclos — visto en traza).
task bus_wr(input [2:0] a, input [7:0] d);
begin
    @(negedge clk);
    bus_address = a; bus_wdata = d; bus_write = 1;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);                        // el ready se arma desde ioreq
    while (!bus_ready) @(negedge clk);     // armado y sin busy
    bus_valid = 1;
    @(negedge clk);                        // el posedge intermedio CAPTURA
    bus_valid = 0; bus_ioreq = 0; bus_write = 0;
    repeat (2) @(negedge clk);
end
endtask
task bus_rd(input [2:0] a, output [7:0] d);
begin
    @(negedge clk);
    bus_address = a; bus_write = 0;
    bus_ioreq = 1; bus_valid = 0;
    @(negedge clk);
    while (!bus_ready) @(negedge clk);
    bus_valid = 1;
    @(negedge clk);
    bus_valid = 0; bus_ioreq = 0;
    while (!bus_rdata_en) @(negedge clk);
    d = bus_rdata;
    repeat (2) @(negedge clk);
end
endtask
task vdp_reg(input [5:0] r, input [7:0] d);
begin bus_wr(3'd1, d); bus_wr(3'd1, {2'b10, r}); end
endtask

integer i, fallos;
logic [7:0] esperado, leido;
logic [31:0] w32;
integer vsc = 0;
logic vs_d = 0;
always @(posedge clk) begin
    vs_d <= display_vs;
    if (display_vs && !vs_d) vsc <= vsc + 1;
end

integer trz = 0;
always @(posedge clk) begin
    if (trz > 0 && trz < 200) begin
        trz <= trz + 1;
        if (bus_valid || u_vdp.u_cpu_interface.ff_bus_valid ||
            u_vdp.u_cpu_interface.ff_bus_ready == 0)
            $display("TRZ c=%0d ioreq=%b val=%b wr=%b a=%0d rdy_o=%b | ffval=%b ffrdy=%b busy=%b",
                     trz, bus_ioreq, bus_valid, bus_write, bus_address, bus_ready,
                     u_vdp.u_cpu_interface.ff_bus_valid,
                     u_vdp.u_cpu_interface.ff_bus_ready,
                     u_vdp.u_cpu_interface.ff_busy);
    end
end

initial begin
    repeat (50) @(posedge clk);
    reset_n = 1;
    wait (vsc >= 1);
    trz = 1;
    // SCREEN 5 como soft_vdp_test2: R#0=06 R#1=40 R#8=0x02 (¡VR=0!) R#9=80
    vdp_reg(6'd0, 8'h06);
    vdp_reg(6'd1, 8'h40);
    vdp_reg(6'd7, 8'h07);
    vdp_reg(6'd8, 8'h02);             // VR=0: el caso que envolvia
    vdp_reg(6'd9, 8'h80);
    vdp_reg(6'd2, 8'h1F);
    // R#14 = 0 y direccion de escritura 0x0000
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'h00);
    bus_wr(3'd1, 8'h40);              // set write addr 0x0000
    // stream de 24576 bytes (1.5 bancos): patron = addr[7:0]^addr[13:8]
    for (i = 0; i < 24576; i = i + 1) begin
        bus_wr(3'd0, (i & 8'hFF) ^ ((i >> 8) & 8'hFF));
        if ((i & 4095) == 0) $display("progreso i=%0d t=%0t", i, $time);
    end
    $display("STREAM ESCRITO (t=%0t) wr_b0=%0d wr_b1=%0d max_waddr(word)=%04x",
             $time, wr_b0, wr_b1, max_waddr);
    $display("SONDAS: cif_req=%0d vif_val=%0d slotb=%0d vif_acc=%0d",
             cif_req, vif_val, slotb, vif_acc);
    repeat (500) @(posedge clk);          // drenar la ultima op (slot ~370ns)

    // --- verificacion en la VRAM del modelo ---
    fallos = 0;
    for (i = 16384; i < 24576; i = i + 1) begin   // el banco 1 entero
        w32 = vram_mem[i >> 2];
        leido = w32 >> (8 * (i & 3));
        esperado = (i & 8'hFF) ^ ((i >> 8) & 8'hFF);
        if (leido !== esperado) begin
            fallos = fallos + 1;
            if (fallos <= 8)
                $display("FALLO VRAM addr=%05x leido=%02x esperado=%02x", i, leido, esperado);
        end
    end
    $display("BANCO1 escritura: fallos=%0d/8192", fallos);

    // --- lectura por puerto cruzando la frontera (0x3FF0 -> 0x4010) ---
    vdp_reg(6'd14, 8'h00);
    bus_wr(3'd1, 8'hF0);
    bus_wr(3'd1, 8'h3F);              // set READ addr 0x3FF0
    for (i = 16368; i < 16400; i = i + 1) begin
        bus_rd(3'd0, leido);
        esperado = (i & 8'hFF) ^ ((i >> 8) & 8'hFF);
        if (leido !== esperado) begin
            fallos = fallos + 1;
            $display("FALLO READ addr=%05x leido=%02x esperado=%02x", i, leido, esperado);
        end
    end

    if (fallos == 0) $display("*** CPU BULK CROSS-BANK: OK ***");
    else             $display("*** CPU BULK CROSS-BANK: FALLO (%0d) ***", fallos);
    #1000;
    $finish;
end

initial begin
    #600000000;
    $display("TIMEOUT vs=%0d", vsc);
    $finish;
end

endmodule
