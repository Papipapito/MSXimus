// ============================================================================
//  usb_kbd_decode.v — boot-report del usb_hid_host -> bitmap keyboard[127:0]
// ----------------------------------------------------------------------------
//  Produce el MISMO formato que el FPGA-Companion (MiSTle) por SPI, para
//  fusionarse con OR: bit = usage HID (<104) pulsado; modificadores en
//  104+bit (LCtrl=104, LShift=105, LAlt=106, LGui=107, RCtrl..RGui=108..111
//  — verificado contra los consumidores del top: keyboard[106]=CODE/KANA).
//  Dominio clk12 del usb_hid_host; los bits son cuasi-estaticos (pulsaciones
//  de ms) y se cruzan por 2FF en el top.
// ============================================================================
module usb_kbd_decode (
    input             clk12,
    input             rst_n,
    input      [1:0]  typ,          // 1 = teclado
    input             report,       // pulso: report nuevo valido
    input      [7:0]  mods,
    input      [7:0]  k1, k2, k3, k4,
    output reg [127:0] bitmap
);
    integer i;
    always @(posedge clk12) begin
        if (!rst_n)
            bitmap <= 128'd0;
        else if (typ == 2'd1 && report) begin
            // reconstruccion completa por report (el boot protocol es de
            // estado, no de eventos): borrar y re-poner
            bitmap <= 128'd0;
            for (i = 0; i < 8; i = i + 1)
                bitmap[104 + i] <= mods[i];
            if (k1 != 8'd0 && k1 < 8'd104) bitmap[k1] <= 1'b1;
            if (k2 != 8'd0 && k2 < 8'd104) bitmap[k2] <= 1'b1;
            if (k3 != 8'd0 && k3 < 8'd104) bitmap[k3] <= 1'b1;
            if (k4 != 8'd0 && k4 < 8'd104) bitmap[k4] <= 1'b1;
        end
        else if (typ != 2'd1)
            bitmap <= 128'd0;       // desconectado o no-teclado: soltar todo
    end
endmodule
