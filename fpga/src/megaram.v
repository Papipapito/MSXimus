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
    input wire [7:0] map_ext,       // puerto #46 (volatil, V3.5). bit0 = NEO: con
                                    // map_sel=ASCII8 -> NEO-8, con ASCII16 -> NEO-16.
                                    // bit1 = LIN0 (21/09/2026): ROM plana LINEAL EN 0000h
                                    // (megaram_addr = bus_addr, pag.0 incluida): los demos
                                    // V9990 de Edd Biddulph llevan "AB" en +4000h y su ISR
                                    // en 0038h; el programa se pone en la pag.0 con OUT (A8h).
                                    // bit2 = ASCII16-X (23/09/2026, con map_sel=ASCII16): ver abajo.
                                    // bit4 = mitad ALTA (A21=1) de la megaram para los
                                    // modos de registro de 8 bits: lo usa el CARGADOR del
                                    // menu (modo SCC) para llenar los 4 MB; en juego va a 0.
                                    // bit5 = A22 (23/09/2026): con el bit4, el cuarto de 2 MB
                                    // de los 8 MB en el que escribe el cargador; en juego a 0.

    output wire megaram_req,
    output wire megaram_wrt,
    output wire [22:0] megaram_addr,    // 23/09/2026: 8 MB (V3.5: [21:0] = 4 MB; antes [20:0] = 2 MB)

    output wire scc_sound_disable,
    output wire scc_mode_plus,      // SCC-I mode reg (BFFE) bit5: 1 = SCC+ layout
    output wire sccplus_win_en      // SCC+ sound window B800-B8FF active (mode bit5 + bank3 bit7)

);

	//`default_nettype none

    // ------------------------------------------------------------------------
    // V3.5 — MEGARAM DE 4 MB (era 2 MB)
    //
    // Los registros de banco pasan de 8 a 9 bits. En Konami4/SCC/ASCII8 el bit 8
    // es siempre 0 (el software escribe 8 bits: 2 MB es su techo natural). En
    // ASCII16 vuelve el bit 7 del valor escrito (bancos de 16K x 256 = 4 MB), que
    // la v2.0.1 descartaba porque no habia memoria detras. Y los NEO-8/NEO-16
    // (registros de 12 bits en dos escrituras, 5000h-7FFFh) usan 9/8 bits.
    //
    // El bit 21 de la direccion (que mitad de 2 MB) sale de: el registro (ASCII16
    // y NEO), o del bit4 del puerto #46 (el cargador, que llena la megaram en
    // modo SCC con registros de 8 bits). En top.v la mitad baja sigue en el banco
    // C (0x400000, donde siempre estuvo) y la alta va a 0x200000-0x3FFFFF, que el
    // mapper dejo libre al recortarse a 2 MB. Todo lo que hoy funciona con <=2 MB
    // cae en las MISMAS direcciones fisicas que antes.
    //
    // 23/09/2026 (MSXimus Z) — ASCII16-X y 8 MB. https://www.grauw.nl/projects/ascii-x/ascii16-x/
    // Dos paginas de 16K: la 1 en 4000-7FFF (espejo C000-FFFF) y la 2 en 8000-BFFF (espejo
    // 0000-3FFF), es decir, A14 elige la pagina. Registros en TODA direccion XX1P xxxx xxxx xxxx
    // (A13=1, A12 = pagina: 2000/6000/A000/E000 -> 1, 3000/7000/B000/F000 -> 2): el banco es de 12
    // bits, los 8 bajos del DATO y los 4 altos de A11-A8. Aqui se guardan 9 (512 bancos = 8 MB, el
    // cartucho XL); los bits 11-9 se ignoran (dan la vuelta, como en el XL). A 0 en el reset. Es
    // ROM: la FlashROM del XL (borrado y programacion) no se emula, las escrituras fuera de los
    // registros no hacen nada. megaram_addr pasa a 23 bits; el bit 22 lo pone el ASCII16-X o, en
    // los modos de 8 bits, el bit5 del #46 (el cargador, como el bit4 con A21).
    // ------------------------------------------------------------------------

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
    //V3.5: los modos NEO y la mitad alta, registrados por la misma razon.
    reg ff_neo8;
    reg ff_neo16;
    reg ff_hi;
    reg ff_lin0;    //21/09: lineal en 0000h (bit1 del #46)
    reg ff_x;       //23/09: ASCII16-X (bit2 del #46 con map_sel = ASCII16)
    reg ff_a22;     //23/09: A22 del cargador (bit5 del #46)
    always @( posedge clk_27m ) begin
        ff_scc_mode <= ( map_sel == 2'b10 ) ? 1'b1 : 1'b0;
        ff_lin0     <= map_ext[1];
        ff_x        <= ( map_ext[2] == 1 && map_sel == 2'b11 ) ? 1'b1 : 1'b0;
        ff_a22      <= map_ext[5];
        ff_neo8     <= ( map_ext[0] == 1 && map_sel == 2'b01 ) ? 1'b1 : 1'b0;
        ff_neo16    <= ( map_ext[0] == 1 && map_sel == 2'b11 ) ? 1'b1 : 1'b0;
        ff_hi       <= map_ext[4];
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
    //21/09: bajo LIN0 la imagen es ROM pura en 0000h-BFFFh: sin ventana de wave (una imagen que
    //sondee el SCC con reg2=3Fh veria la wave RAM en 9800h-98FFh de su propia ROM). ff_lin0 es FF.
    assign megaram_sel_wave = ( ff_lin0 == 0 && bus_addr[8] == 0 && megaram_mode_b[4] == 0 && (megaram_scc_a == 1 || megaram_scc_b == 1) ) ? 1 : 0;
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

    //SRAM de cartucho (ASCII8/16): vive en los 32KB ALTOS de los 2 MB BAJOS
    //(0x1F8000-0x1FFFFF = segmentos 252-255). Solo activa en modos ASCII y con
    //sram_cfg != 0 (lo escribe el menu al lanzar; los juegos sin tag no la ven).
    //En NEO no hay SRAM (map_ext[0] la apaga).
    wire sram_mode;
    wire sram_hit;
    wire [1:0] sram_pg;
    wire [20:0] sram_addr;
    //registrado por la misma razon que ff_scc_mode: fuera del cono de megaram_req
    reg ff_sram_mode;
    always @( posedge clk_27m ) begin
        ff_sram_mode <= ( map_sel[0] == 1 && map_ext[0] == 0 && map_ext[2] == 0 && sram_cfg != 8'h00 ) ? 1'b1 : 1'b0;
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

    //Direccion de los modos clasicos (Konami4/SCC/ASCII8/ASCII16): 4 ventanas de
    //8K en 4000-BFFF por bus_addr[14:13]; las paginas 0 y 3 aliasan como siempre.
    wire [21:0] std_addr;
    assign std_addr = (bus_addr [14:13] == 2'b10 ) ? { megaram_reg0, bus_addr[12:0] } :
                      (bus_addr [14:13] == 2'b11 ) ? { megaram_reg1, bus_addr[12:0] } :
                      (bus_addr [14:13] == 2'b00 ) ? { megaram_reg2, bus_addr[12:0] } :
                                                     { megaram_reg3, bus_addr[12:0] };

    //NEO-8: 6 ventanas de 8K en 0000-BFFF por bus_addr[15:13] (C000-FFFF no existe
    //en el cartucho: se devuelve la ultima ventana, nunca se selecciona).
    //NEO-16: 3 ventanas de 16K en 0000-BFFF por bus_addr[15:14].
    wire [11:0] neo8_sel;
    wire [11:0] neo16_sel;
    assign neo8_sel  = (bus_addr[15:13] == 3'd0) ? neo_reg0 :
                       (bus_addr[15:13] == 3'd1) ? neo_reg1 :
                       (bus_addr[15:13] == 3'd2) ? neo_reg2 :
                       (bus_addr[15:13] == 3'd3) ? neo_reg3 :
                       (bus_addr[15:13] == 3'd4) ? neo_reg4 :
                                                   neo_reg5;
    assign neo16_sel = (bus_addr[15:14] == 2'd0) ? neo_reg0 :
                       (bus_addr[15:14] == 2'd1) ? neo_reg1 :
                                                   neo_reg2;

    //ASCII16-X: A14=1 -> pagina 1 (4000-7FFF y C000-FFFF), A14=0 -> pagina 2 (8000-BFFF y 0000-3FFF)
    wire [8:0] x_sel;
    assign x_sel = (bus_addr[14] == 1) ? x_reg1 : x_reg2;

    assign megaram_addr =  (map_linear == 1 || ff_lin0 == 1) ? { 7'b0000000, bus_addr } :
                          (sram_hit == 1)    ? { 2'b00, sram_addr } :
                          (ff_x == 1)        ? { x_sel, bus_addr[13:0] } :
                          (ff_neo8 == 1)     ? { 1'b0, neo8_sel[8:0], bus_addr[12:0] } :
                          (ff_neo16 == 1)    ? { 1'b0, neo16_sel[7:0], bus_addr[13:0] } :
                                               { ff_a22, std_addr[21] | ff_hi, std_addr[20:0] };

    reg [8:0] megaram_reg0;
    reg [8:0] megaram_reg1;
    reg [8:0] megaram_reg2;
    reg [8:0] megaram_reg3;
    reg [7:0] megaram_mode_a;
    reg [7:0] megaram_mode_b;
    reg [3:0] sram_en;              // SRAM mapeada por ventana 8K (4000/6000/8000/A000)
    reg [1:0] sram_page0;           // pagina SRAM por ventana (Koei 32KB = 4 paginas 8K)
    reg [1:0] sram_page1;
    reg [1:0] sram_page2;
    reg [1:0] sram_page3;
    //NEO: 6 registros de 12 bits (openMSX RomNeo8/RomNeo16: byte bajo en la
    //direccion PAR, nibble alto en la IMPAR; todos a 0 en el reset)
    reg [11:0] neo_reg0;
    reg [11:0] neo_reg1;
    reg [11:0] neo_reg2;
    reg [11:0] neo_reg3;
    reg [11:0] neo_reg4;
    reg [11:0] neo_reg5;
    //ASCII16-X: banco de cada pagina, 9 de los 12 bits (8 MB)
    reg [8:0] x_reg1;
    reg [8:0] x_reg2;

    always @( posedge clk_27m ) begin
        if (bus_reset_n == 0) begin
            megaram_reg0	<= 9'h000;
            megaram_reg1	<= 9'h001;
            megaram_reg2	<= 9'h002;
            megaram_reg3	<= 9'h003;
            megaram_mode_a  <= 8'h00;
            megaram_mode_b  <= 8'h00;
            sram_en         <= 4'b0000;
            sram_page0      <= 2'b00;
            sram_page1      <= 2'b00;
            sram_page2      <= 2'b00;
            sram_page3      <= 2'b00;
            neo_reg0        <= 12'h000;
            neo_reg1        <= 12'h000;
            neo_reg2        <= 12'h000;
            neo_reg3        <= 12'h000;
            neo_reg4        <= 12'h000;
            neo_reg5        <= 12'h000;
            x_reg1          <= 9'h000;
            x_reg2          <= 9'h000;
        end
        else if (scc_wrt == 1) begin
            if (ff_x == 1) begin
                //ASCII16-X (23/09): registro en toda direccion con A13=1, A12 = pagina,
                //banco = {A8, dato} (A11-A9 se ignoran: 8 MB). Sin registros de modo ni SRAM.
                if (bus_addr[13] == 1) begin
                    if (bus_addr[12] == 0) x_reg1 <= { bus_addr[8], cpu_dout };
                    else                   x_reg2 <= { bus_addr[8], cpu_dout };
                end
            end
            else if (map_ext[0] == 1 && map_sel[0] == 1) begin
                //NEO-8 / NEO-16 (V3.5). Registros SOLO en 5000h-7FFFh (donde los
                //situa la especificacion; openMSX no comprueba la pagina, pero
                //ningun software escribe los bancos fuera de ahi). Direccion par
                //= byte bajo, impar = nibble alto. Sin registros de modo ni SRAM.
                if (bus_addr[15:14] == 2'b01 && bus_addr[13:12] != 2'b00) begin
                    if (map_sel[1] == 0) begin
                        //NEO-8: 5000/5800/6000/6800/7000/7800 -> ventanas 0..5
                        case (bus_addr[13:11])
                            3'd2: neo_reg0 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg0[7:0] } : { neo_reg0[11:8], cpu_dout };
                            3'd3: neo_reg1 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg1[7:0] } : { neo_reg1[11:8], cpu_dout };
                            3'd4: neo_reg2 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg2[7:0] } : { neo_reg2[11:8], cpu_dout };
                            3'd5: neo_reg3 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg3[7:0] } : { neo_reg3[11:8], cpu_dout };
                            3'd6: neo_reg4 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg4[7:0] } : { neo_reg4[11:8], cpu_dout };
                            3'd7: neo_reg5 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg5[7:0] } : { neo_reg5[11:8], cpu_dout };
                            default: ;
                        endcase
                    end
                    else begin
                        //NEO-16: 5000/6000/7000 -> ventanas 0..2 (5800/6800/7800 se ignoran)
                        case (bus_addr[13:11])
                            3'd2: neo_reg0 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg0[7:0] } : { neo_reg0[11:8], cpu_dout };
                            3'd4: neo_reg1 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg1[7:0] } : { neo_reg1[11:8], cpu_dout };
                            3'd6: neo_reg2 <= bus_addr[0] ? { cpu_dout[3:0], neo_reg2[7:0] } : { neo_reg2[11:8], cpu_dout };
                            default: ;
                        endcase
                    end
                end
            end
            else if (map_sel == 2'b00) begin
                //Konami4 (sin SCC): regs de banco 6000/8000/A000, banco 0 FIJO
                //en 4000-5FFF. Sin regs de modo (7FFE/BFFE ignorados = ROM pura,
                //inmune a los pokes anticopia de Konami). Slot2Mode=00 via SWIO
                //smart command #0D (Ext1+Ext2); el por-defecto tras reset.
                case (bus_addr[15:11])
                    //Mapped I/O port access on 6000-67FFh ... Bank register write
                    5'b01100: begin
                        megaram_reg1 <= { 1'b0, cpu_dout };
                    end
                    //Mapped I/O port access on 8000-87FFh ... Bank register write
                    5'b10000: begin
                        megaram_reg2 <= { 1'b0, cpu_dout };
                    end
                    //Mapped I/O port access on A000-A7FFh ... Bank register write
                    5'b10100: begin
                        megaram_reg3 <= { 1'b0, cpu_dout };
                    end
                endcase
            end
            else if (map_sel == 2'b10) begin
                case (bus_addr[15:11])
                    //Mapped I/O port access on 5000-57FFh ... Bank register write
                    5'b01010: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg0 <= { 1'b0, cpu_dout };
                        end
                    end
                    //Mapped I/O port access on 7000-77FFh ... Bank register write
                    5'b01110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg1 <= { 1'b0, cpu_dout };
                        end
                    end
                    //Mapped I/O port access on 9000-97FFh ... Bank register write
                    5'b10010: begin
                        if (megaram_mode_b[4] == 0 ) begin
                            megaram_reg2 <= { 1'b0, cpu_dout };
                        end
                    end
                    //Mapped I/O port access on B000-B7FFh ... Bank register write
                    5'b10110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg3 <= { 1'b0, cpu_dout };
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
                            megaram_reg0 <= { 1'b0, cpu_dout };
                            sram_en[0] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page0 <= cpu_dout[1:0];
                        end
                        //ASC8K / 6800-6FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg1 <= { 1'b0, cpu_dout };
                            sram_en[1] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page1 <= cpu_dout[1:0];
                        end
                        //ASC16K / 6000-67FFh (ventana 4000-7FFF = regs internos 0+1)
                        else if (bus_addr[11] == 0) begin
                            // v2.0.1 (bug #24 + Aleste2 2MB en placa): el banco
                            // 8K se formaba con {bit7, bits5:0} DESCARTANDO el
                            // bit 6 => bancos 16K >=64 aliasaban sobre el 1er MB.
                            // V3.5: los 8 bits enteros + mitad = 4 MB (256 bancos
                            // de 16K), que es lo que hay detras desde ahora.
                            megaram_reg0 <= { cpu_dout[7:0], 1'b0 };
                            megaram_reg1 <= { cpu_dout[7:0], 1'b1 };
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
                            megaram_reg2 <= { 1'b0, cpu_dout };
                            sram_en[2] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page2 <= cpu_dout[1:0];
                        end
                        //ASC8K / 7800-7FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg3 <= { 1'b0, cpu_dout };
                            sram_en[3] <= ( sram_cfg != 8'h00 && (cpu_dout & sram_cfg) != 8'h00 ) ? 1'b1 : 1'b0;
                            sram_page3 <= cpu_dout[1:0];
                        end
                        //ASC16K / 7000-77FFh (ventana 8000-BFFF = regs internos 2+3)
                        else if (bus_addr[11] == 0) begin
                            // V3.5: mismo cambio que en la ventana 6000h (8 bits + mitad)
                            megaram_reg2 <= { cpu_dout[7:0], 1'b0 };
                            megaram_reg3 <= { cpu_dout[7:0], 1'b1 };
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
