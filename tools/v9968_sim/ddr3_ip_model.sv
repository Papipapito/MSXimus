// ============================================================================
// ddr3_ip_model.sv — modelo CONDUCTUAL de DDR3_Memory_Interface_Top (solo
// simulacion; en sintesis se compila la IP real de fpga/ddr3/). Reproduce el
// contrato observado por wave_ddr3/v9968_ddr3_backend:
//   - clk_out 74.25MHz autogenerado, ddr_rst un rato al arranque
//   - init_calib_complete tras CALIB_US
//   - cmd 000=write/001=read con cmd_en&cmd_ready; addr en palabras de 16b
//   - write: wr_data[127:0] + wr_data_mask (DM: 1=NO escribir)
//   - read: rd_data_valid con latencia LAT_MIN..LAT_MAX ciclos
//   - plug de fallo: si fail_mode=1 deja de responder lecturas (prueba _95)
// ============================================================================
`timescale 1ns/1ps
module DDR3_Memory_Interface_Top (
    input  wire         memory_clk,
    output wire         pll_stop,
    input  wire         clk,
    input  wire         rst_n,
    output reg          cmd_ready,
    input  wire [2:0]   cmd,
    input  wire         cmd_en,
    input  wire [27:0]  addr,
    output reg          wr_data_rdy,
    input  wire [127:0] wr_data,
    input  wire         wr_data_en,
    input  wire         wr_data_end,
    input  wire [15:0]  wr_data_mask,
    output reg  [127:0] rd_data,
    output reg          rd_data_valid,
    output reg          rd_data_end,
    input  wire         sr_req,
    input  wire         ref_req,
    output wire         sr_ack,
    output wire         ref_ack,
    output reg          init_calib_complete,
    output reg          clk_out,
    input  wire         pll_lock,
    input  wire         burst,
    output reg          ddr_rst,
    output wire [13:0]  O_ddr_addr,
    output wire [2:0]   O_ddr_ba,
    output wire         O_ddr_cs_n,
    output wire         O_ddr_ras_n,
    output wire         O_ddr_cas_n,
    output wire         O_ddr_we_n,
    output wire         O_ddr_clk,
    output wire         O_ddr_clk_n,
    output wire         O_ddr_cke,
    output wire         O_ddr_odt,
    output wire         O_ddr_reset_n,
    output wire [1:0]   O_ddr_dqm,
    inout  wire [15:0]  IO_ddr_dq,
    inout  wire [1:0]   IO_ddr_dqs,
    inout  wire [1:0]   IO_ddr_dqs_n
);

    assign O_ddr_addr = '0; assign O_ddr_ba = '0;
    assign O_ddr_cs_n = 1'b1; assign O_ddr_ras_n = 1'b1;
    assign O_ddr_cas_n = 1'b1; assign O_ddr_we_n = 1'b1;
    assign O_ddr_clk = 1'b0; assign O_ddr_clk_n = 1'b1;
    assign O_ddr_cke = 1'b0; assign O_ddr_odt = 1'b0;
    assign O_ddr_reset_n = 1'b0; assign O_ddr_dqm = 2'b11;
    assign sr_ack = 1'b0; assign ref_ack = 1'b0;
    assign pll_stop = 1'b0;

    parameter int CALIB_US = 20;         // calibracion rapida para el TB
    parameter int LAT_MIN  = 10;         // ciclos clk_out hasta rd_data_valid
    parameter int LAT_MAX  = 18;

    bit fail_mode = 0;                   // el TB lo fuerza via jerarquia
    bit glitch_rdy = 1;                  // _132: readys que caen (refresh &co)

    // clk_out 74.25MHz autogenerado
    initial clk_out = 1'b0;
    always #6.7340 clk_out = ~clk_out;

    // reset + calibracion
    initial begin
        ddr_rst = 1'b1;
        init_calib_complete = 1'b0;
        repeat (50) @(posedge clk_out);
        ddr_rst = 1'b0;
        # (CALIB_US * 1000);
        init_calib_complete = 1'b1;
    end
    // recalibracion si la IP recibe reset externo
    always @(negedge rst_n) begin
        init_calib_complete = 1'b0;
        # (CALIB_US * 1000);
        if (rst_n !== 1'b0) init_calib_complete = 1'b1;
    end

    // memoria por lineas de 128b (indice = addr[27:3] = linea)
    logic [127:0] mem [int unsigned];

    // pipa de lecturas en vuelo (colas paralelas: linea + latencia restante)
    int unsigned rd_line_q[$];
    int          rd_lat_q[$];

    // _132: FIFOs de escritura COMO LA IP REAL — el comando de escritura y
    // su dato entran por interfaces INDEPENDIENTES (cmd_en/cmd_ready y
    // wr_data_en/wr_data_rdy) y el controlador los empareja EN ORDEN. Si el
    // cliente logra colar un lado y pierde el otro (el patron racy viejo),
    // el emparejamiento queda corrido PARA SIEMPRE — exactamente la
    // corrupcion estructurada vista en HW el 23/07.
    int unsigned wcmd_q[$];              // lineas destino (addr[27:3])
    logic [127:0] wdat_d_q[$];           // datos (paralela a wdat_m_q)
    logic [15:0]  wdat_m_q[$];           // mascaras DM

    int lat_lfsr = 7;

    // _132: caida pseudo-aleatoria de los readys (auto-refresh y ZQ de la
    // IP real): cmd_ready cae REF_STALL ciclos cada REF_PERIOD; wr_data_rdy
    // cae con otra fase y ademas a rafagas cortas por LFSR. Un cliente
    // correcto (retener en hasta ver rdy) no pierde nada; el racy pierde
    // operaciones y desincroniza.
    parameter int REF_PERIOD = 380;
    parameter int REF_STALL  = 17;
    int ref_cnt = 0;
    int rdy_lfsr = 29;

    initial begin
        cmd_ready = 1'b1;
        wr_data_rdy = 1'b1;
        rd_data_valid = 1'b0;
        rd_data_end = 1'b0;
        rd_data = '0;
    end

    always @(posedge clk_out) begin
        // readys
        if (glitch_rdy) begin
            ref_cnt = (ref_cnt + 1) % REF_PERIOD;
            rdy_lfsr = (rdy_lfsr * 13 + 7) % 251;
            cmd_ready   <= !(ref_cnt < REF_STALL);
            // wr_data_rdy con fase distinta + rafagas cortas aleatorias
            wr_data_rdy <= !((ref_cnt >= 190 && ref_cnt < 190 + REF_STALL)
                             || (rdy_lfsr < 12));
        end
        else begin
            cmd_ready <= 1'b1; wr_data_rdy <= 1'b1;
        end

        rd_data_valid <= 1'b0;
        rd_data_end   <= 1'b0;
        // compromiso de escrituras: cabeza de ambas FIFOs emparejada en orden
        while (wcmd_q.size() > 0 && wdat_d_q.size() > 0) begin
            automatic int unsigned line = wcmd_q.pop_front();
            automatic logic [127:0] wd = wdat_d_q.pop_front();
            automatic logic [15:0]  wm = wdat_m_q.pop_front();
            automatic logic [127:0] cur = mem.exists(line) ? mem[line] : '0;
            for (int b = 0; b < 16; b++)
                if (!wm[b]) cur[b*8 +: 8] = wd[b*8 +: 8];
            mem[line] = cur;
        end
        // servicio de la cola de lecturas
        for (int i = 0; i < rd_lat_q.size(); i++) rd_lat_q[i] = rd_lat_q[i] - 1;
        if (rd_lat_q.size() > 0 && rd_lat_q[0] <= 0 && !fail_mode) begin
            rd_data <= mem.exists(rd_line_q[0]) ? mem[rd_line_q[0]] : 128'hDEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD_DEAD;
            rd_data_valid <= 1'b1;
            rd_data_end   <= 1'b1;
            void'(rd_line_q.pop_front());
            void'(rd_lat_q.pop_front());
        end
        // aceptar comandos — SOLO con cmd_en && cmd_ready el mismo ciclo
        // (la IP real ignora en silencio lo demas: ese es el contrato)
        if (cmd_en && cmd_ready && init_calib_complete) begin
            if (cmd == 3'b001) begin
                lat_lfsr = (lat_lfsr * 5 + 3) % 97;
                rd_line_q.push_back(addr[27:3]);
                rd_lat_q.push_back(LAT_MIN + (lat_lfsr % (LAT_MAX - LAT_MIN + 1)));
            end
            else if (cmd == 3'b000) begin
                wcmd_q.push_back(addr[27:3]);
            end
        end
        // dato de escritura — interfaz independiente, emparejado por orden
        if (wr_data_en && wr_data_rdy && init_calib_complete) begin
            wdat_d_q.push_back(wr_data);
            wdat_m_q.push_back(wr_data_mask);
        end
    end

endmodule
