`timescale 1ns/1ps
// ============================================================================
// usb_ls_dev_model.sv — 28/09/2026: modelo de DISPOSITIVO USB low-speed (1,5 Mbps) para simular usb_hid_host.
//
// Contesta lo justo que pide el microcodigo de nand2mario (ukp.s): Get_Descriptor(config) en tres IN de 8 bytes,
// Set_Address, Set_Configuration (ZLP DATA1 en la fase de estado) y los IN a EP1 con el informe `rep`.
// Lo importante es `lat_clk`: los ciclos (8 = un tiempo de bit) que tarda en responder desde el final del EOP del
// host (la norma permite de 2 a 6,5 tiempos de bit). El receptor del host alinea los bits con la instruccion `start`, que se
// ejecuta unos ciclos despues de soltar el bus: un dispositivo rapido puede pillarle el SYNC empezado.
// Nivel: J = D- alto/D+ bajo (reposo low-speed), K = D+ alto/D- bajo, SE0 = los dos bajos.
// ============================================================================
module usb_ls_dev_model (
    input  wire        clk,             // 12 MHz, 8 ciclos por bit (el mismo reloj del host)
    inout  wire        dp,
    inout  wire        dm,
    input  wire [9:0]  lat_clk,         // latencia de respuesta en CICLOS de 12 MHz (8 = un tiempo de bit)
    input  real        phase_ns,        // desfase extra antes de responder (0..83 ns): el dispositivo NO va con el reloj del host
    input  real        bit_ns,          // periodo de bit del dispositivo (666,67 ns nominal; la norma admite +-1,5 %)
    input  wire [7:0]  if_class, if_subclass, if_protocol,
    input  wire [63:0] rep,             // informe de EP1 IN, byte 0 en rep[7:0]
    input  wire [3:0]  rep_len,
    output reg  [31:0] n_ep1_in,        // IN a EP1 contestados con datos
    output reg  [31:0] n_ack,           // ACK recibidos del host
    output reg  [31:0] n_rst,           // reset de bus vistos
    output reg  [7:0]  addr,
    output reg         configured
);
    reg oe = 0, tdp = 0, tdm = 0;
    assign dp = oe ? tdp : 1'bz;
    assign dm = oe ? tdm : 1'bz;

    reg verb = 0;
    initial begin n_ep1_in = 0; n_ack = 0; n_rst = 0; addr = 0; configured = 0; if ($test$plusargs("VERB")) verb = 1; end

    // ---------------- receptor ----------------
    reg [7:0] rxb [0:15];
    integer   rxn;
    reg       last_lvl;
    integer   phase;

    // Espera el primer K (arranque del SYNC). Un SE0 largo (> 2,5 us) es un reset de bus.
    task automatic wait_start;
        integer se0ct; reg in_rst, found;
        begin
            se0ct = 0; in_rst = 0; found = 0;
            while (!found) begin
                @(posedge clk);
                if (dp === 1'b1 && dm === 1'b0) begin last_lvl = 1'b1; phase = 1; found = 1; end
                else if (dp === 1'b0 && dm === 1'b0) begin
                    se0ct = se0ct + 1;
                    if (se0ct == 30 && !in_rst) begin
                        in_rst = 1; n_rst = n_rst + 1; addr = 0; configured = 0;
                        ctrl_len = 0; ctrl_ptr = 0; ep1_tog = 0; pending = 0; pend_addr_v = 0;
                    end
                end else begin se0ct = 0; in_rst = 0; end
            end
        end
    endtask

    // Recibe el paquete (ya en K): muestrea a mitad de bit resincronizando en cada flanco, decodifica NRZI
    // y quita el bit de relleno. Termina al muestrear SE0 y esperar el J final del EOP.
    task automatic rx_packet;
        integer ones, nbits; reg prev, cur, bit_v; reg [7:0] sh; reg done;
        begin
            rxn = 0; nbits = 0; ones = 0; prev = 1'b0; sh = 0; done = 0;
            while (!done) begin
                @(posedge clk);
                cur = dp;
                if (cur !== last_lvl) phase = 1; else phase = phase + 1;
                last_lvl = cur;
                if (phase >= 4 && ((phase - 4) % 8) == 0) begin        // mitad de bit: 3 ciclos tras el flanco y cada 8
                    if (dp === 1'b0 && dm === 1'b0) begin
                        wait (dm === 1'b1); @(posedge clk); done = 1;
                    end else begin
                        bit_v = (cur == prev); prev = cur;
                        if (ones == 6) ones = 0;                       // bit de relleno: se descarta
                        else begin
                            if (bit_v) ones = ones + 1; else ones = 0;
                            sh = {bit_v, sh[7:1]}; nbits = nbits + 1;
                            if (nbits == 8) begin if (rxn < 16) rxb[rxn] = sh; rxn = rxn + 1; nbits = 0; end
                        end
                    end
                end
            end
        end
    endtask

    // ---------------- transmisor ----------------
    reg [7:0] txb [0:15];
    reg       tx_lvl; integer tx_ones;

    task automatic tx_byte(input [7:0] b);
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                if (b[k]) tx_ones = tx_ones + 1; else begin tx_lvl = ~tx_lvl; tx_ones = 0; end
                tdp = tx_lvl; tdm = ~tx_lvl; #(bit_ns);
                if (tx_ones == 6) begin tx_lvl = ~tx_lvl; tx_ones = 0; tdp = tx_lvl; tdm = ~tx_lvl; #(bit_ns); end
            end
        end
    endtask

    // Manda SYNC + txb[0..n-1] + EOP tras `lat_bits` tiempos de bit.
    task automatic tx_packet(input integer n);
        integer i;
        begin
            repeat (lat_clk) @(posedge clk); #(phase_ns);
            tx_lvl = 1'b0; tx_ones = 0; oe = 1;
            tx_byte(8'h80);
            for (i = 0; i < n; i = i + 1) tx_byte(txb[i]);
            tdp = 0; tdm = 0; #(2 * bit_ns);                       // SE0 x2
            tdp = 0; tdm = 1; #(bit_ns);                           // J
            oe = 0; @(posedge clk);
        end
    endtask

    function automatic [15:0] crc16(input integer n);   // sobre txb[1..n] (n bytes de datos tras el PID)
        integer i, k; reg [15:0] c; reg b;
        begin
            c = 16'hFFFF;
            for (i = 1; i <= n; i = i + 1)
                for (k = 0; k < 8; k = k + 1) begin
                    b = txb[i][k] ^ c[15];
                    c = {c[14:0], 1'b0};
                    if (b) c = c ^ 16'h8005;
                end
            crc16 = ~c;
        end
    endfunction

    task automatic tx_data(input reg tog, input integer n);   // txb[1..n] ya cargados
        reg [15:0] c;
        begin
            txb[0] = tog ? 8'h4B : 8'hC3;
            c = crc16(n);
            txb[1 + n] = c[7:0]; txb[2 + n] = c[15:8];
            tx_packet(n + 3);
        end
    endtask

    // ---------------- estado del dispositivo ----------------
    reg [7:0] desc [0:63];
    integer   ctrl_len, ctrl_ptr; reg ctrl_tog;
    reg       ep1_tog;
    integer   pending;                 // 0 nada, 1 trozo de control, 2 fase de estado, 3 dato de EP1
    integer   pend_n;
    reg       pend_addr_v; reg [7:0] pend_addr;
    reg       expect_setup, expect_out;
    reg [7:0] req [0:7];
    reg [6:0] tok_addr; reg [3:0] tok_ep;

    initial begin
        ctrl_len = 0; ctrl_ptr = 0; ctrl_tog = 1; ep1_tog = 0; pending = 0; pend_n = 0;
        pend_addr_v = 0; expect_setup = 0; expect_out = 0;
    end

    task automatic load_config;   // 9 config + 9 interfaz + 9 HID + 7 endpoint = 34 bytes
        begin
            desc[0]=8'h09; desc[1]=8'h02; desc[2]=8'h22; desc[3]=8'h00; desc[4]=8'h01; desc[5]=8'h01; desc[6]=8'h00; desc[7]=8'h80; desc[8]=8'h32;
            desc[9]=8'h09; desc[10]=8'h04; desc[11]=8'h00; desc[12]=8'h00; desc[13]=8'h01; desc[14]=if_class; desc[15]=if_subclass; desc[16]=if_protocol; desc[17]=8'h00;
            desc[18]=8'h09; desc[19]=8'h21; desc[20]=8'h10; desc[21]=8'h01; desc[22]=8'h00; desc[23]=8'h01; desc[24]=8'h22; desc[25]=8'h59; desc[26]=8'h00;
            desc[27]=8'h07; desc[28]=8'h05; desc[29]=8'h81; desc[30]=8'h03; desc[31]=8'h08; desc[32]=8'h00; desc[33]=8'h0A;
            ctrl_len = 34;
        end
    endtask

    task automatic load_device;   // 18 bytes
        begin
            desc[0]=8'h12; desc[1]=8'h01; desc[2]=8'h10; desc[3]=8'h01; desc[4]=8'h00; desc[5]=8'h00; desc[6]=8'h00; desc[7]=8'h08;
            desc[8]=8'h10; desc[9]=8'h08; desc[10]=8'h01; desc[11]=8'h00; desc[12]=8'h06; desc[13]=8'h01; desc[14]=8'h00; desc[15]=8'h00; desc[16]=8'h00; desc[17]=8'h01;
            ctrl_len = 18;
        end
    endtask

    task automatic process_request;
        integer wlen;
        begin
            ctrl_ptr = 0; ctrl_len = 0; ctrl_tog = 1;
            wlen = {req[7], req[6]};
            case (req[1])
            8'h06: begin
                if (req[3] == 8'h01) load_device; else if (req[3] == 8'h02) load_config;
                if (wlen < ctrl_len) ctrl_len = wlen;
            end
            8'h05: begin pend_addr = req[2]; pend_addr_v = 1; end
            8'h09: configured = 1;
            default: ;
            endcase
        end
    endtask

    task automatic handle;
        integer i, n;
        begin
            if (verb) $display("[dev %t] rx %0d bytes: %02x %02x %02x %02x  (addr=%0d conf=%0d)", $time, rxn, rxb[0], rxb[1], rxb[2], rxb[3], addr, configured);
            if (rxn < 2 || rxb[0] != 8'h80) ;
            else case (rxb[1])
            8'h2D, 8'hE1, 8'h69: begin                                   // SETUP / OUT / IN
                tok_addr = rxb[2][6:0]; tok_ep = {rxb[3][2:0], rxb[2][7]};
                if (tok_addr != addr[6:0]) ;
                else if (rxb[1] == 8'h2D) expect_setup = 1;
                else if (rxb[1] == 8'hE1) expect_out = 1;
                else begin                                                // IN
                    if (tok_ep == 4'd0) begin
                        if (ctrl_ptr < ctrl_len) begin
                            n = ctrl_len - ctrl_ptr; if (n > 8) n = 8;
                            for (i = 0; i < n; i = i + 1) txb[1 + i] = desc[ctrl_ptr + i];
                            pending = 1; pend_n = n; tx_data(ctrl_tog, n);
                        end else begin
                            pending = 2; tx_data(1'b1, 0);                // ZLP DATA1: fase de estado
                        end
                    end else if (tok_ep == 4'd1) begin
                        if (configured) begin
                            for (i = 0; i < rep_len; i = i + 1) txb[1 + i] = rep[8*i +: 8];
                            pending = 3; n_ep1_in = n_ep1_in + 1; tx_data(ep1_tog, rep_len);
                        end else begin
                            txb[0] = 8'h5A; tx_packet(1);                 // NAK
                        end
                    end
                end
            end
            8'hC3, 8'h4B: begin                                          // DATA0 / DATA1 del host
                if (expect_setup) begin
                    expect_setup = 0;
                    for (i = 0; i < 8; i = i + 1) req[i] = rxb[2 + i];
                    process_request;
                    txb[0] = 8'hD2; tx_packet(1);                         // ACK
                end else if (expect_out) begin
                    expect_out = 0; txb[0] = 8'hD2; tx_packet(1);
                end
            end
            8'hD2: begin                                                 // ACK del host
                n_ack = n_ack + 1;
                case (pending)
                1: begin ctrl_ptr = ctrl_ptr + pend_n; ctrl_tog = ~ctrl_tog; end
                2: begin if (pend_addr_v) begin addr = pend_addr; pend_addr_v = 0; end end
                3: ep1_tog = ~ep1_tog;
                default: ;
                endcase
                pending = 0;
            end
            default: ;
            endcase
        end
    endtask

    initial begin
        forever begin
            wait_start;
            rx_packet;
            handle;
        end
    end
endmodule
