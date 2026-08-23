// ============================================================================
//  sdc_bridge.v — el ESP32-S3 lee la SD a traves del FPGA (destino SDC = 3)
//
//  POR QUE EXISTE
//  --------------
//  La tarjeta SD cuelga del FPGA; el S3 no la toca fisicamente. Para que el
//  lanzador pueda listar ficheros hace falta que el S3 pida sectores y el FPGA
//  se los sirva. El transporte YA estaba (mcu_spi_new expone un strobe por
//  destino y el 3 es el de SD), pero al otro lado no habia nada:
//  fpga_companion lo tenia cableado a cero — `mcu_sdc_din(8'b00000000)`.
//
//  EL ACCESO ES EXCLUSIVO, NO COMPARTIDO — y eso es lo que lo hace simple
//  --------------------------------------------------------------------------
//  El lanzador corre ANTES de que arranque el MSX. Mientras el S3 manda, el
//  Z80 esta en reset; cuando el S3 suelta, el MSX arranca y la SD es suya para
//  siempre. NO hay acceso concurrente, asi que NO hay arbitro: solo un
//  traspaso de propiedad. Un arbitro aqui seria la clase de cosa que falla una
//  vez cada mil arranques y no hay quien la cace.
//
//  ⚠️ PERRO GUARDIAN, y no es opcional: si el S3 pide el mando y se cuelga (o
//  no esta), la maquina se quedaria SIN ARRANCAR. Pasado WDOG_MS sin trafico
//  del S3 se suelta solo. Un companion averiado tiene que degradar a "MSX
//  normal", nunca a ladrillo.
//
//  PROTOCOLO  (trama SPI: [3][comando][carga...], ver Companion.h)
//  --------------------------------------------------------------------------
//    0 ESTADO   devuelve VERSION, luego {7'b0, busy}, luego {7'b0, hold}
//    1 TOMAR    el S3 toma la SD y RETIENE el Z80
//    2 SOLTAR   suelta la SD; el MSX arranca
//    3 LEER     [lba0][lba1][lba2][lba3] (little endian) -> lanza la lectura
//    4 DATOS    los 512 bytes del sector salen por MISO, uno por byte enviado
//
//  El full duplex va un byte por detras: el dato del byte N se ve en el N+1.
//  Por eso el maestro manda un byte de relleno de mas al final de cada lectura.
// ============================================================================
`default_nettype none

module sdc_bridge #(
    parameter CLK_HZ  = 27_000_000,
    parameter WDOG_MS = 8000            // sin trafico del S3 -> soltar
)(
    input  wire        clk,
    input  wire        reset,

    // ---- lado SPI (destino 3 de mcu_spi) --------------------------------
    input  wire        strobe,          // un byte para nosotros
    input  wire        start,           // ...y es el primero (el comando)
    input  wire [7:0]  din,
    output reg  [7:0]  dout,

    // ---- lado tarjeta (se conecta al sd_reader cuando mandamos nosotros) -
    output reg         rstart,          // pulso de "lee este sector"
    output reg  [31:0] rsector,
    input  wire        rbusy,
    input  wire        rdone,
    // el sector llega byte a byte del sd_reader
    input  wire        outen,
    input  wire [8:0]  outaddr,
    input  wire [7:0]  outbyte,

    input  wire [3:0]  card_stat,       // progreso de arranque de la tarjeta

    // ---- gobierno --------------------------------------------------------
    output reg         hold,            // 1 = el S3 manda: retener el Z80

    // 🚨 QUIEN ENCIENDE LA TARJETA. El sd_reader se queda en STANDBY con rbusy
    // ALTO hasta que alguien le pide init (sd_reader.sv:258), y en el MSX quien
    // lo pide es el Z80 escribiendo un registro (top.v: ff_sd_init |= dato[7]).
    // O sea que el lanzador retenia al Z80 y luego le pedia sectores a una
    // tarjeta que solo ese Z80 sabia arrancar. Ahora lo pide el puente.
    output reg         sd_init          // se queda a 1: es idempotente
);

    localparam VERSION = 8'd1;
    localparam integer WDOG_TICKS = (CLK_HZ / 1000) * WDOG_MS;

    // Buffer del sector. Es NUESTRO y no el dpram del Z80 a proposito: aquel
    // tiene los dos puertos ocupados (Z80 y sd_reader) y compartirlo obligaria
    // a razonar sobre quien lo pisa. 512 bytes de BSRAM son baratos comparados
    // con ese dolor de cabeza.
    reg [7:0] buf_mem [0:511];
    reg [8:0] rd_ptr;

    reg [2:0] cmd;
    reg [2:0] arg;                      // que byte de la carga toca
    reg       leyendo;                  // lectura en vuelo

    reg [31:0] wdog;

    // El sd_reader vuelca el sector segun lo va recibiendo.
    always @(posedge clk) begin
        if (outen) buf_mem[outaddr] <= outbyte;
    end

    always @(posedge clk) begin
        if (reset) begin
            hold <= 1'b0;               // por defecto NO retenemos: sin S3, el
            sd_init <= 1'b0;
            rstart <= 1'b0;             // MSX arranca solo. Degradar a "MSX
            rsector <= 32'd0;           // normal", nunca a ladrillo.
            leyendo <= 1'b0;
            cmd <= 3'd0; arg <= 3'd0; rd_ptr <= 9'd0;
            dout <= 8'd0; wdog <= 32'd0;
        end
        else begin
            rstart <= 1'b0;             // pulso de un ciclo

            // ---- perro guardian --------------------------------------------
            if (hold) begin
                if (wdog >= WDOG_TICKS) hold <= 1'b0;   // el S3 no da senales
                else                    wdog <= wdog + 32'd1;
            end

            if (rdone) leyendo <= 1'b0;

            if (strobe) begin
                wdog <= 32'd0;          // hay trafico: el S3 vive

                if (start) begin
                    cmd <= din[2:0];
                    arg <= 3'd0;
                    rd_ptr <= 9'd0;
                    case (din[2:0])
                        3'd0: dout <= VERSION;
                        // TOMAR: ademas de retener, ENCENDER la tarjeta. No
                        // se retira nunca: el lector solo mira init en STANDBY,
                        // asi que pedirlo de mas no hace nada.
                        3'd1: begin hold <= 1'b1; sd_init <= 1'b1; dout <= 8'h01; end
                        3'd2: begin hold <= 1'b0; dout <= 8'h00; end
                        3'd4: dout <= buf_mem[9'd0];
                        default: dout <= 8'd0;
                    endcase
                end
                else begin
                    arg <= (arg == 3'd7) ? arg : arg + 3'd1;
                    case (cmd)
                    3'd0: begin                     // ESTADO
                        case (arg)
                        3'd0: dout <= {7'b0, leyendo | rbusy};
                        3'd1: dout <= {7'b0, hold};
                        // El progreso de arranque de la tarjeta. Se anade
                        // porque su ausencia costo una ronda entera: "ocupada"
                        // no distingue "leyendo" de "ni siquiera ha arrancado".
                        default: dout <= {3'b0, sd_init, card_stat};
                        endcase
                    end
                    3'd3: begin                     // LEER: 4 bytes de LBA
                        case (arg)
                        3'd0: rsector[ 7: 0] <= din;
                        3'd1: rsector[15: 8] <= din;
                        3'd2: rsector[23:16] <= din;
                        3'd3: begin
                            rsector[31:24] <= din;
                            // Solo se lanza si mandamos NOSOTROS. Si el S3 pide
                            // un sector sin haber tomado el mando, se ignora en
                            // silencio: nunca tocar la tarjeta mientras es del
                            // MSX, que es como se corrompen sistemas de ficheros.
                            if (hold && !leyendo && !rbusy) begin
                                rstart  <= 1'b1;
                                leyendo <= 1'b1;
                            end
                        end
                        default: ;
                        endcase
                        dout <= 8'd0;
                    end
                    3'd4: begin                     // DATOS: 512 bytes
                        rd_ptr <= rd_ptr + 9'd1;
                        dout   <= buf_mem[rd_ptr + 9'd1];
                    end
                    default: dout <= 8'd0;
                    endcase
                end
            end
        end
    end

endmodule

`default_nettype wire
