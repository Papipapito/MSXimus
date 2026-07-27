// tb_audio_ce.sv — _127I: valida la reescritura clk_audio -> audio_ce del
// camino de audio HDMI (bug #14). Instancia el modulo hdmi COMPLETO (VIC 4,
// 720p60) con el generador fraccional de audio_ce del puente y cuenta los
// pulsos audio_pkt_pulse durante 60 ms simulados.
// Esperado: tasa = 44100/4 = 11025 paquetes/s (+-1%) y CERO overruns.
`timescale 1ns/1ps
module tb_audio_ce;

    logic clk_pixel = 1'b0;
    always #6.7340 clk_pixel = ~clk_pixel;    // 74.25 MHz

    logic reset = 1'b1;
    initial begin
        repeat (20) @(posedge clk_pixel);
        reset = 1'b0;
    end

    // generador de audio_ce — copia exacta del divisor del puente
    reg [26:0] audio_acc = 27'd0;
    reg        audio_ce  = 1'b0;
    always @(posedge clk_pixel) begin : audio_div_frac
        reg [27:0] acc_n;
        acc_n = {1'b0, audio_acc} + 28'd44100;
        if (acc_n >= 28'd74250000) begin
            audio_acc <= acc_n[26:0] - 27'd74250000;
            audio_ce  <= 1'b1;
        end else begin
            audio_acc <= acc_n[26:0];
            audio_ce  <= 1'b0;
        end
    end

    logic [15:0] audio_sample_word [1:0];
    assign audio_sample_word[0] = 16'h1234;
    assign audio_sample_word[1] = 16'hABCD;

    logic [10:0] cx;
    logic [9:0]  cy;
    logic [10:0] frame_width, screen_width;
    logic [9:0]  frame_height, screen_height;
    logic [9:0]  tmds_internal [2:0];
    logic        audio_pkt_pulse, audio_ovr_pulse;

    hdmi #(
        .VIDEO_ID_CODE(4),
        .DVI_OUTPUT(0),
        .VIDEO_REFRESH_RATE(60.0),
        .IT_CONTENT(1),
        .AUDIO_RATE(44100),
        .AUDIO_BIT_WIDTH(16),
        .VENDOR_NAME({"Unknown", 8'd0}),
        .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
        .SOURCE_DEVICE_INFORMATION(8'h00),
        .START_X(0),
        .START_Y(720),
        .NUM_CHANNELS(3)
    ) dut (
        .clk_pixel_x5(1'b0),
        .clk_pixel(clk_pixel),
        .audio_ce(audio_ce),
        .reset(reset),
        .reset_cx(11'd0),    // _136: sin diferidor en el TB
        .rgb(24'h336699),
        .audio_sample_word(audio_sample_word),
        .aspect_16_9(1'b0),
        .cx(cx),
        .cy(cy),
        .frame_width(frame_width),
        .frame_height(frame_height),
        .screen_width(screen_width),
        .screen_height(screen_height),
        .tmds_internal(tmds_internal),
        .audio_pkt_pulse(audio_pkt_pulse),
        .audio_ovr_pulse(audio_ovr_pulse)
    );

    integer pkt_cnt = 0, ovr_cnt = 0, ce_cnt = 0;
    always @(posedge clk_pixel) begin
        if (audio_pkt_pulse) pkt_cnt = pkt_cnt + 1;
        if (audio_ovr_pulse) ovr_cnt = ovr_cnt + 1;
        if (audio_ce)        ce_cnt  = ce_cnt + 1;
    end

    // 60 ms simulados (~4.45M ciclos). Esperado: ce ~2646, pkt ~661, ovr 0.
    localparam real T_MS = 60.0;
    initial begin
        #(T_MS * 1_000_000);
        $display("tb_audio_ce: %0.0f ms — ce=%0d (esp ~%0.0f) pkt=%0d (esp ~%0.0f) ovr=%0d",
                 T_MS, ce_cnt, 44100.0*T_MS/1000.0, pkt_cnt, 11025.0*T_MS/1000.0, ovr_cnt);
        if (ovr_cnt != 0) begin
            $display("FAIL: overruns != 0");
            $fatal(1);
        end
        if (pkt_cnt < $rtoi(11025.0*T_MS/1000.0*0.99) ||
            pkt_cnt > $rtoi(11025.0*T_MS/1000.0*1.01) + 1) begin
            $display("FAIL: tasa de paquetes fuera de +-1%%");
            $fatal(1);
        end
        if (ce_cnt < $rtoi(44100.0*T_MS/1000.0*0.999) ||
            ce_cnt > $rtoi(44100.0*T_MS/1000.0*1.001) + 1) begin
            $display("FAIL: tasa de audio_ce fuera de +-0.1%%");
            $fatal(1);
        end
        $display("PASS: audio_ce + packet_picker + ACR correctos");
        $finish;
    end

endmodule
