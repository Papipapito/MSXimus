// tb_bridge.sv — unit test del CDC v9968_sdram_bridge (85.909 <-> 108 MHz).
// _148 FIX B: ahora prueba LOS DOS MODOS con el MISMO estimulo:
//   dutW  NARROW_BYTE=0 (camino DDR3): la palabra de 32b + mascara cruzan
//         enteras -> UNA op far. El modelo far escribe por mascara.
//   dutN  NARROW_BYTE=1, FAR_DW=8 (camino legacy memory.v): el bridge
//         SERIALIZA la palabra en hasta 4 ops de byte y solo entonces devuelve
//         bk_done_t. El modelo far escribe 1 byte por op (como memory.v).
// 200 ops aleatorias con MASCARAS PARCIALES (incluida 1-hot de CPU): ambos
// caminos tienen que dejar la memoria BYTE A BYTE identica al modelo dorado, y
// NINGUNO puede tocar un byte no habilitado (la memoria se pre-carga con un
// patron distintivo y se comprueba entera al final).
`timescale 1ns/1ps

module tb_bridge;

logic clk_vdp = 0, clk_108 = 0, rst_n = 0;
always #5.8207 clk_vdp = ~clk_vdp;   // 85.909 MHz
always #4.6296 clk_108 = ~clk_108;   // 108 MHz

logic        bk_req = 0, bk_we = 0;
logic [21:0] bk_addr = 0;
logic [31:0] bk_wdata = 0;
logic [3:0]  bk_wmask = 0;

// ---------------- DUT A: modo PALABRA (DDR3) ----------------
wire  [15:0] bkW_rword;   wire bkW_done_t;
wire         wvW_req, wvW_we;
wire  [21:0] wvW_addr;
wire  [31:0] wvW_wdata;
wire  [3:0]  wvW_wmask;
logic [15:0] wvW_dout = 0;
logic        wvW_done = 0;

v9968_sdram_bridge #(.NARROW_BYTE(0), .FAR_DW(32)) dutW (
    .clk_vdp(clk_vdp), .rst_n(rst_n),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr),
    .bk_wdata(bk_wdata), .bk_wmask(bk_wmask),
    .bk_rword(bkW_rword), .bk_done_t(bkW_done_t),
    .clk_108m(clk_108),
    .wv2_req(wvW_req), .wv2_we(wvW_we), .wv2_addr(wvW_addr),
    .wv2_wdata(wvW_wdata), .wv2_wmask(wvW_wmask),
    .wv2_dout(wvW_dout), .wv2_done(wvW_done)
);

// ---------------- DUT B: modo BYTE serializado (legacy) ----------------
wire  [15:0] bkN_rword;   wire bkN_done_t;
wire         wvN_req, wvN_we;
wire  [21:0] wvN_addr;
wire  [7:0]  wvN_wdata;
logic [15:0] wvN_dout = 0;
logic        wvN_done = 0;

v9968_sdram_bridge #(.NARROW_BYTE(1), .FAR_DW(8)) dutN (
    .clk_vdp(clk_vdp), .rst_n(rst_n),
    .bk_req(bk_req), .bk_we(bk_we), .bk_addr(bk_addr),
    .bk_wdata(bk_wdata), .bk_wmask(bk_wmask),
    .bk_rword(bkN_rword), .bk_done_t(bkN_done_t),
    .clk_108m(clk_108),
    .wv2_req(wvN_req), .wv2_we(wvN_we), .wv2_addr(wvN_addr),
    .wv2_wdata(wvN_wdata), .wv2_wmask(),
    .wv2_dout(wvN_dout), .wv2_done(wvN_done)
);

// ---------------- modelos far (emulan memory.v) ----------------
localparam integer MEMSZ = 262144;         // ventana de prueba
logic [7:0] memW [0:MEMSZ-1];
logic [7:0] memN [0:MEMSZ-1];
logic [7:0] memG [0:MEMSZ-1];              // dorada (referencia)
integer nopsW = 0, nopsN = 0;              // ops far servidas (word vs byte)

integer latW; logic busyW = 0, inflW = 0;
always @(posedge clk_108) begin
    wvW_done <= 0;
    if (inflW && !wvW_req) inflW <= 0;
    if (wvW_req && !busyW && !inflW) begin
        busyW <= 1; inflW <= 1; latW <= 5 + ({$random} % 40);
    end
    else if (busyW) begin
        if (latW == 0) begin
            if (wvW_we) begin
                nopsW <= nopsW + 1;
                if (wvW_wmask[0]) memW[{wvW_addr[17:2],2'b00}] <= wvW_wdata[ 7: 0];
                if (wvW_wmask[1]) memW[{wvW_addr[17:2],2'b01}] <= wvW_wdata[15: 8];
                if (wvW_wmask[2]) memW[{wvW_addr[17:2],2'b10}] <= wvW_wdata[23:16];
                if (wvW_wmask[3]) memW[{wvW_addr[17:2],2'b11}] <= wvW_wdata[31:24];
            end
            wvW_dout <= { wvW_addr[7:0] ^ 8'hA5, wvW_addr[15:8] ^ 8'h3C };
            wvW_done <= 1; busyW <= 0;
        end
        else latW <= latW - 1;
    end
end

integer latN; logic busyN = 0, inflN = 0;
always @(posedge clk_108) begin
    wvN_done <= 0;
    if (inflN && !wvN_req) inflN <= 0;
    if (wvN_req && !busyN && !inflN) begin
        busyN <= 1; inflN <= 1; latN <= 5 + ({$random} % 40);
    end
    else if (busyN) begin
        if (latN == 0) begin
            if (wvN_we) begin
                nopsN <= nopsN + 1;
                memN[wvN_addr[17:0]] <= wvN_wdata;   // 1 BYTE por op, como memory.v
            end
            wvN_dout <= { wvN_addr[7:0] ^ 8'hA5, wvN_addr[15:8] ^ 8'h3C };
            wvN_done <= 1; busyN <= 0;
        end
        else latN <= latN - 1;
    end
end

// ---------------- estimulo + validacion ----------------
integer i, k, errors = 0;
logic dW, dN;
logic [21:0] a;
logic [15:0] expect_w;
logic [31:0] wd;
logic [3:0]  wm;

initial begin
    for (k = 0; k < MEMSZ; k = k + 1) begin
        memW[k] = 8'h5A; memN[k] = 8'h5A; memG[k] = 8'h5A;
    end
    repeat (10) @(posedge clk_vdp);
    rst_n = 1;
    repeat (5) @(posedge clk_vdp);
    for (i = 0; i < 200; i = i + 1) begin
        a  = ({$random} % 65536) * 4;      // palabra alineada dentro de memG
        wd = {$random};
        // mascaras representativas: 1-hot (CPU), pares, y palabra entera.
        // OJO: el indice es i/3 (no i) — las escrituras son i%3==0 y con i%6
        // TODAS caian en mascaras 1-hot: el modo serializado nunca encadenaba
        // mas de un byte y el test pasaba sin probar lo que importa.
        case ((i/3) % 6)
            0: wm = 4'b0001;
            1: wm = 4'b0010;
            2: wm = 4'b0100;
            3: wm = 4'b1000;
            4: wm = 4'b0011;
            default: wm = 4'b1111;
        endcase
        @(posedge clk_vdp);
        bk_addr  <= a;
        bk_we    <= (i % 3 == 0);
        bk_wdata <= wd;
        bk_wmask <= wm;
        bk_req   <= 1;
        @(posedge clk_vdp);
        bk_req <= 0;
        if (i % 3 == 0) begin              // modelo dorado
            if (wm[0]) memG[a[17:0]+0] = wd[ 7: 0];
            if (wm[1]) memG[a[17:0]+1] = wd[15: 8];
            if (wm[2]) memG[a[17:0]+2] = wd[23:16];
            if (wm[3]) memG[a[17:0]+3] = wd[31:24];
        end
        dW = bkW_done_t; dN = bkN_done_t;
        fork : wait_done
            begin
                wait ((bkW_done_t !== dW) );
                wait ((bkN_done_t !== dN) );
                disable wait_done;
            end
            begin
                repeat (8000) @(posedge clk_vdp);
                $display("ERROR op %0d: TIMEOUT sin done (W=%b N=%b)", i,
                         bkW_done_t !== dW, bkN_done_t !== dN);
                errors = errors + 1;
                disable wait_done;
            end
        join
        @(posedge clk_vdp);
        expect_w = { a[7:0] ^ 8'hA5, a[15:8] ^ 8'h3C };
        if (!bk_we && bkW_rword !== expect_w) begin
            $display("ERROR op %0d (W): addr=%h rword=%h esperado=%h", i, a, bkW_rword, expect_w);
            errors = errors + 1;
        end
        if (!bk_we && bkN_rword !== expect_w) begin
            $display("ERROR op %0d (N): addr=%h rword=%h esperado=%h", i, a, bkN_rword, expect_w);
            errors = errors + 1;
        end
        repeat ({$random} % 8) @(posedge clk_vdp);
    end
    // ---- comprobacion INTEGRAL: ni un byte de mas, ni uno de menos ----
    for (k = 0; k < MEMSZ; k = k + 1) begin
        if (memW[k] !== memG[k]) begin
            if (errors < 20)
                $display("ERROR memW[%0d]=%h dorada=%h", k, memW[k], memG[k]);
            errors = errors + 1;
        end
        if (memN[k] !== memG[k]) begin
            if (errors < 20)
                $display("ERROR memN[%0d]=%h dorada=%h", k, memN[k], memG[k]);
            errors = errors + 1;
        end
    end
    $display("OPS FAR: modo palabra=%0d  modo byte=%0d  (ratio %0d.%02d)",
             nopsW, nopsN, (nopsW>0)?(nopsN/nopsW):0,
             (nopsW>0)?(((nopsN*100)/nopsW)%100):0);
    if (errors == 0) $display("*** BRIDGE CDC: 200/200 OPS OK (palabra + byte) ***");
    else             $display("*** BRIDGE CDC: %0d ERRORES ***", errors);
    $finish;
end

initial begin
    #20000000;
    $display("TIMEOUT GLOBAL i=%0d errors=%0d", i, errors);
    $finish;
end

endmodule
