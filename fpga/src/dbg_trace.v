// ============================================================================
// dbg_trace.v — EL ANALIZADOR LOGICO DE MSXimus (idea de Albert, 05/08/2026:
// "montar el mismo debug que el openMSX por el COM11").
//
// EL PROBLEMA: un volcado continuo estilo openMSX NO CABE por el cable —
// COM11 a 115200 = 11,5 KB/s y Fleet genera ~70.000 eventos/s (50k fetches
// M1 + 20k accesos al VDP) = 100-300 KB/s. Entre 9 y 26 veces por encima.
//
// LA SOLUCION (modelo analizador logico): un anillo en BRAM graba TODOS los
// eventos a toda velocidad; un DISPARADOR lo CONGELA y solo entonces se
// vuelca despacio por el UART. Como el disparador natural es el propio
// cuelgue ("llevo N ms sin un solo acceso de I/O"), el anillo queda con los
// milisegundos ANTERIORES al cuelgue = la transicion que nunca hemos visto.
//
// Evento (32 bits): { tipo[3:0], dato[7:0], direccion[15:0], 4'd0 }
//   tipo 0 = fetch M1        (direccion = PC)
//   tipo 1 = escritura I/O   (direccion[7:0] = puerto, dato = valor)
//   tipo 2 = lectura I/O     (direccion[7:0] = puerto, dato = valor)
//   tipo 3 = acceso a memoria en la ventana del disco (SD por slot: en el
//            MSX el interfaz de disco NO es de I/O, va mapeado en memoria —
//            por eso el veredicto "SIN-I/O" no excluia al disco)
//
// Volcado: "T <indice> <hex32>\n" por evento, precedido de "TSTART <n>" y
// cerrado con "TEND". El lector los reordena (el anillo es circular).
//
// Parte del MSXimus. Copyright (C) 2026 Papipapito. GPL-3.0-or-later.
// ============================================================================
module dbg_trace #(
    parameter CLK_HZ   = 53_996_000,
    parameter BAUD     = 115_200,
    parameter AW       = 12,           // 4096 eventos = 16 KB de BRAM
    parameter QUIET_MS = 50,           // ms sin I/O que disparan el congelado
    parameter WARM_IO  = 4096          // accesos de I/O antes de armar el disparo
)(
    input  wire        clk,
    input  wire        rst_n,

    // ---- bus del Z80 (dominio clk_54m) ----
    input  wire [15:0] bus_addr,
    input  wire [7:0]  cpu_dout,
    input  wire [7:0]  cpu_din,
    input  wire        bus_m1_n,
    input  wire        bus_iorq_n,
    input  wire        bus_mreq_n,
    input  wire        bus_rd_n,
    input  wire        bus_wr_n,
    input  wire        disk_window,    // 1 = el acceso cae en la ventana del disco

    // ---- disparo ----
    input  wire        trig_manual,    // boton de la placa (flanco)

    output reg         tx,
    output wire        frozen          // 1 = el volcado MANDA en el cable
);

    localparam integer DIV = CLK_HZ / BAUD;
    localparam integer QUIET_TICKS = (CLK_HZ / 1000) * QUIET_MS;

    // ---------------- captura ----------------
    reg [31:0] ring [0:(1<<AW)-1];
    reg [AW-1:0] wp = 0;
    reg        armed = 1'b1;           // 1 = grabando
    // s032c ARREGLO 2: `frozen` solo reclama el cable MIENTRAS vuelca; al
    // terminar lo devuelve a la radiografia (si no, tras el volcado te
    // quedas sin telemetria y sin saber si sigue vivo).
    reg        dump_done = 1'b0;
    assign     frozen = ~armed & ~dump_done;

    reg [1:0] m1_s   = 2'b11;
    reg [1:0] iow_s  = 2'b11;
    reg [1:0] ior_s  = 2'b11;
    reg [1:0] mem_s  = 2'b11;

    wire io_wr = ~bus_iorq_n & ~bus_wr_n &  bus_m1_n;
    wire io_rd = ~bus_iorq_n & ~bus_rd_n &  bus_m1_n;
    wire mem_d = ~bus_mreq_n & (~bus_rd_n | ~bus_wr_n) & disk_window;

    reg [31:0] ev;
    reg        ev_v;

    always @(posedge clk) begin
        m1_s  <= { m1_s[0],  bus_m1_n };
        iow_s <= { iow_s[0], io_wr };
        ior_s <= { ior_s[0], io_rd };
        mem_s <= { mem_s[0], mem_d };
        ev_v  <= 1'b0;
        if( armed ) begin
            if( m1_s == 2'b10 ) begin                    // fetch M1 (bajada)
                ev <= { 4'd0, 8'd0, bus_addr, 4'd0 };  ev_v <= 1'b1;
            end
            else if( iow_s == 2'b01 ) begin              // fin de OUT
                ev <= { 4'd1, cpu_dout, bus_addr, 4'd0 }; ev_v <= 1'b1;
            end
            else if( ior_s == 2'b01 ) begin              // fin de IN
                ev <= { 4'd2, cpu_din,  bus_addr, 4'd0 }; ev_v <= 1'b1;
            end
            else if( mem_s == 2'b01 ) begin              // acceso al disco
                ev <= { 4'd3, bus_wr_n ? cpu_din : cpu_dout, bus_addr, 4'd0 };
                ev_v <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if( ev_v && armed ) begin
            ring[wp] <= ev;
            wp <= wp + 1'b1;
        end
    end

    // ---------------- disparo ----------------
    // (a) silencio de I/O: el juego colgado NO hace un solo acceso de I/O
    //     durante QUIET_MS => congelamos y el anillo queda con lo de ANTES.
    // (b) boton: para congelar a mano cuando se ve el sintoma en pantalla.
    reg [31:0] quiet = 0;
    reg [1:0]  btn_s = 2'b00;
    // s032c ARREGLO 1 — CALENTAMIENTO. El disparo por silencio NO puede estar
    // vivo desde el reset: en el ARRANQUE hay de sobra 50 ms sin un solo
    // acceso de I/O (init de la FPGA, DDR3, la propia BIOS antes de tocar
    // puertos), asi que el analizador congelaba nada mas encender, volcaba el
    // arranque —que nadie escucha aun— y se quedaba mudo para siempre.
    // Ahora exige ver ARRANCAR LA MAQUINA: hasta que no cuenta WARM_IO
    // accesos de I/O, el silencio no dispara.
    reg [15:0] io_seen = 16'd0;
    wire       warmed  = (io_seen >= WARM_IO);
    always @(posedge clk) begin
        btn_s <= { btn_s[0], trig_manual };
        if( !rst_n ) begin
            quiet <= 0; armed <= 1'b1; io_seen <= 16'd0;
        end
        else if( armed ) begin
            if( iow_s == 2'b01 || ior_s == 2'b01 ) begin
                quiet <= 0;
                if( !warmed ) io_seen <= io_seen + 16'd1;
            end
            else if( warmed ) quiet <= quiet + 1'b1;
            if( (warmed && quiet >= QUIET_TICKS) || btn_s == 2'b01 ) armed <= 1'b0;
        end
    end

    // ---------------- volcado por UART ----------------
    // "TSTART <wp>\n" + 4096 x "<hex32>\n" + "TEND\n" (una sola vez).
    localparam S_IDLE = 3'd0, S_HDR = 3'd1, S_EVENT = 3'd2, S_TAIL = 3'd3, S_DONE = 3'd4;
    reg [2:0]  st = S_IDLE;
    reg [9:0]  baud_cnt = 0;
    reg [3:0]  bit_idx = 0;
    reg [7:0]  cur = 8'hFF;
    reg        sending = 0;
    reg [AW:0] idx = 0;
    reg [3:0]  chr = 0;
    reg [31:0] word_q = 0;
    reg [AW-1:0] rp = 0;

    function [7:0] hexc(input [3:0] v);
        hexc = (v < 10) ? ("0" + {4'd0, v}) : ("a" + {4'd0, v} - 8'd10);
    endfunction

    // cadena de cabecera "TSTART " y de cola "TEND"
    function [7:0] hdrc(input [3:0] i);
        case(i)
        4'd0: hdrc = "T"; 4'd1: hdrc = "S"; 4'd2: hdrc = "T"; 4'd3: hdrc = "A";
        4'd4: hdrc = "R"; 4'd5: hdrc = "T"; default: hdrc = " ";
        endcase
    endfunction
    function [7:0] tailc(input [3:0] i);
        case(i)
        4'd0: tailc = "T"; 4'd1: tailc = "E"; 4'd2: tailc = "N"; 4'd3: tailc = "D";
        default: tailc = 8'h0A;
        endcase
    endfunction

    wire tx_busy = sending;
    reg        push;
    reg [7:0]  push_b;

    always @(posedge clk) begin
        if( !rst_n ) begin
            tx <= 1'b1; sending <= 0; bit_idx <= 0; baud_cnt <= 0;
        end
        else if( sending ) begin
            baud_cnt <= baud_cnt + 1'b1;
            if( baud_cnt == 0 ) begin
                if( bit_idx == 0 )      tx <= 1'b0;
                else if( bit_idx <= 8 ) tx <= cur[bit_idx-1];
                else                    tx <= 1'b1;
            end
            if( baud_cnt == DIV[9:0]-1 ) begin
                baud_cnt <= 0;
                if( bit_idx == 9 ) begin sending <= 0; bit_idx <= 0; end
                else bit_idx <= bit_idx + 1'b1;
            end
        end
        else if( push ) begin
            cur <= push_b; sending <= 1; bit_idx <= 0; baud_cnt <= 0;
        end
        else tx <= 1'b1;
    end

    always @(posedge clk) begin
        push <= 1'b0;
        if( !rst_n ) begin
            st <= S_IDLE; idx <= 0; chr <= 0; rp <= 0;
        end
        else case( st )
        S_IDLE: if( frozen ) begin
                    st <= S_HDR; idx <= 0; chr <= 0; rp <= wp;   // el mas viejo
                end
        S_HDR:  if( !tx_busy && !push ) begin
                    push <= 1'b1;
                    if( chr < 4'd6 )      push_b <= hdrc(chr);
                    else                  push_b <= 8'h0A;
                    if( chr == 4'd6 ) begin st <= S_EVENT; chr <= 0; word_q <= ring[rp]; end
                    else chr <= chr + 1'b1;
                end
        S_EVENT: if( !tx_busy && !push ) begin
                    push <= 1'b1;
                    if( chr < 4'd8 ) push_b <= hexc(word_q[31 - 4*chr -: 4]);
                    else             push_b <= 8'h0A;
                    if( chr == 4'd8 ) begin
                        chr <= 0;
                        rp  <= rp + 1'b1;
                        idx <= idx + 1'b1;
                        word_q <= ring[rp + 1'b1];
                        if( idx == {1'b0, {AW{1'b1}}} ) st <= S_TAIL;
                    end
                    else chr <= chr + 1'b1;
                end
        S_TAIL: if( !tx_busy && !push ) begin
                    push <= 1'b1;
                    push_b <= tailc(chr);
                    if( chr == 4'd4 ) st <= S_DONE;
                    else chr <= chr + 1'b1;
                end
        S_DONE: dump_done <= 1'b1;
        endcase
    end

endmodule
