// TB rapido del dbg_uart byte-al-vuelo (_124d): captura TX a baud y
// reconstruye la linea; PASA si coincide con el patron esperado.
`timescale 1ns/1ps
module tb_dbguart;
reg clk = 0;
always #9.26 clk = ~clk;              // ~54MHz
reg rst_n = 0;
wire tx;
dbg_uart #(.CLK_HZ(53_996_000), .BAUD(115_200), .PERIOD_MS(1)) dut (
    .clk(clk), .rst_n(rst_n),
    .cnt_a(32'h0000_0495), .cnt_b(32'h29c4_8d4d), .cnt_c(32'h295b_0c9f),
    .cnt_d(32'h8005_e3c1), .cnt_e(32'h0007_001f),
    .tx(tx)
);
localparam real BIT_NS = 1e9 / 115200.0;
reg [7:0] line [0:63];
integer n = 0, b;
reg [7:0] ch;
initial begin
    repeat (20) @(posedge clk);
    rst_n = 1;
    forever begin
        @(negedge tx);                 // start
        #(BIT_NS * 1.5);
        ch = 0;
        for (b = 0; b < 8; b = b + 1) begin
            ch[b] = tx;
            #(BIT_NS);
        end
        line[n] = ch; n = n + 1;
        if (ch == 8'h0A) begin
            $write("LINEA: ");
            for (b = 0; b < n; b = b + 1)
                if (line[b] >= 32) $write("%c", line[b]);
            $write("\n");
            if (n == 48 &&
                {line[0],line[1]} == "D " &&
                line[2]=="0"&&line[3]=="0"&&line[4]=="0"&&line[5]=="0"&&
                line[6]=="0"&&line[7]=="4"&&line[8]=="9"&&line[9]=="5" &&
                line[11]=="2"&&line[12]=="9"&&line[13]=="c"&&line[14]=="4"&&
                line[15]=="8"&&line[16]=="d"&&line[17]=="4"&&line[18]=="d" &&
                line[29]=="8"&&line[30]=="0"&&line[31]=="0"&&line[32]=="5"&&
                line[33]=="e"&&line[34]=="3"&&line[35]=="c"&&line[36]=="1" &&
                line[38]=="0"&&line[39]=="0"&&line[40]=="0"&&line[41]=="7"&&
                line[42]=="0"&&line[43]=="0"&&line[44]=="1"&&line[45]=="f")
                $display("*** DBG_UART BYTE-AL-VUELO: OK ***");
            else
                $display("*** DBG_UART: FALLO (n=%0d) ***", n);
            $finish;
        end
    end
end
initial begin #60000000; $display("TIMEOUT"); $finish; end
endmodule
