module megaram_scc(
    input wire clk_27m,
    input wire bus_reset_n,
    input wire [15:0] bus_addr,
    input wire [7:0] cpu_dout,
    input wire bus_rd_n,
    input wire bus_wr_n,
    input wire scc_req,
    input wire scc_wrt,
    input wire [1:0] map_sel,
    input wire map_linear,
    input wire [7:0] sram_cfg,      // puerto #43: ASCII8 = bit de habilitacion SRAM
                                    // (pow2 >= bancos 8K); ASCII16 = no-cero activa el
                                    // modo "valor==0x10"; 0 = SRAM apagada (defecto)

    output wire megaram_req,
    output wire megaram_wrt,
    output wire [20:0] megaram_addr,

    output wire scc_sound_disable,
    output wire scc_mode_plus,      // SCC-I mode reg (BFFE) bit5: 1 = SCC+ layout
    output wire sccplus_win_en      // SCC+ sound window B800-B8FF active (mode bit5 + bank3 bit7)

);

	//`default_nettype none

    assign scc_sound_disable = megaram_mode_b[4];
    assign scc_mode_plus = megaram_mode_b[5];
    assign sccplus_win_en = ( megaram_mode_b[5] == 1 && megaram_reg3[7] == 1 ) ? 1 : 0;

    //Mapped I/O port access on 7FFE-7FFFh / BFFE-BFFFh ... Write protect / SPC mode register
    wire megaram_3fe;
    wire megaram_1ffe;
    assign megaram_3fe = ( bus_addr[10:1] == 10'b1111111111) ? 1 : 0;
    assign megaram_1ffe = ( megaram_3fe == 1 && bus_addr[12:11] == 2'b11 ) ? 1 : 0;

    //Mapped I/O port access on 9800-9FFFh ... Wave memory (solo modo SCC: en
    //Konami4/ASCII un banco 0x3F en reg2 NO debe abrir la ventana de sonido)
    //map_sel REGISTRADO: meterlo directo en este cono alarga el camino
    //combinacional de megaram_req hacia el muestreo a 108MHz del controlador
    //SDRAM (sin restriccion SDC) y rompe en HW real (regresion MG2 v1.7).
    //map_sel es estatico durante el juego: registrarlo es funcionalmente neutro.
    reg ff_scc_mode;
    always @( posedge clk_27m ) begin
        ff_scc_mode <= ( map_sel == 2'b10 ) ? 1'b1 : 1'b0;
    end
    wire megaram_scc_a;
    //ff_scc_mode registrado: fix timing regresion MG2 v1.7
    assign megaram_scc_a = ( ff_scc_mode == 1 && bus_addr[15:11] == 5'b10011 && megaram_mode_b[5] == 0 && megaram_reg2[5:0] == 6'b111111  ) ? 1 : 0;

    //Mapped I/O port access on B800-BFFFh ... Wave memory
    wire megaram_scc_b;
    assign megaram_scc_b = ( ff_scc_mode == 1 && bus_addr[15:11] == 5'b10111 && megaram_mode_b[5] == 1 && megaram_reg3[7] == 1  ) ? 1 : 0;

    //SCC address decoder
    wire megaram_sel_wave;
    reg megaram_sel_memory;
    assign megaram_sel_wave = ( bus_addr[8] == 0 && megaram_mode_b[4] == 0 && (megaram_scc_a == 1 || megaram_scc_b == 1) ) ? 1 : 0;
    //escritura SRAM: en A8 donde este mapeada salvo 6000-7FFF (ahi mandan los
    //regs de banco); en A16 solo en 8000-BFFF (fiel a Hydlide2/A-Train)
    wire sram_wr_ok;
    assign sram_wr_ok = ( sram_hit == 1 && (
                          (map_sel[1] == 1) ? (bus_addr[15:14] == 2'b10)
                                            : (bus_addr[14:13] != 2'b11) ) ) ? 1 : 0;

    assign megaram_sel_memory = ( megaram_sel_wave == 1 ) ? 0 :
                                ( bus_rd_n == 0 ) ? 1 :
                                ( bus_wr_n == 0 && sram_wr_ok == 1 ) ? 1 :
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b010 && megaram_mode_a[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b011 && megaram_mode_a[4] == 1 && megaram_1ffe == 0 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:14] == 2'b01 && megaram_mode_b[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b100 && megaram_mode_b[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b101 && megaram_mode_b[4] == 1 && megaram_1ffe == 0 ) ? 1 : 
                                    0;

    //RAM request
    assign megaram_req = ( megaram_sel_memory == 1 ) ? scc_req : 0;
    assign megaram_wrt = ( megaram_req == 1 && scc_wrt == 1 ) ? 1 : 0;

    //SRAM de cartucho (ASCII8/16): vive en los 32KB ALTOS de la megaram
    //(0x1F8000-0x1FFFFF = segmentos 252-255). Solo activa en modos ASCII y con
    //sram_cfg != 0 (lo escribe el menu al lanzar; los juegos sin tag no la ven).
    wire sram_mode;
    wire sram_hit;
    wire [1:0] sram_pg;
    wire [20:0] sram_addr;
    //registrado por la misma razon que ff_scc_mode: fuera del cono de megaram_req
    reg ff_sram_mode;
    always @( posedge clk_27m ) begin
        ff_sram_mode <= ( map_sel[0] == 1 && sram_cfg != 8'h00 ) ? 1'b1 : 1'b0;
    end
    assign sram_mode = ff_sram_mode;
    assign sram_hit = ( sram_mode == 1 && (
                        (bus_addr[14:13] == 2'b10 && sram_en[0] == 1) ||
                        (bus_addr[14:13] == 2'b11 && sram_en[1] == 1) ||
                        (bus_addr[14:13] == 2'b00 && sram_en[2] == 1) ||
                        (bus_addr[14:13] == 2'b01 && sram_en[3] == 1) ) ) ? 1 : 0;
    assign sram_pg = (bus_addr[14:13] == 2'b10) ? sram_page0 :
                     (bus_addr[14:13] == 2'b11) ? sram_page1 :
                     (bus_addr[14:13] == 2'b00) ? sram_page2 :
                                                  sram_page3;
    //ASCII16: SRAM de 2KB espejada en la ventana; ASCII8: paginas de 8KB
    assign sram_addr = (map_sel[1] == 1) ? { 10'b1111110000, bus_addr[10:0] }
                                         : { 6'b111111, sram_pg, bus_addr[12:0] };

    assign megaram_addr =  (map_linear == 1) ? { 5'b00000, bus_addr} :
                          (sram_hit == 1) ? sram_addr :
                          (bus_addr [14:13] == 2'b10 ) ? { megaram_reg0, bus_addr[12:0] } :
                          (bus_addr [14:13] == 2'b11 ) ? { megaram_reg1, bus_addr[12:0] } :
                          (bus_addr [14:13] == 2'b00 ) ? { megaram_reg2, bus_addr[12:0] } :
                                                         { megaram_reg3, bus_addr[12:0] };

    reg [7:0] megaram_reg0;
    reg [7:0] megaram_reg1;
    reg [7:0] megaram_reg2;
    reg [7:0] megaram_reg3;
    reg [7:0] megaram_mode_a;
    reg [7:0] megaram_mode_b;
    reg [3:0] sram_en;              // SRAM mapeada por ventana 8K (4000/6000/8000/A000)
    reg [1:0] sram_page0;           // pagina SRAM por ventana (Koei 32KB = 4 paginas 8K)
    reg [1:0] sram_page1;
    reg [1:0] sram_page2;
    reg [1:0] sram_page3;

    always @( posedge clk_27m ) begin
        if (bus_reset_n == 0) begin
            megaram_reg0	<= 8'h00;
            megaram_reg1	<= 8'h01;
            megaram_reg2	<= 8'h02;
            megaram_reg3	<= 8'h03;
            megaram_mode_a  <= 8'h00;
            megaram_mode_b  <= 8'h00;
            sram_en         <= 4'b0000;
            sram_page0      <= 2'b00;
            sram_page1      <= 2'b00;
            sram_page2      <= 2'b00;
            sram_page3      <= 2'b00;
        end
        else if (scc_wrt == 1) begin
            if (map_sel == 2'b00) begin
                //Konami4 (sin SCC): regs de banco 6000/8000/A000, banco 0 FIJO
                //en 4000-5FFF. Sin regs de modo (7FFE/BFFE ignorados = ROM pura,
                //inmune a los pokes anticopia de Konami). Slot2Mode=00 via SWIO
                //smart command #0D (Ext1+Ext2); el por-defecto tras reset.
                case (bus_addr[15:11])
                    //Mapped I/O port access on 6000-67FFh ... Bank register write
                    5'b01100: begin
                        megaram_reg1 <= cpu_dout;
                    end
                    //Mapped I/O port access on 8000-87FFh ... Bank register write
                    5'b10000: begin
                        megaram_reg2 <= cpu_dout;
                    end
                    //Mapped I/O port access on A000-A7FFh ... Bank register write
                    5'b10100: begin
                        megaram_reg3 <= cpu_dout;
                    end
                endcase
            end
            else if (map_sel == 2'b10) begin
                case (bus_addr[15:11])
                    //Mapped I/O port access on 5000-57FFh ... Bank register write
                    5'b01010: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg0 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 7000-77FFh ... Bank register write
                    5'b01110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg1 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 9000-97FFh ... Bank register write
                    5'b10010: begin
                        if (megaram_mode_b[4] == 0 ) begin
                            megaram_reg2 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on B000-B7FFh ... Bank register write
                    5'b10110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg3 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 7FFE-7FFFh ... Register write
                    //(mode_a[6] = cerrojo: el menu lo echa al lanzar para que el
                    //juego vea un cartucho SCC puro -- MG2 hace pokes anticopia
                    //a BFFE/7FFE que en una megaram abierta habilitan escritura
                    //y el propio juego se corrompe al cambiar de banco)
                    5'b01111: begin
                        if ( megaram_3fe == 1 && megaram_mode_b[5:4] == 2'b00 && megaram_mode_a[7] == 0 ) begin
                            megaram_mode_a <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on BFFE-BFFFh ... Register write
                    5'b10111: begin
                        if ( megaram_3fe == 1 && megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_a[7] == 0 ) begin
                            megaram_mode_b <= cpu_dout;
                        end
                    end
                endcase
            end
            else begin
                case (bus_addr[15:12])
                    //Mapped I/O port access on 6000-6FFFh ... Bank register write
                    4'b0110: begin
                        //ASC8K / 6000-67FFh
                        if (map_sel[1] == 0 && bus_addr[11] == 0) begin
                            megaram_reg0 <= cpu_dout;
                            sram_en[0] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page0 <= cpu_dout[1:0];
                        end
                        //ASC8K / 6800-6FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg1 <= cpu_dout;
                            sram_en[1] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page1 <= cpu_dout[1:0];
                        end
                        //ASC16K / 6000-67FFh (ventana 4000-7FFF = regs internos 0+1)
                        else if (bus_addr[11] == 0) begin
                            // v2.0.1 (bug #24 + Aleste2 2MB en placa): el banco
                            // 8K se formaba con {bit7, bits5:0} DESCARTANDO el
                            // bit 6 (iba a un registro sin lectores) => bancos
                            // 16K >=64 (el 2o MB) aliasaban sobre el 1o. Ahora
                            // {bits6:0, mitad} = 2MB completos (el limite fisico).
                            megaram_reg0 <= { cpu_dout[6:0], 1'b0 };
                            megaram_reg1 <= { cpu_dout[6:0], 1'b1 };
                            //SRAM ASCII16 (Hydlide2/A-Train): valor exacto 0x10
                            if ( sram_cfg != 8'h00 && cpu_dout == 8'h10 ) begin
                                sram_en[1:0] <= 2'b11;
                            end
                            else begin
                                sram_en[1:0] <= 2'b00;
                            end
                        end
                    end
                    //Mapped I/O port access on 7000-7FFFh ... Bank register write
                    4'b0111: begin
                        //ASC8K / 7000-77FFh
                        if (map_sel[1] == 0 && bus_addr[11] == 0) begin
                            megaram_reg2 <= cpu_dout;
                            sram_en[2] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page2 <= cpu_dout[1:0];
                        end
                        //ASC8K / 7800-7FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg3 <= cpu_dout;
                            sram_en[3] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page3 <= cpu_dout[1:0];
                        end
                        //ASC16K / 7000-77FFh (ventana 8000-BFFF = regs internos 2+3)
                        else if (bus_addr[11] == 0) begin
                            // v2.0.1: mismo fix del bit 6 que en la ventana 6000h
                            megaram_reg2 <= { cpu_dout[6:0], 1'b0 };
                            megaram_reg3 <= { cpu_dout[6:0], 1'b1 };
                            if ( sram_cfg != 8'h00 && cpu_dout == 8'h10 ) begin
                                sram_en[3:2] <= 2'b11;
                            end
                            else begin
                                sram_en[3:2] <= 2'b00;
                            end
                        end
                    end
                endcase
            end
        end
    end

endmodule
