// =============================================================================
//  ws2812.v  —  WS2812B / SK6812 addressable-LED chain driver
//  One data pin drives a whole chain (e.g. CJMCU-2812-8 = 8 LEDs).
//  `rgb` is NUM_LEDS*24 bits: {LED0[23:0], LED1[23:0], ...}, each colour in
//  GRB order (WS2812 wire order), MSB first. LED0 = first in chain (DIN side).
//  Continuously refreshes the chain (latches a fresh `rgb` each frame).
// =============================================================================
module ws2812 #(
    parameter NUM_LEDS = 8,
    parameter CLK_FRE  = 27            // clk frequency in MHz (drives bit timing)
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [NUM_LEDS*24-1:0] rgb,
    output reg                    dout
);
    localparam integer BITS  = NUM_LEDS*24;
    localparam integer T_PER = (CLK_FRE*1250)/1000;  // 1.25us bit period
    localparam integer T0H   = (CLK_FRE*350)/1000;   // ~0.35us high  -> '0'
    localparam integer T1H   = (CLK_FRE*800)/1000;   // ~0.80us high  -> '1'
    localparam integer T_RST = CLK_FRE*60;           // ~60us low      -> latch/reset

    localparam S_RESET = 1'b0, S_SEND = 1'b1;
    reg            state;
    reg [BITS-1:0] shifter;
    reg [8:0]      bitcnt;
    reg [15:0]     cyc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_RESET;
            dout    <= 1'b0;
            cyc     <= 16'd0;
            bitcnt  <= 9'd0;
            shifter <= {BITS{1'b0}};
        end else begin
            case (state)
                S_RESET: begin
                    dout <= 1'b0;
                    if (cyc >= T_RST-1) begin
                        cyc     <= 16'd0;
                        shifter <= rgb;          // latch a fresh frame
                        bitcnt  <= BITS[8:0];
                        state   <= S_SEND;
                    end else cyc <= cyc + 16'd1;
                end
                S_SEND: begin
                    dout <= (cyc < (shifter[BITS-1] ? T1H : T0H)) ? 1'b1 : 1'b0;
                    if (cyc >= T_PER-1) begin
                        cyc     <= 16'd0;
                        shifter <= {shifter[BITS-2:0], 1'b0};
                        bitcnt  <= bitcnt - 9'd1;
                        if (bitcnt <= 9'd1) state <= S_RESET;
                    end else cyc <= cyc + 16'd1;
                end
            endcase
        end
    end
endmodule

// Activity stretcher: holds `active` high for ~HOLD clocks after `trig`,
// so brief events (disk access, keypress, WiFi byte) are visible on a LED.
module led_stretch #(parameter integer HOLD = 1350000)(
    input  wire clk,
    input  wire rst_n,
    input  wire trig,
    output wire active
);
    reg [20:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        cnt <= 21'd0;
        else if (trig)     cnt <= HOLD[20:0];
        else if (cnt != 0) cnt <= cnt - 21'd1;
    end
    assign active = (cnt != 21'd0);
endmodule
