// ============================================================================
// tb_yrw801.v — el motor PCM con la YRW801 REAL: valida el formato 12-bit
// (la onda 0/303 del banco) contra un modelo dorado en python.
// Secuencia identica al test 4 del opl4test.rom pero con la onda elegible.
// ============================================================================
`timescale 1ns/1ps

module tb_yrw801;

reg clk_x1 = 0;
always #6.734 clk_x1 = ~clk_x1;
reg clk_eng = 0;
always @(posedge clk_x1) clk_eng = ~clk_eng;
reg clk_host = 0;
always #9.26 clk_host = ~clk_host;

reg rst_n = 0, eng_rst_n = 0;

reg iorq_n = 1, rd_n = 1, wr_n = 1, m1_n = 1;
reg [7:0] a = 0, din = 0;
wire wave_rd;
wire [7:0] wave_dout;
wire wave_wait_n;
wire [1:0] wave_status;
wire signed [15:0] pcm_l, pcm_r;

wire        mem_req, mem_we;
wire [21:0] mem_addr;
wire [7:0]  mem_wdata;
reg  [7:0]  mem_rdata = 0;
reg  [127:0] mem_rline = 0;
reg         mem_done_t = 0;

// parametros de la nota (plusargs)
reg [15:0] WAVEN = 303;
reg [15:0] FNUM = 0;
reg [7:0]  OCT = 1;
integer NSAMP = 600;

opl4_pcm dut (
    .rst_n(rst_n), .clk_host(clk_host),
    .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
    .addr(a), .din(din),
    .wave_rd(wave_rd), .wave_dout(wave_dout), .wave_wait_n(wave_wait_n),
    .wave_status(wave_status),
    .pcm_l(pcm_l), .pcm_r(pcm_r),
    .clk_eng(clk_eng), .eng_rst_n(eng_rst_n),
    .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
    .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_rline(mem_rline), .mem_done_t(mem_done_t)
);

// memoria con la YRW801 real + latencia DDR3
reg [7:0] wavemem [0:4194303];
reg        p_pend = 0, p_we;
reg [21:0] p_addr;
reg [7:0]  p_dat;
reg [5:0]  p_cnt, p_lat;
integer    li;
reg mem_req_d = 0;
always @(posedge clk_x1) begin
    mem_req_d <= mem_req;
    if (mem_req && !mem_req_d) begin
        p_pend <= 1; p_we <= mem_we; p_addr <= mem_addr; p_dat <= mem_wdata;
        p_cnt <= 0; p_lat <= 6'd20 + ({$random} % 5);
    end
    else if (p_pend) begin
        p_cnt <= p_cnt + 1;
        if (p_cnt == p_lat) begin
            if (p_we) wavemem[p_addr] <= p_dat;
            else begin
                mem_rdata <= wavemem[p_addr];
                for (li = 0; li < 16; li = li + 1)
                    mem_rline[li*8 +: 8] <= wavemem[{p_addr[21:4], 4'b0000} + li];
            end
            mem_done_t <= ~mem_done_t;
            p_pend <= 0;
        end
    end
end

task outp(input [7:0] p, input [7:0] v);
begin
    @(negedge clk_host); a = p; din = v; iorq_n = 0; wr_n = 0;
    #420; @(negedge clk_host); wr_n = 1; iorq_n = 1;
    #2500;
end
endtask

reg [7:0] rdv;
task inp(input [7:0] p);
begin
    @(negedge clk_host); a = p; iorq_n = 0; rd_n = 0;
    #460;
    while (!wave_wait_n) @(posedge clk_host);
    #5; rdv = wave_dout;
    #80; @(negedge clk_host); rd_n = 1; iorq_n = 1;
    #1500;
end
endtask

task wreg(input [7:0] r, input [7:0] v);
begin outp(8'h7E, r); outp(8'h7F, v); end
endtask

// volcado de muestras
integer fd, n = 0, i;
reg pcm_seen = 0;
always @(posedge clk_host) begin
    pcm_seen <= dut.pcm_h3;
    if (dut.pcm_h3 !== pcm_seen && n < NSAMP) begin
        $fdisplay(fd, "%0d", pcm_l);
        n = n + 1;
        if (n == NSAMP) begin
            $display("VOLCADAS %0d muestras", n);
            $finish;
        end
    end
end

initial begin
    if (!$value$plusargs("wave=%d", WAVEN)) WAVEN = 303;
    if (!$value$plusargs("fnum=%d", FNUM)) FNUM = 0;
    if (!$value$plusargs("oct=%d", OCT)) OCT = 1;
    if (!$value$plusargs("nsamp=%d", NSAMP)) NSAMP = 600;
    fd = $fopen("pcm_dump.txt", "w");
    $readmemh("yrw801_2m.hex", wavemem);
    #500  rst_n = 1;
    #1000 eng_rst_n = 1;
    #60000;   // dejar acabar el BARRIDO de reset del motor (768 CE ~ 23us):
              // durante RST=1 las RAMs FNUM/LEVEL/PAN se estan barriendo a 0
              // y las escrituras CPU se pierden (en HW nunca pasa: el reset
              // se suelta ~7s antes de que el software escriba nada)
    outp(8'hC6, 8'h05);
    outp(8'hC7, 8'h03);                       // NEW/NEW2
    wreg(8'h20, (FNUM[6:0]<<1) | WAVEN[8]);   // FNUM low / WTN8
    wreg(8'h38, (OCT[3:0]<<4) | (FNUM[9:7]<<1));
    wreg(8'h50, 8'h01);                       // TL=0, LD
    wreg(8'h08, WAVEN[7:0]);                  // dispara header load
    i = 0;
    inp(8'hC4); inp(8'h7E);
    while (rdv[1] && i < 200) begin
        #10000; inp(8'hC4); inp(8'h7E); i = i + 1;
    end
    $display("LD limpio tras %0d polls", i);
    wreg(8'h68, 8'h80);                       // KEY on
    // +6 slots mas (carga de 7 slots, como The Entertainer)
    for (i = 1; i < 7; i = i + 1) begin
        wreg(8'h20 + i[7:0], 8'h01);
        wreg(8'h38 + i[7:0], 8'h10);
        wreg(8'h50 + i[7:0], 8'h01);
        wreg(8'h08 + i[7:0], 8'h2F);
        inp(8'hC4); inp(8'h7E);
        while (rdv[1]) begin #10000; inp(8'hC4); inp(8'h7E); end
        wreg(8'h68 + i[7:0], 8'h80);
    end
end

initial begin
    #80000000;  // 80ms guardia
    $display("TIMEOUT con %0d muestras", n);
    $finish;
end

endmodule
