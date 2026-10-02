/* osd_glifos.h -- GENERADO por MSX_up_v3/tools/gen_iosys_bram.py (tools/osd_fuente.py). NO EDITAR A MANO.
 * OSD con color de la V3.8: 32 glifos en 0x01-0x1F y 0x7F, paleta de 16 colores, 4 atributos por fila. */
#pragma once

#define C_CLASICO     0
#define C_BLANCO      1
#define C_GRIS_CL     2
#define C_GRIS        3
#define C_GRIS_OSC    4
#define C_NOCHE       5
#define C_AZUL        6
#define C_CIAN        7
#define C_VERDE       8
#define C_VERDE_OSC   9
#define C_AMARILLO   10
#define C_NARANJA    11
#define C_ROJO       12
#define C_VIOLETA    13
#define C_MARINO     14
#define C_NEGRO      15
#define OSD_A(fondo, tinta) ((uint8_t)(((fondo) << 4) | (tinta)))

#define G_BLOQUE         0x01   /* █ */
#define G_MITAD_SUP      0x02   /* ▀ */
#define G_MITAD_INF      0x03   /* ▄ */
#define G_H              0x04   /* ─ */
#define G_V              0x05   /* │ */
#define G_RED_SI         0x06   /* ╭ */
#define G_RED_SD         0x07   /* ╮ */
#define G_RED_II         0x08   /* ╰ */
#define G_RED_ID         0x09   /* ╯ */
#define G_IZQ2           0x0A   /* ▎ */
#define G_IZQ4           0x0B   /* ▌ */
#define G_IZQ6           0x0C   /* ▊ */
#define G_TAPA_IZQ       0x0D   /* ◖ */
#define G_TAPA_DER       0x0E   /* ◗ */
#define G_OK             0x0F   /* ✓ */
#define G_NO             0x10   /* ✗ */
#define G_TRI_DER        0x11   /* ► */
#define G_CIRCULO        0x12   /* ● */
#define G_AVISO          0x13   /* ⚠ */
#define G_PUNTO_MEDIO    0x14   /* · */
#define G_a_AGUDO        0x15   /* á */
#define G_e_AGUDO        0x16   /* é */
#define G_i_AGUDO        0x17   /* í */
#define G_o_AGUDO        0x18   /* ó */
#define G_u_AGUDO        0x19   /* ú */
#define G_n_TILDE        0x1A   /* ñ */
#define G_ABRE_INTERROG  0x1B   /* ¿ */
#define G_SD             0x1C   /* ▤ */
#define G_CHIP           0x1D   /* ▣ */
#define G_NOTA           0x1E   /* ♪ */
#define G_ESTRELLA       0x1F   /* ★ */
#define G_GRADO          0x7F   /* ° */

#ifdef OSD_UTF8_TABLA
static const struct { uint32_t cp; uint8_t g; } osd_utf8[] = {
    { 0x2588, G_BLOQUE },
    { 0x2580, G_MITAD_SUP },
    { 0x2584, G_MITAD_INF },
    { 0x2500, G_H },
    { 0x2502, G_V },
    { 0x256D, G_RED_SI },
    { 0x256E, G_RED_SD },
    { 0x2570, G_RED_II },
    { 0x256F, G_RED_ID },
    { 0x258E, G_IZQ2 },
    { 0x258C, G_IZQ4 },
    { 0x258A, G_IZQ6 },
    { 0x25D6, G_TAPA_IZQ },
    { 0x25D7, G_TAPA_DER },
    { 0x2713, G_OK },
    { 0x2717, G_NO },
    { 0x25BA, G_TRI_DER },
    { 0x25CF, G_CIRCULO },
    { 0x26A0, G_AVISO },
    { 0x00B7, G_PUNTO_MEDIO },
    { 0x00E1, G_a_AGUDO },
    { 0x00E9, G_e_AGUDO },
    { 0x00ED, G_i_AGUDO },
    { 0x00F3, G_o_AGUDO },
    { 0x00FA, G_u_AGUDO },
    { 0x00F1, G_n_TILDE },
    { 0x00BF, G_ABRE_INTERROG },
    { 0x25A4, G_SD },
    { 0x25A3, G_CHIP },
    { 0x266A, G_NOTA },
    { 0x2605, G_ESTRELLA },
    { 0x00B0, G_GRADO },
};
#endif
