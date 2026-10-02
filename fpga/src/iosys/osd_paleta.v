// GENERADO por tools/gen_iosys_bram.py (tools/osd_fuente.py) -- NO EDITAR A MANO. Paleta del OSD, BGR555.
// Atributo = {fondo[3:0], tinta[3:0]}; el 0 es el aspecto de siempre (tinta amarilla sobre negro).
module osd_paleta (input [3:0] ti, input [3:0] fo, output reg [14:0] tinta, output reg [14:0] fondo);
    always @* begin
        case (ti)
            4'd0 : tinta = 15'h43FF;   // CLASICO
            4'd1 : tinta = 15'h7FFF;   // BLANCO
            4'd2 : tinta = 15'h62D5;   // GRIS_CL
            4'd3 : tinta = 15'h41CD;   // GRIS
            4'd4 : tinta = 15'h24E6;   // GRIS_OSC
            4'd5 : tinta = 15'h1C62;   // NOCHE
            4'd6 : tinta = 15'h6565;   // AZUL
            4'd7 : tinta = 15'h7707;   // CIAN
            4'd8 : tinta = 15'h2F48;   // VERDE
            4'd9 : tinta = 15'h1562;   // VERDE_OSC
            4'd10: tinta = 15'h177F;   // AMARILLO
            4'd11: tinta = 15'h0E1F;   // NARANJA
            4'd12: tinta = 15'h18DC;   // ROJO
            4'd13: tinta = 15'h7133;   // VIOLETA
            4'd14: tinta = 15'h3CC3;   // MARINO
            4'd15: tinta = 15'h0000;   // NEGRO
        endcase
        case (fo)
            4'd0 : fondo = 15'h0000;   // CLASICO
            4'd1 : fondo = 15'h7FFF;   // BLANCO
            4'd2 : fondo = 15'h62D5;   // GRIS_CL
            4'd3 : fondo = 15'h41CD;   // GRIS
            4'd4 : fondo = 15'h24E6;   // GRIS_OSC
            4'd5 : fondo = 15'h1C62;   // NOCHE
            4'd6 : fondo = 15'h6565;   // AZUL
            4'd7 : fondo = 15'h7707;   // CIAN
            4'd8 : fondo = 15'h2F48;   // VERDE
            4'd9 : fondo = 15'h1562;   // VERDE_OSC
            4'd10: fondo = 15'h177F;   // AMARILLO
            4'd11: fondo = 15'h0E1F;   // NARANJA
            4'd12: fondo = 15'h18DC;   // ROJO
            4'd13: fondo = 15'h7133;   // VIOLETA
            4'd14: fondo = 15'h3CC3;   // MARINO
            4'd15: fondo = 15'h0000;   // NEGRO
        endcase
    end
endmodule
