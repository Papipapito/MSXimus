// tb_osd.sv - banco del OSD con color de la V3.8: iosys_bl616 + textdisp + la BSRAM REAL (DPX9B del simlib de Gowin).
// Manda por la UART (2 Mbps) las ordenes de cmds.hex (+N=<bytes>) y luego recorre el overlay entero como el
// msx2hdmi a 720p (cada pixel del overlay dura 5 ciclos de hclk) y apunta el color de cada pixel en pix.txt.
// check.py genera las ordenes, pinta lo que deberia salir y compara pixel a pixel.
`timescale 1ns/1ps
module tb_osd;
    reg clk = 0, hclk = 0, resetn = 0;
    always #18.518 clk  = ~clk;     // 27 MHz
    always #6.734  hclk = ~hclk;    // 74,25 MHz

    GSR GSR (.GSRI(1'b1));

    reg        uart_rx = 1'b1;
    reg  [7:0] ox = 8'd255, oy = 8'd0;
    wire [14:0] ocolor;
    wire        overlay;

    iosys_bl616 #(.FREQ(27_000_000), .CORE_ID(16'd77)) dut (
        .clk(clk), .hclk(hclk), .resetn(resetn),
        .overlay(overlay), .overlay_x(ox), .overlay_y(oy), .overlay_color(ocolor),
        .joy1(12'd0), .joy2(12'd0), .hid1(), .hid2(),
        .rom_loading(), .rom_do(), .rom_do_valid(),
        .mgmt_address(), .mgmt_read(), .mgmt_readdata(16'd0), .mgmt_write(), .mgmt_writedata(), .fdd_request(2'd0),
        .kbd_data(), .kbd_data_valid(), .core_config(), .status_in(64'h0),
        .uart_rx(uart_rx), .uart_tx()
    );

    reg [7:0] cmds [0:65535];
    integer n, i, b, x, y, f, malos;
    reg [14:0] c3, c4;

    task enviar(input [7:0] v);
        begin
            uart_rx = 1'b0; #500;
            for (b = 0; b < 8; b = b + 1) begin uart_rx = v[b]; #500; end
            uart_rx = 1'b1; #500;
        end
    endtask

    initial begin
        if (!$value$plusargs("N=%d", n)) n = 0;
        $readmemh("cmds.hex", cmds);
        #200 resetn = 1;
        #2000;
        for (i = 0; i < n; i = i + 1) enviar(cmds[i]);
        #5000;
        if (!overlay) $display("AVISO: el overlay no se ha encendido");
        f = $fopen("pix.txt", "w");
        malos = 0;
        for (y = 0; y < 224; y = y + 1) begin
            @(posedge hclk); oy <= y[7:0];
            repeat (60) @(posedge hclk);                           // "borrado horizontal"
            for (x = 0; x < 256; x = x + 1) begin
                ox <= x[7:0];                                       // cambia en este flanco: ciclo 0 del pixel
                @(posedge hclk); @(posedge hclk); @(posedge hclk);  // ciclos 1..3
                #1 c3 = ocolor;                                     // ciclo 3: OUTPUT (combinacional)
                @(posedge hclk);
                #1 c4 = ocolor;                                     // ciclo 4: color_buf
                if (c3 !== c4) malos = malos + 1;
                $fwrite(f, "%04h\n", c4);
                @(posedge hclk);                                    // ciclo 5 = 0 del siguiente
            end
            ox <= 8'd255;
        end
        $fclose(f);
        $display("pixeles con color inestable entre los ciclos 3 y 4: %0d", malos);
        $finish;
    end
endmodule
