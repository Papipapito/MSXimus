//=============================================================================
// scctest2.c — SCCTEST2.ROM: test de los DOS chips SCC del MSXnano/MSX_up
//              (Tang Console 60K). Valida la build _57 (2o SCC+ + estereo).
//
// QUE HACE
//   1. Detecta el SCC1 (el de la megaram, en NUESTRO cartucho Konami SCC):
//      mapea banco 2 (0x3F->0x9000), patron en wave RAM 9800-981F, relee.
//   2. Detecta el SCC2 ("ghost"/segundo SCC-I) segun el RTL de fpga/top.v.
//   3. Suena: SCC1 nota GRAVE 3s -> silencio -> SCC2 nota AGUDA 3s ->
//      las dos a la vez 3s. En estereo (_57): SCC1=IZQUIERDA, SCC2=DERECHA.
//   4. ESPACIO repite todo.
//
//-----------------------------------------------------------------------------
// MAPEO DEL SEGUNDO SCC (scc2x_*) SEGUN EL RTL — fpga/top.v lineas ~1991-2043
// (glue "Second SCC+", comparte el decode x98h/xb8h de src/scc_glue.v):
//
//  * HABILITACION: config1_ff[2] ("SECOND SCC+ enable", el antiguo bit ghost
//    SCC reconvertido; toggle del menu). POR DEFECTO ESTA A 0 (CONFIG1_DEFAULT
//    = 0xF3 -> bit2=0), asi que este test LO ACTIVA por SWIO:
//        OUT (#40),#48   ; ID goauld: config0_ff <= ~#48 = #B7 -> config_ok
//        IN  A,(#40)     ; readback = #B7 confirma que hay SWIO MSXnano
//        IN  A,(#41)     ; config1 actual (bit1=megaram, bits7:6=slot megaram)
//        OUT (#41),cfg|4 ; set bit2 (read-modify-write: respeta el resto)
//    (El ID NO es el 212 del OCM real: en este core config_ok exige
//     config0_ff==#B7, es decir ID=#48. Ver top.v ~2335.)
//
//  * SLOT: scc2x_slot = (config_megaram_slot==1) ? 2 : 1 — el 2o SCC vive en
//    el OTRO slot primario que la megaram (con el menu tipico: megaram slot 2
//    -> SCC2 en slot 1). Solo mira pri_slot (registro A8 del PPI, pagina 2);
//    IGNORA el slot expandido -> basta conmutar bits 5:4 del puerto A8.
//
//  * REGISTROS (SCC-I): en el slot scc2x, escrituras con MREQ:
//      9000-97FF -> scc2x_bank2 : 0x3F abre la ventana COMPAT en 9800-98FF
//                   (wave ch1 9800-981F, freq 9880/81, vol 988A, mixer 988F)
//      B000-B7FF -> scc2x_bank3 (solo si modeb[4]==0)
//      BFFE-BFFF -> scc2x_modeb : bit5=1 -> modo SCC+ (ventana B800-B8FF si
//                   ademas bank3 bit7=1 y modeb[4]==0); bit5=0 -> compat.
//    La wave RAM tiene read-back (scc2x_dout) -> deteccion por patron.
//
//  * EN LAS BUILDS _55/_56 EL CHIP ESTA STUBBEADO (top.v: scc2x_wav=0,
//    scc2x_dout=8'hFF) -> la ventana devuelve FF y este test debe decir
//    "SCC2: NO DETECTADO" limpiamente. En la _57 (chip restaurado) debe
//    decir DETECTADO y sonar por la DERECHA en estereo.
//
//  * ESTEREO (top.v ~2136, config2_ff[5] via puerto #42):
//      L = PSG1 + SCC1 + OPLL      R = PSG2 + SCC2 + OPLL
//    (el test NO toca config2: solo lo documenta en pantalla)
//
// LECCIONES HEREDADAS DE msxtest.c:
//  - El modulo scc de MSXgl NO sirve (su autodetect escribe 0x3F en 0x9000 de
//    bancos ajenos y cuelga): acceso directo con THUNKS EN RAM (DI + banco
//    0x3F mapeado + acceso + restaurar) — mapear el SCC conmuta el banco
//    8000-9FFF de ESTA MISMA ROM, y la megaram silencia el SCC al desmapear,
//    asi que la nota entera se toca dentro del thunk (bucle de espera con DI).
//  - Fuente con offset 1 (el espacio real es 0x21); en screenGetFullText de
//    openMSX el texto sale con codigos +1 (en pantalla real se ve bien).
//
// Target: ROM_KONAMI_SCC, Machine 2P. Cargar desde el menu MSXnano.
//=============================================================================
#include "msxgl.h"
#include "font/font_mgl_sample6.h"

#define CHR_BLANK 0x21

//-----------------------------------------------------------------------------
// Helpers teclado / espera (de msxtest.c)
//-----------------------------------------------------------------------------
bool KeyDown(u8 key) { return (Keyboard_Read(KEY_ROW(key)) & (1 << KEY_IDX(key))) == 0; }

void WaitSpace()
{
	while (KeyDown(KEY_SPACE))  { Halt(); }
	while (!KeyDown(KEY_SPACE)) { Halt(); }
	while (KeyDown(KEY_SPACE))  { Halt(); }
}

void WaitFrames(u8 n) { for (u8 i = 0; i < n; ++i) Halt(); }

//-----------------------------------------------------------------------------
// Impresion
//-----------------------------------------------------------------------------
void PrintU8Hex2(u8 v)
{
	const c8* hx = "0123456789ABCDEF";
	Print_DrawChar(hx[v >> 4]);
	Print_DrawChar(hx[v & 15]);
}

void Screen0()
{
	VDP_SetMode(VDP_MODE_SCREEN0);
	VDP_SetColor2(4, 15);              // fondo azul, texto blanco
	VDP_FillVRAM_16K(CHR_BLANK, 0x0000, 0x03C0);
	Print_SetTextFont(g_Font_MGL_Sample6, 1);
	Print_SetColor(0x0F, 0x04);
}

//-----------------------------------------------------------------------------
// Generador de thunks en RAM (todo acceso SCC/slot/SWIO con DI y desde RAM)
//-----------------------------------------------------------------------------
u8 g_Thunk[192];
u8 g_TIdx;
volatile u8 g_V1, g_V2, g_V3, g_V4;
u8 g_SaveA8;
u8 g_WaveRam[32];   // copia en RAM de la onda (LDIR valido con el banco conmutado)

void T_B(u8 b)      { g_Thunk[g_TIdx++] = b; }
void T_Reset()      { g_TIdx = 0; T_B(0xF3); }                       // DI
void T_LdA(u8 v)    { T_B(0x3E); T_B(v); }                           // LD A,n
void T_StA(u16 a)   { T_B(0x32); T_B((u8)a); T_B((u8)(a >> 8)); }    // LD (nn),A
void T_LdAM(u16 a)  { T_B(0x3A); T_B((u8)a); T_B((u8)(a >> 8)); }    // LD A,(nn)
void T_InA(u8 p)    { T_B(0xDB); T_B(p); }                           // IN A,(p)
void T_OutA(u8 p)   { T_B(0xD3); T_B(p); }                           // OUT (p),A
void T_Poke(u16 a, u8 v)     { T_LdA(v); T_StA(a); }
void T_Peek(u16 a, u16 dst)  { T_LdAM(a); T_StA(dst); }

// Conmuta la PAGINA 2 (8000-BFFF, bits 5:4 del PPI A8) al slot primario dado.
// El glue scc2x solo mira pri_slot: NO hace falta tocar el slot expandido.
void T_Page2To(u8 slot)
{
	T_InA(0xA8); T_StA((u16)&g_SaveA8);   // guarda el A8 actual
	T_B(0xE6); T_B(0xCF);                 // AND 0xCF (limpia pagina 2)
	T_B(0xF6); T_B((u8)(slot << 4));      // OR  slot<<4
	T_OutA(0xA8);
}
void T_Page2Back() { T_LdAM((u16)&g_SaveA8); T_OutA(0xA8); }

// LDIR g_WaveRam(32) -> ventana wave ch1
void T_WaveLdir(u16 win)
{
	u16 src = (u16)g_WaveRam;
	T_B(0x21); T_B((u8)src); T_B((u8)(src >> 8));   // LD HL,g_WaveRam
	T_B(0x11); T_B((u8)win); T_B((u8)(win >> 8));   // LD DE,win
	T_B(0x01); T_B(32); T_B(0);                     // LD BC,32
	T_B(0xED); T_B(0xB0);                           // LDIR
}

// Espera bloqueante con DI: ~0.51 s por unidad a 3.58 MHz (6 = ~3 s)
void T_Wait(u8 halfsecs)
{
	T_B(0x16); T_B(halfsecs);           // LD D,n
	T_B(0x01); T_B(0xFF); T_B(0xFF);    // LD BC,0xFFFF
	T_B(0x0B); T_B(0x78); T_B(0xB1);    // DEC BC / LD A,B / OR C
	T_B(0x20); T_B(0xFB);               // JR NZ,-5  (bucle interno)
	T_B(0x15);                          // DEC D
	T_B(0x20); T_B(0xF5);               // JR NZ,-11 (recarga BC)
}
void T_Run() { T_B(0xFB); T_B(0xC9); ((void(*)(void))(u16)&g_Thunk[0])(); }  // EI/RET

//-----------------------------------------------------------------------------
// Onda triangular (timbre metalico Konami, de msxtest.c)
//-----------------------------------------------------------------------------
const u8 g_SccTriangle[32] = {
	0x80, 0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0,
	0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70,
	0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00,
	0xF0, 0xE0, 0xD0, 0xC0, 0xB0, 0xA0, 0x90, 0x80,
};

#define PERIOD_GRAVE  0x356   // ~130.6 Hz (Do3): f = 3579545/(32*(P+1))
#define PERIOD_AGUDA  0x06A   // ~1045 Hz (Do6)
#define SCC_VOL       13

//-----------------------------------------------------------------------------
// SCC1 (nuestro cartucho): deteccion por wave RAM (informativa en HW: la
// megaram puede no implementar el read-back; el sonido va igual)
//-----------------------------------------------------------------------------
u8 DetectScc1()
{
	T_Reset();
	T_Poke(0x9000, 0x3F);               // banco 2 = 0x3F -> SCC on
	T_Poke(0x9800, 0xAA); T_Peek(0x9800, (u16)&g_V1);
	T_Poke(0x9801, 0x55); T_Peek(0x9801, (u16)&g_V2);
	T_Poke(0x9000, 0x02);               // restaura el segmento 2
	T_Run();
	return (g_V1 == 0xAA) && (g_V2 == 0x55);
}

//-----------------------------------------------------------------------------
// SWIO MSXnano: OUT (#40),#48 -> IN (#40) debe devolver #B7 (ver cabecera).
// Deja: g_V1=config0 previo, g_V2=readback, g_V3=config1.
//-----------------------------------------------------------------------------
u8 DetectSwio()
{
	T_Reset();
	T_InA(0x40); T_StA((u16)&g_V1);     // config0 previo (para restaurar)
	T_LdA(0x48); T_OutA(0x40);          // seleccion del dispositivo goauld
	T_InA(0x40); T_StA((u16)&g_V2);     // debe leerse 0xB7
	T_InA(0x41); T_StA((u16)&g_V3);     // config1 actual
	T_Run();
	return g_V2 == 0xB7;
}

// Activa config1 bit2 ("SECOND SCC+ enable") con read-modify-write; confirma.
void EnableScc2(u8 cfg1)
{
	T_Reset();
	T_LdA(0x48); T_OutA(0x40);
	T_LdA(cfg1 | 0x04); T_OutA(0x41);
	T_InA(0x41); T_StA((u16)&g_V4);     // confirmacion
	T_Run();
}

// Restaura config0 al valor previo X (se escribe ~X porque config0_ff <= ~dato)
void RestoreConfig0(u8 old0)
{
	T_Reset();
	T_LdA((u8)~old0); T_OutA(0x40);
	T_Run();
}

//-----------------------------------------------------------------------------
// SCC2: deteccion en el slot scc2x (pagina 2 conmutada por A8).
//   compat: bank2(9000)=3F -> patron en 9800/9801
//   plus  : bank3(B000)=80 + modeb(BFFE)=20 -> patron en B800
//   cierre: bank2=0 y releer 9801 — si sigue 0x55 es RAM (falso positivo)
// Deja: g_V1/g_V2 = compat, g_V3 = plus, g_V4 = lectura con ventana cerrada.
//-----------------------------------------------------------------------------
void DetectScc2(u8 slot)
{
	T_Reset();
	T_Page2To(slot);
	T_Poke(0x9000, 0x3F);               // scc2x_bank2 -> ventana compat 98xx
	T_Poke(0x9800, 0xAA); T_Peek(0x9800, (u16)&g_V1);
	T_Poke(0x9801, 0x55); T_Peek(0x9801, (u16)&g_V2);
	T_Poke(0xB000, 0x80);               // scc2x_bank3 bit7
	T_Poke(0xBFFE, 0x20);               // scc2x_modeb bit5 -> modo SCC+ (B8xx)
	T_Poke(0xB800, 0x5A); T_Peek(0xB800, (u16)&g_V3);
	T_B(0xAF);                          // XOR A: limpia modeb, bank3 y bank2
	T_StA(0xBFFE); T_StA(0xB000); T_StA(0x9000);
	T_Peek(0x9801, (u16)&g_V4);         // ventana cerrada: NO debe ser 0x55
	T_Page2Back();
	T_Run();
}

//-----------------------------------------------------------------------------
// Notas (bloqueantes, con DI y el banco mapeado todo el rato — leccion v6)
//-----------------------------------------------------------------------------
void NoteScc1(u16 period, u8 halfsecs)
{
	T_Reset();
	T_Poke(0x9000, 0x3F);
	T_WaveLdir(0x9800);
	T_Poke(0x9880, (u8)period); T_Poke(0x9881, (u8)(period >> 8));
	T_Poke(0x988F, 0x01);               // mixer: canal 1 on
	T_Poke(0x988A, SCC_VOL);
	T_Wait(halfsecs);
	T_Poke(0x988A, 0x00);
	T_Poke(0x988F, 0x00);
	T_Poke(0x9000, 0x02);
	T_Run();
}

void NoteScc2(u8 slot, u16 period, u8 halfsecs)
{
	T_Reset();
	T_Page2To(slot);
	T_Poke(0x9000, 0x3F);               // ventana compat del scc2x
	T_WaveLdir(0x9800);
	T_Poke(0x9880, (u8)period); T_Poke(0x9881, (u8)(period >> 8));
	T_Poke(0x988F, 0x01);
	T_Poke(0x988A, SCC_VOL);
	T_Wait(halfsecs);
	T_B(0xAF);                          // XOR A: vol 0, mixer 0, bank2 0
	T_StA(0x988A); T_StA(0x988F); T_StA(0x9000);
	T_Page2Back();
	T_Run();
}

// Las dos a la vez: programa SCC1, conmuta pagina 2 al slot del SCC2 (los
// registros del SCC1 quedan latcheados y sigue sonando), programa SCC2,
// espera, y apaga en orden inverso.
void NoteBoth(u8 slot, u8 halfsecs)
{
	T_Reset();
	// SCC1 (grave)
	T_Poke(0x9000, 0x3F);
	T_WaveLdir(0x9800);
	T_Poke(0x9880, (u8)PERIOD_GRAVE); T_Poke(0x9881, (u8)(PERIOD_GRAVE >> 8));
	T_Poke(0x988F, 0x01);
	T_Poke(0x988A, SCC_VOL);
	// SCC2 (aguda) en el otro slot
	T_Page2To(slot);
	T_Poke(0x9000, 0x3F);
	T_WaveLdir(0x9800);
	T_Poke(0x9880, (u8)PERIOD_AGUDA); T_Poke(0x9881, (u8)(PERIOD_AGUDA >> 8));
	T_Poke(0x988F, 0x01);
	T_Poke(0x988A, SCC_VOL);
	T_Wait(halfsecs);
	// apaga SCC2 y cierra su ventana
	T_B(0xAF);
	T_StA(0x988A); T_StA(0x988F); T_StA(0x9000);
	// vuelve a nuestro slot y apaga SCC1
	T_Page2Back();
	T_B(0xAF);
	T_StA(0x988A); T_StA(0x988F);
	T_Poke(0x9000, 0x02);
	T_Run();
}

//-----------------------------------------------------------------------------
// Limpieza de fila por VRAM (PRINT_SKIP_SPACE=TRUE: imprimir espacios NO
// borra — leccion de esta ROM v1: la linea de estado se solapaba)
//-----------------------------------------------------------------------------
void ClearRow(u8 y) { VDP_FillVRAM_16K(CHR_BLANK, (u16)y * 40, 40); }

// Linea de estado de la fase de sonido (fila 17)
void Status(const c8* s)
{
	ClearRow(17);
	Print_DrawTextAt(1, 17, s);
}

//=============================================================================
// MAIN
//=============================================================================
void main()
{
	u8 hasSwio, hasScc1, hasScc2, hasPlus, ramAlias;
	u8 cfg1, oldCfg0, scc2Slot;

	Bios_SetKeyClick(FALSE);
	for (u8 i = 0; i < 32; ++i) g_WaveRam[i] = g_SccTriangle[i];

	for (;;)   // el test entero se repite en bucle
	{
		Screen0();
		Print_DrawTextAt(1, 1,  "SCCTEST2 - DOBLE SCC MSXNANO 60K");
		Print_DrawTextAt(1, 2,  "--------------------------------");

		// ---- 1. SCC1 (nuestro cartucho Konami SCC / megaram) ----
		hasScc1 = DetectScc1();
		Print_DrawTextAt(1, 4, "SCC1 megaram 9800: ");
		PrintU8Hex2(g_V1); Print_DrawChar(' '); PrintU8Hex2(g_V2);
		Print_DrawTextAt(1, 5, hasScc1 ? "  -> DETECTADO" : "  -> NO (readback informativo)");

		// ---- 2. SWIO + SCC2 ----
		hasScc2 = FALSE; hasPlus = FALSE; ramAlias = FALSE; scc2Slot = 1;
		hasSwio = DetectSwio();
		oldCfg0 = g_V1;
		cfg1    = g_V3;
		Print_DrawTextAt(1, 7, "SWIO MSXnano 40/48: ");
		PrintU8Hex2(g_V2);
		if (!hasSwio)
		{
			Print_DrawText(" -> NO (openMSX?)");
			Print_DrawTextAt(1, 8, "SCC2: NO DETECTADO (sin SWIO no");
			Print_DrawTextAt(1, 9, "      se puede mapear el 2o chip)");
		}
		else
		{
			Print_DrawText(" -> SI");
			// slot del 2o SCC: el otro que la megaram (top.v scc2x_slot)
			scc2Slot = ((cfg1 >> 6) == 1) ? 2 : 1;
			if ((cfg1 & 0x04) == 0) EnableScc2(cfg1); else g_V4 = cfg1;
			Print_DrawTextAt(1, 8, "cfg1: ");
			PrintU8Hex2(cfg1);
			Print_DrawText(" -> ");
			PrintU8Hex2(g_V4);          // con bit2 (2o SCC+) ya activado
			Print_DrawText("  slot SCC2: ");
			Print_DrawChar('0' + scc2Slot);
			if (((g_V4 >> 4) & 3) == scc2Slot)   // mapper RAM en el mismo slot?
				ramAlias = TRUE;

			DetectScc2(scc2Slot);
			Print_DrawTextAt(1, 9, "SCC2 compat 9800: ");
			PrintU8Hex2(g_V1); Print_DrawChar(' '); PrintU8Hex2(g_V2);
			Print_DrawTextAt(1, 10, "SCC2 plus B800:   ");
			PrintU8Hex2(g_V3);
			Print_DrawTextAt(1, 11, "cierre 9801:      ");
			PrintU8Hex2(g_V4);
			if (g_V4 == 0x55) ramAlias = TRUE;   // relee patron = hay RAM detras
			hasScc2 = (g_V1 == 0xAA) && (g_V2 == 0x55) && !ramAlias;
			hasPlus = (g_V3 == 0x5A) && !ramAlias;

			Print_DrawTextAt(1, 12, "SCC2: ");
			if (ramAlias)     Print_DrawText("RAM EN EL SLOT? (no valido)");
			else if (hasScc2) Print_DrawText(hasPlus ? "DETECTADO (compat+plus)"
			                                         : "DETECTADO (solo compat)");
			else              Print_DrawText("NO DETECTADO (FF = _55/_56)");
			RestoreConfig0(oldCfg0);
		}

		Print_DrawTextAt(1, 14, "Estereo (_57): SCC1=IZQ  SCC2=DER");
		Print_DrawTextAt(1, 16, "SONIDO:");
		Print_DrawTextAt(1, 21, "ESPACIO = fase de sonido");
		WaitSpace();
		ClearRow(21);

		// ---- 3. Sonido (notas bloqueantes con DI, texto antes de cada una) ----
		Status("> 1/3 SCC1 nota GRAVE 3s (IZQ)");
		NoteScc1(PERIOD_GRAVE, 6);
		Status("  ... silencio ...");
		WaitFrames(30);

		if (hasSwio)
		{
			Status("> 2/3 SCC2 nota AGUDA 3s (DER)");
			NoteScc2(scc2Slot, PERIOD_AGUDA, 6);
		}
		else
		{
			Status("> 2/3 SCC2 no mapeable: silencio");
			WaitFrames(150);
		}
		Status("  ... silencio ...");
		WaitFrames(30);

		if (hasSwio)
		{
			Status("> 3/3 LAS DOS A LA VEZ 3s");
			NoteBoth(scc2Slot, 6);
		}
		else
		{
			Status("> 3/3 solo SCC1 (sin SCC2) 3s");
			NoteScc1(PERIOD_GRAVE, 6);
		}

		Status("FIN - ESPACIO = repetir todo");
		WaitSpace();
	}
}
