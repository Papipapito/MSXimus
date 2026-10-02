// 32x28 text display in 8x8 font, with a picorv32 register I/O interface
// to print characters to the display.
//
// MSXimus V3.8 (01/10/2026): CON COLOR, en la MISMA BSRAM. Pasa de 2048 x 8 a 2048 x 9 (el noveno bit lo tiraba el
// modo x8) y el mapa queda (tools/osd_fuente.py):
//   $000-$37F  celdas 32x28: {atributo[1:0], caracter[6:0]}
//   $380-$3EF  tabla de atributos POR FILA: $380 + fila*4 + atributo = {fondo[3:0], tinta[3:0]} (osd_paleta.v)
//   $400-$7FF  fuente: 128 caracteres; los huecos 0x01-0x1F y 0x7F llevan 32 glifos (marcos, bloques, iconos, tildes)
// Cada fila tiene sus cuatro combinaciones de tinta y fondo. La tabla arranca con 0 = amarillo, 1 = blanco (el "hi"
// de siempre: el bit 7 del caracter sigue siendo el bit 0 del atributo), 2 = cian y 3 = negro sobre amarillo, asi que
// un firmware que no sabe de colores se ve como antes.
// Fuera: el logo de 72x14 (su hueco es la tabla) y la columna 0 naranja (el cursor del menu de TangCore).
// Un estado mas por pixel (leer la tabla): 4 de los 5 ciclos de hclk que dura un pixel del overlay a 720p, y el color
// sale un ciclo mas tarde (el overlay se corre 1 pixel de los 1280; no se aprecia).

module textdisp(
	input             clk,              // main logic clock
    input             hclk,             // hdmi clock
	input             resetn,

    input      [7:0]  x,                // 0 - 255
    input      [7:0]  y,                // 0 - 223
    output reg [14:0] color,            // pixel color, NOTE: 3-cycle latency

    // reg_char_we[0]: celda   [25:24] atributo, [20:16] x, [12:8] y, [7:0] caracter (bit 7 = bit 0 del atributo)
    // reg_char_we[1]: tabla   [17:16] atributo, [12:8] fila, [7:0] {fondo, tinta}
	input      [3:0]  reg_char_we,
	input      [31:0] reg_char_di
);
parameter [14:0] COLOR_LOGO = 15'b00000_10101_00000;    // sin uso (ya no hay logo); se deja por compatibilidad

wire       tabla  = reg_char_we[1];
wire [4:0] text_x = reg_char_di[20:16];
wire [4:0] text_y = reg_char_di[12:8];
wire [10:0] ada   = tabla ? {4'b0111, text_y, reg_char_di[17:16]} : {1'b0, text_y, text_x};
wire [8:0]  dina  = tabla ? {1'b0, reg_char_di[7:0]}
                          : {reg_char_di[25], reg_char_di[24] | reg_char_di[7], reg_char_di[6:0]};

reg  [10:0] mem_addr_b;
wire [8:0]  mem_do_b;

gowin_dpb_menu menu_mem (
    .clka(clk), .reseta(1'b0), .ocea(1'b1), .cea(1'b1),
    .ada(ada), .wrea(reg_char_we[0] | reg_char_we[1]),
    .dina(dina), .douta(),

    .clkb(hclk), .resetb(1'b0), .oceb(1'b1), .ceb(1'b1),
    .adb(mem_addr_b), .wreb(1'b0),
    .dinb(9'd0), .doutb(mem_do_b)
);

wire [14:0] pal_tinta, pal_fondo;
osd_paleta paleta (.ti(mem_do_b[3:0]), .fo(mem_do_b[7:4]), .tinta(pal_tinta), .fondo(pal_fondo));

reg [1:0]  atr = 2'd0;           // atributo de la celda en curso
reg        pix = 1'b0;           // bit de la fuente del pixel en curso
reg [14:0] color_buf = 15'd0;
reg [7:0]  x_r = 8'd0;

reg [1:0] state = 2'd0;
localparam MAIN       = 2'd0;   // leer la celda
localparam FETCH_FONT = 2'd1;   // leer la fila del glifo
localparam FETCH_ATTR = 2'd2;   // leer {fondo, tinta} de la tabla de la fila
localparam OUTPUT     = 2'd3;   // sacar el pixel y leer la celda siguiente

always @* begin
    color = color_buf;
    case (state)
    MAIN:       mem_addr_b = {1'b0, y[7:3], x[7:3]};
    FETCH_FONT: mem_addr_b = {1'b1, mem_do_b[6:0], y[2:0]};         // mem_do_b = la celda
    FETCH_ATTR: mem_addr_b = {4'b0111, y[7:3], atr};
    OUTPUT: begin                                                   // mem_do_b = {fondo, tinta}
        mem_addr_b = {1'b0, y[7:3], x[7:3]};
        color = pix ? pal_tinta : pal_fondo;
    end
    endcase
end

always @(posedge hclk) begin
    x_r <= x;
    case (state)
    MAIN, OUTPUT: begin
        state <= MAIN;
        if (state == OUTPUT) color_buf <= color;
        if (x[0] != x_r[0]) state <= FETCH_FONT;                    // pixel nuevo
    end
    FETCH_FONT: begin                                               // aqui mem_do_b es aun la CELDA
        atr   <= mem_do_b[8:7];
        state <= FETCH_ATTR;
    end
    FETCH_ATTR: begin                                               // y aqui la fila del glifo
        pix   <= mem_do_b[x[2:0]];
        state <= OUTPUT;
    end
    endcase
end

endmodule
