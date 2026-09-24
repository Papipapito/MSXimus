//--------------------------------------------------------------------------------------------------------
// Module  : sd_dma
// Function: V3.6 (bloque 2 del plan 3.5, la parte que quedaba): DMA de LECTURA de la
//           SD a la RAM. El Z80 hoy vacia el bufer de 512 B con dos INIR (~21 T por
//           byte = 3 ms por bloque) y la tarjeta, que tarda 0,6 ms, espera parada el
//           80 % del tiempo. Con esto el bufer lo vacia el core y el Z80 solo
//           programa destino y cuenta.
//
//   COMO: el Z80 da la orden de lectura por #47 con el bit2 puesto (05h = leer +
//   DMA) tras haber dejado el destino de 23 bits en sdc_ioport (OUT #4F,80h y
//   despues los 3 bytes). Esta FSM (clk_54m, el dominio de la RAM):
//     1. pide congelar la CPU (active) y espera a que el pegamento la pare con el
//        bus en reposo (frz = 1). Sin CPU no hay arbitro que valga: el puerto de
//        RAM de la CPU queda libre y lo usa la DMA por el MISMO camino que el
//        streamer de la flash del arranque (ram_addr/ram_din/ram_write "stream").
//     2. por cada bloque: espera blk_rdy (multibloque: la tarjeta para el reloj en
//        RHOLD) o el fin de la orden (rbusy = 0: el ULTIMO bloque de un CMD18 y el
//        unico de un CMD17 no levantan blk_rdy, van a RDONE); copia los 512 B del
//        bufer (puerto B del dpram, el lado de la tarjeta, ocioso mientras espera)
//        a la RAM, un byte por turno del controlador (~150 ns), y manda buf_ack.
//     3. con rbusy = 0 (CMD12 contestado) y el bufer vaciado, suelta la CPU. El Z80
//        se despierta en la instruccion siguiente al OUT y mira el estado como
//        siempre (bits 1-2 = timeout / CRC).
//   Si la orden acaba con error (timeout o CRC de lectura), el bloque no se copia
//   (seria basura) y la FSM termina igual: nunca se queda colgada.
//
//   V3.6c: DOS MODOS DE DESTINO y CONTADORES DE PATRONES.
//     * Fisico (byte 2 bit7 = 0): 23 bits de RAM, lineal. Lo usa el menu (megaram).
//       23/09/2026: 24 bits; el bit 23 lo pone el byte que arma (81h en vez de 80h).
//     * LOGICO (byte 2 bit7 = 1): bits 15:0 = direccion Z80; el core la traduce
//       con los registros del mapper (FC-FF, que son de solo escritura para el Z80)
//       -> fisica = {00, mapper_reg[pagina][6:0], offset[13:0]} en el banco A. Al
//       cruzar 16 KB pasa a la pagina siguiente, como haria el Z80 escribiendo de
//       seguido. Lo usa el driver de Nextor: el bufer de DOS puede estar en
//       cualquier pagina que sea RAM del mapper (el driver lo comprueba).
//     * Orden con bit3 (count): mientras copia, cuenta los "32 lo hi" (LD (nn),A)
//       igual que classify_addr del menu (SCC 50/90/B0 + 70; Konami 40/80/A0 + 60;
//       ASCII8 68/78 + 60/70; ASCII16 60/70 + 77FF). Bit4 (rst) pone los cuatro
//       contadores y la ventana a cero antes. El analisis del mapper de una ROM sin
//       etiqueta pasa a coste cero: se lee de #4E indices 32-39.
//
//   Reloj: la FSM va en clk_54m; blk_rdy/rbusy/q_b vienen de clk_27m (hermano del
//   PLLA, fase conocida, como todo el pegamento del SD) y las salidas hacia ese lado
//   (buf_addr/buf_rd/ack) se mantienen >= 4 ciclos para que las vea.
//
//   Coste: sin BSRAM (la del 60K esta al 100 %), ~150 registros, nada en el cono de
//   la CPU: el mux de ram_addr sigue siendo "stream ? : cascada", como con la flash.
//--------------------------------------------------------------------------------------------------------
module sd_dma (
    input  wire        clk,            // clk_54m
    input  wire        rstn,           // bus_reset_n
    input  wire        start,          // pulso (dominio 27 MHz, 2 ciclos aqui): orden con DMA
    input  wire [23:0] dest,           // destino (sdc_ioport, estable): fisico 24 bits (23/09/2026) o logico [15:0]
    input  wire        logical,        // V3.6c: 1 = dest es una direccion Z80 (traducir con el mapper)
    input  wire [7:0]  mreg0,          // V3.6c: registros del mapper (FC-FF), paginas 0..3
    input  wire [7:0]  mreg1,
    input  wire [7:0]  mreg2,
    input  wire [7:0]  mreg3,
    input  wire        cnt_en,         // V3.6c: orden bit3 = contar patrones de mapper en esta DMA
    input  wire        cnt_rst,        // V3.6c: orden bit4 = poner los contadores a cero antes
    input  wire        bus_idle,       // CPU sin ciclo en curso y RAM libre: se puede parar
    input  wire        blk_rdy,        // sd_reader: bloque en el bufer, reloj parado
    input  wire        rbusy,          // sd_reader: orden en curso
    input  wire        sd_err,         // rcrc_error | timeout_error
    input  wire [7:0]  buf_q,          // q_b del dpram del sector
    input  wire        ram_busy,       // memory_ctrl
    output reg         active,         // hay una DMA en marcha (pide congelar la CPU)
    output reg         frz,            // CPU congelada: la DMA manda en el puerto de RAM
    output reg  [8:0]  buf_addr,       // direccion del puerto B del dpram
    output reg         buf_rd,         // rden_b
    output reg         ack,            // buf_ack hacia sd_reader (>= 4 ciclos)
    output reg         ram_req,        // = ram_write del camino stream
    output wire [23:0] ram_addr,       // direccion FISICA de la escritura en curso (24 bits desde el 23/09/2026)
    output reg  [7:0]  ram_din,
    output reg  [7:0]  blocks,         // bloques copiados en la ultima orden (depuracion)
    output wire        rfsh_ok,        // CPU congelada Y sin escritura en vuelo: el refresco
                                       // autonomo de memory.v puede disparar (ver abajo)
    output reg  [15:0] cnt_scc,        // V3.6c: contadores de patrones (#4E indices 32-39)
    output reg  [15:0] cnt_kon,
    output reg  [15:0] cnt_a8,
    output reg  [15:0] cnt_a16
);

    localparam [3:0] S_IDLE   = 4'd0,
                     S_FREEZE = 4'd1,   // esperando bus en reposo para parar la CPU
                     S_WAIT   = 4'd2,   // esperando bloque (blk_rdy) o fin (rbusy=0)
                     S_RD1    = 4'd3,   // direccion puesta: dejar que el puerto B la vea
                     S_WR     = 4'd4,   // esperando que el controlador acepte (busy=1)
                     S_WR2    = 4'd5,   // esperando que termine (busy=0)
                     S_ACK    = 4'd6,   // buf_ack a la tarjeta
                     S_LAST   = 4'd7,   // rbusy cayo: ultimo bloque pendiente?
                     S_DONE   = 4'd8,   // soltar la CPU
                     S_GUARD  = 4'd9;   // antes del primer byte: que acabe un refresco en vuelo

    reg [3:0]  st = S_IDLE;
    reg [2:0]  hold = 3'd0;       // temporizador corto (ciclos de 54 MHz)
    reg [7:0]  tmo  = 8'd0;       // margen para que la orden arranque (rbusy suba)
    reg        start_d = 1'b0;
    reg        have_blk = 1'b0;   // se recibio un bloque (rbusy alto tras la orden)
    reg        rbusy_d = 1'b0;
    reg        last_done = 1'b0;  // el bloque final (RDONE) ya se copio
    reg [23:0] paddr = 24'd0;     // destino fisico en curso
    reg [15:0] laddr = 16'd0;     // destino logico en curso (modo logico)
    reg        is_log = 1'b0;     // la orden en curso es logica
    reg        counting = 1'b0;   // la orden en curso cuenta patrones
    reg [7:0]  w1 = 8'd0, w2 = 8'd0;   // ventana: w2 = hace dos bytes, w1 = byte anterior

    wire start_edge = start & ~start_d;
    // REFRESCO (leccion _175/_181 de memory.v): el refresco autonomo sirve en bucle
    // abierto y puede robarle la media a una aceptacion en vuelo -> la escritura se
    // pierde EN SILENCIO. Por eso aqui el refresco solo se permite mientras la DMA
    // espera a la tarjeta (S_WAIT, >= 600 us por bloque: sobra) y NUNCA durante la
    // rafaga de escrituras; y antes del primer byte de cada bloque se dejan pasar
    // ~40 ciclos (S_GUARD) para que un refresco ya lanzado (2 medias) termine.
    assign rfsh_ok = frz && (st == S_WAIT);

    // ---- traduccion logica -> fisica (banco A: {00, segmento[6:0], offset[13:0]}) ----
    wire [7:0] msel = (laddr[15:14] == 2'b00) ? mreg0 :
                      (laddr[15:14] == 2'b01) ? mreg1 :
                      (laddr[15:14] == 2'b10) ? mreg2 : mreg3;
    assign ram_addr = is_log ? { 3'b000, msel[6:0], laddr[13:0] } : paddr;

    // ---- clasificacion del patron "32 lo hi" (misma tabla que classify_addr) ----
    wire        pat   = (w2 == 8'h32);
    wire [7:0]  plo   = w1;
    wire [7:0]  phi   = buf_q;
    wire        lo0   = (plo == 8'h00);
    wire        hit_scc = pat & lo0 & (phi == 8'h50 || phi == 8'h90 || phi == 8'hB0 || phi == 8'h70);
    wire        hit_kon = pat & lo0 & (phi == 8'h40 || phi == 8'h80 || phi == 8'hA0 || phi == 8'h60);
    wire        hit_a8  = pat & lo0 & (phi == 8'h68 || phi == 8'h78 || phi == 8'h60 || phi == 8'h70);
    wire        hit_a16 = pat & ((lo0 & (phi == 8'h60 || phi == 8'h70)) | ((plo == 8'hFF) & (phi == 8'h77)));

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            st       <= S_IDLE;
            active   <= 1'b0;
            frz      <= 1'b0;
            buf_addr <= 9'd0;
            buf_rd   <= 1'b0;
            ack      <= 1'b0;
            ram_req  <= 1'b0;
            paddr    <= 24'd0;
            laddr    <= 16'd0;
            is_log   <= 1'b0;
            counting <= 1'b0;
            w1       <= 8'd0;
            w2       <= 8'd0;
            cnt_scc  <= 16'd0;
            cnt_kon  <= 16'd0;
            cnt_a8   <= 16'd0;
            cnt_a16  <= 16'd0;
            ram_din  <= 8'd0;
            blocks   <= 8'd0;
            hold     <= 3'd0;
            tmo      <= 8'd0;
            start_d  <= 1'b0;
            have_blk <= 1'b0;
            rbusy_d  <= 1'b0;
            last_done <= 1'b0;
        end else begin
            start_d <= start;
            rbusy_d <= rbusy;
            case (st)
                S_IDLE: begin
                    ack     <= 1'b0;
                    buf_rd  <= 1'b0;
                    ram_req <= 1'b0;
                    frz     <= 1'b0;
                    if (start_edge) begin
                        active    <= 1'b1;
                        paddr     <= dest;
                        laddr     <= dest[15:0];
                        is_log    <= logical;
                        counting  <= cnt_en;
                        if (cnt_rst) begin
                            cnt_scc <= 16'd0;
                            cnt_kon <= 16'd0;
                            cnt_a8  <= 16'd0;
                            cnt_a16 <= 16'd0;
                            w1      <= 8'd0;
                            w2      <= 8'd0;
                        end
                        blocks    <= 8'd0;
                        have_blk  <= 1'b0;
                        last_done <= 1'b0;
                        tmo       <= 8'd255;
                        st        <= S_FREEZE;
                    end
                end

                S_FREEZE: begin
                    // el OUT que dio la orden aun esta en curso: esperar a que el
                    // Z80 suelte el bus y no haya acceso a RAM pendiente
                    if (bus_idle) begin
                        frz <= 1'b1;
                        st  <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    ack    <= 1'b0;
                    buf_rd <= 1'b0;
                    if (rbusy) have_blk <= 1'b1;
                    if (blk_rdy) begin
                        tmo      <= 8'd40;
                        st       <= S_GUARD;
                    end else if (!rbusy && rbusy_d == 1'b0 && have_blk) begin
                        // la orden termino (CMD12 contestado o CMD17 completo)
                        st <= S_LAST;
                    end else if (!rbusy && !have_blk) begin
                        // la orden aun no ha arrancado (el strobe llega por el lado
                        // de 27 MHz). Si en 255 ciclos no arranca (tarjeta sin
                        // inicializar), terminar: la FSM nunca se queda colgada
                        if (tmo == 8'd0) st <= S_DONE;
                        else tmo <= tmo - 8'd1;
                    end
                end

                S_LAST: begin
                    // ultimo bloque: esta en el bufer si la orden acabo BIEN y no
                    // se ha copiado ya (RDONE no levanta blk_rdy)
                    if (sd_err || last_done) st <= S_DONE;
                    else begin
                        last_done <= 1'b1;
                        tmo       <= 8'd40;
                        st        <= S_GUARD;
                    end
                end

                S_GUARD: begin
                    // rfsh_ok ya esta a 0 (no estamos en S_WAIT): ningun refresco nuevo;
                    // dejar que termine el que pudiera estar en vuelo y empezar el bloque
                    if (tmo == 8'd0) begin
                        buf_addr <= 9'd0;
                        buf_rd   <= 1'b1;
                        hold     <= 3'd4;
                        st       <= S_RD1;
                    end else
                        tmo <= tmo - 8'd1;
                end

                S_RD1: begin
                    // >= 2 flancos de clk_27m con la direccion puesta: q_b valido
                    if (hold == 3'd0) begin
                        ram_din <= buf_q;
                        ram_req <= 1'b1;
                        // V3.6c: contadores de patrones sobre el flujo de bytes
                        w2 <= w1;
                        w1 <= buf_q;
                        if (counting) begin
                            if (hit_scc) cnt_scc <= cnt_scc + 16'd1;
                            if (hit_kon) cnt_kon <= cnt_kon + 16'd1;
                            if (hit_a8)  cnt_a8  <= cnt_a8  + 16'd1;
                            if (hit_a16) cnt_a16 <= cnt_a16 + 16'd1;
                        end
                        st      <= S_WR;
                    end else
                        hold <= hold - 3'd1;
                end

                S_WR: begin
                    // memory_ctrl acepta en su ventana dl&dh y sube ram_busy; la
                    // direccion y el dato se quedan quietos hasta entonces
                    if (ram_busy) begin
                        ram_req <= 1'b0;
                        st      <= S_WR2;
                    end
                end

                S_WR2: begin
                    if (!ram_busy) begin
                        paddr <= paddr + 24'd1;
                        laddr <= laddr + 16'd1;
                        if (buf_addr == 9'd511) begin
                            buf_rd <= 1'b0;
                            blocks <= blocks + 8'd1;
                            if (last_done) st <= S_DONE;     // era el bloque final
                            else begin
                                ack  <= 1'b1;                // bufer vaciado: siguiente
                                hold <= 3'd4;
                                st   <= S_ACK;
                            end
                        end else begin
                            buf_addr <= buf_addr + 9'd1;
                            hold     <= 3'd4;
                            st       <= S_RD1;
                        end
                    end
                end

                S_ACK: begin
                    // ack >= 4 ciclos (2 flancos de 27 MHz); luego a esperar el
                    // siguiente bloque. blk_rdy tarda unos ciclos en bajar tras el
                    // ack: el hold cubre ese hueco para no releer el mismo bloque
                    if (hold == 3'd0) begin
                        ack <= 1'b0;
                        if (!blk_rdy) st <= S_WAIT;
                    end else
                        hold <= hold - 3'd1;
                end

                S_DONE: begin
                    frz    <= 1'b0;
                    active <= 1'b0;
                    st     <= S_IDLE;
                end

                default: st <= S_IDLE;
            endcase
        end
    end

endmodule
