// ============================================================================
// sprite3_ru66_setup.svh — LAYOUT *REAL* de la escena de los conejos de la
// demo ru66-v9968-demo (DEVCON 14 de HRA!, port de herraa1 a MSXgl).
//
// NO es un setup sintetico: cada valor esta sacado de
//   C:\Users\alber\proyectosAI\msx\ru66-v9968-demo\devcon.c  +  msx_vdp.c
// (initializer(), rabbit1[], rabbit2[], shadow[], _window1, put_usagi(),
//  el bucle de la "message display area" y set_screen5()).
//
// GEOMETRIA (verificada contra vdp_sprite_info_collect.v y
// vdp_sprite_select_visible_planes.v):
//   SAT  @0x10000  (R#5=0x03, R#11=0x02)   -> plano P en 0x10000 + P*8
//   SPT  @0x08000  (R#6=0x10)
//   byte(pattern,page,yl) = SPT + page*32768 + pattern[7:4]*2048
//                               + yl*128 + pattern[3:0]*8 + {0|4}
//   mgy = ALTURA EN PIXELES en pantalla; altura fuente = 16<<SZ (SZ=y[15:14])
//
//   Planos 0-3  rabbit1 : y=31 SZ=3 mgy=128 mgx=16 patrones 0..3 (o 4..7)
//   Planos 4-7  rabbit2 : idem, rvx=1, patrones 3..0 (o 7..4)
//   Planos 8-9  sombras : y=153 SZ=0 mgy=12 mgx=64 patron 129
//   Planos 10-23 mensaje: y=170 SZ=1 mgy=32 mgx=16 patrones 144..157
//   Plano 24    ventana : y=166 SZ=0 mgy=40 mgx=224 patron 128
//   Plano 25    terminador (y=216)
//
// EL CHOQUE QUE ESTO REPRODUCE (idx13 = {v[12], v[11]^v[14], v[10:0]}):
//   SAT  -> v = 0x4000 + P*2 + m      => idx13 = 2048 + P*2 + m   (P=0..25)
//   patron conejo -> v = 0x2000 + yl*32 + pattern[3:0]*2 + w
//                  => idx13 = yl*32 + pattern[3:0]*2 + w
//   yl=64 => idx13 = 2048..2063 = EXACTAMENTE la SAT de los planos 0..7
//            (los DOS conejos) -> 16 lineas de cache con 2 palabras cada una.
//   yl=65 => idx13 = 2080..2095 = la SAT de los planos 16..23 (mensaje).
//   yl = 64 y 65 se muestran en las lineas de pantalla 95 y 96 (mgy=128 = 1:1
//   sobre 128 lineas fuente, con el sprite arrancando en y=31) = LA MITAD DE
//   LA PANTALLA, justo donde el usuario ve las rayas.
//
// Requiere del TB: task vdp_reg().  Los datos de VRAM los precarga
// ru66_preload.svh EN t=0 (pokes directos al modelo de memoria).
// ============================================================================
    vdp_reg(6'd0,  8'h06);     // G4 (SCREEN5)
    vdp_reg(6'd1,  8'h40);     // display ON (set_display_visible(1))
    vdp_reg(6'd2,  8'h1F);     // PNT page0
    vdp_reg(6'd5,  8'h03);     // SAT @0x10000
    vdp_reg(6'd11, 8'h02);
    vdp_reg(6'd6,  8'h10);     // SPT @0x8000
    vdp_reg(6'd7,  8'h00);     // borde negro
    vdp_reg(6'd8,  8'h08);     // VR=1, SPD=0 -> sprites ON
    vdp_reg(6'd9,  8'h80);     // 212 lineas
    vdp_reg(6'd18, 8'h00);
    vdp_reg(6'd19, 8'h00);
    // R#20 = [S16][CEIE][ILN][EPAL][SCOL][ILNS][SVNS][HS]; SCOL(bit3)=mode3.
    // _163: con el mapa NUEVO de R#20/R#21 (port de 0683e7e) la demo pone 0x9F,
    // no 0xFF — es EL UNICO byte en que difieren los DEVCON.COM de los dos
    // arboles (offset 14882) y el binario del upstream vivo ya trae el 0x9F.
    // Con 0xFF sobre el mapa nuevo se encenderian por accidente el entrelazado
    // plano (bit5) y la interrupcion de fin de comando (bit6).
    // Los comandos extendidos y el 256K los da ahora R#21[0] = 0 (V58).
    vdp_reg(6'd20, 8'h9F);
    vdp_reg(6'd21, 8'h00);
    vdp_reg(6'd23, 8'h00);     // sin offset vertical
    vdp_reg(6'd25, 8'h02);     // left mask; bit7=0 => SIN priority shuffle
    vdp_reg(6'd26, 8'h00);
    vdp_reg(6'd27, 8'h07);
