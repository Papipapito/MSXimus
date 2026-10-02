//=============================================================================
// mxupdate.c - MXUPDATE.COM: actualiza el core del MSXimus 60K/138K desde el propio MSX (V3.8, 01/10/2026)
//
//   MXUPDATE [fichero.UPD] [/C] [/EN] [/ES]   (por defecto MSXIMUS.UPD en el directorio actual)
//   MXUPDATE /N [/S:servidor[:puerto]] [fichero.UPD]
//   /N = descargar la ultima version por la red (UNAPI: el ESP32 del MSXimus) a fichero.UPD y grabarla. Sin /S va
//        a https://msx.barcelona/ota/tang60k/ (o tang138k); /S:192.168.2.200:8000 = el servidor de desarrollo
//        del PC (fpga/zynq/ota/ota_servidor.py del MSXimus Z, http y la carpeta tang60k/).
//   /C = solo comprobar el fichero (cabecera y CRC), sin tocar la flash; vale en cualquier MSX con DOS 2.
//
// Graba en la flash SPI de la FPGA lo que trae un .UPD (tools/mxupd.py: el bitstream y/o el pack de la BIOS) a
// traves del puente de la flash del core (fpga/src/flash_bridge.v, dispositivo de E/S conmutada 4Dh). Orden:
//   1. que el core tenga el puente (V3.8 o posterior) y que la placa (IDCODE del bitstream que hay en la flash)
//      sea la del fichero;
//   2. la cabecera y el CRC-32 de cada segmento del FICHERO, antes de borrar nada;
//   3. borrar y programar sector a sector (4 KB; las paginas que son todo FF no se programan);
//   4. releer la flash entera y comprobar los CRC otra vez.
// La FPGA sigue funcionando con lo que cargo al encender, asi que si algo falla se puede repetir; el core nuevo
// entra al apagar y encender. Los ajustes (0x480000) y las ondas del OPL4 no se tocan.
// El idioma es el del menu (lo cuenta el core en #4E) salvo /EN o /ES.
//=============================================================================
#include "msxgl.h"
#include "network.h"

__sfr __at(0x29) P_PARCHE;
__sfr __at(0x2F) P_VERSION;
__sfr __at(0x40) P_ID;
__sfr __at(0x41) P_A1;          // OUT: A[23:16]   IN: estado
__sfr __at(0x42) P_A2;          // OUT: A[15:8]
__sfr __at(0x43) P_ORDEN;
__sfr __at(0x44) P_DATO;
__sfr __at(0x4E) P_INFO;
#define P_ESTADO P_A1

#define ID_PUENTE   0x4D
#define ST_OCUPADO  0x01
#define ST_PIDE     0x02
#define ST_DATO     0x04
#define ST_AJENO    0x08

#define JIFFY (*(volatile u16*)0xFC9E)

static bool g_en, g_solo_comprobar, g_red;
static c8  g_srv[48];          // /S: servidor (vacio = msx.barcelona)
static u16 g_puerto;
#define T(es, en) (g_en ? (en) : (es))

//-----------------------------------------------------------------------------
// consola
static void Pr(const c8* s) { while (*s) DOS_CharOutput(*s++); }
static void PrN(u32 v)
{
	c8 t[11]; u8 i = 0;
	do { t[i++] = '0' + (u8)(v % 10); v /= 10; } while (v);
	while (i) DOS_CharOutput(t[--i]);
}
static void PrHex(u32 v, u8 dig)
{
	while (dig--) { u8 n = (u8)(v >> (dig * 4)) & 15; DOS_CharOutput(n < 10 ? '0' + n : 'A' + n - 10); }
}
static void Barra(u32 hecho, u32 total)
{
	u8 i, n = total ? (u8)((hecho * 30) / total) : 30;
	DOS_CharOutput('\r');
	Pr("  [");
	for (i = 0; i < 30; i++) DOS_CharOutput(i < n ? '#' : '.');
	Pr("] ");
	PrN(total ? (hecho * 100) / total : 100);
	Pr("% ");
}
static void Fin(u8 err)
{
	__asm ei __endasm;
	Pr("\r\n");
	DOS_Exit(err);
}

//-----------------------------------------------------------------------------
// CRC-32 (zlib) con cuatro tablas de 256 en una pagina alineada; el bucle va en ensamblador (~135 T por byte)
static u8  g_tab[256 * 5];
static u32 g_crc;
static const u8* g_crcp;
static u16 g_crcn;
extern u8 crc_pag[2];

static void CrcBloque(void) __NAKED
{
__asm
	push ix
	ld   hl, (_g_crcn)
	ld   a, h
	or   l
	jr   z, crc_fin
	ld   b, h
	ld   c, l
	ld   hl, (_g_crcp)
	exx
	ld   hl, #_g_crc
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	ld   c, (hl)
	inc  hl
	ld   b, (hl)
crc_bucle:
	exx
	ld   a, (hl)
	inc  hl
	exx
	xor  e
	ld   l, a
_crc_pag::
	ld   h, #0
	ld   a, d
	xor  (hl)
	ld   e, a
	inc  h
	ld   a, c
	xor  (hl)
	ld   d, a
	inc  h
	ld   a, b
	xor  (hl)
	ld   c, a
	inc  h
	ld   b, (hl)
	exx
	dec  bc
	ld   a, b
	or   c
	exx
	jr   nz, crc_bucle
	ld   hl, #_g_crc
	ld   (hl), e
	inc  hl
	ld   (hl), d
	inc  hl
	ld   (hl), c
	inc  hl
	ld   (hl), b
crc_fin:
	pop  ix
	ret
__endasm;
}

static void CrcIniciaTablas(void)
{
	u16 pag = ((u16)g_tab + 255) & 0xFF00;
	u8* t = (u8*)pag;
	u16 i; u8 k;
	for (i = 0; i < 256; i++) {
		u32 c = i;
		for (k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xEDB88320UL : (c >> 1);
		t[i] = (u8)c; t[i + 256] = (u8)(c >> 8); t[i + 512] = (u8)(c >> 16); t[i + 768] = (u8)(c >> 24);
	}
	crc_pag[1] = (u8)(pag >> 8);                // el "ld h,#pagina" del bucle
}
static void Crc(const u8* p, u16 n) { g_crcp = p; g_crcn = n; CrcBloque(); }

//-----------------------------------------------------------------------------
// puente de la flash (los ID de #40 los cambia cualquiera que use la SD: se vuelve a elegir siempre)
static bool Espera(u8 mascara, u8 valor, u16 jiffies)
{
	u16 t0 = JIFFY;
	for (;;) {
		P_ID = ID_PUENTE;
		if ((P_ESTADO & mascara) == valor) return TRUE;
		if ((u16)(JIFFY - t0) > jiffies) return FALSE;
	}
}
static void Direccion(u32 a) { P_ID = ID_PUENTE; P_A1 = (u8)(a >> 16); P_A2 = (u8)(a >> 8); }

static bool Borra4K(u32 a)
{
	if (!Espera(ST_OCUPADO | ST_AJENO, 0, 300)) return FALSE;
	Direccion(a);
	P_ORDEN = 1;
	return Espera(ST_OCUPADO, 0, 300);              // 4 KB: 45 ms tipicos, 400 como mucho
}

static bool Programa256(u32 a, const u8* d)
{
	u16 i;
	if (!Espera(ST_OCUPADO | ST_AJENO, 0, 300)) return FALSE;
	Direccion(a);
	P_ORDEN = 2;
	__asm di __endasm;
	for (i = 0; i < 256; i++) {
		u16 n = 0;
		while (!(P_ESTADO & ST_PIDE)) if (++n == 0) { __asm ei __endasm; return FALSE; }
		P_DATO = d[i];
	}
	__asm ei __endasm;
	return Espera(ST_OCUPADO, 0, 60);
}

// lectura seguida desde 'a' (multiplo de 256): LeeEmpieza, LeeBloque..., LeePara
static bool LeeEmpieza(u32 a)
{
	if (!Espera(ST_OCUPADO | ST_AJENO, 0, 300)) return FALSE;
	Direccion(a);
	P_ORDEN = 3;
	return Espera(ST_DATO, ST_DATO, 60);
}
static bool LeeBloque(u8* d, u16 n)          // FALSE = la flash ha dejado de dar datos
{
	__asm di __endasm;
	P_ID = ID_PUENTE;
	while (n--) {
		u16 t = 0;
		while (!(P_ESTADO & ST_DATO)) if (++t == 0) { __asm ei __endasm; return FALSE; }
		*d++ = P_DATO;
	}
	__asm ei __endasm;
	return TRUE;
}
static void LeePara(void) { P_ID = ID_PUENTE; P_ORDEN = 0; }

//-----------------------------------------------------------------------------
// fichero
static u8 AbreLectura(const c8* ruta) __NAKED
{
	ruta;
__asm
	push ix
	push iy
	ex   de, hl
	ld   a, #0x01
	ld   c, #0x43
	call #0x0005
	or   a
	ld   a, b
	jr   z, ab_ok
	ld   a, #0xFF
ab_ok:
	pop  iy
	pop  ix
	ret
__endasm;
}

typedef struct { u32 dir, tam, crc, off; } Seg;
static u8  g_cab[132];
static Seg g_seg[4];
static u8  g_nseg;
static u8  g_buf[4096];
static u8  g_fh;
static c8  g_ruta[64];

static u32 Le32(const u8* p) { return (u32)p[0] | ((u32)p[1] << 8) | ((u32)p[2] << 16) | ((u32)p[3] << 24); }

static bool LeeFichero(u32 off, u16 n)
{
	DOS_SeekHandle(g_fh, (i32)off, SEEK_SET);
	return DOS_ReadHandle(g_fh, g_buf, n) == n;
}

// IDCODE del bitstream que empieza en d (A5 C3, 06 00 00 00, IDCODE en big endian); 0 si no lo encuentra
static u32 Idcode(const u8* d, u16 n)
{
	u16 i;
	for (i = 0; i + 10 <= n; i++)
		if (d[i] == 0xA5 && d[i + 1] == 0xC3 && d[i + 2] == 0x06 && !d[i + 3] && !d[i + 4] && !d[i + 5])
			return ((u32)d[i + 6] << 24) | ((u32)d[i + 7] << 16) | ((u32)d[i + 8] << 8) | d[i + 9];
	return 0;
}

static void Opciones(void)
{
	u8 n = *(u8*)0x80, i = 0, k = 0;
	const c8* s = (const c8*)0x81;
	// el arranque de MSXgl para DOS NO pone a cero las variables: lo que no se inicializa aqui conserva lo que
	// dejo la ejecucion anterior (visto en openMSX: un /C se colaba en la siguiente orden)
	g_ruta[0] = 0; g_srv[0] = 0; g_puerto = 80;
	g_solo_comprobar = FALSE; g_red = FALSE;
	while (i < n) {
		while (i < n && s[i] == ' ') i++;
		if (i >= n) break;
		if (s[i] == '/') {
			c8 a = s[i + 1] & 0xDF, b = s[i + 2] & 0xDF;
			if (a == 'E' && b == 'N') g_en = TRUE;
			if (a == 'E' && b == 'S') g_en = FALSE;
			if (a == 'C') g_solo_comprobar = TRUE;
			if (a == 'N') g_red = TRUE;
			if (a == 'S' && s[i + 2] == ':') {
				i += 3; k = 0;
				while (i < n && s[i] != ' ' && s[i] != ':' && k < sizeof g_srv - 1) g_srv[k++] = s[i++];
				g_srv[k] = 0;
				g_puerto = 80;
				if (i < n && s[i] == ':') { g_puerto = 0; i++; while (i < n && s[i] >= '0' && s[i] <= '9') g_puerto = g_puerto * 10 + (s[i++] - '0'); }
				g_red = TRUE;
			}
			while (i < n && s[i] != ' ') i++;
		} else {
			k = 0;
			while (i < n && s[i] != ' ' && k < 63) g_ruta[k++] = s[i++];
			g_ruta[k] = 0;
		}
	}
	if (!g_ruta[0]) { const c8* d = "MSXIMUS.UPD"; k = 0; while ((g_ruta[k] = d[k])) k++; }   // k venia de /S:
}


//-----------------------------------------------------------------------------
// red: el manifiesto y el .UPD por HTTP (UNAPI TCP/IP; con TLS si el servidor es msx.barcelona)
static c8  g_hdr[512];
static u16 g_hdr_n;
static c8  g_man[1536];
static u16 g_man_n;
static u8  g_ipsrv[4];
static NetConn g_cx;
typedef struct { c8 var[16]; c8 fich[24]; u32 tam; } Imagen;
static Imagen g_img[4];
static u8 g_nimg;
static c8 g_ver_srv[16];
static c8 g_notas[64];

// (el string.h de MSXgl es el suyo, no el de C)
static bool Prefijo(const c8* s, const c8* p) { while (*p) if (*s++ != *p++) return FALSE; return TRUE; }
static bool Igual(const c8* a, const c8* b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }

static bool LeeIP(const c8* s, u8* ip)
{
	u8 k;
	for (k = 0; k < 4; k++) {
		u16 v = 0; u8 d = 0;
		while (*s >= '0' && *s <= '9') { v = v * 10 + (*s++ - '0'); d++; }
		if (!d || v > 255) return FALSE;
		ip[k] = (u8)v;
		if (k < 3) { if (*s != '.') return FALSE; s++; }
	}
	return *s == 0;
}

static bool Conecta(void)
{
	u16 t0;
	if (g_srv[0]) {
		if (!LeeIP(g_srv, g_ipsrv) && Net_ResolveDNS(g_srv, g_ipsrv) != NET_OK) return FALSE;
		g_cx = Net_Open(g_ipsrv, g_puerto);
	} else {
		if (Net_ResolveDNS("msx.barcelona", g_ipsrv) != NET_OK) return FALSE;
		g_cx = Net_OpenTLS("msx.barcelona", g_ipsrv, 443);
		if (g_cx == NET_INVALID_CONN) g_cx = Net_Open(g_ipsrv, 80);
	}
	if (g_cx == NET_INVALID_CONN) return FALSE;
	t0 = JIFFY;
	while (!Net_IsConnected(g_cx)) if ((u16)(JIFFY - t0) > 600) { Net_Abort(g_cx); return FALSE; }
	return TRUE;
}

static u16 Pega(c8* d, u16 i, const c8* t) { while (*t) d[i++] = *t++; return i; }

// GET de 'nombre' (relativo a la carpeta de la placa) al fichero fh, o a g_man si fh == 0xFF
static bool Http(const c8* placa, const c8* nombre, u8 fh)
{
	u16 i = 0, t0;
	u32 escrito = 0, clen = 0;
	bool cab = FALSE, hay_clen = FALSE, ok = FALSE;
	if (!Conecta()) return FALSE;
	i = Pega(g_hdr, i, "GET ");
	i = Pega(g_hdr, i, g_srv[0] ? "/" : "/ota/");
	i = Pega(g_hdr, i, placa[7] == '1' ? "tang138k/" : "tang60k/");
	i = Pega(g_hdr, i, nombre);
	i = Pega(g_hdr, i, " HTTP/1.0\r\nHost: ");
	i = Pega(g_hdr, i, g_srv[0] ? g_srv : "msx.barcelona");
	i = Pega(g_hdr, i, "\r\nUser-Agent: MXUPDATE\r\nConnection: close\r\n\r\n");
	if (!Net_Send(g_cx, (const u8*)g_hdr, i)) { Net_Abort(g_cx); return FALSE; }
	g_hdr_n = 0; g_man_n = 0;
	t0 = JIFFY;
	for (;;) {
		u16 n = Net_Available(g_cx), off = 0;
		if (!n) {
			if (!Net_IsConnected(g_cx) && !Net_Available(g_cx)) { ok = cab && (!hay_clen || escrito == clen); break; }
			if ((u16)(JIFFY - t0) > 900) break;                // 15 s sin datos
			continue;
		}
		t0 = JIFFY;
		if (n > sizeof g_buf) n = sizeof g_buf;
		if (Net_Recv(g_cx, g_buf, n) != n) break;
		if (!cab) {                                             // cabecera HTTP hasta la linea vacia
			while (off < n && !cab) {
				if (g_hdr_n < sizeof g_hdr - 1) g_hdr[g_hdr_n++] = g_buf[off];
				off++;
				if (g_hdr_n >= 4 && g_hdr[g_hdr_n - 1] == '\n' && g_hdr[g_hdr_n - 3] == '\n') cab = TRUE;
			}
			if (cab) {
				u16 k = 0;
				g_hdr[g_hdr_n] = 0;
				while (g_hdr[k] && g_hdr[k] != ' ') k++;
				if (g_hdr[k + 1] != '2' || g_hdr[k + 2] != '0' || g_hdr[k + 3] != '0') break;
				for (k = 0; g_hdr[k]; k++)
					if ((g_hdr[k] == '\n') && ((g_hdr[k + 1] | 0x20) == 'c') && ((g_hdr[k + 9] | 0x20) == 'l') &&
					    g_hdr[k + 15] == ':') {
						u16 j = k + 16;
						while (g_hdr[j] == ' ') j++;
						while (g_hdr[j] >= '0' && g_hdr[j] <= '9') clen = clen * 10 + (g_hdr[j++] - '0');
						hay_clen = TRUE;
					}
			}
		}
		if (cab && off < n) {
			u16 m = n - off;
			if (fh != 0xFF) {
				if (DOS_WriteHandle(fh, g_buf + off, m) != m) break;
				if (((escrito + m) ^ escrito) & ~0x3FFFUL || escrito + m == clen) Barra(escrito + m, clen);
			} else {
				if (g_man_n + m >= sizeof g_man) break;
				{ u16 j; for (j = 0; j < m; j++) g_man[g_man_n++] = g_buf[off + j]; }
			}
			escrito += m;
			if (hay_clen && escrito >= clen) { ok = TRUE; break; }
		}
	}
	Net_Close(g_cx);
	if (fh == 0xFF) g_man[g_man_n] = 0;
	return ok;
}

// manifiesto: "MSXIMUS-UPD 1", placa=, version=, notas=, imagen=<variante> <fichero> <tamano>
static bool LeeManifiesto(const c8* placa)
{
	c8* l = g_man;
	bool cab = FALSE, placa_ok = FALSE;
	g_nimg = 0; g_ver_srv[0] = 0; g_notas[0] = 0;
	while (*l) {
		c8* f = l;
		u8 k;
		while (*f && *f != '\n') f++;
		if (*f) *f++ = 0;
		k = 0; while (l[k]) k++;
		if (k && l[k - 1] == '\r') l[k - 1] = 0;
		if (Prefijo(l, "MSXIMUS-UPD 1")) cab = TRUE;
		else if (Prefijo(l, "placa=")) placa_ok = Igual(l + 6, placa);
		else if (Prefijo(l, "version=")) { for (k = 0; k < 15 && l[8 + k]; k++) g_ver_srv[k] = l[8 + k]; g_ver_srv[k] = 0; }
		else if (Prefijo(l, "notas=")) { for (k = 0; k < 63 && l[6 + k]; k++) g_notas[k] = l[6 + k]; g_notas[k] = 0; }
		else if (Prefijo(l, "imagen=") && g_nimg < 4) {
			Imagen* im = &g_img[g_nimg];
			c8* q = l + 7;
			for (k = 0; k < 15 && *q && *q != ' '; k++) im->var[k] = *q++;
			im->var[k] = 0;
			while (*q == ' ') q++;
			for (k = 0; k < 23 && *q && *q != ' '; k++) im->fich[k] = *q++;
			im->fich[k] = 0;
			while (*q == ' ') q++;
			im->tam = 0;
			while (*q >= '0' && *q <= '9') im->tam = im->tam * 10 + (*q++ - '0');
			if (im->var[0] && im->fich[0] && im->tam) g_nimg++;
		}
		l = f;
	}
	return cab && placa_ok && g_ver_srv[0] && g_nimg;
}

static bool Contiene(const c8* s, const c8* t)
{
	for (; *s; s++) { const c8* a = s; const c8* b = t; while (*a && *b && *a == *b) { a++; b++; } if (!*b) return TRUE; }
	return FALSE;
}

static void Describe(const Imagen* im)
{
	Pr(Contiene(im->var, "nextor3") ? "Nextor 3" : "Nextor 2.1.4");
	Pr(Contiene(im->var, "-en") ? T(", ingles", ", English") : T(", castellano", ", Spanish"));
}

// BDOS _CREATE ($44): DE = ruta, A = modo, B = atributos -> A = error, B = handle
static u8 CreaEscritura(const c8* ruta) __NAKED
{
	ruta;
__asm
	push ix
	push iy
	ex   de, hl
	xor  a
	ld   b, #0
	ld   c, #0x44
	call #0x0005
	or   a
	ld   a, b
	jr   z, cr_ok
	ld   a, #0xFF
cr_ok:
	pop  iy
	pop  ix
	ret
__endasm;
}

// descarga la version del servidor a g_ruta; FALSE = no se puede o el usuario no quiere
static bool Red(const c8* placa)
{
	u8 i, elegida = 0, fh;
	c8 c;
	if (Net_Init() != NET_OK) { Pr(T("No hay red (UNAPI): configura el WiFi con la W del menu.", "No network (UNAPI): set up the WiFi with W in the menu.")); return FALSE; }
	Pr(T("Preguntando al servidor...\r\n", "Asking the server...\r\n"));
	if (!Http(placa, "manifiesto.txt", 0xFF) || !LeeManifiesto(placa)) {
		Pr(T("Sin conexion con el servidor de actualizaciones.", "Cannot reach the update server.")); return FALSE;
	}
	Pr(T("Version en el servidor: ", "Version on the server: ")); Pr(g_ver_srv); Pr("\r\n");
	if (g_notas[0]) { Pr("  "); Pr(g_notas); Pr("\r\n"); }
	for (i = 0; i < g_nimg; i++) {
		Pr("  "); DOS_CharOutput('1' + i); Pr(") "); Describe(&g_img[i]);
		Pr("  ("); PrN(g_img[i].tam / 1024); Pr(" KB)\r\n");
		if (!elegida && Contiene(g_img[i].var, "-en") == g_en) elegida = i + 1;
	}
	Pr(T("Elige (1-", "Choose (1-")); DOS_CharOutput('0' + g_nimg); Pr(T(", ESC = salir): ", ", ESC = quit): "));
	for (;;) {
		c = DOS_CharInput();
		if (c == 0x1B) return FALSE;
		if (c == 13 && elegida) break;
		if (c >= '1' && c < '1' + g_nimg) { elegida = c - '0'; break; }
	}
	Pr("\r\n");
	Pr(T("Aviso: si la SD no esta preparada para ", "Note: if the SD card is not prepared for "));
	Pr(Contiene(g_img[elegida - 1].var, "nextor3") ? "Nextor 3" : "Nextor 2.1.4");
	Pr(T(",\r\nno arrancara MSX-DOS (MSX SD Maker la prepara). Seguir? (S/N) ",
	     ",\r\nMSX-DOS will not boot (MSX SD Maker prepares it). Go on? (Y/N) "));
	c = DOS_CharInput() & 0xDF;
	if (c != 'S' && c != 'Y') return FALSE;
	Pr(T("\r\nDescargando ", "\r\nDownloading ")); Pr(g_img[elegida - 1].fich); Pr(T(" en ", " to ")); Pr(g_ruta); Pr("\r\n");
	fh = CreaEscritura(g_ruta);
	if (fh == 0xFF) { Pr(T("No se puede crear ", "Cannot create ")); Pr(g_ruta); return FALSE; }
	i = Http(placa, g_img[elegida - 1].fich, fh);
	DOS_CloseHandle(fh);
	if (!i) { Pr(T("\r\nLa descarga se ha cortado. No se ha tocado nada.", "\r\nThe download was interrupted. Nothing was changed.")); return FALSE; }
	Pr("\r\n");
	return TRUE;
}

//-----------------------------------------------------------------------------
void main(void)
{
	u32 id_flash, id_fich, total, hecho;
	u8 i, ver, parche;
	const c8* placa;

	bool puente;
	P_ID = ID_PUENTE;
	puente = P_ID == 0xB2 && (P_ESTADO & 0xF0) == 0xA0;
	g_en = puente && (P_INFO & 0x05) == 0x05;      // el idioma del menu, si el core lo sabe
	Opciones();

	Pr(T("MSXimus - actualizar el core\r\n", "MSXimus - core update\r\n"));
	CrcIniciaTablas();
	if (g_solo_comprobar) { placa = 0; id_flash = 0; goto fichero; }
	if (!puente) {
		Pr(T("Este core no se puede actualizar desde el MSX: hace\r\nfalta la V3.8 o posterior (grabala una vez con el PC).",
		     "This core cannot be updated from the MSX: it needs\r\nV3.8 or later (flash it once from the PC)."));
		Fin(1);
	}
	ver = P_VERSION; parche = P_PARCHE;

	// ---- la placa: el IDCODE del bitstream que hay grabado ----
	if (P_ESTADO & ST_AJENO) {                      // justo tras encender el core carga las ondas del OPL4 de la flash
		Pr(T("Esperando a que el core suelte la flash...\r\n", "Waiting for the core to release the flash...\r\n"));
		if (!Espera(ST_AJENO, 0, 3600)) { Pr(T("La flash sigue ocupada.", "The flash is still busy.")); Fin(1); }
	}
	if (!LeeEmpieza(0)) { Pr(T("La flash no responde.", "The flash does not answer.")); Fin(1); }
	if (!LeeBloque(g_buf, 256)) { LeePara(); Pr(T("La flash no responde.", "The flash does not answer.")); Fin(1); }
	LeePara();
	id_flash = Idcode(g_buf, 256);
	placa = id_flash == 0x0001481BUL ? "console60k" : id_flash == 0x0001081BUL ? "console138k" : 0;
	Pr(T("Core instalado: ", "Installed core: "));
	PrN(ver >> 4); DOS_CharOutput('.'); PrN(ver & 15);
	if (parche && parche < 16) { DOS_CharOutput('.'); PrN(parche); }
	Pr(placa ? (id_flash == 0x0001481BUL ? " (60K)\r\n" : " (138K)\r\n") : "\r\n");
	if (!placa) { Pr(T("No reconozco la placa.", "Unknown board.")); Fin(1); }
	if (g_red && !Red(placa)) Fin(1);

	// ---- el fichero ----
fichero:
	g_fh = AbreLectura(g_ruta);
	if (g_fh == 0xFF) { Pr(T("No encuentro ", "Cannot open ")); Pr(g_ruta); Fin(1); }
	if (DOS_ReadHandle(g_fh, g_cab, sizeof g_cab) < 68) goto mal_fichero;
	for (i = 0; i < 6; i++) if (g_cab[i] != "MXUPD1"[i]) goto mal_fichero;
	g_nseg = g_cab[56];
	if (!g_nseg || g_nseg > 4) goto mal_fichero;
	g_crc = 0xFFFFFFFFUL; Crc(g_cab, 64 + 16 * g_nseg);
	if (~g_crc != Le32(g_cab + 64 + 16 * g_nseg)) goto mal_fichero;
	if (placa) for (i = 0; i < 10; i++) if (g_cab[8 + i] != placa[i]) break;
	if (placa && (i < 10 || (placa[10] ? g_cab[18] != placa[10] : g_cab[18] != 0))) {
		Pr(T("Este fichero es para otra placa: ", "This file is for another board: ")); Pr((c8*)g_cab + 8); Fin(1);
	}
	total = 0;
	for (i = 0; i < g_nseg; i++) {
		const u8* s = g_cab + 64 + 16 * i;
		u32 lim = g_cab[15] == '1' ? 0x800000UL : 0x400000UL;            // el pack: console138k / console60k
		g_seg[i].dir = Le32(s); g_seg[i].tam = Le32(s + 4); g_seg[i].crc = Le32(s + 8); g_seg[i].off = Le32(s + 12);
		// solo el bitstream (0 .. pack) y el pack (512 KB): nunca los ajustes ni las ondas
		if ((g_seg[i].dir & 0xFFF) || !g_seg[i].tam ||
		    !((g_seg[i].dir == 0 && g_seg[i].tam <= lim) || (g_seg[i].dir == lim && g_seg[i].tam <= 0x80000UL)))
			goto mal_fichero;
		total += g_seg[i].tam;
	}
	Pr(T("Fichero: ", "File: ")); Pr(g_ruta); Pr(" - "); Pr((c8*)g_cab + 8); Pr(T(" - version ", " - version ")); Pr((c8*)g_cab + 24);
	Pr(" ("); Pr((c8*)g_cab + 40); Pr(")\r\n");

	// ---- 1. el fichero entero, antes de tocar nada ----
	Pr(T("Comprobando el fichero...\r\n", "Checking the file...\r\n"));
	hecho = 0; id_fich = 0;
	for (i = 0; i < g_nseg; i++) {
		u32 p = 0;
		g_crc = 0xFFFFFFFFUL;
		while (p < g_seg[i].tam) {
			u16 n = (g_seg[i].tam - p) > sizeof g_buf ? sizeof g_buf : (u16)(g_seg[i].tam - p);
			if (!LeeFichero(g_seg[i].off + p, n)) goto mal_fichero;
			if (g_seg[i].dir == 0 && p == 0) id_fich = Idcode(g_buf, 256);
			Crc(g_buf, n);
			p += n; hecho += n;
			Barra(hecho, total);
		}
		if (g_solo_comprobar) {
			Pr("\r\n  0x"); PrHex(g_seg[i].dir, 6); Pr("  "); PrN(g_seg[i].tam); Pr(" bytes  CRC "); PrHex(~g_crc, 8);
			Pr(~g_crc == g_seg[i].crc ? T(" bien", " ok") : T(" MAL", " BAD"));
			if (g_seg[i].dir == 0) { Pr("  IDCODE "); PrHex(id_fich, 8); }
			Pr("\r\n");
		}
		if (~g_crc != g_seg[i].crc) goto mal_fichero;
		if (!g_solo_comprobar && g_seg[i].dir == 0 && id_fich != id_flash) {
			Pr(T("\r\nEl bitstream del fichero es de otro chip.", "\r\nThe bitstream in the file is for another chip."));
			Fin(1);
		}
	}
	if (g_solo_comprobar) { Pr(T("Fichero correcto.", "File OK.")); Fin(0); }
	Pr(T("\r\nFichero correcto. Grabar en la flash? (S/N) ", "\r\nFile OK. Write it to the flash? (Y/N) "));
	{
		c8 c = DOS_CharInput() & 0xDF;
		if (c != 'S' && c != 'Y') { Pr(T("\r\nNo se ha tocado nada.", "\r\nNothing was changed.")); Fin(0); }
	}

	// ---- 2. borrar y programar ----
	Pr(T("\r\nGrabando. NO APAGUES EL MSX.\r\n", "\r\nWriting. DO NOT SWITCH OFF THE MSX.\r\n"));
	hecho = 0;
	for (i = 0; i < g_nseg; i++) {
		u32 p = 0;
		while (p < g_seg[i].tam) {
			u16 n = (g_seg[i].tam - p) > sizeof g_buf ? sizeof g_buf : (u16)(g_seg[i].tam - p);
			u16 k;
			if (!LeeFichero(g_seg[i].off + p, n)) goto mal_lectura;
			for (k = n; k < sizeof g_buf; k++) g_buf[k] = 0xFF;
			if (!Borra4K(g_seg[i].dir + p)) goto mal_flash;
			for (k = 0; k < sizeof g_buf; k += 256) {
				u16 j;
				for (j = 0; j < 256 && g_buf[k + j] == 0xFF; j++) ;
				if (j < 256 && !Programa256(g_seg[i].dir + p + k, g_buf + k)) goto mal_flash;
			}
			p += n; hecho += n;
			Barra(hecho, total);
		}
	}

	// ---- 3. releer y comprobar ----
	Pr(T("\r\nComprobando la flash...\r\n", "\r\nVerifying the flash...\r\n"));
	hecho = 0;
	for (i = 0; i < g_nseg; i++) {
		u32 p = 0;
		g_crc = 0xFFFFFFFFUL;
		if (!LeeEmpieza(g_seg[i].dir)) goto mal_flash;
		while (p < g_seg[i].tam) {
			u16 n = (g_seg[i].tam - p) > 1024 ? 1024 : (u16)(g_seg[i].tam - p);
			if (!LeeBloque(g_buf, n)) goto mal_flash;
			Crc(g_buf, n);
			p += n; hecho += n;
			if (!(p & 0x3FFF) || p == g_seg[i].tam) Barra(hecho, total);
		}
		LeePara();
		if (~g_crc != g_seg[i].crc) goto mal_flash;
	}
	DOS_CloseHandle(g_fh);
	Pr(T("\r\nListo. Apaga y vuelve a encender el MSXimus para\r\nentrar con el core nuevo.",
	     "\r\nDone. Switch the MSXimus off and on again to start\r\nthe new core."));
	Fin(0);

mal_fichero:
	Pr(T("\r\nEl fichero no es valido o esta danado. No se ha tocado nada.",
	     "\r\nThe file is not valid or is damaged. Nothing was changed."));
	Fin(1);
mal_lectura:
	Pr(T("\r\nNo se ha podido leer el fichero.", "\r\nCould not read the file."));
	goto aviso;
mal_flash:
	LeePara();
	Pr(T("\r\nLa flash no ha quedado bien.", "\r\nThe flash was not written correctly."));
aviso:
	Pr(T("\r\nNO APAGUES: el MSX sigue con el core de antes; vuelve a\r\nlanzar MXUPDATE. Si no lo consigues, graba el core con el PC.",
	     "\r\nDO NOT SWITCH OFF: the MSX still runs the old core; run\r\nMXUPDATE again. If it keeps failing, flash the core from the PC."));
	Fin(2);
}
