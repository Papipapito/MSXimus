// SN76489 PSG (SG-1000 / ColecoVision) — 3 canales cuadrados + 1 de ruido.
// Protocolo de escritura: byte con bit7=1 = LATCH (bits 6:5 canal, bit 4
// tipo: 1=atenuacion 0=tono, bits 3:0 = dato bajo); bit7=0 = dato alto del
// registro latcheado (6 bits). Reloj de tono = clk/16 con clk = 3.58 MHz.
// Salida: suma de los 4 canales atenuados, 14 bits con signo implicito 0..N.
module sn76489 (
    input  wire        clk,            // 27 MHz (dominio del bus)
    input  wire        clk_en_3m6,     // enable a 3.58 MHz (1 de cada ~7.5)
    input  wire        reset_n,
    input  wire        wr,             // strobe de escritura (1 ciclo de clk)
    input  wire [7:0]  din,
    output wire [13:0] sound           // mezcla sin signo (0 = silencio)
);

    // registros: tono 10 bits x3, ruido 3 bits, atenuacion 4 bits x4
    reg [9:0] tone0, tone1, tone2;
    reg [2:0] noise_ctl;
    reg [3:0] att0, att1, att2, att3;
    reg [2:0] latch_reg;                // registro latcheado (canal*2 + tipo)

    always @(posedge clk) begin
        if (reset_n == 0) begin
            tone0 <= 0; tone1 <= 0; tone2 <= 0;
            noise_ctl <= 0;
            att0 <= 4'hF; att1 <= 4'hF; att2 <= 4'hF; att3 <= 4'hF;  // mudo
            latch_reg <= 0;
        end
        else if (wr == 1) begin
            if (din[7] == 1) begin
                latch_reg <= din[6:4];
                case (din[6:4])
                    3'b000: tone0[3:0] <= din[3:0];
                    3'b001: att0 <= din[3:0];
                    3'b010: tone1[3:0] <= din[3:0];
                    3'b011: att1 <= din[3:0];
                    3'b100: tone2[3:0] <= din[3:0];
                    3'b101: att2 <= din[3:0];
                    3'b110: noise_ctl <= din[2:0];
                    3'b111: att3 <= din[3:0];
                endcase
            end
            else begin
                case (latch_reg)
                    3'b000: tone0[9:4] <= din[5:0];
                    3'b001: att0 <= din[3:0];
                    3'b010: tone1[9:4] <= din[5:0];
                    3'b011: att1 <= din[3:0];
                    3'b100: tone2[9:4] <= din[5:0];
                    3'b101: att2 <= din[3:0];
                    3'b110: noise_ctl <= din[2:0];
                    3'b111: att3 <= din[3:0];
                endcase
            end
        end
    end

    // divisor /16 sobre el enable de 3.58 MHz
    reg [3:0] div16;
    wire tick = (clk_en_3m6 == 1 && div16 == 0) ? 1 : 0;
    always @(posedge clk) begin
        if (reset_n == 0) div16 <= 0;
        else if (clk_en_3m6 == 1) div16 <= div16 + 1;
    end

    // contadores de tono (la salida conmuta al llegar a 0; periodo 0 = siempre alto)
    reg [9:0] cnt0, cnt1, cnt2;
    reg out0, out1, out2;
    always @(posedge clk) begin
        if (reset_n == 0) begin
            cnt0 <= 0; cnt1 <= 0; cnt2 <= 0;
            out0 <= 1; out1 <= 1; out2 <= 1;
        end
        else if (tick == 1) begin
            if (cnt0 <= 1) begin cnt0 <= tone0; out0 <= (tone0 <= 1) ? 1'b1 : ~out0; end
            else cnt0 <= cnt0 - 1;
            if (cnt1 <= 1) begin cnt1 <= tone1; out1 <= (tone1 <= 1) ? 1'b1 : ~out1; end
            else cnt1 <= cnt1 - 1;
            if (cnt2 <= 1) begin cnt2 <= tone2; out2 <= (tone2 <= 1) ? 1'b1 : ~out2; end
            else cnt2 <= cnt2 - 1;
        end
    end

    // ruido: LFSR 15 bits; ratio por noise_ctl[1:0] (16/32/64 o tono 2)
    reg [14:0] lfsr;
    reg [9:0] ncnt;
    reg nout;
    wire [9:0] nperiod = (noise_ctl[1:0] == 2'b00) ? 10'd16 :
                         (noise_ctl[1:0] == 2'b01) ? 10'd32 :
                         (noise_ctl[1:0] == 2'b10) ? 10'd64 : tone2;
    always @(posedge clk) begin
        if (reset_n == 0) begin
            lfsr <= 15'h4000;
            ncnt <= 0;
            nout <= 0;
        end
        else if (tick == 1) begin
            if (ncnt <= 1) begin
                ncnt <= nperiod;
                nout <= ~nout;
                if (nout == 0) begin    // shift en flanco de subida del divisor
                    // blanco (bit2=1): feedback bit0^bit3; periodico: bit0
                    lfsr <= { (noise_ctl[2] == 1) ? (lfsr[0] ^ lfsr[3]) : lfsr[0], lfsr[14:1] };
                end
            end
            else ncnt <= ncnt - 1;
        end
    end

    // tabla de atenuacion 2 dB por paso (12 bits por canal)
    function [11:0] att_vol;
        input [3:0] att;
        input level;
        begin
            if (level == 0) att_vol = 0;
            else case (att)
                4'h0: att_vol = 12'd4095; 4'h1: att_vol = 12'd3254;
                4'h2: att_vol = 12'd2584; 4'h3: att_vol = 12'd2053;
                4'h4: att_vol = 12'd1631; 4'h5: att_vol = 12'd1295;
                4'h6: att_vol = 12'd1029; 4'h7: att_vol = 12'd817;
                4'h8: att_vol = 12'd649;  4'h9: att_vol = 12'd516;
                4'hA: att_vol = 12'd410;  4'hB: att_vol = 12'd325;
                4'hC: att_vol = 12'd258;  4'hD: att_vol = 12'd205;
                4'hE: att_vol = 12'd163;  4'hF: att_vol = 12'd0;
            endcase
        end
    endfunction

    assign sound = {2'b00, att_vol(att0, out0)} + {2'b00, att_vol(att1, out1)} +
                   {2'b00, att_vol(att2, out2)} + {2'b00, att_vol(att3, lfsr[0])};

endmodule
