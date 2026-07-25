// ============================================================================
// sprite3_setup.svh — configuracion MODE3 de peor caso para reproducir el
// thrashing de la cache de sprites del DEVCON (23/07). Incluido por
// tb_sprite3 (shim) y tb_sprite3r (VRAM perfecta): MISMO setup en ambos.
//
// 16 sprites mode3 magnificados, TODOS solapados en Y=40 (el colector re-pide
// los 16 CADA scanline = peor caso). Patrones repartidos 0x8000+p*2048 (p y
// p+8 aliasan en la cache direct-mapped de 4096 lineas -> thrash). Contenido
// de VRAM DISTINTIVO (byte = {plano, linea}) para que un fetch rancio salga
// como pixel equivocado en el volcado.
//   SAT @0x10000 (R#5=03,R#11=02), SPT @0x8000 (R#6=10), SZ=0 (16 lineas
//   fuente), MGY=48 (magnificado), MGX=32.
// Requiere del TB: tasks vdp_reg, bus_wr, set_wr_ptr, vram_stream_b; ints
// yi_s, yj_s.
// ============================================================================
    vdp_reg(6'd0,  8'h06);     // G4 (SCREEN5)
    vdp_reg(6'd1,  8'h40);     // pantalla ON
    vdp_reg(6'd2,  8'h1F);     // PNT page0
    // _148 FIX 0 — R#8 = [MS][LP][TP][CB][VR][0][SPD][BW].
    // ANTES: 0x2A = 0b0010_1010 -> bit1 = SPD = 1 = SPRITES DESACTIVADOS
    // (vdp_cpu_interface.v:595-599 lo carga en reg_sprite_disable, y
    // vdp_sprite_select_visible_planes.v:222 hace vram_valid & ~reg_sprite_disable:
    // el TB NO generaba NI UN fetch de sprite -> medir el thrashing era imposible).
    // AHORA: 0x08 = 0b0000_1000 -> VR=1, SPD=0, igual que sp3test.asm de HRA.
    vdp_reg(6'd8,  8'h08);     // VR=1, SPD=0 -> sprites ON (de verdad)
    vdp_reg(6'd9,  8'h80);     // 212 lineas
    vdp_reg(6'd7,  8'h00);     // borde negro
    vdp_reg(6'd20, 8'h08);     // R#20 bit3 = sprite_mode3 ON
    vdp_reg(6'd5,  8'h03);     // SAT @ 0x10000
    vdp_reg(6'd11, 8'h02);
    vdp_reg(6'd6,  8'h10);     // SPT @ 0x8000

    // SPT: SOLO las palabras que los 16 sprites muestrean (16 lineas fuente
    // cada uno). Patron del plano p, linea yl: 0x8000 + p*2048 + yl*128.
    // Escribimos 8 bytes (2 dwords: izq+dcha) por (p, yl).
    for (yi_s = 0; yi_s < 16; yi_s = yi_s + 1)                // plano
        for (yj_s = 0; yj_s < 16; yj_s = yj_s + 1) begin      // linea fuente
            set_wr_ptr( (17'h8000 + yi_s*2048 + yj_s*128) >> 14,
                        (17'h8000 + yi_s*2048 + yj_s*128) & 17'h3FFF );
            vram_stream_b( {yi_s[3:0], yj_s[3:0]} );          // byte 0 = {plano,linea}
            vram_stream_b( {yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {yi_s[3:0], yj_s[3:0]} );          // dcha (+4)
            vram_stream_b( {yi_s[3:0], ~yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], yj_s[3:0]} );
            vram_stream_b( {~yi_s[3:0], ~yj_s[3:0]} );
        end

    // SAT @0x10000: 16 planos x 8 bytes
    set_wr_ptr( 17'h10000 >> 14, 17'h10000 & 17'h3FFF );
    for (yi_s = 0; yi_s < 16; yi_s = yi_s + 1) begin
        vram_stream_b( 8'd40 );                    // Y = 40 (todos solapan)
        vram_stream_b( 8'h00 );                    // SZ=0 -> 16 lineas fuente
        vram_stream_b( 8'd48 );                    // MGY = 48 (magnificado)
        vram_stream_b( 8'h01 );                    // palette set 1
        vram_stream_b( 8'd8 + yi_s[7:0]*8'd12 );   // X escalonada
        vram_stream_b( 8'h00 );                    // X_hi=0, page=0
        vram_stream_b( 8'd32 );                    // MGX = 32
        vram_stream_b( yi_s[7:0]*8'd16 );          // pattern = p*16 -> +p*2048
    end
    vram_stream_b( 8'd216 );                       // terminador
    vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 );
    vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 ); vram_stream_b( 8'h00 );
    vram_stream_b( 8'h00 );
