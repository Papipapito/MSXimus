//=============================================================================
// opl4test.c — ROM de VALIDACION DE AUDIO del MSXimus (Y8950 + OPL4 + DDR3)
//
// Version recortada del msxtest para iterar rapido en las fases de audio:
// Y8950 completo (deteccion/timers/ADPCM/IRQ/frase/musica), MoonSound FM
// (deteccion/readback/reloj/musica) y DDR3 wave (calibracion/W-R/DIAG).
// ROM 128K Konami-SCC; la frase de voz va inyectada en segmentos 8-11
// (inject_voice.py). Guard de area plana en build.sh.
//=============================================================================
#include "msxgl.h"
#include "msx-audio.h"
#include "font/font_mgl_sample6.h"

#define CHR_BLANK 0x21

bool KeyDown(u8 key) { return (Keyboard_Read(KEY_ROW(key)) & (1 << KEY_IDX(key))) == 0; }

void WaitSpace()
{
	while (KeyDown(KEY_SPACE))  { Halt(); }
	while (!KeyDown(KEY_SPACE)) { Halt(); }
	while (KeyDown(KEY_SPACE))  { Halt(); }
}

bool WaitFramesOrSpace(u8 frames)
{
	for (u8 i = 0; i < frames; ++i)
	{
		Halt();
		if (KeyDown(KEY_SPACE)) return TRUE;
	}
	return FALSE;
}

void Screen0()
{
	VDP_SetMode(VDP_MODE_SCREEN0);
	VDP_SetColor2(4, 15);
	VDP_FillVRAM_16K(CHR_BLANK, 0x0000, 0x03C0);
	Print_SetTextFont(g_Font_MGL_Sample6, 1);
	Print_SetColor(0x0F, 0x04);
}

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


//-----------------------------------------------------------------------------
// FRASE de voz ADPCM (v6): "MSXimus. MSX Audio funcionando." — 3.5s reales
// codificados a ADPCM-B e INYECTADOS en los segmentos 8-11 del ROM por
// tools/msxtest/inject_voice.py DESPUES del build (la zona plana esta llena).
// Estas constantes deben coincidir con el injector.
// El stream corre desde un thunk en RAM: la ventana 8000-9FFF es nuestro
// propio codigo y hay que conmutarle el banco Konami-SCC (como el SCC test).
//-----------------------------------------------------------------------------
#define VOICE_SEG0  8
#define VOICE_LEN   31429u    // bytes ADPCM (sync con inject_voice.py)
#define VOICE_DELTA 0x5C00u   // 17.9 kHz

u8 g_VozThunk[32];

void VozStreamSeg(u8 seg, u16 len)
{
	u8* t = g_VozThunk; u8 i = 0;
	t[i++]=0xF3;                                   // DI
	t[i++]=0x3E; t[i++]=seg;                       // LD A,seg
	t[i++]=0x32; t[i++]=0x00; t[i++]=0x90;         // LD (9000h),A (bank2=seg)
	t[i++]=0x21; t[i++]=0x00; t[i++]=0x80;         // LD HL,8000h
	t[i++]=0x01; t[i++]=(u8)len; t[i++]=(u8)(len>>8); // LD BC,len
	t[i++]=0x7E;                                   // lp: LD A,(HL)
	t[i++]=0xD3; t[i++]=0xC1;                      //     OUT (C1h),A
	t[i++]=0x23;                                   //     INC HL
	t[i++]=0x0B;                                   //     DEC BC
	t[i++]=0x78; t[i++]=0xB1;                      //     LD A,B / OR C
	t[i++]=0x20; t[i++]=0xF7;                      //     JR NZ,lp (-9)
	t[i++]=0x3E; t[i++]=0x02;                      // LD A,2
	t[i++]=0x32; t[i++]=0x00; t[i++]=0x90;         // LD (9000h),A (restaura)
	t[i++]=0xFB;                                   // EI
	t[i++]=0xC9;                                   // RET
	((void(*)(void))(u16)&g_VozThunk[0])();
}

//-----------------------------------------------------------------------------
// IRQ del Y8950 (_81): gancho en H.KEYI que cuenta interrupciones del chip.
// El KEYINT del BIOS ya ha salvado TODOS los registros antes de llamar al
// hook, asi que una funcion C normal vale. El gancho DEBE bajar /INT
// (reg4=0x80) o la maquina se queda en tormenta.
//-----------------------------------------------------------------------------
volatile u16 g_Y8950IrqCount;

void Y8950IrqHook()
{
	if (g_MSXAudio_IndexPort & 0x80)        // bit7 = IRQ del Y8950
	{
		MSXAudio_SetRegister(0x04, 0x80);   // borra flags -> baja /INT
		++g_Y8950IrqCount;
	}
}

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
	Print_DrawTextAt(1, 1, "MSX-AUDIO (Y8950) FM+ADPCM _80");

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

	// --- ADPCM-B (_80): subir sample a la RAM, releerlo y reproducirlo ---
	// Region: start=0, stop=248|7 nibbles (~127 bytes). 128 escrituras
	// (la que cruza stop dispara EOS; el wrap posterior es inocuo aqui
	// porque el patron es uniforme en los 2 primeros bytes).
	// ¡TODO BAJO DI!: des-enmascarar EOS/BUF con la unidad ociosa deja
	// BUF_RDY=1 (condicion de NIVEL) -> IRQ -> tormenta en HW real/openMSX
	// (mismo patron que el test de timers; verificado colgando openMSX).
	{
		u8 d1, d2;
		bool okw, okr, okp;

		Print_DrawTextAt(1, 7, "ADPCM: probando (zumbido corto)");
		__asm__("di");
		MSXAudio_SetRegister(0x04, 0x60);   // T1/T2 tapados, EOS/BUF visibles
		MSXAudio_SetRegister(0x04, 0x80);   // limpiar flags
		MSXAudio_SetRegister(0x07, 0x01);   // RESET del bloque ADPCM
		MSXAudio_SetRegister(0x08, 0x00);   // RAM, modo 256K
		MSXAudio_SetRegister(0x09, 0x00); MSXAudio_SetRegister(0x0A, 0x00);
		MSXAudio_SetRegister(0x0B, 0x1F); MSXAudio_SetRegister(0x0C, 0x00);
		MSXAudio_SetRegister(0x07, 0x60);   // modo escritura CPU->RAM
		for (u8 i = 0; i < 128; ++i)
			MSXAudio_SetRegister(0x0F, (i & 8) ? 0x22 : 0xAA);  // onda cuadrada suave
		okw = (g_MSXAudio_IndexPort & 0x10) != 0;   // EOS al cruzar stop

		MSXAudio_SetRegister(0x04, 0x80);   // limpiar
		MSXAudio_SetRegister(0x07, 0x01);
		MSXAudio_SetRegister(0x07, 0x20);   // modo lectura RAM->CPU
		d1 = MSXAudio_GetRegister(0x0F);    // dummy 1
		d1 = MSXAudio_GetRegister(0x0F);    // dummy 2
		d1 = MSXAudio_GetRegister(0x0F);    // byte 0 (0xAA)
		d2 = MSXAudio_GetRegister(0x0F);    // byte 1 (0xAA)
		okr = (d1 == 0xAA) && (d2 == 0xAA);

		MSXAudio_SetRegister(0x04, 0x80);
		MSXAudio_SetRegister(0x07, 0x01);
		MSXAudio_SetRegister(0x10, 0x00); MSXAudio_SetRegister(0x11, 0x30); // delta ~9.3kHz
		MSXAudio_SetRegister(0x12, 0xF0);   // volumen alto
		MSXAudio_SetRegister(0x07, 0xB0);   // PLAY desde RAM con REPEAT (zumbido)
		for (volatile u16 w = 0; w < 40000; ++w) {}  // ~0.5s ocupado (DI: sin Halt)
		okp = (g_MSXAudio_IndexPort & 0x10) != 0;    // EOS de cada vuelta
		MSXAudio_SetRegister(0x07, 0x01);   // stop
		MSXAudio_SetRegister(0x04, 0x7C);   // tapar TODO
		MSXAudio_SetRegister(0x04, 0x80);   // limpiar: baja /INT antes de EI
		__asm__("ei");

		Print_DrawTextAt(1, 7, "ADPCM: W:");
		Print_DrawText(okw ? "OK" : "MAL");
		Print_DrawText(" R:");
		Print_DrawText(okr ? "OK" : "MAL");
		Print_DrawText(" Play:");
		Print_DrawText(okp ? "OK" : "MAL");
		Print_DrawText("          ");   // tapar el "probando..." anterior
	}

	// --- IRQ del Y8950 al /INT (_81): gancho H.KEYI + timer1 sin mascara ---
	// En cores sin el cableado (_80 o anterior) cuenta 0 -> "sin cablear".
	{
		u8 hookSave[5];
		u8* hook = (u8*)0xFD9A;             // H.KEYI

		g_Y8950IrqCount = 0;
		__asm__("di");
		for (u8 i = 0; i < 5; ++i) hookSave[i] = hook[i];
		hook[0] = 0xC3;                     // JP Y8950IrqHook
		hook[1] = (u8)((u16)&Y8950IrqHook);
		hook[2] = (u8)((u16)&Y8950IrqHook >> 8);
		MSXAudio_SetRegister(0x04, 0x7C);   // parar + tapar todo
		MSXAudio_SetRegister(0x04, 0x80);   // limpiar
		MSXAudio_SetRegister(0x02, 0xC0);   // timer1 = 5.12ms
		MSXAudio_SetRegister(0x04, 0x3D);   // T1 visible + ST1 (ADPCM tapado)
		__asm__("ei");
		WaitFramesOrSpace(30);              // ~0.25s contando (Halt despierta
		                                    //  con cada IRQ, da igual: cuenta)
		__asm__("di");
		MSXAudio_SetRegister(0x04, 0x7C);   // parar de verdad + tapar
		MSXAudio_SetRegister(0x04, 0x80);   // limpiar: baja /INT
		for (u8 i = 0; i < 5; ++i) hook[i] = hookSave[i];
		__asm__("ei");

		Print_DrawTextAt(20, 5, "IRQ:");
		if (g_Y8950IrqCount > 5)
		{
			Print_DrawText("OK ");
			PrintU8Dec((u8)(g_Y8950IrqCount > 255 ? 255 : g_Y8950IrqCount));
		}
		else Print_DrawText("sin cablear");
	}

	// --- FRASE de voz (v6): subir 31KB reales a la sample RAM y oirla ---
	{
		Print_DrawTextAt(1, 6, "Subiendo frase de voz (31KB)...");
		__asm__("di");
		MSXAudio_SetRegister(0x04, 0x7C);   // todo enmascarado
		MSXAudio_SetRegister(0x04, 0x80);
		MSXAudio_SetRegister(0x07, 0x01);   // reset ADPCM
		MSXAudio_SetRegister(0x08, 0x00);   // RAM, 256K
		MSXAudio_SetRegister(0x09, 0x00); MSXAudio_SetRegister(0x0A, 0x00);
		MSXAudio_SetRegister(0x0B, 0xFF); MSXAudio_SetRegister(0x0C, 0xFF); // stop=max
		MSXAudio_SetRegister(0x07, 0x60);   // modo escritura CPU->RAM
		g_MSXAudio_IndexPort = 0x0F;        // reg de datos seleccionado
		__asm__("ei");
		VozStreamSeg(VOICE_SEG0,     8192);
		VozStreamSeg(VOICE_SEG0 + 1, 8192);
		VozStreamSeg(VOICE_SEG0 + 2, 8192);
		VozStreamSeg(VOICE_SEG0 + 3, (u16)(VOICE_LEN - 24576u));

		__asm__("di");
		MSXAudio_SetRegister(0x07, 0x01);
		MSXAudio_SetRegister(0x09, 0x00); MSXAudio_SetRegister(0x0A, 0x00);
		MSXAudio_SetRegister(0x0B, (u8)((VOICE_LEN * 2u) >> 3));        // fin frase
		MSXAudio_SetRegister(0x0C, (u8)(((VOICE_LEN * 2u) >> 3) >> 8));
		MSXAudio_SetRegister(0x10, (u8)VOICE_DELTA);
		MSXAudio_SetRegister(0x11, (u8)(VOICE_DELTA >> 8));
		MSXAudio_SetRegister(0x12, 0xFF);   // volumen A TOPE (peticion usuario)
		MSXAudio_SetRegister(0x07, 0xA0);   // reproducir UNA vez
		__asm__("ei");
		Print_DrawTextAt(1, 6, "FRASE: \"MSXimus...\" sonando    ");
		WaitFramesOrSpace(240);             // ~4s (la frase dura 3.5)
		__asm__("di");
		MSXAudio_SetRegister(0x07, 0x01);   // stop
		MSXAudio_SetRegister(0x04, 0x7C);
		MSXAudio_SetRegister(0x04, 0x80);
		__asm__("ei");
		Print_DrawTextAt(1, 6, "FRASE: OK (3.5s, 17.9kHz, ADPCM)");
	}

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
// MoonSound FM / OPL4-FM (_82): OPL3 (YMF262) en C4-C7 + stub wave 7E/7F.
// Como el Y8950: sin instrumentos de fabrica, todo a registro. OJO OPL3:
// el reg C0 lleva los bits R/L de salida (0x30) — sin ellos, silencio.
//-----------------------------------------------------------------------------
__sfr __at(0xC4) g_Opl4Sel0;    // write: reg bank 0 / read: STATUS
__sfr __at(0xC5) g_Opl4Dat0;    // write: dato bank 0 / read: reg selecc.
__sfr __at(0xC6) g_Opl4Sel1;    // write: reg bank 1 / read: status (espejo)
__sfr __at(0xC7) g_Opl4Dat1;    // write: dato bank 1
__sfr __at(0x7F) g_Opl4Wave;    // stub wave (lectura: device ID 0x20)

void Opl4Wr0(u8 reg, u8 v) { g_Opl4Sel0 = reg; g_Opl4Dat0 = v; }
void Opl4Wr1(u8 reg, u8 v) { g_Opl4Sel1 = reg; g_Opl4Dat1 = v; }

void Opl4SetVoice(u8 ch, const u8* v)   // mismo formato de 9 bytes que g_AudPiano
{
	u8 s = g_AudOpOfs[ch];
	Opl4Wr0(0x20 + s, v[0]); Opl4Wr0(0x40 + s, v[1]);
	Opl4Wr0(0x60 + s, v[2]); Opl4Wr0(0x80 + s, v[3]);
	Opl4Wr0(0x23 + s, v[4]); Opl4Wr0(0x43 + s, v[5]);
	Opl4Wr0(0x63 + s, v[6]); Opl4Wr0(0x83 + s, v[7]);
	Opl4Wr0(0xC0 + ch, 0x30 | v[8]);     // 0x30 = salida R+L (gotcha OPL3)
}

u8 g_Opl4ShadowB0[9];
void Opl4KeyOn(u8 ch, u8 note)
{
	u8 blk = note / 12 - 1;
	u16 fn = g_AudFNum[note % 12];       // misma tabla: fs OPL3 = 49.7k
	u8 b0 = 0x20 | (blk << 2) | (u8)(fn >> 8);
	Opl4Wr0(0xB0 + ch, g_Opl4ShadowB0[ch] & 0x1F);
	Opl4Wr0(0xA0 + ch, (u8)fn);
	Opl4Wr0(0xB0 + ch, b0);
	g_Opl4ShadowB0[ch] = b0;
}
void Opl4KeyOff(u8 ch)
{
	g_Opl4ShadowB0[ch] &= 0x1F;
	Opl4Wr0(0xB0 + ch, g_Opl4ShadowB0[ch]);
}

void TestOPL4FM()
{
	u8 st1, st2, rb, wid;
	bool det, okrb;

	Screen0();
	Print_DrawTextAt(1, 1, "MOONSOUND FM (OPL4/OPL3) _82");

	// --- deteccion AdLib por timers (bajo DI, la disciplina de siempre) ---
	__asm__("di");
	Opl4Wr0(0x04, 0x60);                 // mask T1+T2
	Opl4Wr0(0x04, 0x80);                 // IRQ reset
	st1 = g_Opl4Sel0;                    // status: bits 7:5 deben ser 0
	Opl4Wr0(0x02, 0xC0);                 // T1 = (256-192)*80us = 5.12ms
	Opl4Wr0(0x04, 0x01);                 // arranca T1 sin mascara
	for (volatile u16 w = 0; w < 8000; ++w) {}
	st2 = g_Opl4Sel0;                    // espera IRQ(b7)+FT1(b6)
	Opl4Wr0(0x04, 0x60);                 // parar + mask
	Opl4Wr0(0x04, 0x80);                 // limpiar
	__asm__("ei");
	det = ((st1 & 0xE0) == 0) && ((st2 & 0xC0) == 0xC0);

	Print_DrawTextAt(1, 3, "Detectado: ");
	Print_DrawText(det ? "SI" : "NO << FALLO");
	Print_DrawText("  ");
	PrintU8Hex2(st1); Print_DrawText("->"); PrintU8Hex2(st2);
	if (!det)
	{
		Print_DrawTextAt(1, 22, "ESPACIO para seguir");
		WaitSpace();
		return;
	}

	// --- read-back de registros (shadow; el YMF278B real es legible) ---
	Opl4Wr0(0x20, 0x55);
	g_Opl4Sel0 = 0x20;                   // dejar seleccionado el reg 0x20
	rb = g_Opl4Dat0;                     // lectura C5 = registro selecc.
	okrb = (rb == 0x55);
	Opl4Wr0(0x20, 0x00);
	wid = g_Opl4Wave;                    // 7F: device ID (0x20 en el stub)

	Print_DrawTextAt(1, 5, "Readback: ");
	Print_DrawText(okrb ? "OK" : "MAL");
	Print_DrawText("  wave-id=");
	PrintU8Hex2(wid);

	// --- v7: MEDIR EL RELOJ REAL del OPL3 con su propio timer T1 ---
	// T1 con preset 0 = 256 ticks de 80us = 20.48ms por desborde (a reloj
	// nominal): ~98 desbordes en 2.0s. Si el core corre rapido (PLL mal),
	// la cuenta sube proporcionalmente ("tono agudo" = cuenta alta).
	// Mismo conteo en el Y8950 (reloj 3.58M conocido-bueno) como CONTROL.
	// El flag queda pegado hasta el clear -> el polling no pierde desbordes.
	// (el Y8950 no necesita control: su afinacion ya esta validada en HW, y
	//  ademas su IRQ esta cableada — un flag visible aqui daria tormenta)
	{
		u16 t0; u16 cO = 0; u8 fifty;
		fifty = (*(volatile u8*)0x002B & 0x80) ? 1 : 0;

		Opl4Wr0(0x04, 0x60); Opl4Wr0(0x04, 0x80);
		Opl4Wr0(0x02, 0x00);             // T1 periodo maximo (20.48ms/desborde)
		Opl4Wr0(0x04, 0x01);             // arranca (OPL4 sin IRQ cableada = seguro)
		t0 = *(volatile u16*)0xFC9E;     // JIFFY
		while ((u16)(*(volatile u16*)0xFC9E - t0) < 120)
			if (g_Opl4Sel0 & 0x40)
			{
				++cO;
				// v8: RE-ARRANCAR tras cada clear — este core aplica TODOS
				// los bits del reg 4 en cada escritura (el 0x80 a secas
				// tambien escribe ST1=0 y PARA el timer: el "T1x2s=001"
				// de la v7 nos lo paramos nosotros mismos)
				Opl4Wr0(0x04, 0x80);
				Opl4Wr0(0x04, 0x01);
			}
		Opl4Wr0(0x04, 0x60); Opl4Wr0(0x04, 0x80);

		Print_DrawTextAt(1, 6, "Reloj: T1x2s=");
		PrintU8Dec((u8)(cO > 255 ? 255 : cO));
		Print_DrawText(fifty ? " (esperado 117)" : " (esperado 98)");
	}

	Print_DrawTextAt(1, 8,  "Sonando: THE ENTERTAINER (Joplin)");
	Print_DrawTextAt(1, 10, "ahora en el OPL3 del MoonSound:");
	Print_DrawTextAt(1, 11, "melodia + bajo, timbre OPL3");
	Print_DrawTextAt(1, 20, "En bucle... ESPACIO = terminar");

	// --- setup: modo OPL3 (NEW=1) + voces + player de 2 pistas ---
	Opl4Wr1(0x05, 0x01);                 // NEW=1 (modo OPL3)
	Opl4Wr0(0x01, 0x00);
	Opl4Wr0(0xBD, 0x00);
	for (u8 c = 0; c < 9; ++c) { g_Opl4ShadowB0[c] = 0; Opl4KeyOff(c); }
	Opl4SetVoice(0, g_AudPiano);
	Opl4SetVoice(1, g_AudBass);

	{
		MusTrack trk[2];
		u8 tick = (*(volatile u8*)0x002B & 0x80) ? 8 : 10;
		trk[0].seq = g_AudMelody;  trk[0].len = numberof(g_AudMelody);  trk[0].ch = 0;
		trk[1].seq = g_AudBassSeq; trk[1].len = numberof(g_AudBassSeq); trk[1].ch = 1;
		for (u8 t = 0; t < 2; ++t) { trk[t].idx = 0; trk[t].left = 0; }
		for (;;)
		{
			// mismo secuenciador pero con key-on/off del OPL3
			for (u8 t = 0; t < 2; ++t)
			{
				MusTrack* k = &trk[t];
				if (k->left)
				{
					--k->left;
					if (k->left == 1) Opl4KeyOff(k->ch);
					if (k->left) continue;
				}
				{
					const MusEv* e = &k->seq[k->idx];
					k->idx = (u8)((k->idx + 1) % k->len);
					k->left = e->dur;
					if (e->note) Opl4KeyOn(k->ch, e->note);
					else         Opl4KeyOff(k->ch);
				}
			}
			if (WaitFramesOrSpace(tick)) break;
		}
	}

	for (u8 c = 0; c < 9; ++c) Opl4KeyOff(c);
	// v7: mute — TL a tope en TODOS los operadores de ambos bancos
	// v8: + DESCONECTAR la salida (bits R/L del reg C0 a 0): aunque un
	// canal siguiera oscilando con estado corrupto, sin salida no suena
	for (u8 i = 0; i < 9; ++i)
	{
		u8 s = g_AudOpOfs[i];
		Opl4Wr0(0x40 + s, 0x3F); Opl4Wr0(0x43 + s, 0x3F);
		Opl4Wr1(0x40 + s, 0x3F); Opl4Wr1(0x43 + s, 0x3F);
		Opl4Wr0(0xC0 + i, 0x00); Opl4Wr1(0xC0 + i, 0x00);
	}
	Print_DrawTextAt(1, 22, "FIN OPL4-FM - ESPACIO");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// DDR3 wave memory (_86): puerto debug 34h-37h del bring-up de la fase
// wavetable del OPL4. 34/35/36 = direccion (escribir 36 dispara prefetch);
// 37 OUT = escribir byte (autoinc) / IN = byte prefetchado (+prefetch de
// addr+1). IN 36 = status {bit1=busy, bit0=ready}.
//-----------------------------------------------------------------------------
__sfr __at(0x34) g_WavA0;
__sfr __at(0x35) g_WavA1;
__sfr __at(0x36) g_WavA2;
__sfr __at(0x37) g_WavDat;

#define WAV_WAIT()  while (g_WavA2 & 0x02)

void WavSetAddr(u8 a2, u8 a1, u8 a0)
{
	g_WavA0 = a0; g_WavA1 = a1; g_WavA2 = a2;   // el 36 dispara prefetch
	WAV_WAIT();
}

//-----------------------------------------------------------------------------
// _95: telemetria del blindaje anti-cuelgue (los cuelgues fantasma de la
// _92-_94). Lecturas nuevas:
//   IN 36h ST = {err, reintentos[2:0], done, activo, busy, ready} del loader
//   IN 34h D3 = {calib_drop, wd_calib[2:0], ops_rescatadas[3:0]} de la DDR3
//   IN 35h MT = {inflight_wd[3:0], alive[3:0]} del motor; alive avanza con
//               cada CE -> dos lecturas con nibble bajo distinto = motor VIVO
//-----------------------------------------------------------------------------
void PrintDiagLine(u8 y)
{
	u8 m1, m2, alive = 0;
	Print_SetPosition(1, y);
	Print_DrawText("DIAG ST=");
	PrintU8Hex2(g_WavA2);
	Print_DrawText(" D3=");
	PrintU8Hex2(g_WavA0);
	Print_DrawText(" MT=");
	m1 = g_WavA1;
	PrintU8Hex2(m1);
	for (u8 i = 0; i < 8; ++i)
	{
		m2 = g_WavA1;
		if ((m2 ^ m1) & 0x0F) { alive = 1; break; }
	}
	Print_DrawText(alive ? " vivo" : " MUERTO");
}

void TestWaveDDR3()
{
	u8 st;
	u16 errs = 0;

	Screen0();
	Print_DrawTextAt(1, 1, "DDR3 WAVE (OPL4 fase 2) _95");

	st = g_WavA2;
	Print_DrawTextAt(1, 3, "Calibracion DDR3: ");
	if (st == 0xFF) { Print_DrawText("SIN SOPORTE (core <_86)"); goto ddr_end; }
	Print_DrawText((st & 0x01) ? "OK" : "FALLO");
	if (!(st & 0x01)) goto ddr_end;

	// v10: esperar al loader de la YRW801 si aun carga (bit2; ~7s tras boot)
	if (g_WavA2 & 0x04)
	{
		Print_DrawTextAt(1, 5, "YRW801: cargando de flash...");
		while ((g_WavA2 & 0x04) && !KeyDown(KEY_SPACE)) Halt();
	}

	// patron 1: 64 bytes consecutivos (lanes de rafaga) — MITAD ALTA de los
	// 4MB (0x300100): la mitad baja 0-2MB es la YRW801, no pisarla
	WavSetAddr(0x30, 0x01, 0x00);
	for (u8 i = 0; i < 64; ++i) { g_WavDat = (u8)(i ^ 0xA5); WAV_WAIT(); }
	WavSetAddr(0x30, 0x01, 0x00);
	for (u8 i = 0; i < 64; ++i)
	{
		u8 v = g_WavDat; WAV_WAIT();
		if (v != (u8)(i ^ 0xA5)) ++errs;
	}

	// patron 2: strides de 64KB entre 2MB y 4MB (cruza filas y bancos)
	for (u8 i = 0; i < 32; ++i)
	{
		WavSetAddr(0x20 | (i & 0x1F), 0x00, 0x33);
		g_WavDat = (u8)(i * 7 + 1); WAV_WAIT();
	}
	for (u8 i = 0; i < 32; ++i)
	{
		u8 v;
		WavSetAddr(0x20 | (i & 0x1F), 0x00, 0x33);
		v = g_WavDat; WAV_WAIT();
		if (v != (u8)(i * 7 + 1)) ++errs;
	}

	Print_DrawTextAt(1, 5, "W/R (2-4MB, rafagas+strides): ");
	if (errs == 0) Print_DrawText("OK ");
	else { Print_DrawText("ERR "); PrintU8Dec((u8)(errs > 255 ? 255 : errs)); }

	// v11: DIAGNOSTICO de lanes/mascara del burst (para el ERR 096 del HW):
	// A) escribir 16 bytes DISTINTOS (40h+i) seguidos en un burst y volcarlo
	//    -> se ve si el lane de escritura/lectura esta desplazado/invertido
	// B) burst limpio: escribir UN byte (77h) en el lane 5 y volcar los 16
	//    -> se ve donde aterriza y si la mascara pisa a los vecinos
	{
		Print_DrawTextAt(1, 11, "DIAG A (esc 40-4F, leo):");
		WavSetAddr(0x31, 0x00, 0x00);
		for (u8 i = 0; i < 16; ++i) { g_WavDat = (u8)(0x40 + i); WAV_WAIT(); }
		WavSetAddr(0x31, 0x00, 0x00);
		Print_SetPosition(1, 12);
		for (u8 i = 0; i < 16; ++i) { u8 v = g_WavDat; WAV_WAIT(); PrintU8Hex2(v); }

		Print_DrawTextAt(1, 14, "DIAG B (77h en lane 5, leo):");
		WavSetAddr(0x32, 0x00, 0x05);
		g_WavDat = 0x77; WAV_WAIT();
		WavSetAddr(0x32, 0x00, 0x00);
		Print_SetPosition(1, 15);
		for (u8 i = 0; i < 16; ++i) { u8 v = g_WavDat; WAV_WAIT(); PrintU8Hex2(v); }
	}

	// v10: YRW801 presente? — primeros 8 bytes de DDR3[0] (cabecera)
	{
		u8 b[8]; u8 ff = 1, zz = 1;
		WavSetAddr(0x00, 0x00, 0x00);
		for (u8 i = 0; i < 8; ++i)
		{
			b[i] = g_WavDat; WAV_WAIT();
			if (b[i] != 0xFF) ff = 0;
			if (b[i] != 0x00) zz = 0;
		}
		Print_DrawTextAt(1, 7, "YRW801[0..7]: ");
		for (u8 i = 0; i < 8; ++i) PrintU8Hex2(b[i]);
		Print_DrawTextAt(1, 9, (ff || zz)
			? "  (vacia: flashea yrw801.rom en 0x500000)"
			: "  (datos presentes: ROM cargada)         ");
	}

	// _99: INTEGRIDAD de lectura DDR3 — DOBLE pasada de 32KB + suma16
	// contra la esperada del yrw801.bin real (0x24E9). OJO: el test
	// "motor==debug" es CIEGO al modo comun (ambos leen la MISMA DDR3:
	// si ella devuelve basura, coinciden igual). Este no lo es:
	//   - sumas DISTINTAS entre pasadas = lecturas INESTABLES (ojo de
	//     calibracion marginal, varia por arranque)
	//   - iguales pero != 24E9 = corrupcion FIJA (loader/sistematica)
	//   - iguales y 24E9 = datos PERFECTOS -> el sospechoso es el motor
	{
		u16 s1 = 0, s2 = 0;
		Print_DrawTextAt(1, 19, "INTEG 32Kx2: leyendo...");
		WavSetAddr(0x00, 0x00, 0x00);
		for (u16 i = 0; i < 32768; ++i) { s1 += g_WavDat; WAV_WAIT(); }
		WavSetAddr(0x00, 0x00, 0x00);
		for (u16 i = 0; i < 32768; ++i) { s2 += g_WavDat; WAV_WAIT(); }
		Print_DrawTextAt(1, 19, "INTEG 32Kx2: ");
		PrintU8Hex2(s1 >> 8); PrintU8Hex2(s1 & 0xFF);
		Print_DrawText("/");
		PrintU8Hex2(s2 >> 8); PrintU8Hex2(s2 & 0xFF);
		Print_DrawText(" e24E9 ");
		if (s1 != s2)          Print_DrawText("INESTABLE");
		else if (s1 != 0x24E9) Print_DrawText("MAL-FIJO");
		else                   Print_DrawText("OK");
	}

ddr_end:
	PrintDiagLine(17);                    // _95: telemetria siempre visible
	Print_DrawTextAt(1, 22, "ESPACIO para seguir");
	WaitSpace();
}

//-----------------------------------------------------------------------------
// MoonSound WAVE (_89): motor PCM YMF278B (srg320) + YRW801 en DDR3.
// Puertos 7E (selector/status) y 7F (dato); los regs wave requieren NEW2=1
// (bank1 reg 05 bit1). El status de C4 lleva ahora bit1=LD (cargando header)
// y bit0=BUSY del wave, como el chip real.
//-----------------------------------------------------------------------------
__sfr __at(0x7E) g_MoonSel;

void MoonWr(u8 reg, u8 v) { g_MoonSel = reg; g_Opl4Wave = v; }
u8   MoonRd(u8 reg) { g_MoonSel = reg; return g_Opl4Wave; }

// espera a que el header de la onda termine de cargar (~300us; LD en bit1 del
// STATUS C4 — leer C4 ademas rearma el flag como en el chip real)
void MoonWaitLD()
{
	for (u16 t = 0; t < 2000; ++t)
		if (!(g_Opl4Sel0 & 0x02)) return;
}

// programa y dispara una nota: wave 9 bits, fnum 10 bits, oct con signo
void MoonKeyOn(u8 slot, u16 wave, u16 fnum, u8 oct)
{
	MoonWr(0x20 + slot, (u8)((fnum << 1) | (wave >> 8)));   // FNUM[6:0] | WTN8
	MoonWr(0x38 + slot, (u8)((oct << 4) | ((fnum >> 7) << 1))); // OCT | FNUM[9:7]
	MoonWr(0x50 + slot, 0x01);                              // TL=0 (max), LD=1
	MoonWr(0x08 + slot, (u8)wave);                          // dispara carga header
	MoonWaitLD();
	MoonWr(0x68 + slot, 0x80);                              // KEY on, pan centro
}

//--- player wavetable: multisample del Grand Piano YRW801 -------------------
// splits {onda, raiz MIDI} por track; slot = base del track + indice de split
const u16 g_MoonWave[5] = { 300, 301, 302, 303, 304 };
const u8  g_MoonRoot[5] = {  38,  55,  62,  67,  75 };   // D2 G3 D4 G4 D#5
// fnum = 1024*(2^(s/12)-1), s=0..11
const u16 g_MoonFN[12] = { 0, 61, 125, 194, 266, 343, 424, 510, 602, 699, 801, 910 };

u8 g_MoonLastSlot[3];      // ultimo slot sonando por track (0xFF = ninguno)

// slots: track0 (melodia) usa splits 2/3/4 en slots 0-2;
//        track1 (bajo)    usa splits 0/1   en slots 3-4;
//        track2 (acomp)   usa splits 2/3   en slots 5-6
u8 MoonPickSlot(u8 track, u8 note, u8* split)
{
	if (track == 1) { *split = (note < 47) ? 0 : 1; return 3 + *split; }
	if (track == 2) { *split = (note < 65) ? 2 : 3; return 5 + (*split - 2); }
	*split = (note < 65) ? 2 : (note < 71) ? 3 : 4;
	return (u8)(*split - 2);
}

void MoonNoteOff(u8 track)
{
	if (g_MoonLastSlot[track] != 0xFF)
		MoonWr(0x68 + g_MoonLastSlot[track], 0x40);   // KEY=0 + DAMP
}

void MoonNoteOn(u8 track, u8 note)
{
	u8 split, slot;
	i8 s, oct;
	u16 fn;
	slot = MoonPickSlot(track, note, &split);
	s = (i8)(note - g_MoonRoot[split]);
	oct = 1;
	while (s < 0)   { s += 12; --oct; }
	while (s >= 12) { s -= 12; ++oct; }
	fn = g_MoonFN[(u8)s];
	MoonNoteOff(track);
	MoonWr(0x20 + slot, (u8)((fn << 1) | (g_MoonWave[split] >> 8)));
	MoonWr(0x38 + slot, (u8)(((u8)oct << 4) | (u8)((fn >> 7) << 1)));
	MoonWr(0x68 + slot, 0x80);                        // KEY on, pan centro
	g_MoonLastSlot[track] = slot;
}

void MoonEntertainer()
{
	// setup: cargar el header de cada slot (una vez) + niveles por pista
	const u8 slot_split[7] = { 2, 3, 4, 0, 1, 2, 3 };
	const u8 slot_tl[7]    = { 2, 2, 2, 8, 8, 14, 14 };  // melodia/bajo/acomp
	for (u8 k = 0; k < 7; ++k)
	{
		u16 w = g_MoonWave[slot_split[k]];
		MoonWr(0x68 + k, 0x00);                       // key off
		MoonWr(0x20 + k, (u8)(w >> 8));               // WTN8 (fnum 0)
		MoonWr(0x50 + k, (u8)((slot_tl[k] << 1) | 1)); // TL + LD
		MoonWr(0x08 + k, (u8)w);                      // dispara carga header
		MoonWaitLD();
	}
	for (u8 k = 0; k < 3; ++k) g_MoonLastSlot[k] = 0xFF;

	{
		MusTrack trk[3];
		u8 tick = (*(volatile u8*)0x002B & 0x80) ? 8 : 10;
		trk[0].seq = g_AudMelody;  trk[0].len = numberof(g_AudMelody);
		trk[1].seq = g_AudBassSeq; trk[1].len = numberof(g_AudBassSeq);
		trk[2].seq = g_AudCompSeq; trk[2].len = numberof(g_AudCompSeq);
		for (u8 k = 0; k < 3; ++k) { trk[k].ch = k; trk[k].idx = 0; trk[k].left = 0; }
		for (;;)
		{
			for (u8 k = 0; k < 3; ++k)
			{
				MusTrack* m = &trk[k];
				if (m->left)
				{
					--m->left;
					if (m->left == 1) MoonNoteOff(k);   // staccato ragtime
					if (m->left) continue;
				}
				{
					const MusEv* e = &m->seq[m->idx];
					m->idx = (u8)((m->idx + 1) % m->len);
					m->left = e->dur;
					if (e->note) MoonNoteOn(k, e->note);
					else         MoonNoteOff(k);
				}
			}
			if (WaitFramesOrSpace(tick)) break;
		}
	}
	for (u8 k = 0; k < 7; ++k) MoonWr(0x68 + k, 0x40);   // todo off + damp
}

void TestOPL4Wave()
{
	u8 id0, id1;
	bool det;

	Screen0();
	Print_DrawTextAt(1, 1, "MOONSOUND WAVE (YMF278B) _95");

	// NEW/NEW2 (imprescindible para tocar los regs wave)
	Opl4Wr1(0x05, 0x03);

	// deteccion: reg 02 = 0x20|modo. El stub de la _85-_88 devuelve 0x20
	// SIEMPRE -> se escribe modo 0x11 y se relee: el motor real refleja 0x31
	id0 = MoonRd(0x02);
	MoonWr(0x02, 0x11);
	id1 = MoonRd(0x02);
	MoonWr(0x02, 0x00);
	det = (id0 == 0x20) && (id1 == 0x31);

	Print_DrawTextAt(1, 3, "Motor PCM: ");
	Print_DrawText(det ? "SI" : "NO (stub/core viejo)");
	Print_DrawText(" ");
	PrintU8Hex2(id0); PrintU8Hex2(id1);
	PrintDiagLine(18);                   // _95: aqui se ve SI el motor late
	                                     // (fila 18: la 20 la pisa "En bucle"
	                                     //  y los espacios son transparentes)
	if (!det) goto wave_end;

	// si el loader aun copia la YRW801, esperar (bit2 del puerto 36)
	if (g_WavA2 != 0xFF && (g_WavA2 & 0x04))
	{
		Print_DrawTextAt(1, 5, "YRW801: cargando...");
		while ((g_WavA2 & 0x04) && !KeyDown(KEY_SPACE)) Halt();
	}

	// YRW801 leida POR EL MOTOR (regs 3-6) vs puerto debug DDR3 (34-37):
	// si coinciden, el camino motor->DDR3 esta entero
	{
		u8 be[8], bd[8], eq = 1;
		MoonWr(0x02, 0x01);                  // MEMMODE on
		MoonWr(0x03, 0x00); MoonWr(0x04, 0x00); MoonWr(0x05, 0x00);
		for (u8 i = 0; i < 8; ++i) be[i] = MoonRd(0x06);
		MoonWr(0x02, 0x00);
		WavSetAddr(0x00, 0x00, 0x00);        // mismo origen via puerto debug
		for (u8 i = 0; i < 8; ++i) { bd[i] = g_WavDat; WAV_WAIT(); }
		for (u8 i = 0; i < 8; ++i) if (be[i] != bd[i]) eq = 0;
		Print_DrawTextAt(1, 5, "Motor lee YRW801: ");
		for (u8 i = 0; i < 8; ++i) PrintU8Hex2(be[i]);
		Print_DrawTextAt(1, 6, eq ? "  == puerto debug: OK"
		                          : "  != puerto debug: FALLO");
	}

	// RAM de muestras (0x200000+, el bit21 que faltaba): escribir y releer
	{
		u8 v0, v1, v2;
		MoonWr(0x02, 0x01);
		MoonWr(0x03, 0x20); MoonWr(0x04, 0x00); MoonWr(0x05, 0x00);
		MoonWr(0x06, 0xA5); MoonWr(0x06, 0x5A); MoonWr(0x06, 0xC3);
		MoonWr(0x03, 0x20); MoonWr(0x04, 0x00); MoonWr(0x05, 0x00);
		v0 = MoonRd(0x06); v1 = MoonRd(0x06); v2 = MoonRd(0x06);
		MoonWr(0x02, 0x00);
		Print_DrawTextAt(1, 8, "RAM muestras 2MB: ");
		Print_DrawText((v0 == 0xA5 && v1 == 0x5A && v2 == 0xC3) ? "OK" : "ERR ");
		if (v0 != 0xA5) { PrintU8Hex2(v0); PrintU8Hex2(v1); PrintU8Hex2(v2); }
	}

	// --- THE ENTERTAINER en el GRAND PIANO wavetable de la YRW801 ---
	// Multisample real: la melodia/bajo/acompanamiento eligen el SPLIT del
	// piano mas cercano a cada nota (raices medidas por autocorrelacion del
	// loop: onda 300=D2, 301=G3, 302=D4, 303=G4, 304=D#5). Un slot por
	// track+split (7 slots), headers cargados UNA vez en el setup; cambiar
	// de nota solo toca F-num/octava. (La onda 0 del banco es un zumbido de
	// 42 muestras: el "grito" del primer arpegio era la onda, no el motor.)
	Print_DrawTextAt(1, 10, "THE ENTERTAINER (Joplin) ahora");
	Print_DrawTextAt(1, 11, "en el GRAND PIANO wavetable:");
	Print_DrawTextAt(1, 12, "3 pistas, multisample YRW801");
	Print_DrawTextAt(1, 20, "En bucle... ESPACIO = terminar");
	MoonWr(0xF9, 0x00);                      // mezcla PCM a 0dB
	MoonEntertainer();

wave_end:
	Print_DrawTextAt(1, 22, "ESPACIO para seguir");
	WaitSpace();
}

//=============================================================================
// MAIN
//=============================================================================
void main()
{
	Bios_SetKeyClick(FALSE);
	MSXAudio_Initialize();

	for (;;)
	{
		Screen0();
		Print_DrawTextAt(1, 1,  "OPL4TEST - AUDIO DEL MSXIMUS");
		Print_DrawTextAt(1, 3,  "1) Y8950: detecta/timers/IRQ/");
		Print_DrawTextAt(1, 4,  "   ADPCM + FRASE + Entertainer");
		Print_DrawTextAt(1, 5,  "2) MoonSound FM: detecta/reloj");
		Print_DrawTextAt(1, 6,  "   + Entertainer en OPL3");
		Print_DrawTextAt(1, 7,  "3) DDR3 wave: calibracion+W/R");
		Print_DrawTextAt(1, 8,  "4) MoonSound WAVE: motor PCM");
		Print_DrawTextAt(1, 10, "(la musica se corta con ESPACIO)");
		Print_DrawTextAt(1, 22, "ESPACIO = empezar");
		WaitSpace();

		TestY8950();
		TestOPL4FM();
		TestWaveDDR3();
		TestOPL4Wave();

		Screen0();
		Print_DrawTextAt(1, 1, "FIN - ESPACIO = repetir");
		WaitSpace();
	}
}
