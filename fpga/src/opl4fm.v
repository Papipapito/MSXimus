// ============================================================================
// opl4fm.v — MoonSound FM (OPL3/YMF262 del YMF278B) para MSXimus (_82)
//
// Integra el core gtaylormb/opl3_fpga (LGPL-3.0, fork antxiko/mangOPL4 con
// los fixes de Gowin: TICK_COUNT entero en timers, pragma en control_ops)
// mapeado en C4h-C7h como el MoonSound real. Adaptacion a MSXimus del
// wrapper cartridge_opl3.sv de mangOPL4 (BSD-3, Jokin Miragaia) — gracias:
//  - El host_if del core lleva FIFO asincrona clk_host->clk_opl3: se le dan
//    las señales CRUDAS del bus (cs/rd/wr sostenidos) y el se apaña.
//  - SHADOW REGS 2x256: el YMF278B real permite LEER los registros FM
//    (openMSX YMF278B.cc: read C5/C7 = readReg del latch); el core de
//    Taylor es solo-escritura -> espejo de escrituras del bus. Sin esto
//    MoonBlaster FM y similares fallan el write/read-verify.
//  - Status en C4 Y C6 (el chip real lo espeja en port&3 == 0 y 2).
//  - Stub del puerto WAVE 7Eh/7Fh: lectura de 7F devuelve 0x20 (device ID
//    del YMF278B) para que VGMPlay/players detecten "MoonSound" y toquen
//    la parte FM. El software wave sonara incompleto: FASE 2 = wavetable
//    real (YMF278B.sv de srg320 + DDR3). Documentado en el LEEME.
//
// Reloj: 33.75 MHz (PLLA propia, 27x40/32 exacto; -0.35% vs 33.8688 nominal
// del MoonSound; pkg con CLK_DIV_COUNT=682 -> fs 49.487 kHz, -0.06%).
// IRQ: NO cableada en _82 (la deteccion estandar va por polling del status;
// mangOPL4 documenta que el cableado directo tormenta con VGMPlay — su
// solucion pulso+gap queda para un build futuro si hace falta).
// ============================================================================

module opl4fm (
    input  wire        rst_n,        // bus_reset_n
    input  wire        clk_host,     // clk_54m (dominio del bus)
    input  wire        clk_opl3,     // 33.75 MHz (pll_3375)

    input  wire        iorq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    input  wire        m1_n,
    input  wire [7:0]  addr,
    input  wire [7:0]  din,

    input  wire [1:0]  wave_status,  // _89: {LD,BUSY} del motor PCM (OR en C4/C6)

    output wire        fm_rd,        // lectura C4-C7 en curso (para el mux)
    output wire        wave_rd,      // lectura 7Fh en curso (stub wave)
    output wire [7:0]  dout,         // dato C4-C7 (status/shadow)
    output wire [7:0]  wave_dout,    // dato 7Fh (stub 0x20)
    output reg signed [15:0] pcm_out, // al mixer (registrado, dominio host)
    output wire        int_n         // _108: IRQ del timer OPL4 (dominio host,
                                     // 2FF; VGMPlay/MBWave la NECESITAN: su
                                     // play va del Timer1 a 1130Hz por IRQ)
);

// ---------------------------------------------------------------------------
// _91: BUS REGISTRADO antes del decode. El T80 saca IORQ/WR/addr en el
// flanco de BAJADA de clk_54m y este modulo consume en el de SUBIDA: el
// cono de decode era un path de MEDIO ciclo (9.26ns) que llevaba desde la
// _82 pasando por los pelos segun la loteria de placement. Registrar el
// bus da el ciclo entero; el retardo (18.5ns) es nada frente al ciclo I/O
// del Z80 (~1us).
// ---------------------------------------------------------------------------
reg        iorq_r, rd_r, wr_r, m1_r;
reg [7:0]  addr_r, din_r;
always @(posedge clk_host) begin
    iorq_r <= iorq_n; rd_r <= rd_n; wr_r <= wr_n; m1_r <= m1_n;
    addr_r <= addr;   din_r <= din;
end

// ---------------------------------------------------------------------------
// decodificacion C4h-C7h (movida del wrapper mangOPL4)
// ---------------------------------------------------------------------------
wire cs_opl3 = (iorq_r == 1'b0) && (m1_r == 1'b1) && (addr_r[7:2] == 6'b110001);
assign fm_rd = cs_opl3 && (rd_r == 1'b0);

// stub wave 7Eh-7Fh: solo 7F drivea (7E flota en el chip real)
wire cs_wave = (iorq_r == 1'b0) && (m1_r == 1'b1) && (addr_r[7:1] == 7'b0111111);
assign wave_rd   = cs_wave && (rd_r == 1'b0) && addr_r[0];
assign wave_dout = 8'h20;            // device ID del YMF278B (deteccion)

// ---------------------------------------------------------------------------
// shadow register file (read-back que el core no tiene)
// ---------------------------------------------------------------------------
// ERA v3 (sin SSRAM): las shadows van a BSRAM con lectura SINCRONA.
// Como FF eran 4.096 registros + dos muxes 256:1 — el bocado que faltaba
// para colocar la build completa (v3b002: 2.9-4.3K REG unPlaced). El ciclo
// extra de la lectura registrada es invisible: sel_reg_* cambia con la
// escritura de seleccion, MUCHOS ciclos de clk_host antes de que el Z80
// muestree el dato del readback (una I/O read son ~15 ciclos de 54MHz).
// v3b010+: los DOS bancos comparten UNA BSRAM 512x8 (bit alto = banco):
// el Z80 solo puede leer un banco a la vez (C5 o C7) y solo escribe uno
// por ciclo de bus (strobes we0/we1 excluyentes por addr_r[1:0]).
(* syn_ramstyle = "block_ram" *) reg [7:0] shadow [0:511];
reg [7:0] sh_q;
reg [7:0] sel_reg_b0;
reg [7:0] sel_reg_b1;

reg  prev_wr_active;
wire wr_active = cs_opl3 && (wr_r == 1'b0);
wire wr_strobe = wr_active && !prev_wr_active;

always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) begin
        prev_wr_active <= 1'b0;
        sel_reg_b0 <= 8'd0;
        sel_reg_b1 <= 8'd0;
    end
    else begin
        prev_wr_active <= wr_active;
        if (wr_strobe) begin
            case (addr_r[1:0])
                2'b00: sel_reg_b0 <= din_r;
                2'b10: sel_reg_b1 <= din_r;
                default: ;
            endcase
        end
    end
end

// _121diag: media etapa NEGEDGE en las escrituras de las shadow — misma
// clase de hold que pww->pw_mem en el shim (registro->AD de BSRAM
// demasiado corto, -0.02): dato/indice/enable se recapturan a contraflanco
// y la BSRAM los ve estables medio ciclo a cada lado. La escritura aterriza
// 1 ciclo despues: irrelevante (las lecturas de shadow van a ritmo de CPU).
reg       shw_we0_n, shw_we1_n;
reg [7:0] shw_idx0_n, shw_idx1_n, shw_dat_n;
always @(negedge clk_host) begin
    shw_we0_n  <= wr_strobe && (addr_r[1:0] == 2'b01);
    shw_we1_n  <= wr_strobe && (addr_r[1:0] == 2'b11);
    shw_idx0_n <= sel_reg_b0;
    shw_idx1_n <= sel_reg_b1;
    shw_dat_n  <= din_r;
end
wire       sh_we    = shw_we0_n | shw_we1_n;
wire [8:0] sh_waddr = shw_we1_n ? {1'b1, shw_idx1_n} : {1'b0, shw_idx0_n};
wire [8:0] sh_raddr = addr_r[1] ? {1'b1, sel_reg_b1} : {1'b0, sel_reg_b0};
always @(posedge clk_host) begin
    if (sh_we) shadow[sh_waddr] <= shw_dat_n;
    sh_q <= shadow[sh_raddr];           // era v3: lectura registrada (BSRAM)
end

// mux de lectura: status del core en C4/C6, registro shadow en C5/C7.
// _89: el status del YMF278B real mezcla los flags FM (timers, bits 5-7)
// con los del wave (bit1=LD, bit0=BUSY) — se ORean los del motor PCM.
wire [7:0] opl3_dout;
assign dout = (addr_r[0] == 1'b0) ? (opl3_dout | {6'b000000, wave_status}) : // C4/C6
                                    sh_q;      // C5/C7: shadow (BSRAM unica)

// ---------------------------------------------------------------------------
// core OPL3 (fork mangOPL4; FIFO async interna clk_host->clk_opl3)
// ---------------------------------------------------------------------------
wire signed [23:0] sample_l, sample_r;   // opl3_pkg::DAC_OUTPUT_WIDTH = 24

opl3 u_opl3 (
    .clk               (clk_opl3),
    .clk_host          (clk_host),
    .clk_dac           (1'b0),
    .ic_n              (rst_n),
    .cs_n              (~cs_opl3),
    .rd_n              (rd_r),
    .wr_n              (wr_r),
    .address           (addr_r[1:0]),
    .din               (din_r),
    .dout              (opl3_dout),
    .sample_valid      ( ),
    .sample_l          (sample_l),
    .sample_r          (sample_r),
    .led               ( ),
    .irq_n             (opl3_irq_n),  // _108: cableada (antes solo polling)
    .force_clear_flags (1'b0)
);

// _108: IRQ al bus — 2FF al dominio host (27M y 54M son hermanos del PLLA,
// cruce cronometrado; la disciplina 3FF es para payloads, esto es 1 bit).
wire opl3_irq_n;
reg  irq_s0 = 1'b1, irq_s1 = 1'b1;
always @(posedge clk_host) begin
    irq_s0 <= opl3_irq_n;
    irq_s1 <= irq_s0;
end
assign int_n = irq_s1;

// ---------------------------------------------------------------------------
// audio: mono (L+R)/2 en clk_opl3, a NIVEL NATIVO del chip (_83).
// El core saca sample = canal <<< 5 (DAC_LEFT_SHIFT en dac_prep.sv): rango
// real +/-2^20, NO +/-2^17 — la "calibracion gain 64x" de mangOPL4 venia de
// medir UNA voz; con musica real mi _82 recortaba sin parar (HW: "suena
// raro y mal" = clipping duro x8). >>5 devuelve el 16-bit verdadero, al
// mismo nivel que el snd del OPLL/Y8950 en el mixer. Clamp solo de guarda.
// ---------------------------------------------------------------------------
// _85: ¡OJO SEMANTICA VERILOG! Las CONCATENACIONES son UNSIGNED: con
// ({sign,l} + {sign,r}) >>> 1 la suma era unsigned y el >>> degeneraba en
// shift LOGICO -> cada muestra NEGATIVA se convertia en un positivo enorme
// (media onda rectificada con picos = la "distorsion de volumen" del HW,
// verificado en sim: -1000 -> +16776216). Extension de signo via wires
// DECLARADOS signed para que toda la aritmetica sea signed.
wire signed [24:0] sample_l_ext = {sample_l[23], sample_l};
wire signed [24:0] sample_r_ext = {sample_r[23], sample_r};
reg signed [24:0] mono_q;
always @(posedge clk_opl3)
    mono_q <= (sample_l_ext + sample_r_ext) >>> 1;

wire signed [19:0] mono_n = mono_q[24:5];          // >>5: nivel nativo
wire ovf = (mono_n[19:15] != {5{mono_n[19]}});     // guarda (casi nunca)
reg signed [15:0] pcm_opl3;
always @(posedge clk_opl3) begin
    if (ovf) pcm_opl3 <= mono_n[19] ? 16'sh8000 : 16'sh7FFF;
    else     pcm_opl3 <= mono_n[15:0];
end

// cruce a dominio host por registro simple (audio a 49.5kHz: sobra)
always @(posedge clk_host or negedge rst_n) begin
    if (!rst_n) pcm_out <= 16'sd0;
    else        pcm_out <= pcm_opl3;
end

endmodule
