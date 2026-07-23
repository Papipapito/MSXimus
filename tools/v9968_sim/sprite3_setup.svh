// ============================================================================
// sprite3_setup.svh — configuracion MODE3 (fiel al sp3test.asm de HRA, que
// SI renderiza en HW) para reproducir el thrashing de la cache de sprites.
// Incluido por tb_sprite3 (shim) y tb_sprite3r (VRAM perfecta).
//
// Registros EXACTOS de sp3test: R#8=0x08, R#20=0x19 (mode3+EPAL+HS),
// SAT@0x7600 (R#5=0xEF,R#11=0x01), SPT@0x8000 (R#6=0x10). Paleta extendida
// por DEFECTO (como sp3test). 16 sprites magnificados SOLAPADOS en Y=40 (el
// colector re-pide los 16 CADA scanline = peor caso); patrones p*16 ->
// 0x8000 + p*2048, que aliasan de dos en dos en la cache (p y p+8).
// Contenido de la SPT DISTINTIVO ({plano,linea}) para que un fetch rancio
// salga como pixel equivocado en el volcado.
// Requiere del TB: tasks vdp_reg, bus_wr, set_wr_ptr, vram_stream_b; ints
// yi_s, yj_s.
// ============================================================================
    vdp_reg(6'd0,  8'h06);     // G4 (SCREEN5)
    vdp_reg(6'd1,  8'h40);     // pantalla ON
    vdp_reg(6'd2,  8'h1F);     // PNT page0
    vdp_reg(6'd7,  8'h07);     // borde
    vdp_reg(6'd8,  8'h08);     // VR=1, SPD=0 -> sprites ON (fiel sp3test)
    vdp_reg(6'd9,  8'h80);     // 212 lineas
    vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd20, 8'h19);     // mode3 (bit3) + EPAL (bit4) + HS (bit0)
    vdp_reg(6'd23, 8'h00);
    vdp_reg(6'd25, 8'h00);
    vdp_reg(6'd26, 8'h00);
    vdp_reg(6'd27, 8'h00);
    vdp_reg(6'd6,  8'h10);     // SPT @ 0x8000
    vdp_reg(6'd5,  8'hEF);     // SAT @ 0x7600 (LOW)
    vdp_reg(6'd11, 8'h01);     // SAT @ 0x7600 (HIGH)

    // SPT: palabras que muestrean los 16 sprites (16 lineas fuente cada uno).
    // Patron del plano p, linea yl -> 0x8000 + p*2048 + yl*128 (todo < 64KB,
    // sin banking). 8 bytes (izq+dcha) distintivos por (p, yl).
    for (yi_s = 0; yi_s < 16; yi_s = yi_s + 1)
        for (yj_s = 0; yj_s < 16; yj_s = yj_s + 1) begin
            // bank = addr[17:14], a14 = addr[13:0]
            set_wr_ptr( ((17'h8000 + yi_s*2048 + yj_s*128) >> 14) & 4'hF,
                        (17'h8000 + yi_s*2048 + yj_s*128) & 17'h3FFF );
            vram_stream_b( {yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], ~yj_s[3:0]} );
        end

    // SAT @0x7600: 16 planos x 8 bytes (layout sp3test: Y(2), MGY, color,
    // X(2), MGX, pattern). Todos en Y=40 (solapan), MGY=48 (magnificado),
    // SZ=0, color=0 (TP=0 opaco, palset 0), MGX=32, pattern=p*16.
    set_wr_ptr( (17'h7600 >> 14) & 4'hF, 17'h7600 & 17'h3FFF );
    for (yi_s = 0; yi_s < 16; yi_s = yi_s + 1) begin
        vram_stream_b( 8'd40 );                    // Y lo
        vram_stream_b( 8'h00 );                    // Y hi (SZ=0)
        vram_stream_b( 8'd48 );                    // MGY = 48
        vram_stream_b( 8'h00 );                    // color: TP=0, palset 0
        vram_stream_b( 8'd8 + yi_s[7:0]*8'd12 );   // X lo (escalonada)
        vram_stream_b( 8'h00 );                    // X hi
        vram_stream_b( 8'd32 );                    // MGX = 32
        vram_stream_b( yi_s[7:0]*8'd16 );          // pattern = p*16 -> +p*2048
    end
    vram_stream_b( 8'd216 );                       // terminador Y=216
    vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 );
    vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 );
    vram_stream_b( 8'h00 );
