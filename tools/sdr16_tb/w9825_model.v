// ============================================================================
//  w9825_model.v — Modelo conductual del Winbond W9825G6KH (SDR SDRAM 256Mbit,
//  4M x 4 banks x 16). Solo para simulación (tools/sdr16_tb).
// ----------------------------------------------------------------------------
//  - Comandos: MRS / REF / PRE / ACT / WR / RD / NOP / DESELECT.
//  - CL=2, BL=1 (valida el mode register que programa memory.v).
//  - Lectura: conduce DQ en la ventana CL2 y la MANTIENE un ciclo extra para
//    emular la retención por capacidad del bus (el controlador latchea en las
//    fases 5 Y 6; en HW real el bus retiene el valor — ver SDR_MEMORY_PORT.md).
//  - Escritura: BL=1 con máscara DQM por byte, muestreada en el flanco del comando.
//  - Sin checks estrictos de timing (tRCD/tRP): el objetivo es la CORRECCIÓN
//    funcional del mapeo/lanes/arbitraje, no el timing analógico.
// ============================================================================
`timescale 1ns/1ps

module w9825_model (
    input  wire        clk,
    input  wire        cke,
    input  wire        cs_n,
    input  wire        ras_n,
    input  wire        cas_n,
    input  wire        we_n,
    input  wire [12:0] addr,
    input  wire [1:0]  ba,
    input  wire [1:0]  dqm,
    inout  wire [15:0] dq
);

    // 4 banks x 8192 rows x 512 cols = 16M words (32MB)
    reg [15:0] mem [0:(1<<24)-1];
    reg [12:0] row_of_bank [0:3];
    reg [12:0] mode_reg = 13'h0;
    reg        mode_set = 0;

    integer refresh_count = 0;
    integer write_count = 0;
    integer read_count  = 0;
    integer act_before_mrs = 0;

    wire [3:0] cmd = {cs_n, ras_n, cas_n, we_n};
    localparam CMD_MRS = 4'b0000;
    localparam CMD_REF = 4'b0001;
    localparam CMD_PRE = 4'b0010;
    localparam CMD_ACT = 4'b0011;
    localparam CMD_WR  = 4'b0100;
    localparam CMD_RD  = 4'b0101;
    localparam CMD_NOP = 4'b0111;

    // --- pipeline de lectura CL2 (+1 ciclo de retención de bus) ---
    reg        rd_s0 = 0, rd_s1 = 0, rd_s2 = 0;
    reg [15:0] rd_d0, rd_d1, rd_d2;

    assign dq = rd_s1 ? rd_d1 :
                rd_s2 ? rd_d2 : 16'hzzzz;

    wire [23:0] rw_index = {ba, row_of_bank[ba], addr[8:0]};

    always @(posedge clk) begin
        if (cke) begin
            // avanzar pipeline de lectura
            rd_s1 <= rd_s0;  rd_d1 <= rd_d0;
            rd_s2 <= rd_s1;  rd_d2 <= rd_d1;
            rd_s0 <= 0;

            case (cmd)
                CMD_MRS: begin
                    mode_reg <= addr;
                    mode_set <= 1;
                    // memory.v programa: WBL=single(A9=1) CL=2(A6:4=010) BT=seq(A3=0) BL=1(A2:0=000)
                    if (addr[6:4] !== 3'b010)
                        $display("[W9825][%0t] ERROR: MRS con CL=%0d (esperado CL=2)", $time, addr[6:4]);
                    if (addr[2:0] !== 3'b000)
                        $display("[W9825][%0t] ERROR: MRS con BL!=1 (A2:0=%b)", $time, addr[2:0]);
                    if (addr[9] !== 1'b1)
                        $display("[W9825][%0t] ERROR: MRS sin single-write-burst (A9=%b)", $time, addr[9]);
                end
                CMD_REF: refresh_count = refresh_count + 1;
                CMD_PRE: ; // precharge (all si A10) — sin bookkeeping estricto
                CMD_ACT: begin
                    if (!mode_set) act_before_mrs = act_before_mrs + 1;
                    row_of_bank[ba] <= addr;
                end
                CMD_WR: begin
                    write_count = write_count + 1;
                    if (!dqm[0]) mem[rw_index][7:0]  <= dq[7:0];
                    if (!dqm[1]) mem[rw_index][15:8] <= dq[15:8];
                end
                CMD_RD: begin
                    read_count = read_count + 1;
                    rd_s0 <= 1;
                    rd_d0 <= mem[rw_index];
                end
                default: ; // NOP / deselect
            endcase
        end
    end

endmodule
