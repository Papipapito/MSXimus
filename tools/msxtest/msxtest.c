//=============================================================================
// msxtest.c — ROM de VALIDACION del MSXnano port (Tang Console 60K)
//
// Recorre los sistemas criticos: todos los modos de pantalla del V9958,
// sprites, comandos VDP, scroll fino, blink R#13 (el registro del bug MG2),
// PSG (tonos/ruido/ENVOLVENTES), OPLL (MSX-Music), Y8950 (MSX-Audio FM _79:
// deteccion+timers+musica), RTC, teclado, joystick, turbo F11 (benchmark).
//
// Flujo: antes de cada prueba grafica, una pantalla de texto explica QUE
// DEBES VER; ESPACIO muestra la prueba; ESPACIO pasa a la siguiente.
//
// Target: ROM 32K plana (cargar desde el menu MSXnano). MSX2+ (V9958).
//=============================================================================
#include "msxgl.h"
#include "psg.h"
#include "msx-music.h"
#include "msx-audio.h"
#include "clock.h"
#include "draw.h"
#include "font/font_mgl_sample6.h"

// La fuente se carga con offset 1 -> el ESPACIO real es el codigo 0x21.
// (Rellenar con 0x20 mostraba la basura de VRAM del patron 0x20 en HW real.)
#define CHR_BLANK 0x21

//-----------------------------------------------------------------------------
// Helpers de teclado (lectura directa de fila, sin buffers)
//-----------------------------------------------------------------------------
bool KeyDown(u8 key) { return (Keyboard_Read(KEY_ROW(key)) & (1 << KEY_IDX(key))) == 0; }

void WaitSpace()
{
	while (KeyDown(KEY_SPACE))  { Halt(); }
	while (!KeyDown(KEY_SPACE)) { Halt(); }
	while (KeyDown(KEY_SPACE))  { Halt(); }
}

// Espera N frames o hasta ESPACIO (devuelve TRUE si se pulso)
bool WaitFramesOrSpace(u8 frames)
{
	for (u8 i = 0; i < frames; ++i)
	{
		Halt();
		if (KeyDown(KEY_SPACE)) return TRUE;
	}
	return FALSE;
}

//-----------------------------------------------------------------------------
// Pantalla de anuncio (SCREEN 0): titulo + "debes ver" + ESPACIO
//-----------------------------------------------------------------------------
void Screen0()
{
	VDP_SetMode(VDP_MODE_SCREEN0);
	VDP_SetColor2(4, 15);              // fondo azul, texto blanco
	VDP_FillVRAM_16K(CHR_BLANK, 0x0000, 0x03C0);
	Print_SetTextFont(g_Font_MGL_Sample6, 1);
	Print_SetColor(0x0F, 0x04);
}

void Announce(const c8* title, const c8* l1, const c8* l2, const c8* l3)
{
	Screen0();
	Print_DrawTextAt(1, 1,  "MSXUP TEST - VALIDACION 60K");
	Print_DrawTextAt(1, 2,  "---------------------------");
	Print_DrawTextAt(1, 4,  title);
	Print_DrawTextAt(1, 7,  "DEBES VER/OIR:");
	if (l1) Print_DrawTextAt(2, 9,  l1);
	if (l2) Print_DrawTextAt(2, 11, l2);
	if (l3) Print_DrawTextAt(2, 13, l3);
	Print_DrawTextAt(1, 21, "ESPACIO = mostrar la prueba");
	Print_DrawTextAt(1, 22, "(y ESPACIO otra vez = seguir)");
	WaitSpace();
}

// Variante con opcion de SALTAR (para pruebas con bug conocido): TRUE=mostrar
bool AnnounceSkippable(const c8* title, const c8* l1, const c8* l2, const c8* l3)
{
	Screen0();
	Print_DrawTextAt(1, 1,  "MSXUP TEST - VALIDACION 60K");
	Print_DrawTextAt(1, 2,  "---------------------------");
	Print_DrawTextAt(1, 4,  title);
	Print_DrawTextAt(1, 7,  "DEBES VER/OIR:");
	if (l1) Print_DrawTextAt(2, 9,  l1);
	if (l2) Print_DrawTextAt(2, 11, l2);
	if (l3) Print_DrawTextAt(2, 13, l3);
	Print_DrawTextAt(1, 20, "ESC o S = SALTAR (recomendado)");
	Print_DrawTextAt(1, 22, "ESPACIO = mostrar (CUELGA HOY)");
	while (KeyDown(KEY_SPACE) || KeyDown(KEY_S) || KeyDown(KEY_ESC)) Halt();
	for (;;)
	{
		Halt();
		if (KeyDown(KEY_SPACE)) { while (KeyDown(KEY_SPACE)) Halt(); return TRUE; }
		if (KeyDown(KEY_S) || KeyDown(KEY_ESC))
		{
			while (KeyDown(KEY_S) || KeyDown(KEY_ESC)) Halt();
			return FALSE;
		}
	}
}

//-----------------------------------------------------------------------------
// SCREEN 2/4: dibujo por ESCRITURA DIRECTA a VRAM. (Los comandos del VDP son
// INDOCUMENTADOS en G2/G3 en el chip real: openMSX los ejecuta, el VDP FPGA
// no -> en HW quedaba la "pagina vieja" del screen anterior. Leccion v3.)
//-----------------------------------------------------------------------------
void DrawG2Direct()
{
	// nombres: secuencial 0..255 en los 3 tercios
	for (u16 i = 0; i < 768; ++i) VDP_Poke_16K((u8)i, 0x1800 + i);
	// patrones por tercio: solido / rayas verticales / bloques
	VDP_FillVRAM_16K(0xFF, 0x0000, 0x0800);
	VDP_FillVRAM_16K(0xAA, 0x0800, 0x0800);
	VDP_FillVRAM_16K(0x3C, 0x1000, 0x0800);
	// colores: 16 barras verticales (2 chars por barra), fondo negro
	for (u16 n = 0; n < 768; ++n)
	{
		u8 bar = (u8)((n & 31) >> 1);
		VDP_FillVRAM_16K((u8)((bar << 4) | 0x01), 0x2000 + n * 8, 8);
	}
}

//-----------------------------------------------------------------------------
// Dibujo comun en modos bitmap (usa el MOTOR DE COMANDOS del VDP)
//-----------------------------------------------------------------------------
void BitmapPattern(u16 width, u8 colors)
{
	u16 bar = width / colors;
	for (u8 c = 0; c < colors; ++c)
		Draw_FillBox(c * bar, 0, (c + 1) * bar - 1, 105, c, 0);
	// Rejilla inferior + circulo + diagonales (LINE/PSET del motor de comandos)
	for (u16 x = 0; x < width; x += 16) Draw_LineV(x, 108, 210, colors - 1, 0);
	for (u8 y = 108; y < 210; y += 16)  Draw_LineH(0, width - 1, y, colors - 1, 0);
	Draw_Circle(width / 2, 158, 40, colors > 8 ? 10 : 2, 0);
	Draw_Line(0, 108, width - 1, 210, colors > 8 ? 8 : 1, 0);
	Draw_Line(0, 210, width - 1, 108, colors > 8 ? 8 : 1, 0);
}

//-----------------------------------------------------------------------------
// Sprites: patron 16x16 (bloque redondeado)
//-----------------------------------------------------------------------------
const u8 g_SprPat[] = {
	0x3F, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x3F,
	0xFC, 0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFC,
};

typedef struct { u8 x, y; i8 dx, dy; } Ball;
Ball g_Balls[8];

void InitBalls()
{
	for (u8 i = 0; i < 8; ++i)
	{
		g_Balls[i].x = 20 + i * 26;
		g_Balls[i].y = 40 + ((i & 3) * 30);
		g_Balls[i].dx = (i & 1) ? 2 : -2;
		g_Balls[i].dy = (i & 2) ? 1 : -1;
	}
}

void MoveBalls(bool sm1)
{
	for (u8 i = 0; i < 8; ++i)
	{
		Ball* b = &g_Balls[i];
		b->x += b->dx; b->y += b->dy;
		if (b->x < 4 || b->x > 230) b->dx = -b->dx;
		if (b->y < 4 || b->y > 170) b->dy = -b->dy;
		if (sm1) VDP_SetSpriteSM1(i, b->x, b->y, 0, (i + 2) & 0x0F);
		else     VDP_SetSpriteExUniColor(i, b->x, b->y, 0, (i + 2) & 0x0F);
	}
}

void SpriteLoop(bool sm1)
{
	VDP_SetSpriteFlag(VDP_SPRITE_SIZE_16);
	VDP_LoadSpritePattern(g_SprPat, 0, 4);
	InitBalls();
	VDP_EnableSprite(TRUE);
	while (!WaitFramesOrSpace(1)) MoveBalls(sm1);
	VDP_DisableSprite();
	// v5: fuera de pantalla ademas de deshabilitados (los init de modo
	// re-activan R#8 y mostraban la tabla de atributos vieja al reiniciar)
	for (u8 i = 0; i < 8; ++i)
	{
		if (sm1) VDP_SetSpriteSM1(i, 0, 208, 0, 0);
		else     VDP_SetSpriteExUniColor(i, 0, 216, 0, 0);
	}
}

//-----------------------------------------------------------------------------
// PSG por registros directos (prueba las envolventes — fix #2 YM2149)
//-----------------------------------------------------------------------------
void PsgTone(u8 ch, u16 period, u8 vol)
{
	PSG_SetRegister(ch * 2, period & 0xFF);
	PSG_SetRegister(ch * 2 + 1, period >> 8);
	PSG_SetRegister(8 + ch, vol);
}

void PsgSilence()
{
	PSG_SetRegister(8, 0); PSG_SetRegister(9, 0); PSG_SetRegister(10, 0);
	PSG_SetRegister(7, 0xBF); // todo apagado (puerto B salida)
}

// Escala ascendente (periodos = 1789772.5 / (16*f))
const u16 g_Scale[] = { 426, 379, 338, 319, 284, 253, 226, 213 }; // Do..Do'

void TestPSG()
{
	Screen0();
	Print_DrawTextAt(1, 1, "PSG (AY/YM2149)");
	Print_DrawTextAt(1, 3, "1) Escala en canal A, B y C");
	Print_DrawTextAt(1, 4, "   (3 voces identicas y limpias)");
	Print_DrawTextAt(1, 5, "2) Bateria de RUIDO (5 golpes)");
	Print_DrawTextAt(1, 6, "3) ENVOLVENTES: 5 notas con caida");
	Print_DrawTextAt(1, 7, "   suave + zumbido triangular 3s");
	Print_DrawTextAt(1, 8, "   (sin clicks ni cortes = OK)");
	Print_DrawTextAt(1, 20, "Sonando... (ESPACIO al acabar)");

	// 1) escala en cada canal
	for (u8 ch = 0; ch < 3; ++ch)
	{
		PsgSilence();
		PSG_SetRegister(7, (u8)(0xBF & ~(1 << ch))); // solo tono del canal ch
		for (u8 n = 0; n < 8; ++n)
		{
			PsgTone(ch, g_Scale[n], 13);
			if (WaitFramesOrSpace(8)) goto psg_end;
		}
		PSG_SetRegister(8 + ch, 0);
		if (WaitFramesOrSpace(15)) goto psg_end;
	}
	// 2) percusion de ruido
	PsgSilence();
	PSG_SetRegister(7, 0xB7); // ruido en canal A
	for (u8 i = 0; i < 5; ++i)
	{
		PSG_SetRegister(6, 12);
		PSG_SetRegister(8, 13);
		if (WaitFramesOrSpace(5)) goto psg_end;
		PSG_SetRegister(8, 0);
		if (WaitFramesOrSpace(12)) goto psg_end;
	}
	// 3) envolventes: notas con decay (shape 0) y triangulo continuo (shape 14)
	PsgSilence();
	PSG_SetRegister(7, 0xBE); // tono canal A
	for (u8 n = 0; n < 5; ++n)
	{
		PsgTone(0, g_Scale[n], 16);      // vol=16 -> modo envolvente
		PSG_SetRegister(11, 0x00);
		PSG_SetRegister(12, 0x10);       // periodo envolvente
		PSG_SetRegister(13, 0x00);       // shape \___ (decay)
		if (WaitFramesOrSpace(25)) goto psg_end;
	}
	PsgTone(0, 426, 16);
	PSG_SetRegister(11, 0x00);
	PSG_SetRegister(12, 0x28);
	PSG_SetRegister(13, 0x0E);           // shape \/\/ (triangulo continuo)
	WaitFramesOrSpace(180);

psg_end:
	PsgSilence();
	Print_DrawTextAt(1, 22, "FIN PSG - ESPACIO");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// SCC (la ROM va en mapper KONAMI SCC -> el SCC esta en NUESTRO cartucho).
// OJO: activar el SCC (0x3F->0x9000) CONMUTA el banco 0x8000-0x9FFF de esta
// misma ROM, asi que cada acceso se hace desde un THUNK EN RAM que activa,
// accede y RESTAURA el banco (seg 2) con las interrupciones cerradas.
//-----------------------------------------------------------------------------
u8 g_SccThunk[20];
volatile u8 g_SccVal;

void SccCallThunk() { ((void(*)(void))(u16)&g_SccThunk[0])(); }

void SccPoke(u8 reg, u8 v)   // reg = offset sobre 0x9800 (0x00-0x8F)
{
	u16 dst = 0x9800 + reg;
	u8* t = g_SccThunk; u8 i = 0;
	t[i++] = 0xF3;                                    // DI
	t[i++] = 0x3E; t[i++] = 0x3F;                     // LD A,0x3F
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A  (SCC on)
	t[i++] = 0x3E; t[i++] = v;                        // LD A,v
	t[i++] = 0x32; t[i++] = (u8)dst; t[i++] = dst>>8; // LD (0x98xx),A
	t[i++] = 0x3E; t[i++] = 0x02;                     // LD A,2
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A  (restaura)
	t[i++] = 0xFB;                                    // EI
	t[i++] = 0xC9;                                    // RET
	SccCallThunk();
}

// v6: NOTA COMPLETA con el SCC MAPEADO todo el rato (la megaram silencia el
// SCC al desmapear el banco -> los pokes sueltos no sonaban; los juegos lo
// dejan mapeado). DI + on + freq/vol/mixer + bucle ~130ms + off + EI.
void SccNote(u16 period, u8 vol)
{
	u8* t = g_SccThunk; u8 i = 0;
	t[i++] = 0xF3;                                    // DI
	t[i++] = 0x3E; t[i++] = 0x3F;                     // LD A,0x3F
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A (SCC on)
	t[i++] = 0x3E; t[i++] = (u8)period;               // LD A,freqL
	t[i++] = 0x32; t[i++] = 0x80; t[i++] = 0x98;      // LD (0x9880),A
	t[i++] = 0x3E; t[i++] = (u8)(period >> 8);        // LD A,freqH
	t[i++] = 0x32; t[i++] = 0x81; t[i++] = 0x98;      // LD (0x9881),A
	t[i++] = 0x3E; t[i++] = 0x01;                     // LD A,1
	t[i++] = 0x32; t[i++] = 0x8F; t[i++] = 0x98;      // LD (0x988F),A (mixer ch1)
	t[i++] = 0x3E; t[i++] = vol;                      // LD A,vol
	t[i++] = 0x32; t[i++] = 0x8A; t[i++] = 0x98;      // LD (0x988A),A
	t[i++] = 0x01; t[i++] = 0xFF; t[i++] = 0xFF;      // LD BC,0xFFFF (~130ms)
	t[i++] = 0x0B;                                    // bucle: DEC BC
	t[i++] = 0x78;                                    //        LD A,B
	t[i++] = 0xB1;                                    //        OR C
	t[i++] = 0x20; t[i++] = 0xFB;                     //        JR NZ,-5
	t[i++] = 0xAF;                                    // XOR A
	t[i++] = 0x32; t[i++] = 0x8A; t[i++] = 0x98;      // LD (0x988A),A (vol 0)
	t[i++] = 0x3E; t[i++] = 0x02;                     // LD A,2
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A (restaura)
	t[i++] = 0xFB;                                    // EI
	t[i++] = 0xC9;                                    // RET
	SccCallThunk();
}

u8 SccPeek(u8 reg)
{
	u16 src = 0x9800 + reg;
	u16 dst = (u16)&g_SccVal;
	u8* t = g_SccThunk; u8 i = 0;
	t[i++] = 0xF3;                                    // DI
	t[i++] = 0x3E; t[i++] = 0x3F;                     // LD A,0x3F
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A
	t[i++] = 0x3A; t[i++] = (u8)src; t[i++] = src>>8; // LD A,(0x98xx)
	t[i++] = 0x32; t[i++] = (u8)dst; t[i++] = dst>>8; // LD (g_SccVal),A
	t[i++] = 0x3E; t[i++] = 0x02;                     // LD A,2
	t[i++] = 0x32; t[i++] = 0x00; t[i++] = 0x90;      // LD (0x9000),A
	t[i++] = 0xFB;                                    // EI
	t[i++] = 0xC9;                                    // RET
	SccCallThunk();
	return g_SccVal;
}

// onda triangular (32 muestras i8)
const u8 g_SccTriangle[32] = {
	0x80, 0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0,
	0x00, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70,
	0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00,
	0xF0, 0xE0, 0xD0, 0xC0, 0xB0, 0xA0, 0x90, 0x80,
};

void TestSCC()
{
	u8 ok;

	Screen0();
	Print_DrawTextAt(1, 1, "SCC (KONAMI) - via megaram");
	Print_DrawTextAt(1, 3, "Detectando SCC en el cartucho...");

	// v7: deteccion por lectura de wave RAM SOLO INFORMATIVA — la megaram
	// real puede no implementar el readback (openMSX si) y bloqueaba el test.
	// La escala suena INCONDICIONAL: si el mapper es KONAMI SCC, hay SCC.
	SccPoke(0x00, 0xAA);
	ok = (SccPeek(0x00) == 0xAA);
	if (ok) { SccPoke(0x00, 0x55); ok = (SccPeek(0x00) == 0x55); }

	if (ok) Print_DrawTextAt(1, 5, "readback wave RAM: OK");
	else    Print_DrawTextAt(1, 5, "readback wave RAM: NO (informativo)");
	Print_DrawTextAt(1, 7, "Escala de 8 notas x2 con el timbre");
	Print_DrawTextAt(1, 8, "METALICO caracteristico del SCC");
	Print_DrawTextAt(1, 9, "(onda triangular, tipo Konami).");
	Print_DrawTextAt(1, 20, "Sonando... (ESPACIO al acabar)");

	for (u8 w = 0; w < 32; ++w) SccPoke(w, g_SccTriangle[w]);  // wave ch1
	for (u8 rep = 0; rep < 2; ++rep)
		for (u8 n = 0; n < 8; ++n)
		{
			SccNote(g_Scale[n] >> 1, 12); // nota bloqueante ~130ms (DI)
			if (WaitFramesOrSpace(2)) goto scc_end;
		}
scc_end:
	SccPoke(0x8A, 0);
	SccPoke(0x8F, 0x00);
	Print_DrawTextAt(1, 22, "FIN SCC - ESPACIO");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// OPLL / MSX-Music (YM2413 interno del MSXnano)
//-----------------------------------------------------------------------------
void OpllKeyOn(u8 ch, u16 fnum, u8 blk, u8 inst, u8 vol)
{
	MSXMusic_SetRegister(0x30 + ch, (inst << 4) | vol);
	MSXMusic_SetRegister(0x10 + ch, fnum & 0xFF);
	MSXMusic_SetRegister(0x20 + ch, 0x10 | (blk << 1) | (fnum >> 8));
}

void OpllKeyOff(u8 ch, u16 fnum, u8 blk)
{
	MSXMusic_SetRegister(0x20 + ch, (blk << 1) | (fnum >> 8));
}

const u16 g_FNum[] = { 172, 192, 216, 229, 257, 288, 323, 343 }; // Do..Do'

void TestOPLL(u8 fmType)
{
	Screen0();
	Print_DrawTextAt(1, 1, "MSX-MUSIC (OPLL YM2413)");
	Print_DrawTextAt(1, 3, "Detectado: ");
	if (fmType == MSXMUSIC_INTERNAL)      Print_DrawText("INTERNO (correcto)");
	else if (fmType == MSXMUSIC_EXTERNAL) Print_DrawText("EXTERNO (FM-PAC?)");
	else                                  Print_DrawText("NO DETECTADO << FALLO!");
	if (fmType == MSXMUSIC_NOTFOUND)
	{
		Print_DrawTextAt(1, 22, "ESPACIO para seguir");
		WaitSpace();
		return;
	}
	Print_DrawTextAt(1, 5, "1) Escala de PIANO FM (8 notas)");
	Print_DrawTextAt(1, 6, "2) Acorde sostenido de VIOLIN 3s");
	Print_DrawTextAt(1, 7, "   (timbre FM claro, sin ruido)");
	Print_DrawTextAt(1, 20, "Sonando... (ESPACIO al acabar)");

	// 1) escala de piano (instrumento 3)
	for (u8 n = 0; n < 8; ++n)
	{
		OpllKeyOn(0, g_FNum[n], 4, 3, 2);
		if (WaitFramesOrSpace(10)) goto opll_end;
		OpllKeyOff(0, g_FNum[n], 4);
		if (WaitFramesOrSpace(2)) goto opll_end;
	}
	if (WaitFramesOrSpace(20)) goto opll_end;
	// 2) acorde de violin (instrumento 1) en 3 canales
	OpllKeyOn(0, g_FNum[0], 4, 1, 3);
	OpllKeyOn(1, g_FNum[2], 4, 1, 3);
	OpllKeyOn(2, g_FNum[4], 4, 1, 3);
	WaitFramesOrSpace(180);
	OpllKeyOff(0, g_FNum[0], 4);
	OpllKeyOff(1, g_FNum[2], 4);
	OpllKeyOff(2, g_FNum[4], 4);

opll_end:
	MSXMusic_Mute();
	Print_DrawTextAt(1, 22, "FIN OPLL - ESPACIO");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// Y8950 / MSX-AUDIO (FM del _79: jtopl2 en C0/C1; ADPCM-B pendiente).
// A diferencia del OPLL, el OPL no tiene instrumentos de fabrica: hay que
// programar los operadores. Deteccion + test de TIMERS (lo que los replayers
// usan para el tempo) + MUSICA: The Entertainer (Scott Joplin 1902, dominio
// publico) a 3 voces FM + bateria en modo ritmo del OPL.
//-----------------------------------------------------------------------------

void PrintU8Dec(u8 v);    // definidas mas abajo (seccion Sistema)
void PrintU8Hex2(u8 v);

// offset de slot del operador 1 por canal (op2 = slot+3)
const u8 g_AudOpOfs[9] = { 0, 1, 2, 8, 9, 10, 16, 17, 18 };

// F-num OPL (A4=440Hz, fs=3579545/72): fnum = f * 2^16 / 49716 (bloque 4 = octava de C4)
const u16 g_AudFNum[12] = { 345, 365, 387, 410, 435, 460, 488, 517, 547, 580, 615, 651 };

// instrumento = { m20, m40, m60, m80, c20, c40, c60, c80, fb/cnt }
const u8 g_AudPiano[9] = { 0x01, 0x1C, 0xF4, 0x27,  0x01, 0x00, 0xF2, 0x45, 0x0C }; // honky-tonk
const u8 g_AudBass[9]  = { 0x01, 0x10, 0xF6, 0x26,  0x01, 0x08, 0xF4, 0x36, 0x08 };
const u8 g_AudComp[9]  = { 0x01, 0x1C, 0xF4, 0x27,  0x01, 0x14, 0xF2, 0x45, 0x0C }; // piano suave

u8 g_AudShadowB0[9];   // ultimo B0 por canal (para key-off sin saltar de octava)

void AudSetVoice(u8 ch, const u8* v)
{
	u8 s = g_AudOpOfs[ch];
	MSXAudio_SetRegister(0x20 + s, v[0]);
	MSXAudio_SetRegister(0x40 + s, v[1]);
	MSXAudio_SetRegister(0x60 + s, v[2]);
	MSXAudio_SetRegister(0x80 + s, v[3]);
	MSXAudio_SetRegister(0x23 + s, v[4]);
	MSXAudio_SetRegister(0x43 + s, v[5]);
	MSXAudio_SetRegister(0x63 + s, v[6]);
	MSXAudio_SetRegister(0x83 + s, v[7]);
	MSXAudio_SetRegister(0xC0 + ch, v[8]);
}

void AudKeyOn(u8 ch, u8 note)   // note = numero MIDI (60 = C4); DEBE ser >= 12
{
	u8 blk = note / 12 - 1;
	u16 fn = g_AudFNum[note % 12];
	u8 b0 = 0x20 | (blk << 2) | (u8)(fn >> 8);
	MSXAudio_SetRegister(0xB0 + ch, g_AudShadowB0[ch] & 0x1F); // key-off previo (retrigger)
	MSXAudio_SetRegister(0xA0 + ch, (u8)fn);
	MSXAudio_SetRegister(0xB0 + ch, b0);
	g_AudShadowB0[ch] = b0;
}

void AudKeyOff(u8 ch)
{
	g_AudShadowB0[ch] &= 0x1F;
	MSXAudio_SetRegister(0xB0 + ch, g_AudShadowB0[ch]);
}

//--- secuenciador: eventos {nota MIDI (0=silencio), duracion en semicorcheas}
typedef struct { u8 note, dur; } MusEv;

// The Entertainer — frase A (4 compases de 2/4 en bucle; el "pickup" D-D#-E
// va plegado al final para que el bucle enlace). 32 semicorcheas/vuelta.
const MusEv g_AudMelody[] = {
	{72,2},{64,1},{72,2},{64,1},{72,8},           // C5 E4 C5 E4 C5~ (el hook; el
	                                               //  5o C5 LIGADO = sincopa ragtime)
	{72,1},{74,1},                                 // C5 D5
	{75,1},{76,1},{72,1},{74,1},{76,2},{71,1},{74,1}, // D#5 E5 C5 D5 E5~ B4 D5
	{72,5},{62,1},{63,1},{64,1},                   // C5 largo + pickup D4 D#4 E4
};
const MusEv g_AudBassSeq[] = {                     // stride (corcheas)
	{48,2},{43,2},{48,2},{52,2},                   // C3 G2 C3 E3
	{53,2},{54,2},{55,2},{43,2},                   // F3 F#3 G3 G2 (cromatica ragtime)
	{48,2},{43,2},{45,2},{47,2},                   // C3 G2 A2 B2
	{48,2},{55,2},{48,2},{ 0,2},                   // C3 G3 C3 (respiro)
};
const MusEv g_AudCompSeq[] = {                     // acompanamiento a contratiempo
	{ 0,2},{67,2},{ 0,2},{64,2},                   // - G4 - E4
	{ 0,2},{69,2},{ 0,2},{65,2},                   // - A4 - F4
	{ 0,2},{67,2},{ 0,2},{62,2},                   // - G4 - D4
	{ 0,2},{67,2},{64,2},{ 0,2},                   // - G4 E4 -
};

// bateria (modo ritmo OPL, reg BD): patron de 8 semicorcheas
// bits: 0x10=bombo 0x08=caja 0x01=charles
const u8 g_AudDrumPat[8] = { 0x11, 0x00, 0x01, 0x00, 0x09, 0x00, 0x01, 0x00 };

typedef struct { const MusEv* seq; u8 len, ch, idx, left; } MusTrack;

void AudTrackTick(MusTrack* t)
{
	if (t->left)
	{
		--t->left;
		if (t->left == 1) AudKeyOff(t->ch);     // hueco de 1 tick (staccato ragtime)
		if (t->left) return;
	}
	// avanzar al siguiente evento (con wrap = bucle)
	{
		const MusEv* e = &t->seq[t->idx];
		t->idx = (u8)((t->idx + 1) % t->len);
		t->left = e->dur;
		if (e->note) AudKeyOn(t->ch, e->note);
		else         AudKeyOff(t->ch);
	}
}

void TestY8950()
{
	u8 st0, st1, st2;
	bool det;

	Screen0();
	Print_DrawTextAt(1, 1, "MSX-AUDIO (Y8950) - FM nuevo _79");

	// --- deteccion (mismo criterio que MSXgl: bits 1-2 indiferentes) ---
	det = MSXAudio_Detect();
	st0 = g_MSXAudio_IndexPort;
	Print_DrawTextAt(1, 3, "Detectado: ");
	Print_DrawText(det ? "SI" : "NO << FALLO");
	Print_DrawText("  status=");
	PrintU8Hex2(st0);
	if (!det)
	{
		Print_DrawTextAt(1, 22, "ESPACIO para seguir");
		WaitSpace();
		return;
	}

	// --- test de TIMERS via status (el metodo de deteccion "AdLib") ---
	// ¡OJO! En un MSX-Audio real el IRQ del Y8950 va al /INT del Z80 y el
	// ISR del BIOS no lo limpia -> tormenta de interrupciones (verificado en
	// openMSX: KEYINT re-entrando y stack cayendo). Por eso TODO el test de
	// timer va con las interrupciones CERRADAS y espera ocupada, y el
	// IRQ-RESET baja la linea ANTES del EI. (En el _79 irq_n no esta
	// conectado, pero el ROM debe funcionar tambien con hardware real.)
	// GOTCHA Y8950 (2a tormenta, cazada en openMSX): el reg 4 del Y8950 tiene
	// MASCARAS tambien para EOS/BUF_RDY del ADPCM (bits 4:3), que un OPL2 no
	// tiene. Escribir 0x04=0x01 las des-enmascara TODAS y el flag BUF_RDY
	// (buffer ADPCM "listo", condicion de NIVEL) dispara un IRQ que el
	// IRQ-RESET no puede matar (el flag re-salta al instante) -> tormenta al
	// EI. Solucion = como el software MSX-Audio real: fuentes ADPCM SIEMPRE
	// enmascaradas; solo T1 visible durante el test.
	__asm__("di");
	MSXAudio_SetRegister(0x04, 0x7C);            // parar + ENMASCARAR TODO
	MSXAudio_SetRegister(0x04, 0x80);            // IRQ RESET -> flags a 0
	st1 = g_MSXAudio_IndexPort;                  // debe tener bit7:5 a 0
	MSXAudio_SetRegister(0x02, 0xC0);            // timer1 = (256-192)*80us = 5.1ms
	MSXAudio_SetRegister(0x04, 0x3D);            // T1 des-enmascarado + ST1;
	                                             //  T2/EOS/BUF_RDY enmascarados
	for (volatile u16 w = 0; w < 8000; ++w) {}   // ~70ms ocupado >> 5.1ms
	st2 = g_MSXAudio_IndexPort;                  // debe tener IRQ(b7)+FT1(b6)
	// PARAR de verdad: con bit7=1 el OPL IGNORA el resto de bits (ST1 seguiria
	// a 1 recargando -> en la 2a vuelta la deteccion leeria 0xC0 = falso NO).
	// Primero parar+enmascarar, despues IRQ-RESET (baja /INT), y solo entonces EI.
	MSXAudio_SetRegister(0x04, 0x7C);            // ST1=0 + todo enmascarado
	MSXAudio_SetRegister(0x04, 0x80);            // borra flags + baja /INT
	__asm__("ei");
	Print_DrawTextAt(1, 5, "Timers: ");
	if (((st1 & 0xE0) == 0) && ((st2 & 0xC0) == 0xC0)) Print_DrawText("OK");
	else                                               Print_DrawText("FALLO");
	Print_DrawText("  ");
	PrintU8Hex2(st1); Print_DrawText("->"); PrintU8Hex2(st2);

	Print_DrawTextAt(1, 8,  "Sonando: THE ENTERTAINER (Joplin)");
	Print_DrawTextAt(1, 10, "3 voces FM programadas a registro");
	Print_DrawTextAt(1, 11, "(sin preset: esto NO es el OPLL)");
	Print_DrawTextAt(1, 12, "+ bateria del MODO RITMO del OPL");
	Print_DrawTextAt(1, 20, "En bucle... ESPACIO = terminar");

	// --- setup de voces ---
	MSXAudio_SetRegister(0x01, 0x00);            // test off
	MSXAudio_SetRegister(0x08, 0x00);            // CSM/NOTE-SEL off
	for (u8 c = 0; c < 9; ++c) { g_AudShadowB0[c] = 0; AudKeyOff(c); }
	AudSetVoice(0, g_AudPiano);
	AudSetVoice(1, g_AudBass);
	AudSetVoice(2, g_AudComp);
	// bateria: operadores de ch6 (bombo), ch7 (charles+caja), ch8 (tom+plato)
	{
		// static const -> ROM directa (un const local SDCC lo copia a PILA
		// byte a byte: ~140 bytes de codigo + 27 de stack tirados)
		static const u8 drums[9]  = { 0x00, 0x08, 0xF8, 0x48,  0x00, 0x04, 0xF8, 0x48, 0x00 }; // BD
		static const u8 drums7[9] = { 0x01, 0x00, 0xFB, 0x3B,  0x00, 0x08, 0xF8, 0x68, 0x00 }; // HH+SD
		static const u8 drums8[9] = { 0x02, 0x0A, 0xF8, 0x68,  0x02, 0x0A, 0xF5, 0x35, 0x00 }; // TOM+CYM
		AudSetVoice(6, drums);
		AudSetVoice(7, drums7);
		AudSetVoice(8, drums8);
	}
	// tono de los canales de percusion (fnum/bloque; key via reg BD)
	MSXAudio_SetRegister(0xA6, 0x56); MSXAudio_SetRegister(0xB6, 0x09); // bombo ~65Hz
	MSXAudio_SetRegister(0xA7, 0x0F); MSXAudio_SetRegister(0xB7, 0x0E); // caja ~200Hz
	MSXAudio_SetRegister(0xA8, 0x3C); MSXAudio_SetRegister(0xB8, 0x0D); // tom ~120Hz
	MSXAudio_SetRegister(0xBD, 0x20);            // modo ritmo ON, tambores off

	// --- bucle del secuenciador ---
	// semicorchea = 10 frames a 60Hz (90 BPM) u 8 a 50Hz (94 BPM): tempo
	// ragtime casi identico en NTSC y PAL (byte 0x002B del BIOS, bit7=50Hz)
	{
		u8 tick = (*(volatile u8*)0x002B & 0x80) ? 8 : 10;
		MusTrack trk[3];
		u8 step = 0;
		trk[0].seq = g_AudMelody;  trk[0].len = numberof(g_AudMelody);  trk[0].ch = 0;
		trk[1].seq = g_AudBassSeq; trk[1].len = numberof(g_AudBassSeq); trk[1].ch = 1;
		trk[2].seq = g_AudCompSeq; trk[2].len = numberof(g_AudCompSeq); trk[2].ch = 2;
		for (u8 t = 0; t < 3; ++t) { trk[t].idx = 0; trk[t].left = 0; }

		for (;;)
		{
			u8 hit = g_AudDrumPat[step & 7];
			MSXAudio_SetRegister(0xBD, 0x20);              // key-off tambores
			if (hit) MSXAudio_SetRegister(0xBD, 0x20 | hit);
			for (u8 t = 0; t < 3; ++t) AudTrackTick(&trk[t]);
			++step;
			if (WaitFramesOrSpace(tick)) break;
		}
	}

	// --- silencio total ---
	for (u8 c = 0; c < 9; ++c) AudKeyOff(c);
	MSXAudio_SetRegister(0xBD, 0x00);
	MSXAudio_Mute();
	Print_DrawTextAt(1, 22, "FIN Y8950 - ESPACIO");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// Sistema: version MSX + RTC en vivo + benchmark de turbo F11
//-----------------------------------------------------------------------------
void PrintU8Dec(u8 v)
{
	Print_DrawChar('0' + (v / 100) % 10);
	Print_DrawChar('0' + (v / 10) % 10);
	Print_DrawChar('0' + v % 10);
}

void PrintU8Hex2(u8 v)
{
	const c8* hx = "0123456789ABCDEF";
	Print_DrawChar(hx[v >> 4]);
	Print_DrawChar(hx[v & 15]);
}

void TestSystem()
{
	u8 ver = Sys_GetMSXVersion();

	Screen0();
	Print_DrawTextAt(1, 1, "SISTEMA / RTC / TURBO F11");
	Print_DrawTextAt(1, 3, "MSX: ");
	switch (ver)
	{
	case 0:  Print_DrawText("MSX1   << FALLO (debe ser 2+)"); break;
	case 1:  Print_DrawText("MSX2   << FALLO (debe ser 2+)"); break;
	case 2:  Print_DrawText("MSX2+  (correcto)"); break;
	default: Print_DrawText("TURBO-R?"); break;
	}
	Print_DrawTextAt(1, 5, "RTC        :  :   (debe AVANZAR)");
	Print_DrawTextAt(1, 8, "BENCH: bucle fijo, frames tardados");
	Print_DrawTextAt(1, 9, " a 3.58 MHz: valor alto estable");
	Print_DrawTextAt(1, 10, " PULSA F11 (turbo 5.37): BAJA ~33%");
	Print_DrawTextAt(1, 11, " F11 otra vez: vuelve a subir");
	Print_DrawTextAt(1, 13, "FRAMES:");
	Print_DrawTextAt(1, 21, "MANTEN ESPACIO = siguiente prueba");

	RTC_Initialize();
	while (!KeyDown(KEY_SPACE))
	{
		// RTC en vivo (BCD por nibbles)
		Print_SetPosition(6, 5);
		PrintU8Dec(RTC_GetHour());
		Print_DrawChar(':');
		PrintU8Dec(RTC_GetMinute());
		Print_DrawChar(':');
		PrintU8Dec(RTC_GetSecond());

		// benchmark: bucle fijo medido en frames (JIFFY del BIOS, 0xFC9E)
		{
			u16 t0 = *(volatile u16*)0xFC9E;
			for (volatile u16 i = 0; i < 20000; ++i) {}
			{
				u16 dt = *(volatile u16*)0xFC9E - t0;
				Print_SetPosition(9, 13);
				PrintU8Dec((u8)dt);
			}
		}
	}
	while (KeyDown(KEY_SPACE)) Halt();   // drenar la pulsacion que nos saco
}

//-----------------------------------------------------------------------------
// Teclado + joystick en vivo
//-----------------------------------------------------------------------------
void TestInput()
{
	Screen0();
	Print_DrawTextAt(1, 1, "TECLADO (matriz) + JOYSTICK");
	Print_DrawTextAt(1, 3, "Pulsa teclas: la fila cambia de FF");
	Print_DrawTextAt(1, 4, "al valor de la tecla (y vuelve).");
	Print_DrawTextAt(1, 18, "JOY1 dir/btn:");
	Print_DrawTextAt(1, 20, "Flechas,letras,SHIFT,GRAPH,CTRL...");
	Print_DrawTextAt(1, 22, "ESC = siguiente prueba");

	while (!KeyDown(KEY_ESC))
	{
		for (u8 row = 0; row < 9; ++row)
		{
			Print_SetPosition(2, 6 + row);
			Print_DrawText("FILA ");
			Print_DrawChar('0' + row);
			Print_DrawText(": ");
			PrintU8Hex2(Keyboard_Read(row));
		}
		Print_SetPosition(15, 18);
		PrintU8Hex2(Joystick_Read(JOY_PORT_1));
		Halt();
	}
}

//-----------------------------------------------------------------------------
// Blink R#13 — EL registro del bug MG2 (#22)
//-----------------------------------------------------------------------------
void TestBlink()
{
	VDP_SetMode(VDP_MODE_SCREEN0_W80);
	VDP_SetColor2(4, 15);
	VDP_FillVRAM_16K(CHR_BLANK, 0x0000, 0x0800);
	Print_SetTextFont(g_Font_MGL_Sample6, 1);
	Print_SetColor(0x0F, 0x04);
	Print_DrawTextAt(2, 2,  "BLINK R#13 (el registro del bug de Metal Gear 2)");
	Print_DrawTextAt(2, 5,  "TODO EL TEXTO debe PARPADEAR entre dos colores");
	Print_DrawTextAt(2, 7,  "(blanco/azul <-> amarillo/rojo, ritmo ~0.7 s)");
	Print_DrawTextAt(2, 12, "SI PARPADEA: R#13 y el blink del VDP van bien");
	Print_DrawTextAt(2, 14, "SI SE QUEDA FIJO en un color: FALLO de blink");
	Print_DrawTextAt(2, 20, "ESPACIO = siguiente (el test LIMPIA R#13 al salir)");

	VDP_SetBlinkColor2(8, 10);     // color alterno: texto amarillo, fondo rojo
	VDP_SetBlinkScreen();          // atributo blink en toda la pantalla
	VDP_SetBlinkTime2(4, 4);       // ~0.67 s cada color

	WaitSpace();

	VDP_SetBlinkTime(0);           // lo que hace el fix del menu: R#13 = 0
	VDP_CleanBlinkScreen();
}

//-----------------------------------------------------------------------------
// Scroll fino V9958 (R#23 vertical + R#26/27 horizontal)
//-----------------------------------------------------------------------------
void TestScroll()
{
	VDP_SetMode(VDP_MODE_SCREEN5);
	VDP_SetColor(0x00);
	VDP_CommandHMMV(0, 0, 256, 256, 0x11);   // v5: pagina ENTERA (el wrap del
	VDP_CommandWait();                       // scroll ensenaba lineas 212-255)
	BitmapPattern(256, 16);

	u8 v = 0; u16 h = 0; u8 phase = 0;
	while (TRUE)
	{
		Halt();
		if (KeyDown(KEY_SPACE)) break;
		if (phase < 128) VDP_SetVerticalOffset(++v);
		else             { h = (h + 1) & 0x1FF; VDP_SetHorizontalOffset(h); }
		++phase;
	}
	VDP_SetVerticalOffset(0);
	VDP_SetHorizontalOffset(0);
	while (KeyDown(KEY_SPACE)) Halt();
}

//-----------------------------------------------------------------------------
// SCREEN 8 (256 colores): bandas RGB + gris
//-----------------------------------------------------------------------------
void TestScreen8()
{
	VDP_SetMode(VDP_MODE_SCREEN8);
	VDP_SetColor(0x00);
	VDP_CommandHMMV(0, 0, 256, 212, 0x00);   // v5: limpiar (los huecos entre
	VDP_CommandWait();                       // bandas ensenaban VRAM vieja)
	// G7: byte de color = GGGRRRBB
	for (u8 i = 0; i < 8; ++i)
	{
		u8 x0 = i * 32;
		Draw_FillBox(x0, 0,   x0 + 31, 45,  (u8)(i << 2), 0);                          // rojo
		Draw_FillBox(x0, 50,  x0 + 31, 95,  (u8)(i << 5), 0);                          // verde
		Draw_FillBox(x0, 100, x0 + 31, 145, (u8)(i >> 1), 0);                          // azul
		Draw_FillBox(x0, 150, x0 + 31, 195, (u8)((i << 5) | (i << 2) | (i >> 1)), 0);  // gris
	}
	WaitSpace();
}

//-----------------------------------------------------------------------------
// SCREEN 12 (YJK del V9958): degradado continuo
//-----------------------------------------------------------------------------
u8 g_LineBuf[256];

void TestScreen12()
{
	VDP_SetMode(VDP_MODE_SCREEN12);
	VDP_SetColor(0x00);
	for (u16 x = 0; x < 256; ++x)
		g_LineBuf[x] = (u8)((x >> 3) << 3);   // Y = rampa 0..31, J=K=0
	for (u8 y = 0; y < 212; ++y)
		VDP_WriteVRAM(g_LineBuf, (u16)y << 8, 0, 256);
	WaitSpace();
}

//=============================================================================
// MAIN
//=============================================================================
void main()
{
	u8 fmType;

	Bios_SetKeyClick(FALSE);
	fmType = MSXMusic_Initialize();

	for (;;)   // el test entero se repite en bucle
	{

	Announce("BIENVENIDO: TEST DEL MSXNANO 60K",
	         "Pantallas de prueba en secuencia.",
	         "Cada una te dice antes que esperar.",
	         "Ten a mano el LEEME para el checklist.");

	// ---- 1. Sistema / RTC / turbo ----
	TestSystem();

	// ---- 2. Modos MSX1 ----
	Announce("SCREEN 1 (texto 32 col + patron)",
	         "Rejilla de caracteres ASCII blanca",
	         "sobre fondo azul, borde CIAN.", NULL);
	VDP_SetMode(VDP_MODE_SCREEN1);
	VDP_SetColor(0x57);
	Print_SetTextFont(g_Font_MGL_Sample6, 1);
	VDP_FillVRAM_16K(CHR_BLANK, 0x1800, 0x0300);  // nombres: espacio real
	VDP_FillVRAM_16K(0xF4, 0x2000, 0x0020);       // colores: blanco/azul
	Print_SetColor(0x0F, 0x04);
	for (u8 r = 0; r < 7; ++r)
	{
		Print_SetPosition(1, 3 + r);
		for (u8 c = 0; c < 30; ++c) Print_DrawChar((c8)(32 + r * 30 + c));
	}
	WaitSpace();

	Announce("SCREEN 2 + SPRITES modo 1",
	         "3 franjas: barras SOLIDAS arriba,",
	         "RAYADAS en medio, BLOQUES abajo;",
	         "8 sprites 16x16 rebotando limpios.");
	VDP_SetMode(VDP_MODE_SCREEN2);
	VDP_SetColor(0x07);
	DrawG2Direct();
	SpriteLoop(TRUE);

	if (AnnounceSkippable("SCREEN 3 (multicolor)",
	         "BUG APARCADO #1: este modo CUELGA",
	         "el MSXnano (20K y 60K) hoy.",
	         "Casi ningun juego usa SCREEN 3."))
	{
		VDP_SetMode(VDP_MODE_SCREEN3);
		VDP_SetColor(0x01);
		for (u16 a = 0; a < 0x800; ++a) VDP_Poke_16K((u8)(a * 7), a);
		WaitSpace();
	}

	// ---- 3. Modos MSX2 bitmap ----
	Announce("SCREEN 4 (G3) + SPRITES modo 2",
	         "Como SCREEN 2 (3 franjas de",
	         "barras) con sprites modo 2.", NULL);
	VDP_SetMode(VDP_MODE_SCREEN4);
	VDP_SetColor(0x07);
	DrawG2Direct();
	SpriteLoop(FALSE);

	Announce("SCREEN 5 (G4, 256px 16 colores)",
	         "Patron de barras/rejilla/circulo",
	         "dibujado por el MOTOR DE COMANDOS",
	         "del VDP (LMMV/LINE/PSET).");
	VDP_SetMode(VDP_MODE_SCREEN5);
	VDP_SetColor(0x07);
	VDP_CommandHMMV(0, 0, 256, 212, 0x00);
	VDP_CommandWait();
	BitmapPattern(256, 16);
	WaitSpace();

	Announce("SCREEN 6 (G5, 512px 4 colores)",
	         "Mismo patron pero DOBLE anchura:",
	         "lineas el doble de finas.", NULL);
	VDP_SetMode(VDP_MODE_SCREEN6);
	VDP_SetColor(0x07);
	VDP_CommandHMMV(0, 0, 512, 212, 0x00);
	VDP_CommandWait();
	BitmapPattern(512, 4);
	WaitSpace();

	Announce("SCREEN 7 (G6, 512px 16 colores)",
	         "Patron completo a 512 pixels:",
	         "barras finas y rejilla densa.", NULL);
	VDP_SetMode(VDP_MODE_SCREEN7);
	VDP_SetColor(0x07);
	VDP_CommandHMMV(0, 0, 512, 212, 0x00);
	VDP_CommandWait();
	BitmapPattern(512, 16);
	WaitSpace();

	Announce("SCREEN 8 (G7, 256 COLORES)",
	         "4 bandas: ROJO, VERDE, AZUL y GRIS",
	         "en 8 escalones cada una.",
	         "Colores puros, sin mezclas raras.");
	TestScreen8();

	Announce("SCREEN 12 (YJK del V9958!)",
	         "Degradado gris-azulado SUAVE",
	         "(32 escalones casi continuos).",
	         "Bandas de colores locos = FALLO.");
	TestScreen12();

	// ---- 4. Features V9958 ----
	Announce("SCROLL FINO V9958 (R#23 + R#26/27)",
	         "El patron se desplaza SUAVE:",
	         "primero vertical, luego horizontal",
	         "pixel a pixel (sin saltos).");
	TestScroll();

	Announce("BLINK R#13 (registro del bug MG2)",
	         "Pantalla de texto a 80 columnas",
	         "PARPADEANDO entera entre 2 colores.", NULL);
	TestBlink();

	// ---- 5. Sonido ----
	TestPSG();
	TestSCC();
	TestOPLL(fmType);
	TestY8950();

	// ---- 6. Entrada ----
	TestInput();

	// ---- FIN ----
	Screen0();
	Print_DrawTextAt(1, 1,  "FIN DEL TEST");
	Print_DrawTextAt(1, 4,  "Si todo salio como se anuncio:");
	Print_DrawTextAt(1, 6,  "VDP (modos, sprites, comandos,");
	Print_DrawTextAt(1, 7,  "scroll, blink), PSG+envolventes,");
	Print_DrawTextAt(1, 8,  "SCC, OPLL FM, Y8950 FM, RTC,");
	Print_DrawTextAt(1, 9,  "turbo F11, teclado, joy: VALIDADOS.");
	Print_DrawTextAt(1, 12, "Manual (ver LEEME): kanji, Coleco,");
	Print_DrawTextAt(1, 13, "WiFi (sin pines aun), SD caliente.");
	Print_DrawTextAt(1, 21, "ESPACIO = repetir todo el test");
	WaitSpace();

	}
}
