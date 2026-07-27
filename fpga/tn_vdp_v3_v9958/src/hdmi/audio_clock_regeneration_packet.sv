// Implementation of HDMI audio clock regeneration packet
// By Sameer Puri https://github.com/sameer

// See HDMI 1.4b Section 5.3.3
module audio_clock_regeneration_packet
#(
    parameter real VIDEO_RATE = 25.2E6,
    parameter int AUDIO_RATE = 48e3
)
(
    input logic clk_pixel,
    // _127I (bug #14): clk_audio ERA un reloj de fabric (registro-divisor) —
    // Gowin lo rutaba por recursos genericos (PR1014, "excessive delay or
    // skew") y el skew intra-dominio podia corromper el contador => CTS
    // basura => el receptor re-engancha su PLL de audio a trompicones.
    // Ahora es un clock-enable de 1 ciclo @fs, sincrono a clk_pixel.
    input logic audio_ce,
    output logic clk_audio_counter_wrap = 0,
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);

// See Section 7.2.3, values derived from "Other" row in Tables 7-1, 7-2, 7-3.
//localparam bit [19:0] N = AUDIO_RATE % 125 == 0 ? 20'(16 * AUDIO_RATE / 125) : AUDIO_RATE % 225 == 0 ? 20'(196 * AUDIO_RATE / 225) : 20'(AUDIO_RATE * 16 / 125);
localparam bit [19:0] N = AUDIO_RATE % 125 == 0 ? 20'(16 * AUDIO_RATE / 125) : AUDIO_RATE % 225 == 0 ? 20'(32 * AUDIO_RATE / 225) : 20'(AUDIO_RATE * 16 / 125);

localparam int CLK_AUDIO_COUNTER_WIDTH = $clog2(N / 128);
localparam bit [CLK_AUDIO_COUNTER_WIDTH-1:0] CLK_AUDIO_COUNTER_END = CLK_AUDIO_COUNTER_WIDTH'(N / 128 - 1);
logic [CLK_AUDIO_COUNTER_WIDTH-1:0] clk_audio_counter = CLK_AUDIO_COUNTER_WIDTH'(0);
logic internal_clk_audio_counter_wrap = 1'd0;
always_ff @(posedge clk_pixel)
begin
    if (audio_ce)
    begin
        if (clk_audio_counter == CLK_AUDIO_COUNTER_END)
        begin
            clk_audio_counter <= CLK_AUDIO_COUNTER_WIDTH'(0);
            internal_clk_audio_counter_wrap <= !internal_clk_audio_counter_wrap;
        end
        else
            clk_audio_counter <= clk_audio_counter + 1'd1;
    end
end

logic [1:0] clk_audio_counter_wrap_synchronizer_chain = 2'd0;
always_ff @(posedge clk_pixel)
    clk_audio_counter_wrap_synchronizer_chain <= {internal_clk_audio_counter_wrap, clk_audio_counter_wrap_synchronizer_chain[1]};

// _127I: declaraciones como int con paso intermedio entero (mismo valor,
// 82500 para 44.1k/74.25M); el original bit[19:0] + int'(N) + real'()
// rompia el constant-folding de Verilator 5.020.
localparam int SAMPLES_PER_WRAP = N / 128;
localparam int CYCLE_TIME_STAMP_COUNTER_IDEAL = int'(VIDEO_RATE * SAMPLES_PER_WRAP / AUDIO_RATE);
localparam int CYCLE_TIME_STAMP_COUNTER_WIDTH = $clog2(int'(VIDEO_RATE * SAMPLES_PER_WRAP / AUDIO_RATE * 1.1)); // Account for 10% deviation in audio clock

logic [19:0] cycle_time_stamp = 20'd0;
logic [CYCLE_TIME_STAMP_COUNTER_WIDTH-1:0] cycle_time_stamp_counter = CYCLE_TIME_STAMP_COUNTER_WIDTH'(0);
always_ff @(posedge clk_pixel)
begin
    if (clk_audio_counter_wrap_synchronizer_chain[1] ^ clk_audio_counter_wrap_synchronizer_chain[0])
    begin
        cycle_time_stamp_counter <= CYCLE_TIME_STAMP_COUNTER_WIDTH'(0);
        cycle_time_stamp <= {(20-CYCLE_TIME_STAMP_COUNTER_WIDTH)'(0), cycle_time_stamp_counter + CYCLE_TIME_STAMP_COUNTER_WIDTH'(1)};
        clk_audio_counter_wrap <= !clk_audio_counter_wrap;
    end
    else
        cycle_time_stamp_counter <= cycle_time_stamp_counter + CYCLE_TIME_STAMP_COUNTER_WIDTH'(1);
end

// "An HDMI Sink shall ignore bytes HB1 and HB2 of the Audio Clock Regeneration Packet header."
`ifdef MODEL_TECH
assign header = {8'd0, 8'd0, 8'd1};
`else
assign header = {8'dX, 8'dX, 8'd1};
`endif

// "The four Subpackets each contain the same Audio Clock regeneration Subpacket."
genvar i;
generate
    for (i = 0; i < 4; i++)
    begin: same_packet
        assign sub[i] = {N[7:0], N[15:8], {4'd0, N[19:16]}, cycle_time_stamp[7:0], cycle_time_stamp[15:8], {4'd0, cycle_time_stamp[19:16]}, 8'd0};
    end
endgenerate

endmodule
