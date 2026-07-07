// ============================================================================
//  memory.v — Controlador SDR del MSXnano, PORTADO a bus de 16 bits para el
//  módulo Tang SDRAM (Winbond W9825G6KH, 16M×16, 32MB) de la Console 60K.
// ----------------------------------------------------------------------------
//  Cirugía 32→16 bits aplicada según docs/SDR_MEMORY_PORT.md. La FSM, el
//  arbitraje CPU/VDP por video_dhclk/dlclk, el fix MG2 (refresh nunca roba una
//  ESCRITURA VDP) y el contrato ram_*/vram_* NO cambian.
//
//  Cambios respecto al memory.v del TN20K (SDRAM embebida de 32 bits):
//   1. Bus de datos 32→16, DQM 4→2, byte-en-palabra = sdram_addr[0].
//   2. Dirección 11→13 bits (W9825: 8192 filas × 512 cols × 4 bancos).
//   3. MAPEO GEOMETRÍA-PRESERVANTE: el bit sdram_addr[1] (antes seleccionaba la
//      mitad alta/baja del word de 32b vía DQM HU/HL) pasa a ser el LSB de
//      COLUMNA. Así, cada word de 32b original = 2 columnas de 16b adyacentes,
//      y la geometría de colisión CPU↔VRAM del banco D queda IDÉNTICA al
//      diseño original (VRAM en cols pares de la región 3'b111; los bytes que
//      antes iban a las lanes HU/HL viven ahora en las cols impares).
//        CPU: bank=addr[22:21] · row={2'b00,addr[12:2]} · col={addr[20:13],addr[1]} · byte=addr[0]
//        VDP: bank=2'b11      · row={2'b00,vram[10:0]}  · col={3'b111,vram[15:11],1'b0} · byte=vram[16]
//   4. TRISTATE EXPLÍCITO (fix de portabilidad): el original hacía
//      `assign IO_sdram_dq = SdrDat` con SdrDat<=z en lecturas y luego LEÍA
//      SdrDat (el reg) para capturar el dato — un idioma que solo funciona
//      porque Gowin lo mapea al pad de la SDRAM EMBEBIDA. Con chip externo por
//      GPIO (GW5A) y en simulación eso lee 'z'. Ahora: dq_oe + dq_in explícitos.
//   5. El latch de lectura dispara en las fases 5 Y 6 (doble ventana): cubre
//      CL2 y CL2+registro-de-pad. En fase 6 el chip ya no conduce (BL=1, DQM):
//      el bus retiene el valor por capacidad (igual que hacía el TN20K). El
//      testbench lo modela; ver docs/SDR_MEMORY_PORT.md.
//
//  ✔ VERIFICADO EN SIMULACIÓN (Icarus): tools/sdr16_tb/ (modelo W9825 + auto-check).
//  ⚠ CKE: el módulo Tang SDRAM ata CKE a nivel alto en placa (el .cst de
//    C64Nano no tiene pin CKE) → O_sdram_cke queda sin constraint en el 60K.
// ============================================================================

module memory_ctrl #(
    // Console 60K: el chip SDR es EXTERNO (modulo por header). Con el reloj en
    // fase (como la SDRAM embebida del GW2AR) el viaje pad+traza+tAC+pad puede
    // dejar el dato de lectura fuera de la ventana del primer latch. Invertir
    // el reloj reenviado (180 grados) adelanta al chip media T y devuelve el
    // dato comodo en fase 5 (truco clasico de SDR externo; nand2mario igual).
    parameter SDCLK_INVERT = 1'b0
)(
    input wire clk_27m,          // OJO: top.v lo alimenta con clk_54m
	input wire clk_108m,
	input wire bus_reset_n,
	input wire video_dhclk,
	input wire video_dlclk,

	input wire [7:0] ram_din,
    input wire ram_req,
    input wire ram_write,
	input wire [22:0] ram_addr,
	input wire [7:0] vram_din,
	input wire vram_write,
	input wire [16:0] vram_addr,
    input wire bus_rfsh_n,

	output reg [7:0] ram_dout,
	output reg [15:0] vram_dout,
    output reg ram_busy,

    // SDRAM externa (módulo Tang SDRAM, W9825G6KH 16M×16) por GPIO
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n, // chip select
    output wire O_sdram_cas_n, // columns address select
    output wire O_sdram_ras_n, // row address select
    output wire O_sdram_wen_n, // write enable
    inout wire [15:0] IO_sdram_dq, // 16 bit bidirectional data bus
    output wire [12:0] O_sdram_addr, // 13 bit multiplexed address bus
    output wire [1:0] O_sdram_ba, // four banks
    output wire [1:0] O_sdram_dqm // 16/2
);

	//`default_nettype none

    assign O_sdram_clk = SDCLK_INVERT ? ~clk_108m : clk_108m;
    assign O_sdram_cke = 1;
    assign O_sdram_cs_n = SdrCmd[3];
    assign O_sdram_ras_n = SdrCmd[2];
    assign O_sdram_cas_n = SdrCmd[1];
    assign O_sdram_wen_n = SdrCmd[0];

    assign O_sdram_dqm[1] = SdrUdq;
    assign O_sdram_dqm[0] = SdrLdq;
    assign O_sdram_ba[1] = SdrBa[1];
    assign O_sdram_ba[0] = SdrBa[0];

    assign O_sdram_addr = SdrAdr;

    // Tristate explícito del bus de datos (ver cabecera, cambio 4)
    assign IO_sdram_dq = dq_oe ? SdrDat : 16'hzzzz;
    wire [15:0] dq_in = IO_sdram_dq;


    reg [22:0] sdram_addr;
    wire sdram_read;
    reg sdram_write;
    wire sdram_dout;
    reg [2:0] sdram_seq;
    reg enable_sdram;

    always @ (posedge clk_27m) begin
        if ( bus_reset_n == 0) begin
            sdram_seq <= 3'd0;
            enable_sdram <= 0;
            sdram_addr <= 0;
            sdram_write <= 0;
            ram_busy <= 0;
        end
        else begin
            enable_sdram <= 0;
            case ( sdram_seq )
                3'd0 : begin
                    sdram_write <= 0;
                    if  ( ram_req == 1 && ( video_dlclk == 1 && video_dhclk == 1 ) ) begin
                        sdram_seq <= 3'd1;
                        ram_busy <= 1;
                    end
                end
                3'd1 : begin
                    enable_sdram <= 1;
                    sdram_addr <= ram_addr[22:0] ;
                    sdram_write <= ram_write;
                    sdram_seq <= 3'd2;
                end
                3'd2 : begin
                    enable_sdram <= 1;
                    if ( video_dlclk == 0 && video_dhclk == 0 ) begin
                        sdram_write <= 0;
                        sdram_seq <= 3'd3;
                    end
                end
                3'd3 : begin
                    enable_sdram <= 1;
                    sdram_write <= 0;
                    ram_dout <= RamDbi;
                    sdram_seq <= 3'd4;
                    ram_busy <= 0;
                end
                3'd4 : begin
                    if ( ram_req == 0 ) begin
                        sdram_seq <= 3'd0;
                    end
                end
                default: begin
                    sdram_seq <= 3'd0;
                end
            endcase
        end
    end

    // NOTA sim: initializers añadidos en el port (= power-up real de Gowin, 0).
    // Sin ellos, ff_mem_seq/ff_sdr_seq arrancan en X en simulación y el init
    // se bloquea (misma higiene que la auditoría pide para kanji.v).
    reg [2:0] ff_sdr_seq = 3'b000;
    reg [4:0]  RstSeq = 0;
    // SDRAM control signals
    reg  [2:0] SdrSta = 3'b000;
    reg  [3:0] SdrCmd = 4'b1111;             //-- deselect en el arranque
    reg  [1:0] SdrBa = 2'b00;
    reg  SdrUdq = 1;
    reg  SdrLdq = 1;
    reg  [12:0] SdrAdr = 0;
    reg  [15:0] SdrDat = 0;
    reg  dq_oe = 0;
    reg  [1:0] SdrSize = 2'b11;

    localparam [3:0] SdrCmd_de = 4'b1111;            //-- deselect
    localparam [3:0] SdrCmd_pr = 4'b0010;            //-- precharge all
    localparam [3:0] SdrCmd_re = 4'b0001;            //-- refresh
    localparam [3:0] SdrCmd_ms = 4'b0000;            //-- mode register set

    localparam [3:0] SdrCmd_xx = 4'b0111;            //-- no operation
    localparam [3:0] SdrCmd_ac = 4'b0011;            //-- activate
    localparam [3:0] SdrCmd_rd = 4'b0101;            //-- read
    localparam [3:0] SdrCmd_wr = 4'b0100;            //-- write

    reg [7:0]  RamDbi = 0;
    reg [1:0] ff_mem_seq = 2'b00;
    reg [15:0] FreeCounter = 0;

//    ----------------------------------------------------------------
//    -- SDRAM access
//    ----------------------------------------------------------------
//    --   SdrSta = "000" => idle
//    --   SdrSta = "001" => precharge all
//    --   SdrSta = "010" => refresh
//    --   SdrSta = "011" => mode register set
//    --   SdrSta = "100" => read cpu
//    --   SdrSta = "101" => write cpu
//    --   SdrSta = "110" => read vdp
//    --   SdrSta = "111" => write vdp
//    ----------------------------------------------------------------

    always @ ( posedge clk_108m ) begin
        //-- 00 > 01 > 11 > 10
        ff_mem_seq <= { ff_mem_seq[0], (~ ff_mem_seq[1]) } ;
    end

    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            FreeCounter <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter <= FreeCounter + 1;
        end
    end

    reg [19:0] FreeCounter2;
    always @ ( posedge clk_108m ) begin
        if ( RstSeq < 5'b01000 ) begin
            FreeCounter2 <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter2 <= FreeCounter2 + 1;
        end
    end

    //-- RstSeq count
    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            RstSeq <= 0;
        end
        if( ff_mem_seq == 2'b00 && FreeCounter[15:0] == 16'hFFFF && RstSeq != 5'b11111 ) begin
            RstSeq <= RstSeq + 1;                                                   //-- 3ms (= 65536 / 21.48MHz)
        end
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b111 ) begin
            if( RstSeq[4:2] == 3'b000 ) begin
                SdrSta <= 3'b000;                                                //-- idle
            end
            else if( RstSeq[4:2] == 3'b001 ) begin
            //--  case RstSeq(1 downto 0) is
            //--      when "00"       => SdrSta <= "000";                         -- idle
            //--      when "01"       => SdrSta <= "001";                         -- precharge all
            //--      when "10"       => SdrSta <= "010";                         -- refresh (more than 8 cycles)
            //--      when others     => SdrSta <= "011";                         -- mode register set
            //--  end case;
                SdrSta <= { 1'b0, RstSeq[1:0] };
            end
            else if( bus_rfsh_n == 0 && video_dlclk == 1 && vram_write == 0 ) begin
                //-- refresh roba el slot VDP SOLO si el VDP va a LEER (display/
                //-- sprite, recuperable al siguiente frame). Si va a ESCRIBIR
                //-- (comando del blitter HMMV/HMMM o acceso CPU por puerto), NO:
                //-- el VDP da ACK incondicional y la escritura se perderia ->
                //-- agujeros permanentes en VRAM (glitch de MG2 al cambiar de
                //-- pantalla). Hay >100k ciclos RFSH del Z80 por frame; saltarse
                //-- los pocos que coinciden con vram_write no afecta el refresh.
                SdrSta <= 3'b010;                                                //-- refresh
            end
            else begin
                //--  Normal memory access mode
                SdrSta[2] <= 1;                                               //-- read/write cpu/vdp
            end
        end
        else if( ff_sdr_seq == 3'b001 && SdrSta[2] == 1 && RstSeq[4:3] == 2'b11 )begin
            SdrSta[1] <= video_dlclk;                                            //-- 0:cpu, 1:vdp
            if( video_dlclk == 0 ) begin
                SdrSta[0] <= sdram_write;         //-- for cpu
            end
            else begin
                SdrSta[0] <= vram_write;       //-- for vdp
            end
        end
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000:
                if( SdrSta[2] == 1 ) begin               //-- cpu/vdp read/write
                    SdrCmd <= SdrCmd_ac;
                end
                else if( SdrSta[1:0] == 2'b00 ) begin  //-- idle
                    SdrCmd <= SdrCmd_xx;
                end
                else if( SdrSta[1:0] == 2'b01 ) begin  //-- precharge all
                    SdrCmd <= SdrCmd_pr;
                end
                else if( SdrSta[1:0] == 2'b10 ) begin  //-- refresh
                    SdrCmd <= SdrCmd_re;
                end
                else begin                                   //-- mode register set
                    SdrCmd <= SdrCmd_ms;
                end
            3'b001:
                SdrCmd <= SdrCmd_xx;
            3'b010:
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        SdrCmd <= SdrCmd_rd;            //-- "100"(cpu read) / "110"(vdp read)
                    end
                    else begin
                        SdrCmd <= SdrCmd_wr;            //-- "101"(cpu write) / "111"(vdp write)
                    end
                end
            3'b011:
                SdrCmd <= SdrCmd_xx;
            default: ;
                //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
            end
            3'b010: begin
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        //-- lectura: habilitar los dos bytes; el latch elige
                        SdrUdq <= 0;
                        SdrLdq <= 0;
                    end
                    else begin
                        if( video_dlclk == 0 ) begin
                            //-- cpu write: lane por sdram_addr[0] (0=bajo, 1=alto)
                            SdrUdq <= ~ sdram_addr[0];
                            SdrLdq <= sdram_addr[0];
                        end
                        else begin
                            //-- vdp write: lane por vram_addr[16]
                            SdrUdq <= ~vram_addr[16];
                            SdrLdq <=  vram_addr[16];
                        end
                    end
                end
            end
            3'b011: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( SdrSta[2] == 0 ) begin                                       //-- set [command mode]
                    //--           (A12:A11=00) WBL=single TM=off CL=2 WT=0(seq) BL=1
                    SdrAdr <= { 2'b00, 3'b010, 1'b0, 3'b010, 1'b0, 3'b000 };
                    SdrBa  <= 2'b00;                                             //-- bank A
                end
                else begin                                                           //-- set [row address]
                    if( video_dlclk == 0 ) begin
                        SdrAdr <= { 2'b00, sdram_addr[12:2] };   //-- cpu read/write (fila = mismos bits que el original)
                        SdrBa  <= sdram_addr[22:21];                         //-- bank A+B+C+D
                    end
                    else begin
                        SdrAdr <= { 2'b00, vram_addr[10:0] };                   //-- vdp read/write
                        SdrBa  <= 2'b11;                                         //-- bank D
                    end
                end
            end
            3'b010: begin                                                                             //-- set [column address]
                SdrAdr[12:9] <= 4'b0010;                                                           //-- A10=1 => enable auto precharge
                //-- when A10=1, SdrBa is ignored and all banks are selected
                //-- be careful not to assign SdrBa during auto precharge, otherwise it will cause instability
                if( video_dlclk == 0 ) begin
                    //-- cpu: col = {addr[20:13], addr[1]} — el bit addr[1] (antes
                    //-- media palabra de 32b) es ahora el LSB de columna
                    SdrAdr[8:0] <= { sdram_addr[20:13], sdram_addr[1] };                          //-- cpu read/write
                end
                else begin
                    //-- vdp: misma región alta de columnas que el original, col par
                    SdrAdr[8:0] <= { 3'b111, vram_addr[15:11], 1'b0 };
                end
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b010 ) begin
            if( SdrSta[2] == 1 ) begin
                if( SdrSta[0] == 0 ) begin
                    dq_oe <= 0;                                                  //-- lectura: bus en Z
                end
                else begin
                    dq_oe <= 1;
                    if( video_dlclk == 0 ) begin
                        SdrDat <= { ram_din, ram_din };                //-- "101"(cpu write)
                    end
                    else begin
                        SdrDat <= { vram_din, vram_din };          //-- "111"(vdp write)
                    end
                end
            end
        end
        else begin
            dq_oe <= 0;
        end
    end

    //-- Data read latch for CPU
    reg ff_sdr_seq_5 = 0;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_5 <= 0;
        if( ff_sdr_seq == 3'b100 ) begin
            ff_sdr_seq_5 <= 1;
        end
    end
    reg ff_sdr_seq_6 = 0;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_6 <= 0;
        if( ff_sdr_seq == 3'b101 ) begin
            ff_sdr_seq_6 <= 1;
        end
    end
    reg SdrSta_4 = 0;
    always @ ( posedge clk_108m ) begin
        SdrSta_4 <= 0;
        if( SdrSta[2:0] == 3'b100 ) begin
            SdrSta_4 <= 1;
        end
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
            if( SdrSta_4 == 1 ) begin                        //-- read cpu
                if( sdram_addr[0] == 1'b0 )
                    RamDbi <= dq_in[7:0];
                else
                    RamDbi <= dq_in[15:8];
            end
        end
    end


    //-- Data read latch for VDP
    always @ ( posedge clk_108m ) begin
            if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
                if( SdrSta == 3'b110 ) begin                        //-- read vdp
                    vram_dout <= dq_in;
                end
            end
    end

    //SDRAM controller state
    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( video_dhclk == 1 ) begin
                    ff_sdr_seq <= 3'b001;
                end
            end
            3'b111: begin
                if( video_dhclk == 0 ) begin
                    ff_sdr_seq <= 3'b000;
                end
            end
            default: begin
                ff_sdr_seq <= ff_sdr_seq + 1;
            end
        endcase
    end

endmodule
