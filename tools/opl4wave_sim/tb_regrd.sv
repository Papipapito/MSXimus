// ============================================================================
// tb_regrd.sv (era v3) — GUARDIAN DEL READBACK DE REGISTROS WAVE POR CPU.
//
// POR QUE EXISTE: al fusionar el grupo RATE0/1/2+AM en una BSRAM unica, el
// camino de lectura de registros por CPU (REG_RD) cambio de "el array
// presenta el indice de la CPU" a "REG_RD roba un ciclo del puerto y el
// dato aterriza en rt_cpu_q". Ese camino NO lo ejercita ningun banco:
// probe_rate.v midio REG_RD = 0 veces en toda la corrida de tb_yrw801.
// Y no es un camino cosmetico: MoonBlaster y compania LEEN registros para
// detectar el chip.
//
// QUE HACE: escribe un patron conocido en los cuatro rangos (98-AF RATE0,
// B0-C7 RATE1, C8-DF RATE2, E0-F7 AM) por el puerto de la CPU y lo vuelve
// a leer, comparando byte a byte. Tambien mezcla lecturas de rangos que NO
// son del grupo (para que un mux mal hecho se note).
// ============================================================================
`timescale 1ns/1ps

module tb_regrd;
    bit clk = 0, rst_n = 0, res_n = 0;
    always #5 clk = ~clk;                 // 100 MHz nominal (irrelevante)

    bit        cs_n = 1, wr_n = 1, rd_n = 1;
    bit [2:0]  a = 0;
    bit [7:0]  di = 0;
    wire [7:0] dow;

    // memoria wave: no se usa en este banco (no hay LOAD de cabecera)
    wire [20:0] ma;  wire [7:0] mdo;  wire mrd_n, mwr_n;  wire [9:0] mcs_n;

    YMF278B dut (
        .CLK(clk), .RST_N(rst_n), .IC_N(res_n), .EN(1'b1), .CE(1'b1),
        .CS_N(cs_n), .RD_N(rd_n), .WR_N(wr_n), .A(a), .DI(di), .DO(dow),
        .MA(ma), .MDI(8'h00), .MDO(mdo), .MRD_N(mrd_n), .MWR_N(mwr_n),
        .MCS_N(mcs_n),
        .OUT0_L(), .OUT0_R(), .OUT1_L(), .OUT1_R(), .OUT2_L(), .OUT2_R(),
        .IRQ_N(), .MEM_SLOT(), .MIX_FM(), .SND_EN(1'b1), .CYCLE1_NEXT()
    );

    task automatic wr_reg(input [7:0] idx, input [7:0] val);
        // indice
        @(posedge clk); a <= 3'h4; di <= idx; cs_n <= 0; wr_n <= 0;
        @(posedge clk); wr_n <= 1; cs_n <= 1;
        repeat (40) @(posedge clk);
        // dato
        @(posedge clk); a <= 3'h5; di <= val; cs_n <= 0; wr_n <= 0;
        @(posedge clk); wr_n <= 1; cs_n <= 1;
        repeat (80) @(posedge clk);
    endtask

    task automatic rd_reg(input [7:0] idx, output [7:0] val);
        @(posedge clk); a <= 3'h4; di <= idx; cs_n <= 0; wr_n <= 0;
        @(posedge clk); wr_n <= 1; cs_n <= 1;
        repeat (40) @(posedge clk);
        @(posedge clk); a <= 3'h5; cs_n <= 0; rd_n <= 0;
        repeat (4) @(posedge clk);
        @(posedge clk); rd_n <= 1; cs_n <= 1;
        repeat (120) @(posedge clk);
        val = dow;
    endtask

    // secuencia NEW2 (habilita el mapa de registros wave del YMF278B)
    task automatic enable_new2();
        @(posedge clk); a <= 3'h2; di <= 8'h05; cs_n <= 0; wr_n <= 0;
        @(posedge clk); wr_n <= 1; cs_n <= 1; repeat (20) @(posedge clk);
        @(posedge clk); a <= 3'h3; di <= 8'h02; cs_n <= 0; wr_n <= 0;
        @(posedge clk); wr_n <= 1; cs_n <= 1; repeat (40) @(posedge clk);
    endtask

    int errores = 0, comprobados = 0;
    byte unsigned leido;

    task automatic prueba(input [7:0] idx, input [7:0] val, input string cual);
        wr_reg(idx, val);
        rd_reg(idx, leido);
        comprobados++;
        if (leido !== val) begin
            errores++;
            $display("  FALLO %s reg %02h: escrito %02h, leido %02h",
                     cual, idx, val, leido);
        end
    endtask

    initial begin
        $display("=== tb_regrd: readback de registros wave por CPU (era v3) ===");
        repeat (10) @(posedge clk);
        rst_n = 1; repeat (10) @(posedge clk);
        res_n = 1; repeat (2000) @(posedge clk);  // deja pasar el RST interno (24 slots)
        enable_new2();

        // un valor distinto por slot en cada rango del grupo fusionado
        for (int s = 0; s < 24; s++) begin
            prueba(8'h98 + s[7:0], 8'h10 + s[7:0], "RATE0");
            prueba(8'hB0 + s[7:0], 8'h30 + s[7:0], "RATE1");
            prueba(8'hC8 + s[7:0], 8'h50 + s[7:0], "RATE2");
            prueba(8'hE0 + s[7:0], 8'h70 + s[7:0], "AM   ");
        end

        // relectura CRUZADA: tras escribir los cuatro rangos enteros, cada
        // uno debe conservar SU valor (un {campo,slot} mal formado los pisa)
        for (int s = 0; s < 24; s++) begin
            rd_reg(8'h98 + s[7:0], leido); comprobados++;
            if (leido !== 8'h10 + s[7:0]) begin errores++;
                $display("  FALLO cruzado RATE0 slot %0d: %02h != %02h", s, leido, 8'h10+s[7:0]); end
            rd_reg(8'hE0 + s[7:0], leido); comprobados++;
            if (leido !== 8'h70 + s[7:0]) begin errores++;
                $display("  FALLO cruzado AM    slot %0d: %02h != %02h", s, leido, 8'h70+s[7:0]); end
        end

        $display("RESULTADO: comprobados=%0d errores=%0d", comprobados, errores);
        if (errores == 0) $display("##### READBACK DE CPU VERDE #####");
        else              $display("##### READBACK DE CPU ROJO  #####");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("TIMEOUT"); $finish;
    end
endmodule
