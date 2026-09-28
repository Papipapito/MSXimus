// tb_usb_pad_rid.sv — banco del decodificador de mandos HID genericos (usb_pad_rid.v), 28/09/2026.
// Los informes son los medidos al "USB Gamepad" 0810:0001 (los mismos 28 casos de padtest/test_pad0810.c de la Zynq)
// mas un informe de mando "SNES USB" (byte 0 = eje X) que el modulo ha de ignorar por completo.
// Icarus: iverilog -g2012 -o tb.vvp tb_usb_pad_rid.sv ../../fpga/src/usb_direct/usb_pad_rid.v && vvp -n tb.vvp
`timescale 1ns/1ps
module tb_usb_pad_rid;
    reg clk = 0; always #41.67 clk = ~clk;   // 12 MHz
    reg clr = 1, strobe = 0; reg [3:0] idx = 0; reg [7:0] b = 0;
    wire rid1; wire [11:0] snes;
    usb_pad_rid dut (.clk(clk), .clr(clr), .strobe(strobe), .idx(idx), .b(b), .rid1(rid1), .snes(snes));

    integer fails = 0;
    localparam UP = 12'h010, DN = 12'h020, LF = 12'h040, RT = 12'h080, A = 12'h100, X = 12'h200, B = 12'h001, Y = 12'h002,
               SEL = 12'h004, STA = 12'h008, L = 12'h400, R = 12'h800;

    task send(input [63:0] rep);   // 8 bytes, byte 0 en rep[7:0]
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                @(negedge clk); idx = k; b = rep[8*k +: 8]; strobe = 1;
                @(negedge clk); strobe = 0;
                @(negedge clk);
            end
            @(negedge clk);
        end
    endtask
    task check(input [8*24-1:0] what, input [63:0] rep, input [11:0] want);
        begin
            send(rep);
            if (snes !== want) begin fails = fails + 1; $display("FALLO %0s: %03x esperado %03x", what, snes, want); end
            else $display("ok   %0s -> %03x", what, snes);
        end
    endtask
    // informe 0810 en reposo: 01 80 80 7F 7F 0F 00 00  (byte 0 = rep[7:0])
    function [63:0] r0810(input [7:0] rz, z, x, y, b5, b6);
        r0810 = {8'h00, b6, b5, y, x, z, rz, 8'h01};
    endfunction

    initial begin
        repeat (3) @(negedge clk); clr = 0; repeat (2) @(negedge clk);
        check("reposo",            r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        check("hat arriba",        r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h00, 8'h00), UP);
        check("hat arriba-der",    r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h01, 8'h00), UP | RT);
        check("hat derecha",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h02, 8'h00), RT);
        check("hat abajo-der",     r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h03, 8'h00), DN | RT);
        check("hat abajo",         r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h04, 8'h00), DN);
        check("hat abajo-izq",     r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h05, 8'h00), DN | LF);
        check("hat izquierda",     r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h06, 8'h00), LF);
        check("hat arriba-izq",    r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h07, 8'h00), UP | LF);
        check("hat suelto",        r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        check("stick X izquierda", r0810(8'h80, 8'h80, 8'h00, 8'h7F, 8'h0F, 8'h00), LF);
        check("stick X derecha",   r0810(8'h80, 8'h80, 8'hFF, 8'h7F, 8'h0F, 8'h00), RT);
        check("stick X casi (30h)",r0810(8'h80, 8'h80, 8'h30, 8'h7F, 8'h0F, 8'h00), LF);
        check("stick X zona muerta",r0810(8'h80, 8'h80, 8'h50, 8'h7F, 8'h0F, 8'h00), 12'h000);
        check("stick Y arriba",    r0810(8'h80, 8'h80, 8'h7F, 8'h00, 8'h0F, 8'h00), UP);
        check("stick Y abajo",     r0810(8'h80, 8'h80, 8'h7F, 8'hFF, 8'h0F, 8'h00), DN);
        check("stick derecho (Rz/Z) no hace nada", r0810(8'h00, 8'hFF, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        check("boton 1 = A",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h1F, 8'h00), A);
        check("boton 2 = B",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h2F, 8'h00), B);
        check("boton 3 = X",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h4F, 8'h00), X);
        check("boton 4 = Y",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h8F, 8'h00), Y);
        check("boton 5 = L",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h01), L);
        check("boton 6 = R",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h02), R);
        check("boton 9 = SELECT",  r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h10), SEL);
        check("boton 10 = START",  r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h20), STA);
        check("hat izq + A + stick abajo", r0810(8'h80, 8'h80, 8'h7F, 8'hFF, 8'h16, 8'h00), LF | DN | A);
        check("reposo otra vez",   r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        // informe de un mando "SNES USB" (byte 0 = eje X = 00 izquierda, botones en 5-6): este modulo NO opina
        check("SNES: izquierda+A (ignorado aqui)", {8'h00, 8'h30, 8'h3F, 8'h7F, 8'h7F, 8'h80, 8'h7F, 8'h00}, 12'h000);
        if (rid1 !== 1'b0) begin fails = fails + 1; $display("FALLO: rid1 deberia ser 0 con un informe SNES"); end
        // y de vuelta al generico tras el SNES
        check("0810 tras SNES: hat arriba", r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h00, 8'h00), UP);
        // mando fuera: conerr
        @(negedge clk); clr = 1; @(negedge clk); clr = 0; @(negedge clk);
        if (snes !== 12'h000) begin fails = fails + 1; $display("FALLO: conerr no limpia (%03x)", snes); end
        if (fails == 0) $display("##### tb_usb_pad_rid: TODO OK #####"); else $display("##### tb_usb_pad_rid: %0d FALLOS #####", fails);
        $finish;
    end
endmodule
