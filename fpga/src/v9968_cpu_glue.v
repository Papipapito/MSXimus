// ============================================================================
// v9968_cpu_glue.v — Adaptador del bus I/O del T80 (clk_54m, señales estilo
// Z80: csw_n/csr_n activos bajo durante el ciclo I/O) al bus valid/ready del
// V9968 (clk_86). Sustituye el enganche directo que tenia el V9958.
//
// Diseño (lección _91: TODO registrado, nada combinacional cruzando dominios):
//  - csw_n/csr_n se sincronizan con 2FF al dominio 85.9; el NIVEL bajo con el
//    flag `served` limpio dispara UNA transaccion valid/ready por ciclo I/O
//    del Z80 (_177: antes era el FLANCO de bajada — un flanco que llegaba con
//    bus_valid aun alto se PERDIA en silencio, el bug #26; con nivel+served,
//    si el bus esta ocupado la transaccion simplemente sale mas tarde, con
//    wait_n reteniendo al Z80 mientras tanto).
//  - addr/dato del T80 son cuasi-estaticos durante todo el ciclo I/O
//    (cientos de ns) → se latchean tras el sync sin FIFO.
//  - Lecturas: bus_rdata_en captura el dato en cdi_r, que queda estable hasta
//    la SIGUIENTE lectura. _177: ademas rd_pend retiene wait_n hasta que el
//    dato de ESTA lectura ha aterrizado — el Z80 ya no puede muestrear cdi_r
//    antes de tiempo (el f(dir-1) del VRAMSOAK: umbral medido LAT>=340 en
//    tb_cpuif_dbl MODE=5; la cura /WAIT estaba BLOQUEADA porque el refresco
//    de la SDRAM colgaba del RFSH del Z80 — desbloqueada por el _175, que lo
//    hizo autonomo).
//  - wait_n va gateado al ciclo I/O del VDP (fuera de el, alto): jamas frena
//    un ciclo ajeno. TIMEOUT fail-open de 1024 ciclos (~12us): si algun tipo
//    de lectura no emitiera rdata_en, se libera al Z80 y quedamos como antes
//    del _177 (dato rancio una vez > cuelgue infinito).
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
    output wire       wait_n,        // _177: retener al Z80 (re-sincronizar
                                     // a clk_54m en el top antes del T80)

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
    // _177: NIVEL sincronizado (etapa 1; la 0 absorbe la metaestabilidad)
    wire io_wr = (csw_s[1] == 1'b0);
    wire io_rd = (csr_s[1] == 1'b0);

    // _177: una transaccion por ciclo I/O — `served` se limpia cuando los
    // dos cs vuelven a alto (fin del ciclo; el Z80 siempre suelta IORQ >=1
    // T-state entre ciclos, cientos de ns >> 2 ciclos de 85.9 del sync).
    reg served = 1'b0;
    // _177: lectura en vuelo — el dato de ESTA lectura aun no esta en cdi_r
    reg rd_pend = 1'b0;
    // _177: timeout fail-open del wait. _184 (caza Fleet/DQ2 05/08): de
    // 2^10 (~11.9us) a 2^12 ciclos de 85.9 (~47.7us) — en los modos MSX1
    // el turno CPU puede tardar decenas de us (inanicion del drenaje, ver
    // _186b en el shim); la correa corta convertia esas esperas en datos
    // rancios servidos al Z80. Se mantiene el seguro anti-cuelgue.
    reg [12:0] wtmo = 13'd0;
    wire wtmo_hit = wtmo[12];

    always @( posedge clk_86 ) begin
        if( !rst_n ) begin
            bus_valid <= 1'b0;
            bus_ioreq <= 1'b0;
            bus_write <= 1'b0;
            served    <= 1'b0;
            rd_pend   <= 1'b0;
        end
        else begin
            if( bus_valid ) begin
                if( bus_ready ) begin
                    bus_valid <= 1'b0;      // transaccion aceptada
                    bus_ioreq <= 1'b0;
                end
            end
            else if( (io_wr || io_rd) && !served ) begin
                // addr/dato llevan >=2 ciclos de 85.9 estables (viajaron con
                // el propio cs): latch directo
                bus_address <= { 1'b0, mode };
                bus_wdata   <= cdo;
                bus_write   <= io_wr;
                bus_ioreq   <= 1'b1;
                bus_valid   <= 1'b1;
                served      <= 1'b1;
                rd_pend     <= io_rd && !io_wr;
            end
            if( !io_wr && !io_rd ) served <= 1'b0;   // fin del ciclo I/O
            if( bus_rdata_en ) rd_pend <= 1'b0;      // dato aterrizado
            if( wtmo_hit ) rd_pend <= 1'b0;          // fail-open
        end
    end

    // _177: contador del timeout — corre mientras haya motivo de wait
    wire wait_cause = (io_wr || io_rd) && ( !served || bus_valid || rd_pend );
    always @( posedge clk_86 ) begin
        if( !rst_n )           wtmo <= 13'd0;
        else if( !wait_cause ) wtmo <= 13'd0;
        else if( !wtmo_hit )   wtmo <= wtmo + 13'd1;
    end

    // _177: wait activo (bajo) SOLO durante un ciclo I/O del VDP con trabajo
    // pendiente: transaccion sin emitir, sin aceptar, o lectura sin dato.
    assign wait_n = ~( wait_cause && !wtmo_hit );

    // captura del dato de lectura (estable hasta la siguiente)
    always @( posedge clk_86 ) begin
        if( bus_rdata_en ) cdi_r <= bus_rdata;
    end

endmodule
