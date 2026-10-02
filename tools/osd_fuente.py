#!/usr/bin/env python3
"""osd_fuente.py - paleta y glifos del OSD con color de la V3.8 (01/10/2026).

La BSRAM del overlay (fpga/src/iosys/gowin_dpb_menu.v, generada por gen_iosys_bram.py) es UNA sola BSRAM de 2048 x 9:
  $000-$37F  celdas 32x28: {atributo[1:0], caracter[6:0]}
  $380-$3EF  tabla de atributos POR FILA: $380 + fila*4 + atributo = {fondo[3:0], tinta[3:0]} de la paleta de 16
  $400-$7FF  fuente: 128 caracteres x 8 filas (bit 0 = pixel izquierdo)
Cada fila de la pantalla tiene sus cuatro combinaciones de tinta y fondo; asi cabe el color sin gastar ni una BSRAM
mas (el 60K esta al 100 %). La paleta y los glifos imitan los del OSD del MSXimus Z (MSXimus_zynq/fpga/zynq/tools/
osd_fuente.py), pero aqui solo hay 32 huecos: los codigos 0x01-0x1F y 0x7F, que en la fuente de siempre estan vacios.
"""
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
FONT_VH = os.path.normpath(os.path.join(AQUI, "..", "fpga", "src", "iosys", "font.vh"))

# (nombre, RGB de 5 bits); el 0 como tinta es el amarillo de siempre y como fondo el negro
PALETA = [
    ("CLASICO",   (31, 31, 16), (0, 0, 0)),
    ("BLANCO",    (31, 31, 31), (31, 31, 31)),
    ("GRIS_CL",   (21, 22, 24), (21, 22, 24)),
    ("GRIS",      (13, 14, 16), (13, 14, 16)),
    ("GRIS_OSC",  (6, 7, 9),    (6, 7, 9)),
    ("NOCHE",     (2, 3, 7),    (2, 3, 7)),
    ("AZUL",      (5, 11, 25),  (5, 11, 25)),
    ("CIAN",      (7, 24, 29),  (7, 24, 29)),
    ("VERDE",     (8, 26, 11),  (8, 26, 11)),
    ("VERDE_OSC", (2, 11, 5),   (2, 11, 5)),
    ("AMARILLO",  (31, 27, 5),  (31, 27, 5)),
    ("NARANJA",   (31, 16, 3),  (31, 16, 3)),
    ("ROJO",      (28, 6, 6),   (28, 6, 6)),
    ("VIOLETA",   (19, 9, 28),  (19, 9, 28)),
    ("MARINO",    (3, 6, 15),   (3, 6, 15)),
    ("NEGRO",     (0, 0, 0),    (0, 0, 0)),
]
C = {n: i for i, (n, _, _) in enumerate(PALETA)}

# atributos de cada fila al encender (el firmware de siempre no sabe de tablas: 0 = amarillo, 1 = su "hi" blanco)
ATRIB_DEFECTO = [(C["NEGRO"] << 4) | C["CLASICO"], (C["NEGRO"] << 4) | C["BLANCO"],
                 (C["NEGRO"] << 4) | C["CIAN"], (C["AMARILLO"] << 4) | C["NEGRO"]]


def bgr555(rgb):
    r, g, b = rgb
    return (b << 10) | (g << 5) | r


def _fila(bits):
    return sum(1 << i for i in range(8) if bits[i] == "#")


def _dib(*filas):
    assert len(filas) == 8 and all(len(f) == 8 for f in filas), filas
    return [_fila(f) for f in filas]


def _ascii():
    s = open(FONT_VH, encoding="utf-8", errors="ignore").read()
    g = [[int(v, 16) for v in re.findall(r"8'h([0-9a-fA-F]{2})", r)] for r in re.findall(r"'\{([^}]*)\}", s)]
    g = [r for r in g if len(r) == 8]
    assert len(g) == 128, len(g)
    return g


ASCII = _ascii()


def _acento(base, acento):
    g = list(ASCII[ord(base)])
    for i, f in enumerate(acento if isinstance(acento, list) else [acento]):
        g[i] = _fila(f)
    return g


def _espejo6(v):
    return sum(1 << (5 - i) for i in range(6) if v >> i & 1)


V = 0x08
CODIGOS = list(range(0x01, 0x20)) + [0x7F]
GLIFOS = []                     # (codigo, NOMBRE, bitmap[8], caracter unicode)


def glifo(nombre, bitmap, uni):
    GLIFOS.append((CODIGOS[len(GLIFOS)], nombre, bitmap, uni))


glifo("BLOQUE", [0xFF] * 8, "█")
glifo("MITAD_SUP", [0xFF] * 4 + [0] * 4, "▀")
glifo("MITAD_INF", [0] * 4 + [0xFF] * 4, "▄")
glifo("H", [0, 0, 0, 0xFF, 0, 0, 0, 0], "─")
glifo("V", [V] * 8, "│")
glifo("RED_SI", _dib("........", "........", "........", ".....###", "....#...", "...#....", "...#....", "...#...."), "╭")
glifo("RED_SD", _dib("........", "........", "........", "###.....", "...#....", "...#....", "...#....", "...#...."), "╮")
glifo("RED_II", _dib("...#....", "...#....", "....#...", ".....###", "........", "........", "........", "........"), "╰")
glifo("RED_ID", _dib("...#....", "...#....", "..#.....", "###.....", "........", "........", "........", "........"), "╯")
glifo("IZQ2", [0x03] * 8, "▎")
glifo("IZQ4", [0x0F] * 8, "▌")
glifo("IZQ6", [0x3F] * 8, "▊")
glifo("TAPA_IZQ", _dib("...#####", ".#######", "########", "########", "########", "########", ".#######", "...#####"), "◖")
glifo("TAPA_DER", _dib("#####...", "#######.", "########", "########", "########", "########", "#######.", "#####..."), "◗")
glifo("OK", _dib("........", ".......#", "......##", ".....##.", "#...##..", "##.##...", ".###....", "..#....."), "✓")
glifo("NO", _dib("........", "##....##", ".##..##.", "..####..", "...##...", "..####..", ".##..##.", "##....##"), "✗")
glifo("TRI_DER", _dib(".#......", ".##.....", ".###....", ".####...", ".###....", ".##.....", ".#......", "........"), "►")
glifo("CIRCULO", _dib("........", "..###...", ".#####..", ".#####..", ".#####..", "..###...", "........", "........"), "●")
glifo("AVISO", _dib("...##...", "..#..#..", "..#..#..", ".##..##.", ".######.", "###..###", "########", "........"), "⚠")
glifo("PUNTO_MEDIO", _dib("........", "........", "........", "...##...", "...##...", "........", "........", "........"), "·")
glifo("a_AGUDO", _acento("a", "...##..."), "á")
glifo("e_AGUDO", _acento("e", "...##..."), "é")
glifo("i_AGUDO", _acento("i", "...##..."), "í")
glifo("o_AGUDO", _acento("o", "...##..."), "ó")
glifo("u_AGUDO", _acento("u", "...##..."), "ú")
glifo("n_TILDE", _acento("n", [".##..#..", "#..##..."]), "ñ")
glifo("ABRE_INTERROG", [_espejo6(ASCII[ord("?")][6 - i]) for i in range(7)] + [0], "¿")
glifo("SD", _dib("..#####.", ".##.#.#.", "#######.", "#######.", "#######.", "#######.", "#######.", "........"), "▤")
glifo("CHIP", _dib("..#..#..", ".######.", "##....##", ".#.##.#.", ".#.##.#.", "##....##", ".######.", "..#..#.."), "▣")
glifo("NOTA", _dib("...####.", "...#..#.", "...#..#.", "...#..#.", ".###.##.", "####.##.", ".##.....", "........"), "♪")
glifo("ESTRELLA", _dib("...#....", "...#....", "#######.", ".#####..", "..###...", ".##.##..", ".#...#..", "........"), "★")
glifo("GRADO", _dib(".###....", "#...#...", ".###....", "........", "........", "........", "........", "........"), "°")
assert len(GLIFOS) == len(CODIGOS) == 32, len(GLIFOS)


def fuente():
    """128 caracteres x 8 filas: la fuente de siempre con los 32 glifos en sus huecos."""
    f = [list(g) for g in ASCII]
    for cod, _, bm, _ in GLIFOS:
        assert not any(f[cod]), "el hueco 0x%02X no estaba vacio" % cod
        f[cod] = list(bm)
    return f


def unicode_a_codigo():
    return {g[3]: g[0] for g in GLIFOS}
