// ============================================================================
// usb_pad_rid.v — 28/09/2026 (V3.7.2): mandos HID GENERICOS por los USB-A del fabric.
//
// usb_hid_host (nand2mario) no lee el descriptor HID: da por hecho el informe de los mandos "SNES USB" (ejes
// 00/7F/FF en los bytes 0-1, botones en 5-6). Un mando generico como el "USB Gamepad" 0810:0001 manda otra cosa:
//   [0] Report ID = 01h   [1] Rz   [2] Z   [3] X   [4] Y   [5] hat[3:0] + botones 1-4   [6] botones 5-12   [7] fabricante
// (el mismo informe que parsea hid_pad.c en el companion de la Zynq a partir del descriptor). Con el core de antes,
// ese mando enumeraba, respondian los botones y no se movia nada; y el eje Rz en el byte 1 dejaba arriba/abajo
// pegados (solo 7Fh soltaba y ese stick reposa en 80h).
//
// Este decodificador va EN PARALELO al de siempre y solo actua cuando el byte 0 del informe es 01h (un Report ID;
// un mando SNES lleva ahi el eje X: 00/7F/FF, nunca 01). Entonces:
//   - cruceta = hat del byte 5 (0..7 desde arriba, en el sentido del reloj; 8..F = reposo) O el stick izquierdo de
//     los bytes 3-4 con umbrales (< 40h / > C0h: valen los sticks analogicos, no solo 00/FF);
//   - botones 1/2/3/4 -> A/B/X/Y (como en la Zynq: disparo A = boton 1, B = boton 2), 5/6 -> L/R, 9/10 -> SELECT/START.
// El resultado se OR-ea con la palabra SNES del core (que en ese modo no aporta direcciones: usb_hid_host silencia sus
// bytes 1, 5 y 6 con rid1). Los mandos SNES que ya iban siguen igual: aqui todo queda a 0.
// Palabra SNES (la del BL616, top.v): bit 4 arriba, 5 abajo, 6 izq, 7 der, 8 A, 9 X, 0 B, 1 Y, 2 SEL, 3 START, 10 L, 11 R.
// ============================================================================
module usb_pad_rid (
    input  wire        clk,          // usbclk (12 MHz), el del bloque process_in_data de usb_hid_host
    input  wire        clr,          // conerr: mando fuera -> todo a 0
    input  wire        strobe,       // un byte del informe de entrada aceptado (typ == 3)
    input  wire [3:0]  idx,          // rcvct: indice del byte dentro del informe
    input  wire [7:0]  b,            // ukpdat: el byte
    output reg         rid1,         // el informe en curso empieza por 01h (modo generico)
    output wire [11:0] snes          // aportacion a game_snes
);
    reg xl, xr, yu, yd;              // stick izquierdo (bytes 3-4)
    reg hu, hd, hl, hr;              // hat (byte 5)
    reg ba, bb, bx, by, bl, br, bsel, bsta;

    always @(posedge clk) begin
        if (clr) begin
            rid1 <= 1'b0;
            xl <= 0; xr <= 0; yu <= 0; yd <= 0; hu <= 0; hd <= 0; hl <= 0; hr <= 0;
            ba <= 0; bb <= 0; bx <= 0; by <= 0; bl <= 0; br <= 0; bsel <= 0; bsta <= 0;
        end else if (strobe) begin
            case (idx)
            4'd0: begin
                rid1 <= (b == 8'h01);
                if (b != 8'h01) begin   // no es un informe con Report ID: este decodificador no opina
                    xl <= 0; xr <= 0; yu <= 0; yd <= 0; hu <= 0; hd <= 0; hl <= 0; hr <= 0;
                    ba <= 0; bb <= 0; bx <= 0; by <= 0; bl <= 0; br <= 0; bsel <= 0; bsta <= 0;
                end
            end
            4'd3: if (rid1) begin xl <= (b < 8'h40); xr <= (b > 8'hC0); end                 // X del stick izquierdo
            4'd4: if (rid1) begin yu <= (b < 8'h40); yd <= (b > 8'hC0); end                 // Y del stick izquierdo
            4'd5: if (rid1) begin                                                            // hat + botones 1-4
                hu <= (b[3:0] == 4'd7) | (b[3:0] == 4'd0) | (b[3:0] == 4'd1);
                hr <= (b[3:0] == 4'd1) | (b[3:0] == 4'd2) | (b[3:0] == 4'd3);
                hd <= (b[3:0] == 4'd3) | (b[3:0] == 4'd4) | (b[3:0] == 4'd5);
                hl <= (b[3:0] == 4'd5) | (b[3:0] == 4'd6) | (b[3:0] == 4'd7);
                ba <= b[4]; bb <= b[5]; bx <= b[6]; by <= b[7];
            end
            4'd6: if (rid1) begin bl <= b[0]; br <= b[1]; bsel <= b[4]; bsta <= b[5]; end   // botones 5, 6, 9, 10
            default: ;
            endcase
        end
    end

    assign snes = { br, bl, bx, ba, (xr | hr), (xl | hl), (yd | hd), (yu | hu), bsta, bsel, by, bb };
endmodule
