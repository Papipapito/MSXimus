// ============================================================================
// v9968_cpu_glue.v — Adaptador del bus I/O del T80 (clk_54m, señales estilo
// Z80: csw_n/csr_n activos bajo durante el ciclo I/O) al bus valid/ready del
// V9968 (clk_86). Sustituye el enganche directo que tenia el V9958.
//
// Diseño (lección _91: TODO registrado, nada combinacional cruzando dominios):
//  - csw_n/csr_n se sincronizan con 2FF al dominio 85.9; el FLANCO DE BAJADA
//    dispara UNA transaccion valid/ready por ciclo I/O del Z80.
//  - addr/dato del T80 son cuasi-estaticos durante todo el ciclo I/O
//    (cientos de ns) → se latchean tras el sync sin FIFO.
//  - Lecturas: bus_rdata_en captura el dato en cdi_r, que queda estable hasta
//    la SIGUIENTE lectura (el T80 lo muestrea al final de su ciclo, cientos
//    de ns despues — igual que hacia el tn_vdp). A 5.37 MHz sobra margen.
//  - int_n del V9968 pasa tal cual (nivel, el T80 lo sincroniza a su manera).
//
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================

module v9968_cpu_glue (
    input  wire       clk_86,        // 85.909 MHz (dominio del V9968)
    input  wire       rst_n,

    // --- lado T80 (señales cuasi-estaticas durante el ciclo I/O) ---
    input  wire       csw_n,         // escritura VDP (98-9B), activo bajo
    input  wire       csr_n,         // lectura VDP, activo bajo
    input  wire [1:0] mode,          // bus_addr[1:0]
    input  wire [7:0] cdo,           // dato del T80 (escrituras)
    output reg  [7:0] cdi_r,         // dato al T80 (lecturas, estable)

    // --- lado V9968 (bus valid/ready en clk_86) ---
    output reg  [2:0] bus_address,
    output reg        bus_ioreq,
    output reg        bus_write,
    output reg        bus_valid,
    input  wire       bus_ready,
    output reg  [7:0] bus_wdata,
    input  wire [7:0] bus_rdata,
    input  wire       bus_rdata_en
);

    // sync 2FF de los chip-selects
    reg [2:0] csw_s = 3'b111;
    reg [2:0] csr_s = 3'b111;
    always @( posedge clk_86 ) begin
        csw_s <= { csw_s[1:0], csw_n };
        csr_s <= { csr_s[1:0], csr_n };
    end
    wire wr_start = (csw_s[2] == 1'b1) && (csw_s[1] == 1'b0);  // flanco bajada
    wire rd_start = (csr_s[2] == 1'b1) && (csr_s[1] == 1'b0);

    always @( posedge clk_86 ) begin
        if( !rst_n ) begin
            bus_valid <= 1'b0;
            bus_ioreq <= 1'b0;
            bus_write <= 1'b0;
        end
        else begin
            if( bus_valid ) begin
                if( bus_ready ) begin
                    bus_valid <= 1'b0;      // transaccion aceptada
                    bus_ioreq <= 1'b0;
                end
            end
            else if( wr_start || rd_start ) begin
                // addr/dato llevan >=2 ciclos de 85.9 estables (viajaron con
                // el propio cs): latch directo
                bus_address <= { 1'b0, mode };
                bus_wdata   <= cdo;
                bus_write   <= wr_start;
                bus_ioreq   <= 1'b1;
                bus_valid   <= 1'b1;
            end
        end
    end

    // captura del dato de lectura (estable hasta la siguiente)
    always @( posedge clk_86 ) begin
        if( bus_rdata_en ) cdi_r <= bus_rdata;
    end

endmodule
