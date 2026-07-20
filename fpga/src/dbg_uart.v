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
    output reg         tx
);

    localparam integer DIV = CLK_HZ / BAUD;             // ~469
    localparam integer TICKS = (CLK_HZ / 1000) * PERIOD_MS;

    // snapshot de los contadores (cuasi-estaticos)
    reg [31:0] s_a, s_b, s_c, s_d;

    // mensaje: "D aaaaaaaa bbbbbbbb cccccccc dddddddd\r\n" = 39 chars
    localparam MSG_LEN = 39;
    reg [7:0] msg [0:MSG_LEN-1];

    function [7:0] hexc(input [3:0] v);
        hexc = (v < 10) ? ("0" + {4'd0, v}) : ("a" + {4'd0, v} - 8'd10);
    endfunction

    integer i;
    task build_msg;
        begin
            msg[0] = "D"; msg[1] = " ";
            for (i = 0; i < 8; i = i + 1) msg[2+i]  = hexc(s_a[28-4*i +: 4]);
            msg[10] = " ";
            for (i = 0; i < 8; i = i + 1) msg[11+i] = hexc(s_b[28-4*i +: 4]);
            msg[19] = " ";
            for (i = 0; i < 8; i = i + 1) msg[20+i] = hexc(s_c[28-4*i +: 4]);
            msg[28] = " ";
            for (i = 0; i < 8; i = i + 1) msg[29+i] = hexc(s_d[28-4*i +: 4]);
            msg[37] = 8'h0D; msg[38] = 8'h0A;
        end
    endtask

    reg [31:0] period_cnt;
    reg [9:0]  baud_cnt;
    reg [3:0]  bit_idx;         // 0=start, 1-8=datos, 9=stop
    reg [7:0]  cur_byte;
    reg [5:0]  msg_idx;         // _123: 39 chars ya no caben en 5 bits
    reg        sending;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx <= 1'b1;
            period_cnt <= 0; baud_cnt <= 0; bit_idx <= 0;
            msg_idx <= 0; sending <= 0; cur_byte <= 0;
            s_a <= 0; s_b <= 0; s_c <= 0; s_d <= 0;
        end
        else begin
            if (!sending) begin
                tx <= 1'b1;
                period_cnt <= period_cnt + 1;
                if (period_cnt >= TICKS) begin
                    period_cnt <= 0;
                    s_a <= cnt_a; s_b <= cnt_b; s_c <= cnt_c; s_d <= cnt_d;
                    build_msg;
                    msg_idx <= 0; bit_idx <= 0; baud_cnt <= 0;
                    sending <= 1;
                    cur_byte <= 8'h44;   // "D" (se recarga por msg_idx igualmente)
                end
            end
            else begin
                baud_cnt <= baud_cnt + 1;
                if (baud_cnt == 0) begin
                    // emitir el bit actual
                    if (bit_idx == 0) begin
                        cur_byte <= msg[msg_idx];
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
