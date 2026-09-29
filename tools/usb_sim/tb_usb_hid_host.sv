`timescale 1ns/1ps
// ============================================================================
// tb_usb_hid_host.sv — 28/09/2026: usb_hid_host (nand2mario) + usb_pad_rid contra un dispositivo low-speed modelado
// (usb_ls_dev_model) con latencia de respuesta configurable. Comprueba que los 8 bytes del informe acaban en
// dat[0..7] (dbg_hid_report) tal cual y que game_snes dice lo que toca.
//   +LAT=n    tiempos de bit de latencia del dispositivo (2..6)          [4]   (+LATC=n en ciclos de 12 MHz)
//   +PHASE=n  desfase extra en ns antes de responder (el dispositivo no va con el reloj del host)   [0]
//   +BITPS=n  periodo de bit del dispositivo en ps (666667 nominal; 656667/676667 = -/+1,5 %)      [666667]
//   +DEV=pad  mando 0810 (class 3, sub 0, proto 0, informes con Report ID 01h)   [pad]
//   +DEV=snes mando SNES USB (bytes 0-1 ejes, 5-6 botones)
//   +DEV=kbd  teclado (proto 1)
// Se ejecuta desde fpga/ (el host lee src/usb_direct/usb_hid_host_rom.hex).
// ============================================================================
module tb_usb_hid_host;
    reg clk = 0; always #41.667 clk = ~clk;      // 12 MHz
    reg rst_n = 0;
    tri0 usb_dp;                                  // 15k a masa en el host
    tri1 usb_dm;                                  // 1k5 a 3V3 en el dispositivo low-speed: reposo J

    wire [1:0]  typ; wire report; wire conerr; wire [63:0] rep_dbg; wire [11:0] snes;
    wire [7:0]  kmod, k1, k2, k3, k4, mbtn; wire signed [7:0] mdx, mdy;
    usb_hid_host dut (
        .usbclk(clk), .usbrst_n(rst_n), .usb_dm(usb_dm), .usb_dp(usb_dp),
        .typ(typ), .report(report), .conerr(conerr),
        .key_modifiers(kmod), .key1(k1), .key2(k2), .key3(k3), .key4(k4),
        .mouse_btn(mbtn), .mouse_dx(mdx), .mouse_dy(mdy),
        .game_snes(snes), .game_l(), .game_r(), .game_u(), .game_d(),
        .game_a(), .game_b(), .game_x(), .game_y(), .game_sel(), .game_sta(), .game_lb(), .game_rb(),
        .dbg_hid_report(rep_dbg)
    );

    reg [7:0]  lat = 8'd4; reg [9:0] latc = 10'd32;
    real       phase_ns = 0.0, bit_ns = 666.667; integer phase_i = 0, bitps_i = 666667;
    reg [7:0]  ifc = 8'd3, ifs = 8'd0, ifp = 8'd0;
    reg [63:0] rep = 64'h0000_0F7F_7F80_8001;
    reg [3:0]  rep_len = 4'd8;
    wire [31:0] n_ep1, n_ack, n_rst; wire [7:0] daddr; wire dconf;
    usb_ls_dev_model dev (
        .clk(clk), .dp(usb_dp), .dm(usb_dm), .lat_clk(latc), .phase_ns(phase_ns), .bit_ns(bit_ns),
        .if_class(ifc), .if_subclass(ifs), .if_protocol(ifp),
        .rep(rep), .rep_len(rep_len),
        .n_ep1_in(n_ep1), .n_ack(n_ack), .n_rst(n_rst), .addr(daddr), .configured(dconf)
    );

    integer nrep = 0;
    always @(posedge clk) if (report) nrep = nrep + 1;

    localparam [11:0] UP = 12'h010, DN = 12'h020, LF = 12'h040, RT = 12'h080, A = 12'h100, B = 12'h001,
                      X = 12'h200, Y = 12'h002, SEL = 12'h004, STA = 12'h008, L = 12'h400, R = 12'h800;
    integer fails = 0;
    reg [63:0] devs = "pad";

    // Pone el informe, espera 3 informes recibidos por el host y compara dat[] y game_snes.
    task automatic probe(input [8*26-1:0] what, input [63:0] r, input [11:0] want);
        integer n0, t; reg [63:0] got; reg ok;
        begin
            rep = r; n0 = nrep; t = 0;
            while (nrep < n0 + 3 && t < 60_000_000) begin @(posedge clk); t = t + 1; end   // < 5 s
            repeat (200) @(posedge clk);
            got = rep_dbg;
            ok = (nrep >= n0 + 3) && (got == r) && (snes == want);
            if (!ok) fails = fails + 1;
            $display("%s  %0s dat= %02x %02x %02x %02x %02x %02x %02x %02x  snes=%03x (quiero %03x)%s",
                     ok ? "OK  " : "FAIL", what,
                     got[7:0], got[15:8], got[23:16], got[31:24], got[39:32], got[47:40], got[55:48], got[63:56],
                     snes, want, (nrep < n0 + 3) ? "  SIN INFORMES" : "");
        end
    endtask

    function automatic [63:0] r0810(input [7:0] rz, z, x, y, b5, b6);
        r0810 = {8'h00, b6, b5, y, x, z, rz, 8'h01};
    endfunction
    function automatic [63:0] rsnes(input [7:0] x, y, b5, b6);   // ejes 00/7F/FF en 0-1, 80 80 80, botones 5-6
        rsnes = {8'h00, b6, b5, 8'h80, 8'h80, 8'h80, y, x};
    endfunction

    // 29/09 (60K, V3.7.4): el dispositivo contesta tres IN de EP1 con un ZLP (DATA vacio). El host lo estroba como
    // UN byte 00 (el primero del CRC); con la decision del eje X en el byte 0 eso era IZQUIERDA, y con un mando con
    // Report ID ningun informe posterior la soltaba (nunca trae 7Fh en el byte 0): en el menu, cada seleccion >= 18
    // volvia 18 atras (IZQUIERDA del joystick = pagina anterior) y parecia que la lista no hacia scroll.
    task automatic zlp_burst;
        integer n0, t;
        begin
            rep_len = 4'd0; n0 = n_ep1; t = 0;
            while (n_ep1 < n0 + 3 && t < 60_000_000) begin @(posedge clk); t = t + 1; end
            repeat (200) @(posedge clk);
            $display("     tras %0d ZLP: snes=%03x", n_ep1 - n0, snes);
            rep_len = 4'd8;
        end
    endtask

    integer t0;
    initial begin
        if ($value$plusargs("LAT=%d", lat)) latc = lat * 8;
        if ($value$plusargs("LATC=%d", latc)) ;
        if ($value$plusargs("PHASE=%d", phase_i)) phase_ns = phase_i;            // ns
        if ($value$plusargs("BITPS=%d", bitps_i)) bit_ns = bitps_i / 1000.0;     // ps: 656667 = -1,5 %, 676667 = +1,5 %
        if ($value$plusargs("DEV=%s", devs)) ;
        if (devs == "kbd") begin ifp = 8'd1; rep = 64'h0; end
        else if (devs == "snes") begin rep = rsnes(8'h7F, 8'h7F, 8'h0F, 8'h00); end
        $display("== usb_hid_host + dispositivo %0s, latencia %0d ciclos (%0d.%0d tiempos de bit) + %0d ns, bit de %0d ps",
                 devs, latc, latc / 8, (latc % 8) * 125 / 100, phase_i, bitps_i);
        repeat (10) @(posedge clk); rst_n = 1;

        // enumeracion (200 ms de espera + 2 resets + descriptores): tope 500 ms
        t0 = 0;
        while (!(typ === 2'd1 || typ === 2'd2 || typ === 2'd3) && t0 < 6_000_000) begin @(posedge clk); t0 = t0 + 1; end
        $display("typ=%0d tras %0d ms (resets=%0d, addr=%0d, configured=%0d)", typ, t0 / 12000, n_rst, daddr, dconf);
        while (!dconf && t0 < 6_000_000) begin @(posedge clk); t0 = t0 + 1; end
        if (!dconf) begin $display("FAIL: el dispositivo nunca quedo configurado"); $finish; end

        if (devs == "kbd") begin
            if (typ != 2'd1) begin $display("FAIL typ teclado=%0d", typ); fails = fails + 1; end
            probe("kbd reposo",   64'h0, 12'h000);
            probe("kbd tecla A",  64'h0000_0000_0004_0000, 12'h000);
            if (k1 != 8'h04) begin $display("FAIL key1=%02x", k1); fails = fails + 1; end
        end else if (devs == "snes") begin
            if (typ != 2'd3) begin $display("FAIL typ=%0d", typ); fails = fails + 1; end
            probe("snes reposo",     rsnes(8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
            probe("snes derecha",    rsnes(8'hFF, 8'h7F, 8'h0F, 8'h00), RT);
            probe("snes abajo",      rsnes(8'h7F, 8'hFF, 8'h0F, 8'h00), DN);
            probe("snes boton A",    rsnes(8'h7F, 8'h7F, 8'h2F, 8'h00), A);
            probe("snes reposo 2",   rsnes(8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
            zlp_burst;
            probe("snes tras ZLP",   rsnes(8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        end else begin
            if (typ != 2'd3) begin $display("FAIL typ=%0d", typ); fails = fails + 1; end
            probe("0810 reposo",         r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
            probe("0810 hat derecha",    r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h02, 8'h00), RT);
            probe("0810 hat abajo",      r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h04, 8'h00), DN);
            probe("0810 stick derecha",  r0810(8'h80, 8'h80, 8'hFF, 8'h7F, 8'h0F, 8'h00), RT);
            probe("0810 stick abajo",    r0810(8'h80, 8'h80, 8'h7F, 8'hFF, 8'h0F, 8'h00), DN);
            probe("0810 boton 1",        r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h1F, 8'h00), A);
            probe("0810 boton 2",        r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h2F, 8'h00), B);
            probe("0810 reposo 2",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
            zlp_burst;
            probe("0810 tras ZLP",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
            probe("0810 hat izq tras ZLP", r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h06, 8'h00), LF);
            probe("0810 reposo 3",       r0810(8'h80, 8'h80, 8'h7F, 8'h7F, 8'h0F, 8'h00), 12'h000);
        end
        $display("%0s: %0s latencia %0d ciclos -> %0d fallos (informes=%0d, IN EP1=%0d, ACK=%0d)",
                 fails == 0 ? "RESULTADO OK" : "RESULTADO FAIL", devs, latc, fails, nrep, n_ep1, n_ack);
        $finish;
    end
endmodule
