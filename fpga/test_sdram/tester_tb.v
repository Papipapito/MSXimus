// tester_tb.v — sanity del sdram_tester contra el modelo W9825 (Icarus)
`timescale 1ns/1ps

module tester_tb;

    reg clk108 = 0;
    always #4.63 clk108 = ~clk108;
    reg clk54 = 0;
    initial begin #4.63; forever begin clk54 = ~clk54; #9.26; end end

    reg rst_n = 0;

    wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
    wire [15:0] sd_dq;
    wire [12:0] sd_addr;
    wire [1:0]  sd_ba, sd_dqm;
    wire [1:0]  status;
    wire        pass_tick;
    wire [15:0] err_cpu, err_vram;

    sdram_tester #(.SWEEP_BITS(8), .INIT_CYCLES(25'd2000)) tester (
        .clk_108m(clk108), .clk_54m(clk54), .rst_n(rst_n),
        .O_sdram_clk(sd_clk), .O_sdram_cke(sd_cke), .O_sdram_cs_n(sd_cs_n),
        .O_sdram_cas_n(sd_cas_n), .O_sdram_ras_n(sd_ras_n), .O_sdram_wen_n(sd_wen_n),
        .IO_sdram_dq(sd_dq), .O_sdram_addr(sd_addr), .O_sdram_ba(sd_ba), .O_sdram_dqm(sd_dqm),
        .status(status), .pass_tick(pass_tick), .err_cpu(err_cpu), .err_vram(err_vram)
    );

    w9825_model sdram (
        .clk(sd_clk), .cke(sd_cke), .cs_n(sd_cs_n), .ras_n(sd_ras_n),
        .cas_n(sd_cas_n), .we_n(sd_wen_n), .addr(sd_addr), .ba(sd_ba),
        .dqm(sd_dqm), .dq(sd_dq)
    );

    // chivato EN el ciclo del check
    wire [16:0] chk_vaddr = {1'b0, 6'h15, tester.vidx};
    wire [12:0] chk_row = {2'b00, chk_vaddr[10:0]};
    wire [8:0]  chk_col = {3'b111, chk_vaddr[15:11], 1'b0};
    wire [23:0] chk_idx = {2'b11, chk_row, chk_col};
    always @(posedge clk54) begin
        if (tester.tst == 4'd11) begin   // T_VR_CHECK
            if (tester.vram_dout[7:0]  != tester.pat_vram({1'b0, chk_vaddr[15:0]}) ||
                tester.vram_dout[15:8] != tester.pat_vram({1'b1, chk_vaddr[15:0]}))
                $display("[CHK] vidx=%0d dout=%04x esp=%02x%02x model_mem=%04x t=%0t",
                         tester.vidx, tester.vram_dout,
                         tester.pat_vram({1'b1, chk_vaddr[15:0]}),
                         tester.pat_vram({1'b0, chk_vaddr[15:0]}),
                         sdram.mem[chk_idx], $time);
        end
    end

    integer guard;
    initial begin
        $display("=== tester_tb: sdram_tester vs modelo W9825 ===");
        rst_n = 0;
        repeat (40) @(posedge clk108);
        rst_n = 1;

        // acelerar el init del memory_ctrl (RstSeq via FreeCounter)
        while (tester.mem1.RstSeq !== 5'b11111) begin
            @(negedge clk108);
            force tester.mem1.FreeCounter = 16'hFFF0;
            @(negedge clk108);
            release tester.mem1.FreeCounter;
            repeat (90) @(posedge clk108);
        end

        // esperar veredicto (pass o fallo) con timeout
        guard = 0;
        while (status == 2'd0 && guard < 4000000) begin
            @(posedge clk54); guard = guard + 1;
        end

        $display("status=%0d err_cpu=%0d err_vram=%0d (guard=%0d)", status, err_cpu, err_vram, guard);
        if (status == 2'd1) $display("*** TESTER PASS ***");
        else                $display("*** TESTER FALLO/TIMEOUT ***");
        $finish;
    end

    initial begin
        #80_000_000;
        $display("TIMEOUT duro"); $finish;
    end

endmodule
