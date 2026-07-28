// ============================================================================
// dbg_uart.v — Telemetria de debug TX-only por el USB-UART de la Console
// (usb_uart_tx -> BL616 -> COM11 en el PC). Plan msx_debug_uart 2026-07-15.
//
// Emite periodicamente una linea ASCII con los contadores de diagnostico
// (valores cuasi-estaticos muestreados; el cruce de dominios se tolera por
// snapshot — un LSB rasgado en una muestra no importa para telemetria).
//
// Formato: "D <hex32> <hex32> <hex32> <hex32>\n"  cada ~250ms a 115200-8N1.
// (_123: 4a palabra = {fan_en, 11'b0, dbg_cnt del termometro RO} para
//  CALIBRAR el ventilador con datos reales — en HW _119 y _122 no disparo.)
//
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================
module dbg_uart #(
    parameter CLK_HZ  = 53_996_000,     // clk_54m
    parameter BAUD    = 115_200,
    parameter PERIOD_MS = 250
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] cnt_a,           // p.ej. misses del shim
    input  wire [31:0] cnt_b,           // p.ej. completaciones canal A/B
    input  wire [31:0] cnt_c,           // p.ej. drops/otros
    input  wire [31:0] cnt_d,           // _123: {fan_en, 11'b0, ro dbg_cnt}
    input  wire [31:0] cnt_e,           // _124: park {pisadas[15:0], drenajes[15:0]}
    input  wire [31:0] cnt_f,           // _154: drops del shim {s1_pfq[15:0], wq_full[15:0]} — sano = 0
    input  wire [31:0] cnt_g,           // _161c: salud del ADPCM {24'd0, wq_lost[3:0], wd_hits[3:0]} — sano = 0
    output reg         tx
);

    localparam integer DIV = CLK_HZ / BAUD;             // ~469
    localparam integer TICKS = (CLK_HZ / 1000) * PERIOD_MS;

    // snapshot de los contadores (cuasi-estaticos)
    reg [31:0] s_a, s_b, s_c, s_d, s_e, s_f, s_g;

    // mensaje: "D aaaaaaaa bbbbbbbb cccccccc dddddddd eeeeeeee\r\n" = 48 chars
    // _124d: el mensaje YA NO se materializa en un array (48x8 FF + un
    // decodificador one-shot de ~400 LUTs que se disparaba entero en un
    // ciclo): cada byte se computa AL VUELO desde los snapshots cuando le
    // toca transmitirse (byte_at, mux de ~4 niveles a 54MHz = gratis).
    localparam MSG_LEN = 66;   // _161c: 7 palabras (era 57 con 6)

    function [7:0] hexc(input [3:0] v);
        hexc = (v < 10) ? ("0" + {4'd0, v}) : ("a" + {4'd0, v} - 8'd10);
    endfunction

    function [7:0] byte_at(input [6:0] idx);   // _161c: 7 bits (66 > 63)
        reg [31:0] w;
        reg [2:0]  nib;
        begin
            if (idx == 7'd0)  byte_at = "D";
            else if (idx == 7'd1  || idx == 7'd10 || idx == 7'd19 ||
                     idx == 7'd28 || idx == 7'd37 || idx == 7'd46 ||
                     idx == 7'd55) byte_at = " ";
            else if (idx == 7'd64) byte_at = 8'h0D;
            else if (idx == 7'd65) byte_at = 8'h0A;
            else begin
                if      (idx <= 7'd9)  begin w = s_a; nib = idx - 7'd2;  end
                else if (idx <= 7'd18) begin w = s_b; nib = idx - 7'd11; end
                else if (idx <= 7'd27) begin w = s_c; nib = idx - 7'd20; end
                else if (idx <= 7'd36) begin w = s_d; nib = idx - 7'd29; end
                else if (idx <= 7'd45) begin w = s_e; nib = idx - 7'd38; end
                else if (idx <= 7'd54) begin w = s_f; nib = idx - 7'd47; end
                else                   begin w = s_g; nib = idx - 7'd56; end
                // nibble MSB-first: char nib muestra w[28-4*nib +:4];
                // (7-nib) = ~nib en 3 bits => desplazamiento {~nib, 2'b00}
                byte_at = hexc(w[{~nib, 2'b00} +: 4]);
            end
        end
    endfunction

    reg [31:0] period_cnt;
    reg [9:0]  baud_cnt;
    reg [3:0]  bit_idx;         // 0=start, 1-8=datos, 9=stop
    reg [7:0]  cur_byte;
    reg [6:0]  msg_idx;         // _161c: 66 chars ya no caben en 6 bits
    reg        sending;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx <= 1'b1;
            period_cnt <= 0; baud_cnt <= 0; bit_idx <= 0;
            msg_idx <= 0; sending <= 0; cur_byte <= 0;
            s_a <= 0; s_b <= 0; s_c <= 0; s_d <= 0; s_e <= 0; s_f <= 0; s_g <= 0;
        end
        else begin
            if (!sending) begin
                tx <= 1'b1;
                period_cnt <= period_cnt + 1;
                if (period_cnt >= TICKS) begin
                    period_cnt <= 0;
                    s_a <= cnt_a; s_b <= cnt_b; s_c <= cnt_c; s_d <= cnt_d; s_e <= cnt_e; s_f <= cnt_f;
                    s_g <= cnt_g;
                    msg_idx <= 0; bit_idx <= 0; baud_cnt <= 0;
                    sending <= 1;
                    cur_byte <= 8'h44;   // "D" (se recarga por byte_at igualmente)
                end
            end
            else begin
                baud_cnt <= baud_cnt + 1;
                if (baud_cnt == 0) begin
                    // emitir el bit actual
                    if (bit_idx == 0) begin
                        cur_byte <= byte_at(msg_idx);
                        tx <= 1'b0;                          // start
                    end
                    else if (bit_idx <= 8) tx <= cur_byte[bit_idx-1];
                    else tx <= 1'b1;                         // stop
                end
                if (baud_cnt == DIV[9:0] - 1) begin
                    baud_cnt <= 0;
                    if (bit_idx == 9) begin
                        bit_idx <= 0;
                        if (msg_idx == MSG_LEN-1) sending <= 0;
                        else msg_idx <= msg_idx + 1;
                    end
                    else bit_idx <= bit_idx + 1;
                end
            end
        end
    end

endmodule
