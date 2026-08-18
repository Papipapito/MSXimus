// ============================================================================
//  msx_mouse.v — raton MSX emulado sobre un raton USB de PC
//
//  El raton MSX NO es de cuadratura: es "inteligente" y habla por handshake
//  con el pin 8 del puerto de joystick. El MSX mueve ese pin y el raton va
//  presentando CUATRO nibbles por los bits 0-3 del puerto A del PSG:
//  X alto, X bajo, Y alto, Y bajo. Los botones van en los bits 4 y 5, activos
//  a nivel BAJO.
//
//  PROTOCOLO TOMADO DE openMSX (src/input/Mouse.cc), no de memoria. Los cuatro
//  detalles que se pierde quien lo escribe de oido:
//
//   1. Hay OCHO fases, no cuatro. Una ronda de sondeo completa son DOS ciclos:
//      el principal (XHIGH1..YLOW1) y uno ALTERNO (XHIGH2..YLOW2). El alterno
//      devuelve deltas a CERO a proposito: es lo que distingue un raton de un
//      trackball, y el software lo usa para detectarlo.
//   2. Se avanza por FLANCO del strobe: las fases *HIGH esperan que BAJE y las
//      *LOW que SUBA. Ojo, la referencia esta escrita por NIVEL — pero es que
//      alli la funcion solo se llama cuando el host ESCRIBE el puerto. Un
//      raton de verdad solo ve el pin, no las escrituras, asi que por nivel la
//      maquina avanzaria SOLA y capturaria el delta antes de que empiece el
//      sondeo (movimiento perdido). Cazado por tb_msx_mouse, prueba 1.
//   3. EL DELTA VA NEGADO. openMSX Mouse.cc:255 — "hostXY is negated when
//      converting to MsxXY". Mover a la derecha da delta NEGATIVO.
//   4. Timeout de 1,5 ms sin actividad -> la fase vuelve a YLOW2, de forma que
//      el siguiente strobe alto arranca en XHIGH1 y cada ronda queda
//      sincronizada. Ese valor sale de la caza del bug #474 de openMSX: tiene
//      que ser MENOR que un frame para que el joytest funcione.
//
//  El delta se entrega saturado a +-127 y se CONSUME del acumulador (no se
//  borra): asi los movimientos lentos no se pierden al dividir por
//  sensibilidad, que es la trampa clasica de un raton USB moderno con mucho
//  mas DPI que uno de MSX.
// ============================================================================
`default_nettype none

module msx_mouse (
    input  wire        clk,            // clk_54m
    input  wire        rst_n,

    // informe del raton USB, YA sincronizado a este dominio
    input  wire        rep_pulse,      // 1 ciclo por informe nuevo
    input  wire signed [7:0] dx,       // delta del host (+ = derecha)
    input  wire signed [7:0] dy,       // delta del host (+ = abajo)
    input  wire [1:0]  btn,            // {derecho, izquierdo}, activo ALTO

    // sensibilidad: el delta se divide por 2^sens antes de entregarlo
    input  wire [2:0]  sens,

    // pin 8 del puerto de joystick (psgPB[4] puerto 1 / psgPB[5] puerto 2)
    input  wire        strobe,

    // lo que el MSX lee en el registro 14 del PSG
    output wire [7:0]  data
);

    // Si algun dia el movimiento sale invertido en placa, este es el unico
    // sitio que hay que tocar. Va a 1 porque es lo que hace openMSX.
    localparam NEGAR_DELTA = 1'b1;

    localparam [2:0] P_XHI1 = 3'd0, P_XLO1 = 3'd1, P_YHI1 = 3'd2, P_YLO1 = 3'd3,
                     P_XHI2 = 3'd4, P_XLO2 = 3'd5, P_YHI2 = 3'd6, P_YLO2 = 3'd7;

    reg [2:0] phase = P_YLO2;

    // Acumuladores (curXRel/curYRel de la referencia). 12 bits con signo dan
    // margen de sobra entre sondeos y permiten guardar el RESTO de la division
    // por sensibilidad.
    reg signed [11:0] cur_x = 12'sd0, cur_y = 12'sd0;
    // Delta ya entregable, en complemento a 2 de 8 bits.
    reg signed  [7:0] rel_x = 8'sd0,  rel_y = 8'sd0;

    // ---- acumulacion de informes -------------------------------------------
    // Saturamos el acumulador para que un arrastre largo sin que nadie lea no
    // lo haga dar la vuelta y salga un salto en direccion contraria.
    localparam signed [11:0] ACC_MAX =  12'sd2047;
    localparam signed [11:0] ACC_MIN = -12'sd2048;

    wire signed [12:0] nx = $signed({cur_x[11], cur_x}) + $signed({{5{dx[7]}}, dx});
    wire signed [12:0] ny = $signed({cur_y[11], cur_y}) + $signed({{5{dy[7]}}, dy});

    // ---- entrega: dividir por sensibilidad, saturar a +-127 -----------------
    wire signed [11:0] sc_x = cur_x >>> sens;
    wire signed [11:0] sc_y = cur_y >>> sens;

    wire signed [7:0] cl_x = (sc_x >  12'sd127) ?  8'sd127 :
                             (sc_x < -12'sd127) ? -8'sd127 : sc_x[7:0];
    wire signed [7:0] cl_y = (sc_y >  12'sd127) ?  8'sd127 :
                             (sc_y < -12'sd127) ? -8'sd127 : sc_y[7:0];

    // lo realmente consumido del acumulador (deja el resto dentro)
    wire signed [11:0] use_x = $signed({{4{cl_x[7]}}, cl_x}) <<< sens;
    wire signed [11:0] use_y = $signed({{4{cl_y[7]}}, cl_y}) <<< sens;

    // ---- timeout de 1,5 ms --------------------------------------------------
    // 54 MHz * 1,5 ms = 81.000 ciclos. Se rearma con cada CAMBIO del strobe,
    // que es el equivalente en hardware al "lastTime" de la referencia (alla
    // se rearma en cada escritura al puerto).
    localparam [16:0] TMO_CY = 17'd81000;
    reg [16:0] tmo = 17'd0;
    reg        strobe_d = 1'b1;
    wire       strobe_chg = (strobe != strobe_d);
    wire       tmo_hit = (tmo >= TMO_CY);

    // ⚠️ El timeout tiene que ser un PULSO, no un estado. La referencia
    // resetea la fase y ACTO SEGUIDO evalua el nivel del strobe en la misma
    // llamada; si aqui se deja como nivel, un strobe quieto en alto mantiene
    // tmo_hit eterno (solo se rearma al CAMBIAR el strobe) y la maquina se
    // queda congelada en YLOW2 para siempre: la primera lectura de cada ronda
    // devuelve el nibble anterior y todo sale corrido una posicion. Cazado por
    // tb_msx_mouse, prueba 1.
    reg        tmo_hit_d = 1'b0;
    wire       tmo_edge = tmo_hit && !tmo_hit_d;

    always @(posedge clk) begin
        if (!rst_n) begin
            tmo <= 17'd0;
            strobe_d <= 1'b1;
            tmo_hit_d <= 1'b0;
        end
        else begin
            strobe_d  <= strobe;
            tmo_hit_d <= tmo_hit;
            if (strobe_chg)      tmo <= 17'd0;
            else if (!tmo_hit)   tmo <= tmo + 17'd1;
        end
    end

    // ---- la maquina ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            phase <= P_YLO2;
            cur_x <= 12'sd0; cur_y <= 12'sd0;
            rel_x <= 8'sd0;  rel_y <= 8'sd0;
        end
        else begin
            // acumular lo que llegue del USB
            if (rep_pulse) begin
                cur_x <= (nx > ACC_MAX) ? ACC_MAX : (nx < ACC_MIN) ? ACC_MIN : nx[11:0];
                cur_y <= (ny > ACC_MAX) ? ACC_MAX : (ny < ACC_MIN) ? ACC_MIN : ny[11:0];
            end

            if (tmo_edge) begin
                // Silencio: resincronizar. La referencia vuelve a YLOW2 (no a
                // XHIGH1) justamente para que el software que se salta la BIOS
                // y no hace el ciclo alterno siga recibiendo deltas en cada
                // ronda.
                phase <= P_YLO2;
            end
            else begin
                case (phase)
                P_XHI1, P_XHI2,
                P_YHI1, P_YHI2: if (strobe_chg && !strobe) phase <= phase + 3'd1;

                P_XLO1, P_XLO2: if (strobe_chg &&  strobe) phase <= phase + 3'd1;

                P_YLO1: if (strobe_chg && strobe) begin
                    // ciclo ALTERNO con deltas a CERO (anti-trackball)
                    phase <= P_XHI2;
                    rel_x <= 8'sd0;
                    rel_y <= 8'sd0;
                end

                P_YLO2: if (strobe_chg && strobe) begin
                    // arranca el ciclo principal: aqui se captura el delta
                    phase <= P_XHI1;
                    rel_x <= NEGAR_DELTA ? -cl_x : cl_x;
                    rel_y <= NEGAR_DELTA ? -cl_y : cl_y;
                    // consumir SOLO lo entregado; el resto se queda para el
                    // siguiente sondeo (si no, con sensibilidad alta los
                    // movimientos lentos no moverian el puntero jamas)
                    if (rep_pulse) begin
                        cur_x <= ((nx > ACC_MAX) ? ACC_MAX : (nx < ACC_MIN) ? ACC_MIN : nx[11:0]) - use_x;
                        cur_y <= ((ny > ACC_MAX) ? ACC_MAX : (ny < ACC_MIN) ? ACC_MIN : ny[11:0]) - use_y;
                    end
                    else begin
                        cur_x <= cur_x - use_x;
                        cur_y <= cur_y - use_y;
                    end
                end
                endcase
            end
        end
    end

    // ---- salida -------------------------------------------------------------
    reg [3:0] nib;
    always @(*) begin
        case (phase)
        P_XHI1, P_XHI2: nib = rel_x[7:4];
        P_XLO1, P_XLO2: nib = rel_x[3:0];
        P_YHI1, P_YHI2: nib = rel_y[7:4];
        default:        nib = rel_y[3:0];
        endcase
    end

    // bits 4/5 = boton izquierdo/derecho, ACTIVOS A NIVEL BAJO
    assign data = {2'b11, ~btn[1], ~btn[0], nib};

endmodule
`default_nettype wire
