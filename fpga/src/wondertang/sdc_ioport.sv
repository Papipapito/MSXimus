//--------------------------------------------------------------------------------------------------------
// Module  : sdc_ioport
// Function: V3.5c — registros del controlador SD por PUERTOS DE E/S, dentro del
//           dispositivo goauld #48 del SWIO (OUT (#40),#48 y luego #41-#4F).
//           La ventana de memoria de pag.1 (7C00h-7EFFh del slot 3-2) sigue
//           existiendo, byte a byte como siempre: los drivers viejos no se enteran.
//
//   #47 W : orden (bit0 leer, bit1 escribir, bit7 init), igual que SDC_CMD.
//           Ademas pone el puntero del bufer a 0.
//       R : estado {busy, 0, 0, blk_rdy, 1, rcrc, timeout, crc}. El bit3 fijo a 1
//           y los bits 6:5 a 0 sirven de sonda: un core sin puertos devuelve FFh.
//   #48-#4B W : LBA bytes 0..3 (SDC_SADDR).   R: #48 tipo de tarjeta (el tamano,
//               por #4E indices 7-9).
//   #4C   R/W : un byte del bufer de sector; el puntero avanza solo (INIR/OTIR).
//   #4D   W : bloques de la SIGUIENTE orden: 0/1 = CMD17/CMD24; N>1 = CMD18/CMD25.
//             La ventana de memoria lo devuelve a 1 al dar una orden por ella.
//         R : ese valor.
//   #4E   W : indice (0..31) del byte de informacion que devolvera la lectura de
//             #4E (2 = estado, 12 = tipo, 13 = MID, 25-27 = cronometro, 28 = firma).
//   #4F   W : puntero a 0.   R: puntero[7:0] (depuracion).
//           V3.6: OUT #4F,80h arma el registro de DESTINO de la DMA y los TRES
//           OUT #4F siguientes son la direccion fisica de 23 bits (bajo, medio,
//           alto; bit7 del alto = 1 -> MODO LOGICO, V3.6c: los 16 bits bajos son
//           una direccion Z80 que el core traduce con el mapper). Cualquier
//           otro OUT #4F sigue rebobinando el puntero (el
//           driver de Nextor manda 00h). #47 con el bit2: leer + DMA (05h).
//
//   buf_ack: pulso de un ciclo cuando se ha leido o escrito el byte 511 por #4C.
//   En multibloque es el "bufer vaciado / bufer lleno" que sd_reader espera.
//
// ⚠️ V3.5d — TODAS LAS SALIDAS VAN REGISTRADAS, Y LOS DATOS SE CAPTURAN AQUI.
//   No es cosmetica: en el 60K, con el chip al 98% de CLS, el IORQ_n y el WR_n
//   del Z80 son nodos saturados, y de ellos salen desde siempre los peores
//   caminos (los CE de config2/config6/snd_gain, ppi_port_*). Colgar de ahi un
//   decode combinacional se llevo por delante tres campanas enteras:
//     - mux de direccion del bufer -> BSRAM : 0,171 ns (dado 3191)
//     - CE de config2/config6/snd_gain      : -1,55 ns (dado 3187)
//     - CE de sd_wr_fail                    : -0,791 ns (dado 3209)
//   Por eso las ordenes y el LBA salen como PULSO DE UN CICLO mas su dato ya
//   capturado (cmd_val / saddr_val): el padre no vuelve a mirar el bus. El
//   pulso se toma en el FLANCO DE SUBIDA del ciclo de E/S, cuando el Z80 ya ha
//   puesto el dato, y dura un ciclo, asi que tampoco se cuela un dato rancio
//   al soltar el bus. Un ciclo de clk_27m (37 ns) contra un ciclo de E/S del
//   Z80 (~840 ns) no se nota.
//--------------------------------------------------------------------------------------------------------
module sdc_ioport (
    input  wire       clk,
    input  wire       rstn,
    input  wire       sel,          // dispositivo #48 seleccionado (YA REGISTRADO en el padre)
    input  wire [3:0] addr,         // bus_addr[3:0]
    input  wire       rd_n,
    input  wire       wr_n,
    input  wire [7:0] din,          // cpu_dout
    input  wire       force1,       // orden dada por la ventana de memoria -> count = 1
    output reg        cmd_wr,       // pulso de 1 ciclo: OUT #47
    output reg  [7:0] cmd_val,      // el dato de esa orden
    output reg  [3:0] saddr_wr,     // pulsos de 1 ciclo: OUT #48..#4B
    output reg  [7:0] saddr_val,    // el dato de ese byte del LBA
    output reg        data_sel,     // nivel registrado: ciclo IN u OUT #4C
    output reg        data_wr,      // nivel registrado: ciclo OUT #4C
    output reg  [7:0] data_val,     // el dato a escribir en el bufer, ya capturado
    output reg  [8:0] ptr,
    output reg        buf_ack,
    output reg  [7:0] count,
    output reg  [5:0] info_idx,     // V3.6c: 6 bits (32-39 = contadores de patrones)
    output reg [23:0] dma_addr,     // V3.6: destino de la DMA de lectura (fisico o logico); 23/09/2026: 24 bits
    output reg        dma_log       // V3.6c: 1 = dma_addr[15:0] es una direccion Z80 (modo logico)
);

    // ⚠️ ETAPA DE REGISTRO A LA ENTRADA (V3.5d, tras cuatro campanas perdidas).
    // Registrar solo las SALIDAS no bastaba: el decode seguia mirando addr/wr_n
    // del bus, y el enable del registro quedaba al final de la cadena que sale
    // del Z80 (`cpu1/IStatus -> u_sdio/saddr_val/CE`, -0,566 ns en el dado 3251;
    // antes -0,791 en `sd_wr_fail/CE`). Ese nodo ya iba al limite en el diseno
    // original -- en el mismo informe, `IStatus -> ppi_port_a/CE` sale con 0,078
    // ns SIN tocar nada nuestro. Asi que aqui NADA mira el bus directamente:
    // todas las entradas pasan primero por un flip-flop, y de ahi para dentro
    // todo es sincrono. `sel` ya viene registrado del padre, con lo que addr,
    // wr_n y din llegan alineados con el.
    reg [3:0] addr_r = 4'd0;
    reg       wr_n_r = 1'b1;
    reg       rd_n_r = 1'b1;
    reg [7:0] din_r  = 8'd0;
    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            addr_r <= 4'd0;
            wr_n_r <= 1'b1;
            rd_n_r <= 1'b1;
            din_r  <= 8'd0;
        end else begin
            addr_r <= addr;
            wr_n_r <= wr_n;
            rd_n_r <= rd_n;
            din_r  <= din;
        end
    end

    wire w47 = sel && addr_r == 4'h7 && ~wr_n_r;
    wire a4c = sel && addr_r == 4'hC && (~wr_n_r || ~rd_n_r);
    wire w4c = sel && addr_r == 4'hC && ~wr_n_r;
    wire w4d = sel && addr_r == 4'hD && ~wr_n_r;
    wire w4e = sel && addr_r == 4'hE && ~wr_n_r;
    wire w4f = sel && addr_r == 4'hF && ~wr_n_r;
    wire [3:0] w48 = { sel && addr_r == 4'hB && ~wr_n_r,
                       sel && addr_r == 4'hA && ~wr_n_r,
                       sel && addr_r == 4'h9 && ~wr_n_r,
                       sel && addr_r == 4'h8 && ~wr_n_r };

    reg       a4c_d = 1'b0;
    reg       w47_d = 1'b0;
    reg [3:0] w48_d = 4'd0;
    reg       w4f_d = 1'b0;
    reg [1:0] dma_idx = 2'd3;    // 3 = desarmado; 0..2 = byte que toca

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            ptr       <= 9'd0;
            a4c_d     <= 1'b0;
            w47_d     <= 1'b0;
            w48_d     <= 4'd0;
            buf_ack   <= 1'b0;
            count     <= 8'd1;
            info_idx  <= 6'd0;
            cmd_wr    <= 1'b0;
            cmd_val   <= 8'd0;
            saddr_wr  <= 4'd0;
            saddr_val <= 8'd0;
            data_sel  <= 1'b0;
            data_wr   <= 1'b0;
            data_val  <= 8'd0;
            w4f_d     <= 1'b0;
            dma_idx   <= 2'd3;
            dma_addr  <= 24'd0;
            dma_log   <= 1'b0;
        end else begin
            // --- orden (#47): pulso de un ciclo al empezar el OUT, con su dato ---
            w47_d  <= w47;
            cmd_wr <= w47 && !w47_d;
            if (w47 && !w47_d) cmd_val <= din_r;

            // --- LBA (#48-#4B): igual, un pulso por byte ---
            w48_d    <= w48;
            saddr_wr <= w48 & ~w48_d;
            if (|(w48 & ~w48_d)) saddr_val <= din_r;

            // --- bufer (#4C): nivel registrado + dato capturado ---
            data_sel <= a4c;
            data_wr  <= w4c;
            if (w4c) data_val <= din_r;

            // el puntero avanza con la MISMA senal registrada que la direccion,
            // para que direccion, escritura e incremento vayan siempre juntos
            a4c_d   <= data_sel;
            buf_ack <= 1'b0;
            if (a4c_d && !data_sel) begin       // fin del ciclo IN/OUT #4C
                ptr <= ptr + 9'd1;              // 511 + 1 = 0 (9 bits)
                if (ptr == 9'd511) buf_ack <= 1'b1;
            end
            if (w47 || w4f) ptr <= 9'd0;        // la orden (o #4F) rebobina el bufer
            // V3.6: destino de la DMA por #4F (pulso de un ciclo, como la orden)
            w4f_d <= w4f;
            if (w4f && !w4f_d) begin
                // V3.6c: 80h solo ARMA estando desarmado; armado, 80h es un byte mas
                // (el alto con bit7 = modo logico y segmento 0).
                // 23/09/2026: 81h tambien arma y pone el bit 23 del destino fisico (los 4 MB
                // altos de la megaram de 8 MB); 80h lo deja a 0, como siempre.
                if (dma_idx == 2'd3) begin if (din_r[7:1] == 7'b1000000) begin dma_idx <= 2'd0; dma_addr[23] <= din_r[0]; end end
                else if (dma_idx == 2'd0) begin dma_addr[7:0]   <= din_r;      dma_idx <= 2'd1; end
                else if (dma_idx == 2'd1) begin dma_addr[15:8]  <= din_r;      dma_idx <= 2'd2; end
                else if (dma_idx == 2'd2) begin dma_addr[22:16] <= din_r[6:0]; dma_log <= din_r[7]; dma_idx <= 2'd3; end
            end
            if (w4d)        count <= din_r;
            if (force1)     count <= 8'd1;
            if (w4e)        info_idx <= din_r[5:0];
        end
    end

endmodule
