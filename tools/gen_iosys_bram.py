#!/usr/bin/env python3
"""
gen_iosys_bram.py - genera fpga/src/iosys/gowin_dpb_menu.v con la BSRAM del
overlay YA INICIALIZADA.

POR QUE
-------
El gowin_dpb_menu.v que publica nand2mario trae todos los INIT_RAM a CERO: la
fuente real se la mete el IDE de Gowin desde un font.mi que no esta en el repo.
Con la BSRAM vacia el overlay pinta negro sobre negro y no se puede saber si la
cadena (BSRAM -> textdisp -> mux -> HDMI) funciona o no.

Aqui se rellena desde font.vh, y ademas se PRE-CARGA texto en el buffer de
caracteres. Asi el primer bitstream ya ensena algo en la tele sin necesitar
firmware en el BL616 ni una sola linea de RTL de usar y tirar. Cuando el MCU
exista, sobrescribe el buffer por el camino normal.

MAPA de la BSRAM (2 KB, 11 bits de direccion) -- de textdisp.v:
  $000-$37F  buffer de caracteres 32x28   addr = (y/8)*32 + (x/8)
  $380-$3FF  ROM del logo 72x14 1bpp      addr = $380 + fila*9 + col/8
  $400-$7FF  ROM de fuente 128 x 8 bytes  addr = $400 + char*8 + fila
El bit de fuente que se pinta es mem_do_b[x[2:0]]: bit 0 = pixel IZQUIERDO.
font.vh ya viene en ese orden; NO se reordena.
"""
import re, sys, pathlib

BASE = pathlib.Path(__file__).resolve().parent.parent
FONT = BASE / "fpga/src/iosys/font.vh"
PLANTILLA = BASE / "fpga/src/iosys/gowin_dpb_menu.plantilla.v"
SALIDA = BASE / "fpga/src/iosys/gowin_dpb_menu.v"

# Texto del peldano 1. 32 columnas, 28 filas.
LINEAS = [
    (2,  "MSXimus V3.1"),
    (4,  "iosys_bl616 - peldano 1"),
    (6,  "overlay HDMI: OK"),
    (9,  "BSRAM + textdisp + mux rgb_out"),
    (11, "esperando al BL616..."),
]

def leer_fuente():
    """font.vh: 128 filas de '{ 8'hXX, ... 8'hXX} -> 1024 bytes."""
    txt = FONT.read_text()
    filas = re.findall(r"'\{([^}]*)\}", txt)
    filas = [f for f in filas if "8'h" in f]
    if len(filas) != 128:
        sys.exit("font.vh: esperaba 128 caracteres, hay %d" % len(filas))
    out = []
    for f in filas:
        bs = [int(v, 16) for v in re.findall(r"8'h([0-9a-fA-F]{2})", f)]
        if len(bs) != 8:
            sys.exit("caracter con %d bytes, esperaba 8" % len(bs))
        out += bs
    return out

def main():
    mem = [0] * 2048
    # $400-$7FF: fuente
    for i, b in enumerate(leer_fuente()):
        mem[0x400 + i] = b
    # $380-$3FF: logo -> se deja a cero (el de nand2mario no esta en su repo;
    # cuando hagamos el nuestro se genera aqui). logo_active nunca se activa
    # con LOGO_X/LOGO_Y fuera de pantalla, asi que cero = invisible.
    # $000-$37F: buffer de caracteres precargado
    for fila, texto in LINEAS:
        col = max(0, (32 - len(texto)) // 2)
        for i, ch in enumerate(texto):
            if col + i >= 32:
                break
            mem[fila * 32 + col + i] = ord(ch) & 0x7F

    # INIT_RAM_xx: 64 parametros de 256 bits = 32 bytes cada uno.
    # El byte j del bloque ocupa los bits [8j+7:8j] => se imprime el byte 31
    # PRIMERO en la cadena hexadecimal.
    inits = {}
    for k in range(64):
        val = 0
        for j in range(32):
            val |= mem[k * 32 + j] << (8 * j)
        inits["INIT_RAM_%02X" % k] = "256'h%064X" % val

    plantilla = PLANTILLA.read_text()
    n = 0
    def sub(m):
        nonlocal n
        n += 1
        return "%s = %s;" % (m.group(1), inits[m.group(2)])
    salida = re.sub(r"(defparam dpb_inst_0\.(INIT_RAM_[0-9A-F]{2})) = 256'h[0-9A-Fa-f]+;",
                    sub, plantilla)
    if n != 64:
        sys.exit("sustituidos %d INIT_RAM, esperaba 64" % n)

    cab = ("// GENERADO por tools/gen_iosys_bram.py -- NO EDITAR A MANO.\n"
           "// Plantilla: gowin_dpb_menu.plantilla.v (IP de Gowin, via nand2mario/nestang)\n"
           "// La BSRAM lleva la fuente 8x8 y texto precargado; ver el script.\n")
    SALIDA.write_text(cab + salida)
    usados = sum(1 for b in mem if b)
    print("OK: %s (%d bytes no nulos de 2048)" % (SALIDA.name, usados))

main()
