`timescale 1ns/1ps
// tb_cfgreg.sv - V3.7.5: las escrituras a los puertos de config (#40-#43, #45, #46) y al mapper (FC-FF) con y sin
// la etapa de registro (cfgN_req_r / mreg_*_r). Ciclos OUT realistas: IORQ_n bajo 15..24 ciclos de 27 MHz, pulsos
// de clk_enable_3m6_27 cada 7 u 8 ciclos (3,58 MHz), fase aleatoria, dato y direccion estables alrededor del OUT.
// Tras cada OUT se comparan los registros de las dos versiones y el numero de pulsos de update/flash/reset.
module blocks #(parameter NEW = 0) (
    input clk, input en, input rst_n,
    input [7:0] addr, input iorq_n, input wr_n, input m1_n, input [7:0] dout, input config_ok,
    output reg [7:0] config0_ff, config1_temp_ff, config3_ff, config6_ff,
    output reg [5:0] config2_temp_ff,
    output reg config1_update, config2_update, config_flash_write_ff, config_reset_ff, turbo_boot,
    output reg [7:0] m0, m1, m2, m3
);
    wire config0_req = (addr == 8'h40 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire config1_req = (config_ok && addr == 8'h41 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire config2_req = (config_ok && addr == 8'h42 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire config3_req = (config_ok && addr == 8'h43 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire config5_req = (config_ok && addr == 8'h45 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire config6_req = (config_ok && addr == 8'h46 && iorq_n == 0 && m1_n == 1 && wr_n == 0);
    wire mapper_reg_write = (iorq_n == 0 && m1_n == 1 && wr_n == 0) && (addr[7:2] == 6'b111111);

    reg c0 = 0, c1 = 0, c2 = 0, c3 = 0, c5 = 0, c6 = 0, mw = 0; reg [7:0] d = 0; reg [1:0] ma = 0; reg [7:0] md = 0;
    always @(posedge clk) begin
        c0 <= config0_req; c1 <= config1_req; c2 <= config2_req; c3 <= config3_req; c5 <= config5_req;
        c6 <= config6_req; d <= dout; mw <= mapper_reg_write; ma <= addr[1:0]; md <= dout;
    end
    wire q0 = NEW ? c0 : config0_req, q1 = NEW ? c1 : config1_req, q2 = NEW ? c2 : config2_req;
    wire q3 = NEW ? c3 : config3_req, q5 = NEW ? c5 : config5_req, q6 = NEW ? c6 : config6_req;
    wire [7:0] qd = NEW ? d : dout;
    wire qmw = NEW ? mw : mapper_reg_write; wire [1:0] qma = NEW ? ma : addr[1:0]; wire [7:0] qmd = NEW ? md : dout;

    initial begin config0_ff = 0; config1_temp_ff = 0; config3_ff = 0; config6_ff = 0; config2_temp_ff = 0;
                  turbo_boot = 0; config1_update = 0; config2_update = 0; config_flash_write_ff = 0;
                  config_reset_ff = 0; end
    always @(posedge clk) begin
        config_reset_ff <= 0; config_flash_write_ff <= 0; config1_update <= 0; config2_update <= 0;
        if (en) begin
            if (q0) config0_ff <= ~qd;
            if (q1) begin config1_update <= 1; config1_temp_ff <= qd; end
            if (q3) config3_ff <= qd;
            if (q6) config6_ff <= qd;
            if (q2) begin
                config2_update <= 1; config2_temp_ff <= qd[5:0];
                if (qd[6]) config_flash_write_ff <= 1;
                if (qd[7]) config_reset_ff <= 1;
            end
        end
        if (q5) turbo_boot <= qd[0];
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin m0 <= 8'd3; m1 <= 8'd2; m2 <= 8'd1; m3 <= 8'd0; end
        else if (qmw) case (qma) 2'd0: m0 <= qmd; 2'd1: m1 <= qmd; 2'd2: m2 <= qmd; 2'd3: m3 <= qmd; endcase
    end
endmodule

module tb_cfgreg;
    reg clk = 0; always #18.519 clk = ~clk;                 // 27 MHz
    reg en = 0; integer ph = 0, per = 7;
    always @(posedge clk) begin                              // un pulso cada 7 u 8 ciclos (27 / 3,58 = 7,54)
        ph = ph + 1;
        if (ph >= per) begin ph = 0; per = (per == 7) ? 8 : 7; en <= 1; end else en <= 0;
    end
    reg rst_n = 0; reg [7:0] addr = 0, dout = 0; reg iorq_n = 1, wr_n = 1, m1_n = 1, config_ok = 1;
    wire [7:0] a0, a1t, a3, a6, b0, b1t, b3, b6, am0, am1, am2, am3, bm0, bm1, bm2, bm3; wire [5:0] a2t, b2t;
    wire a1u, a2u, afw, arst, atb, b1u, b2u, bfw, brst, btb;
    blocks #(0) O (clk, en, rst_n, addr, iorq_n, wr_n, m1_n, dout, config_ok, a0, a1t, a3, a6, a2t, a1u, a2u, afw, arst, atb, am0, am1, am2, am3);
    blocks #(1) N (clk, en, rst_n, addr, iorq_n, wr_n, m1_n, dout, config_ok, b0, b1t, b3, b6, b2t, b1u, b2u, bfw, brst, btb, bm0, bm1, bm2, bm3);

    integer na1u = 0, na2u = 0, nafw = 0, narst = 0, nb1u = 0, nb2u = 0, nbfw = 0, nbrst = 0;
    always @(posedge clk) if (rst_n) begin
        na1u = na1u + a1u; na2u = na2u + a2u; nafw = nafw + afw; narst = narst + arst;
        nb1u = nb1u + b1u; nb2u = nb2u + b2u; nbfw = nbfw + bfw; nbrst = nbrst + brst;
    end

    integer i, k, len, fails = 0, nvar = 0, seed = 29092026;
    integer pa1u = 0, pa2u = 0, pafw = 0, parst = 0, pb1u = 0, pb2u = 0, pbfw = 0, pbrst = 0;
    reg [7:0] ports [0:10];
    initial begin
        ports[0] = 8'h40; ports[1] = 8'h41; ports[2] = 8'h42; ports[3] = 8'h43; ports[4] = 8'h45; ports[5] = 8'h46;
        ports[6] = 8'hFC; ports[7] = 8'hFD; ports[8] = 8'hFE; ports[9] = 8'hFF; ports[10] = 8'h98;   // 98 = ajeno
        repeat (5) @(posedge clk); rst_n = 1;
        for (i = 0; i < 20000; i = i + 1) begin
            k = $urandom(seed) % 11;
            repeat ($urandom % 40 + 20) @(posedge clk);       // entre OUTs (y fase aleatoria frente a en)
            #($urandom % 37);
            addr = ports[k]; dout = $urandom; wr_n = 0;       // T1: direccion y dato
            #(280);                                           // ~1 T-estado despues, IORQ_n baja (T2)
            iorq_n = 0;
            len = $urandom % 10 + 15;                         // 15..24 ciclos de 27 MHz (T2..T3 + Tw)
            repeat (len) @(posedge clk);
            #($urandom % 37);
            iorq_n = 1; wr_n = 1;
            #(140);                                           // el dato se aguanta medio T tras IORQ_n
            dout = $urandom;                                  // y luego cambia (siguiente ciclo del Z80)
            repeat (6) @(posedge clk);
            if ({a0, a1t, a2t, a3, a6, atb, am0, am1, am2, am3} !== {b0, b1t, b2t, b3, b6, btb, bm0, bm1, bm2, bm3}) begin
                fails = fails + 1;
                if (fails < 6) $display("DIFF OUT %02x: viejo %02x %02x %02x %02x %02x %b | %02x %02x %02x %02x  nuevo %02x %02x %02x %02x %02x %b | %02x %02x %02x %02x",
                    ports[k], a0, a1t, a2t, a3, a6, atb, am0, am1, am2, am3, b0, b1t, b2t, b3, b6, btb, bm0, bm1, bm2, bm3);
            end
            // los pulsos: por OUT, la version vieja y la nueva han de dar ALGUNO o NINGUNO a la vez (el numero puede
            // variar en uno si un pulso de clk_enable cae en el borde de la ventana: el update es idempotente y la
            // escritura en flash y el reset ya recibian 1-2 pulsos por OUT con el codigo viejo)
            if (((na1u > pa1u) != (nb1u > pb1u)) || ((na2u > pa2u) != (nb2u > pb2u)) ||
                ((nafw > pafw) != (nbfw > pbfw)) || ((narst > parst) != (nbrst > pbrst))) begin
                fails = fails + 1;
                if (fails < 6) $display("DIFF pulsos OUT %02x dato %02x: update1 %0d/%0d update2 %0d/%0d flash %0d/%0d reset %0d/%0d",
                    ports[k], dout, na1u - pa1u, nb1u - pb1u, na2u - pa2u, nb2u - pb2u, nafw - pafw, nbfw - pbfw, narst - parst, nbrst - pbrst);
            end
            if (na2u - pa2u != nb2u - pb2u) nvar = nvar + 1;
            pa1u = na1u; pa2u = na2u; pafw = nafw; parst = narst; pb1u = nb1u; pb2u = nb2u; pbfw = nbfw; pbrst = nbrst;
        end
        $display("tb_cfgreg: 20000 OUT, %0d diferencias; OUT con distinto NUMERO de pulsos de update2 (solo informativo): %0d", fails, nvar);
        if (fails == 0) $display("RESULTADO OK"); else $display("RESULTADO FAIL");
        $finish;
    end
endmodule
