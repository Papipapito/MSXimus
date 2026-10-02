// flash_bridge.v - MSXimus V3.8 (01/10/2026): la flash SPI de la FPGA, vista desde el MSX, para ACTUALIZAR el core
// (bitstream y pack) sin programador. Es un dispositivo de E/S conmutada (como el de Panasonic): se selecciona
// escribiendo su ID en #40 y entonces los puertos #41-#4F son suyos. ID = 4Dh ('M'); con el seleccionado, #40
// devuelve B2h (el ID invertido, como el resto).
//
//   OUT #41  A[23:16]           OUT #42  A[15:8]   (la direccion va en paginas de 256 bytes)
//   OUT #43  orden              1 = borrar el sector de 4 KB de A[23:12]
//                               2 = programar la pagina A[23:8] (despues, 256 OUT #44; la flash no se borra)
//                               3 = leer desde A[23:8]:00 (despues, IN #44 byte a byte, seguidos)
//                               0 = acabar la lectura
//   OUT #44  dato a programar   IN #44  dato leido (y pide el siguiente)
//   IN  #41  estado             bit0 orden en curso (borrar/programar) o lectura sin dato todavia
//                               bit1 la programacion espera un dato    bit2 hay dato leido
//                               bit3 la flash la usa otro (arranque, cargador de ondas): esperar
//                               bits 7-4 = 1010 (firma: hay puente)
//   OUT #4E / IN #4E  info del menu para el OSD del BL616 (bit0 menu en ingles, bit1 Nextor 3); se guarda hasta
//                     apagar (el reset del MSX no lo borra) y llega al firmware en el estado del iosys.
//
// Usa el modulo `flash` de flash_rw.v (el de guardar los ajustes): su escritura borra el sector y programa los
// bytes que le dan; aqui se le anade programar SIN borrar (write_noerase) y esperar a cada byte (write_din_ok).
// Un borrado es su escritura de siempre con un solo byte FF (programar FF no cambia nada).
// Todo en clk_54m, el reloj del modulo flash; las peticiones del bus se registran una vez (como las de config).
module flash_bridge (
    input             clk,
    input             reset_n,          // de encendido: el reset del MSX no corta una orden a medias
    input             sel,              // config0_ff == B2h
    input      [3:0]  bus_port,         // bus_addr[3:0]
    input             wr_req,           // OUT a #40-#4F (sin mirar sel)
    input             rd_req,           // IN a #40-#4F
    input      [7:0]  bus_din,
    output     [7:0]  dout,             // respuesta de los IN (combinacional, con bus_port)
    output reg [1:0]  info = 2'd0,
    output reg        info_ok = 1'b0,
    input             libre,            // el arranque y el cargador de ondas no usan la flash

    // modulo flash
    output reg        f_wr_start = 1'b0,
    output            f_wr_sel,         // las salidas de escritura de abajo mandan (si no, las de los ajustes)
    output            f_noerase,
    output     [23:0] f_addr,
    output     [7:0]  f_wdata,
    output            f_wdata_ok,
    output            f_wterm,
    input             f_write_busy,
    input      [7:0]  f_write_counter,
    output reg        f_rd_sel = 1'b0,  // el puerto de lectura del modulo es nuestro
    output reg        f_rd = 1'b0,
    output reg        f_term = 1'b0,
    input      [7:0]  f_rdata,
    input             f_data_ready,
    input             f_idle            // el modulo esta en STATE_LOAD_CMD_TO_SEND
);
    reg        wr_r = 1'b0, wr_d = 1'b0, rd_r = 1'b0, rd_d = 1'b0;
    reg [3:0]  port_r = 4'd0, port_rd = 4'd0;
    reg [7:0]  din_r = 8'd0;
    always @(posedge clk) begin
        wr_r <= wr_req & sel; wr_d <= wr_r;
        rd_r <= rd_req & sel; rd_d <= rd_r;
        port_r <= bus_port; din_r <= bus_din;
        if (rd_r) port_rd <= port_r;
    end
    wire wr_stb = wr_r & ~wr_d;                     // principio del OUT
    wire rd_end = ~rd_r & rd_d;                     // FINAL del IN: el Z80 ya tiene el dato

    reg [15:0] a = 16'd0;
    reg        op = 1'b0, op_pend = 1'b0, prog = 1'b0, visto = 1'b0;
    reg        lleno = 1'b0;
    reg [7:0]  wdat = 8'd0, wc_d = 8'd0;

    assign f_wr_sel   = op | op_pend;
    assign f_noerase  = prog;
    assign f_addr     = {a, 8'h00};
    assign f_wdata    = prog ? wdat : 8'hFF;
    assign f_wdata_ok = prog ? (lleno & (wc_d == f_write_counter)) : 1'b1;   // el ciclo en que se lo lleva ya no vale
    assign f_wterm    = ~prog;

    wire rvalid = f_rd_sel & f_data_ready & ~f_term;
    wire [7:0] estado = {4'b1010, ~libre, rvalid, prog & op & ~lleno, op | op_pend | (f_rd_sel & ~rvalid)};
    assign dout = (bus_port == 4'h0) ? 8'hB2 :
                  (bus_port == 4'h1) ? estado :
                  (bus_port == 4'h2) ? a[7:0] :
                  (bus_port == 4'h4) ? f_rdata :
                  (bus_port == 4'hE) ? {5'b0, info_ok, info} : 8'hFF;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            a <= 16'd0; op <= 1'b0; op_pend <= 1'b0; prog <= 1'b0; visto <= 1'b0; lleno <= 1'b0;
            f_wr_start <= 1'b0; f_rd_sel <= 1'b0; f_rd <= 1'b0; f_term <= 1'b0;
        end else begin
            f_wr_start <= 1'b0;
            f_rd <= 1'b0;
            wc_d <= f_write_counter;
            if (wc_d != f_write_counter) lleno <= 1'b0;             // el modulo se ha llevado el byte

            // una orden de escritura espera a que el modulo este libre y nadie mas lea
            if (op_pend && f_idle && !f_write_busy && libre && !f_rd_sel && !f_wr_start) begin
                f_wr_start <= 1'b1;
                op_pend <= 1'b0;
                op <= 1'b1;
                visto <= 1'b0;
            end
            if (op) begin
                if (f_write_busy) visto <= 1'b1;
                else if (visto) begin op <= 1'b0; prog <= 1'b0; end
            end
            // fin de una lectura: terminate hasta que el modulo vuelve a reposo
            if (f_term && f_idle && !f_data_ready) begin f_term <= 1'b0; f_rd_sel <= 1'b0; end
            if (rd_end && port_rd == 4'h4 && rvalid) f_rd <= 1'b1;   // siguiente byte

            if (wr_stb) case (port_r)
                4'h1: a[15:8] <= din_r;
                4'h2: a[7:0]  <= din_r;
                4'h3: if (!op && !op_pend && !f_rd_sel) case (din_r)
                          8'd1: begin op_pend <= 1'b1; prog <= 1'b0; end
                          8'd2: begin op_pend <= 1'b1; prog <= 1'b1; lleno <= 1'b0; end
                          8'd3: if (libre && f_idle && !f_write_busy) begin f_rd_sel <= 1'b1; f_rd <= 1'b1; end
                          default: ;
                      endcase
                      else if (din_r == 8'd0 && f_rd_sel) f_term <= 1'b1;
                4'h4: if (prog && op) begin wdat <= din_r; lleno <= 1'b1; end
                4'hE: begin info <= din_r[1:0]; info_ok <= 1'b1; end
                default: ;
            endcase
        end
    end
endmodule
