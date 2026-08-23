// ============================================================================
//  launcher_svc.v — servicios del lanzador del S3 (destino OSD = 2)
//
//  POR QUE EXISTE
//  --------------
//  El lanzador corre en el ESP32-S3 pero la tele cuelga del FPGA: el S3 no
//  tiene salida HDMI y nunca la tendra. Lo que si puede es MANDAR EL CONTENIDO
//  y dejar que pinte quien ya sabe — el V9968, que junto con msx2hdmi_v9968 es
//  la cadena de video que mas horas de depuracion lleva encima del proyecto.
//  Reusarla en vez de escribir un compositor nuevo no es pereza: con el CLS al
//  98% un framebuffer propio es pedirle a los dados que fallen.
//
//  LA CLAVE QUE LO HACE BARATO
//  ---------------------------
//  El V9968 NO se habla con ciclos de I/O del Z80: tiene un bus valid/ready
//  limpio (top.v:1902). Asi que no hay que falsificar un Z80 — basta un mux
//  entre v9968_cpu_glue y este modulo. Y el VDP cuelga de rst86_n, NO de
//  esp_boot_ok: mientras retenemos el Z80 en reset, el VDP y el HDMI siguen
//  vivos. Esa es toda la idea.
//
//  PROTOCOLO  (trama SPI: [2][comando][carga...])
//  --------------------------------------------------------------------------
//    0 ESTADO    VERSION, {7'b0,lleno}, perdidos_hi, perdidos_lo
//    1 ESCRIBIR  [puerto][dato]            una escritura suelta
//    2 VOLCADO   [puerto][d0][d1][d2]...   todo lo que siga, al mismo puerto
//    3 TECLAS    16 bytes = el vector de teclado USB del FPGA (para navegar)
//
//  Los puertos son bus_address[2:0] = {1'b0, 0x98..0x9B & 3}, igual que hace
//  el glue (v9968_cpu_glue.v:98). 0=datos VRAM, 1=registro, 2=paleta,
//  3=registro indirecto.
//
//  CONTRAPRESION: NO LA HAY, Y POR ESO SE CUENTA
//  --------------------------------------------------------------------------
//  El SPI no se puede frenar a mitad de trama, asi que si el VDP no traga al
//  ritmo del S3 (~1,7 MB/s a 13,33 MHz) los bytes SE PIERDEN. En vez de
//  suponer que no pasara, se CUENTAN y el S3 los lee con ESTADO. El S3 manda
//  a trozos y consulta. Un contador que puedes mirar vale mas que una
//  estimacion de ancho de banda que nadie ha medido.
// ============================================================================
`default_nettype none

module launcher_svc #(
    parameter FIFO_AW = 8               // 256 entradas
)(
    // ---- dominio del SPI (clk_27m) --------------------------------------
    input  wire         clk,
    input  wire         reset,
    input  wire         strobe,         // un byte para nosotros
    input  wire         start,          // ...y es el primero (el comando)
    input  wire [7:0]   din,
    output reg  [7:0]   dout,
    input  wire [127:0] keys,           // teclado USB del FPGA (ya en clk_27m)

    // ---- dominio del VDP (clk_86) ---------------------------------------
    input  wire        clk_vdp,
    input  wire        rst_vdp_n,
    input  wire        owns,            // 1 = manda el S3 (sdc_bridge.hold)
    output reg  [2:0]  vdp_address,
    output reg         vdp_ioreq,
    output reg         vdp_write,
    output reg         vdp_valid,
    input  wire        vdp_ready,
    output reg  [7:0]  vdp_wdata
);

    localparam [7:0] VERSION = 8'd1;
    localparam DW = 11;                 // {puerto[2:0], dato[7:0]}

    reg [DW-1:0] mem [0:(1<<FIFO_AW)-1];

    // ======================= lado escritura (clk) ===========================
    reg  [7:0]   cmd;
    reg  [3:0]   state;
    reg  [2:0]   port_reg;
    reg  [15:0]  perdidos;
    reg  [127:0] keys_lat;

    reg  [DW-1:0]    push_dat;
    reg              push;

    reg  [FIFO_AW:0] wbin, wgry, rgry_w1, rgry_w2;
    reg              lleno;
    wire [FIFO_AW:0] wbin_nx = wbin + {{FIFO_AW{1'b0}}, (push & ~lleno)};
    wire [FIFO_AW:0] wgry_nx = wbin_nx ^ (wbin_nx >> 1);

    always @(posedge clk) begin
        if (reset) begin
            wbin <= 0; wgry <= 0; rgry_w1 <= 0; rgry_w2 <= 0; lleno <= 1'b0;
        end else begin
            if (push && !lleno) mem[wbin[FIFO_AW-1:0]] <= push_dat;
            wbin    <= wbin_nx;
            wgry    <= wgry_nx;
            rgry_w1 <= rgry;                 // 2FF: puntero de lectura -> aqui
            rgry_w2 <= rgry_w1;
            // el puntero sincronizado va ATRASADO, o sea que la cola parece
            // mas llena de lo que esta: se equivoca del lado seguro.
            lleno   <= (wgry_nx == {~rgry_w2[FIFO_AW:FIFO_AW-1],
                                     rgry_w2[FIFO_AW-2:0]});
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            cmd <= 8'd0; state <= 4'd0; port_reg <= 3'd0;
            perdidos <= 16'd0; dout <= 8'd0;
            push <= 1'b0; push_dat <= {DW{1'b0}};
            keys_lat <= 128'd0;
        end else begin
            push <= 1'b0;

            if (strobe) begin
                if (start) begin
                    cmd   <= din;
                    state <= 4'd0;
                    // se congela el teclado al empezar la lectura: si no, los
                    // 16 bytes podrian salir de dos instantes distintos y el
                    // S3 veria una tecla a medio pulsar.
                    if (din == 8'd3) keys_lat <= keys;
                    if (din == 8'd0) dout <= VERSION;
                end else begin
                    if (state != 4'd15) state <= state + 4'd1;

                    case (cmd)
                    8'd0: begin                       // ESTADO
                        case (state)
                        4'd0: dout <= {7'b0, lleno};
                        4'd1: dout <= perdidos[15:8];
                        4'd2: dout <= perdidos[7:0];
                        default: dout <= 8'd0;
                        endcase
                    end
                    8'd1: begin                       // ESCRIBIR
                        if (state == 4'd0) port_reg <= din[2:0];
                        else if (state == 4'd1) begin
                            push     <= 1'b1;
                            push_dat <= {port_reg, din};
                            if (lleno) perdidos <= perdidos + 16'd1;
                        end
                    end
                    8'd2: begin                       // VOLCADO
                        if (state == 4'd0) port_reg <= din[2:0];
                        else begin
                            push     <= 1'b1;
                            push_dat <= {port_reg, din};
                            if (lleno) perdidos <= perdidos + 16'd1;
                        end
                    end
                    8'd3: begin                       // TECLAS
                        dout <= keys_lat[{state, 3'b000} +: 8];
                    end
                    default: dout <= 8'd0;
                    endcase
                end
            end
        end
    end

    // ======================= lado lectura (clk_vdp) =========================
    reg  [FIFO_AW:0] rbin, rgry, wgry_r1, wgry_r2;
    reg              vacio;
    reg  [DW-1:0]    rdat;
    reg              pop;
    wire [FIFO_AW:0] rbin_nx = rbin + {{FIFO_AW{1'b0}}, pop};
    wire [FIFO_AW:0] rgry_nx = rbin_nx ^ (rbin_nx >> 1);

    reg owns_v1, owns_v2;

    localparam V_IDLE = 2'd0, V_WAIT = 2'd1;
    reg [1:0] vstate;

    always @(posedge clk_vdp) begin
        if (!rst_vdp_n) begin
            rbin <= 0; rgry <= 0; wgry_r1 <= 0; wgry_r2 <= 0; vacio <= 1'b1;
            rdat <= {DW{1'b0}};
            owns_v1 <= 1'b0; owns_v2 <= 1'b0;
            vstate <= V_IDLE;
            vdp_address <= 3'd0; vdp_ioreq <= 1'b0; vdp_write <= 1'b0;
            vdp_valid   <= 1'b0; vdp_wdata <= 8'd0;
            pop <= 1'b0;
        end else begin
            rbin    <= rbin_nx;
            rgry    <= rgry_nx;
            wgry_r1 <= wgry;                 // 2FF: puntero de escritura -> aqui
            wgry_r2 <= wgry_r1;
            vacio   <= (rgry_nx == wgry_r2);
            rdat    <= mem[rbin[FIFO_AW-1:0]];
            owns_v1 <= owns;
            owns_v2 <= owns_v1;
            pop     <= 1'b0;

            case (vstate)
            V_IDLE: begin
                // sin mando no se toca el bus: el mux de top.v ya nos aparta,
                // pero un modulo que no empuja cuando no le toca es una cosa
                // menos que razonar.
                if (!vacio && owns_v2) begin
                    vdp_address <= rdat[10:8];
                    vdp_wdata   <= rdat[7:0];
                    vdp_write   <= 1'b1;
                    vdp_ioreq   <= 1'b1;
                    vdp_valid   <= 1'b1;
                    pop         <= 1'b1;
                    vstate      <= V_WAIT;
                end
            end
            V_WAIT: begin
                if (vdp_ready) begin         // aceptada (v9968_cpu_glue.v:90)
                    vdp_valid <= 1'b0;
                    vdp_ioreq <= 1'b0;
                    vstate    <= V_IDLE;
                end
            end
            default: vstate <= V_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
