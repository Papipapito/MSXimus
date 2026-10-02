// tb_fbr.sv - banco del puente de la flash de la V3.8 (fpga/src/flash_bridge.v + el modulo flash de flash_rw.v)
// contra un modelo de flash SPI (03/06/05/20/02). Hace lo que hara el actualizador desde el MSX (borrar un sector,
// programar dos paginas esperando el bit 1, leer y comparar) y comprueba que guardar los ajustes sigue igual.
// Uso (desde Windows):
//   wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSX_up_v3_port/tools/flash_tb && bash run.sh"
`timescale 1ns/1ps

module spi_flash_model (input sclk, input cs_n, input mosi, output reg miso = 1'b0);
    reg [7:0]  mem [0:(1<<20)-1];      // la ventana baja de 1 MB (las pruebas usan direcciones distintas en ella)
    reg [7:0]  cmd, sr;
    reg [23:0] addr;
    integer    nbits;
    reg        wel = 0, wip = 0;
    reg [7:0]  obyte;
    integer    i;
    initial for (i = 0; i < (1<<20); i = i + 1) mem[i] = i[7:0] ^ 8'h5A;

    event ev_prog, ev_erase;
    always @(ev_prog)  begin wip = 1; #3000 wip = 0; end
    always @(ev_erase) begin wip = 1; #5000 wip = 0; end
    always @(negedge cs_n) begin nbits = 0; cmd = 8'h00; end
    always @(posedge cs_n) begin
        if (cmd == 8'h02 && nbits > 32 && wel) begin wel = 0; -> ev_prog; end
    end
    always @(posedge sclk) if (!cs_n) begin
        sr = {sr[6:0], mosi};
        nbits = nbits + 1;
        if (nbits == 8) begin
            cmd = sr;
            if (cmd == 8'h06) wel = 1;
        end else if (nbits == 32 && (cmd == 8'h03 || cmd == 8'h02 || cmd == 8'h20)) begin
            addr = {addr[15:0], sr};
            if (cmd == 8'h20 && wel) begin
                for (i = 0; i < 4096; i = i + 1) mem[{addr[19:12], 12'h000} + i] = 8'hFF;
                wel = 0; -> ev_erase;
            end
        end else if (nbits > 8 && nbits < 32) begin
            if (nbits % 8 == 0) addr = {addr[15:0], sr};
        end else if (nbits > 32 && cmd == 8'h02 && (nbits % 8 == 0) && wel) begin
            mem[{addr[19:8], 8'h00} + addr[7:0]] = mem[{addr[19:8], 8'h00} + addr[7:0]] & sr;
            addr[7:0] = addr[7:0] + 1;
        end
    end
    always @(negedge sclk) if (!cs_n) begin
        if (cmd == 8'h05 && nbits >= 8) begin
            if (nbits % 8 == 0) obyte = {6'b0, wel, wip};
            miso = obyte[7 - (nbits % 8)];
        end else if (cmd == 8'h03 && nbits >= 32) begin
            if (nbits % 8 == 0) obyte = mem[addr[19:0]];
            miso = obyte[7 - (nbits % 8)];
            if (nbits % 8 == 7) addr = addr + 1;
        end
    end
endmodule

module tb_fbr;
    reg clk = 0, reset_n = 0;
    always #9.259 clk = ~clk;          // 54 MHz

    wire sclk, cs_n, mosi, miso;
    spi_flash_model fl (.sclk(sclk), .cs_n(cs_n), .mosi(mosi), .miso(miso));

    // lado del MSX
    reg  [3:0] port = 0;
    reg        wr_req = 0, rd_req = 0, sel = 1;
    reg  [7:0] din = 0;
    wire [7:0] dout;

    // lado de los ajustes (como en top.v)
    reg        cfg_we = 0;
    wire [7:0] wcnt;
    wire [7:0] cfg_din = (wcnt == 0) ? 8'h41 : (wcnt == 1) ? 8'h42 : 8'h10 + wcnt;
    wire       cfg_term = (wcnt == 8'd11);

    wire        b_wr_start, b_wr_sel, b_noerase, b_wdata_ok, b_wterm, b_rd_sel, b_rd, b_term, b_info_ok;
    wire [23:0] b_addr;
    wire [7:0]  b_wdata, f_dout;
    wire [1:0]  b_info;
    wire        f_ready, f_busy, f_wbusy, f_idle;
    reg         ff_rd = 0, ff_term = 0;

    flash #(.STARTUP_WAIT(1)) dut_f (
        .clk(clk), .reset_n(reset_n), .SCLK(sclk), .CS(cs_n), .MISO(miso), .MOSI(mosi),
        .addr(b_rd_sel ? b_addr : 24'h400000), .rd(b_rd_sel ? b_rd : ff_rd), .terminate(b_rd_sel ? b_term : ff_term),
        .dout(f_dout), .data_ready(f_ready), .busy(f_busy),
        .write_enable(cfg_we | b_wr_start), .write_din(b_wr_sel ? b_wdata : cfg_din), .write_busy(f_wbusy),
        .write_counter(wcnt), .write_terminate(b_wr_sel ? b_wterm : cfg_term),
        .write_addr(b_wr_sel ? b_addr : 24'h480000),
        .write_noerase(b_wr_sel & b_noerase), .write_din_ok(~b_wr_sel | b_wdata_ok), .idle(f_idle)
    );
    flash_bridge dut_b (
        .clk(clk), .reset_n(reset_n), .sel(sel), .bus_port(port), .wr_req(wr_req), .rd_req(rd_req),
        .bus_din(din), .dout(dout), .info(b_info), .info_ok(b_info_ok), .libre(1'b1),
        .f_wr_start(b_wr_start), .f_wr_sel(b_wr_sel), .f_noerase(b_noerase), .f_addr(b_addr), .f_wdata(b_wdata),
        .f_wdata_ok(b_wdata_ok), .f_wterm(b_wterm), .f_write_busy(f_wbusy), .f_write_counter(wcnt),
        .f_rd_sel(b_rd_sel), .f_rd(b_rd), .f_term(b_term), .f_rdata(f_dout), .f_data_ready(f_ready), .f_idle(f_idle)
    );

    // un OUT / IN del Z80: ~20 ciclos de 54 MHz con la peticion activa y una pausa
    task outp(input [3:0] p, input [7:0] v);
        begin
            @(posedge clk); port <= p; din <= v; wr_req <= 1;
            repeat (20) @(posedge clk);
            wr_req <= 0;
            repeat (60) @(posedge clk);
        end
    endtask
    reg [7:0] leido;
    task inp(input [3:0] p);
        begin
            @(posedge clk); port <= p; rd_req <= 1;
            repeat (18) @(posedge clk);
            leido = dout;
            repeat (2) @(posedge clk);
            rd_req <= 0;
            repeat (60) @(posedge clk);
        end
    endtask
    integer fallos = 0, k, esperas;
    task espera_libre;
        begin
            esperas = 0;
            inp(1);
            while (leido[0] && esperas < 100000) begin inp(1); esperas = esperas + 1; end
            if (leido[0]) begin $display("FALLO: el puente no acaba la orden"); fallos = fallos + 1; end
        end
    endtask
    function [7:0] dato(input integer n); dato = (n * 7 + 3) ^ (n >> 8); endfunction

    initial begin
        #100 reset_n = 1;
        repeat (50) @(posedge clk);

        inp(1);
        if (leido[7:4] != 4'b1010) begin $display("FALLO: sin firma en #41 (%02x)", leido); fallos = fallos + 1; end
        inp(0);
        if (leido != 8'hB2) begin $display("FALLO: #40 = %02x", leido); fallos = fallos + 1; end

        // 1. borrar el sector 0x123000
        outp(1, 8'h12); outp(2, 8'h30); outp(3, 8'd1);
        espera_libre;
        for (k = 0; k < 4096; k = k + 1)
            if (fl.mem[20'h23000 + k] !== 8'hFF) begin
                if (fallos < 10) $display("FALLO: 0x123%03x = %02x tras borrar", k, fl.mem[20'h23000 + k]);
                fallos = fallos + 1;
            end
        if (fl.mem[20'h22FFF] !== (8'hFF ^ 8'h5A) || fl.mem[20'h24000] !== 8'h5A) begin
            $display("FALLO: el borrado se ha salido del sector"); fallos = fallos + 1;
        end

        // 2. programar las paginas 0x123000 y 0x123100 esperando el bit 1 antes de cada byte
        for (k = 0; k < 512; k = k + 1) begin
            if (k % 256 == 0) begin
                outp(1, 8'h12); outp(2, 8'h30 + k / 256); outp(3, 8'd2);
            end
            inp(1);
            while (!leido[1]) inp(1);
            outp(4, dato(k));
            if (k % 256 == 255) espera_libre;
        end
        for (k = 0; k < 512; k = k + 1)
            if (fl.mem[20'h23000 + k] !== dato(k)) begin
                if (fallos < 10) $display("FALLO: 0x%06x = %02x, se esperaba %02x", 24'h123000 + k, fl.mem[20'h23000 + k], dato(k));
                fallos = fallos + 1;
            end
        if (fl.mem[20'h23200] !== 8'hFF) begin $display("FALLO: se ha programado de mas"); fallos = fallos + 1; end

        // 3. leer 600 bytes desde 0x123000 con IN #44
        outp(1, 8'h12); outp(2, 8'h30); outp(3, 8'd3);
        inp(1);
        while (!leido[2]) inp(1);
        for (k = 0; k < 600; k = k + 1) begin
            inp(4);
            if (leido !== fl.mem[20'h23000 + k]) begin
                if (fallos < 20) $display("FALLO: lectura %0d = %02x, en la flash %02x", k, leido, fl.mem[20'h23000 + k]);
                fallos = fallos + 1;
            end
        end
        outp(3, 8'd0);
        repeat (200) @(posedge clk);
        if (b_rd_sel) begin $display("FALLO: la lectura no suelta el puerto"); fallos = fallos + 1; end

        // 4. info del menu
        outp(4'hE, 8'h03);
        inp(4'hE);
        if (leido != 8'h07 || b_info != 2'b11 || !b_info_ok) begin $display("FALLO: info %02x", leido); fallos = fallos + 1; end

        // 5. sin seleccionar (otro ID en #40) el puente no hace nada
        sel = 0;
        outp(1, 8'h00); outp(3, 8'd1);
        repeat (2000) @(posedge clk);
        if (f_wbusy || b_wr_sel) begin $display("FALLO: el puente obedece sin estar seleccionado"); fallos = fallos + 1; end
        sel = 1;

        // 6. guardar los ajustes como siempre (borra 0x480000 y programa 12 bytes)
        @(posedge clk); cfg_we <= 1; @(posedge clk); @(posedge clk); cfg_we <= 0;
        wait (f_wbusy); wait (!f_wbusy);
        for (k = 0; k < 12; k = k + 1)
            if (fl.mem[20'h80000 + k] !== ((k == 0) ? 8'h41 : (k == 1) ? 8'h42 : 8'h10 + k)) begin
                $display("FALLO: ajustes byte %0d = %02x", k, fl.mem[20'h80000 + k]); fallos = fallos + 1;
            end
        if (fl.mem[20'h80000 + 12] !== 8'hFF) begin $display("FALLO: ajustes, byte 12 = %02x", fl.mem[20'h8000C]); fallos = fallos + 1; end
        if (fl.mem[20'h23000] !== dato(0)) begin $display("FALLO: los ajustes han tocado otra cosa"); fallos = fallos + 1; end

        if (fallos == 0) $display("OK: borrar, programar 2 paginas, leer 600 bytes, info, sin seleccionar y ajustes");
        else $display("%0d FALLOS", fallos);
        $finish;
    end
    initial begin #40_000_000_0 $display("FALLO: tiempo agotado"); $finish; end
endmodule
