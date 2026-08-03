#!/usr/bin/env python3
"""
make_logo_c6.py - Convierte el logo del MSXimus a un bitmap para la pantalla
del companion C6 (Waveshare ESP32-C6-LCD-1.3, ST7789V2 240x240, RGB565).

Genera LogoMsximus.h con los datos EN CRUDO (240*240*2 = 115 KB). El hermano
de la S3 (make_logo_lcd.py) comprime con RLE porque aquel firmware iba al 80%
de su particion; aqui NO hace falta: el del C6 va al 52% de 3 MB, o sea ~1,5 MB
libres. Crudo = sin decodificador que pueda tener bugs.

Uso:  python tools/make_logo_c6.py [imagen] [--preview salida.png]
      por defecto lee ../MSX_up/docs/logo/msximus_boot_src.png
"""
import sys
import os
from PIL import Image

W, H = 240, 240                 # el panel es cuadrado
BG = (0, 0, 0)                  # fondo NEGRO: es el que usa el resto de la
                                # pantalla de estado, asi el corte no canta
MARGIN = 10

DEFAULT_SRC = os.path.join(os.path.dirname(__file__), "..", "..",
                           "MSX_up", "docs", "logo", "msximus_boot_src.png")


def to_rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else DEFAULT_SRC
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]

    im = Image.open(src)
    # El fuente es RGBA: se compone sobre el fondo para que la transparencia no
    # salga como basura al descartar el canal alfa.
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        fondo = Image.new("RGBA", im.size, BG + (255,))
        im = Image.alpha_composite(fondo, im)
    im = im.convert("RGB")

    # Encajar MANTENIENDO PROPORCION dentro del lienzo menos el margen. El logo
    # es muy apaisado (~2,6:1), asi que mandara el ancho y quedara centrado en
    # vertical: eso es lo correcto, estirarlo para llenar quedaria deforme.
    cw, ch = W - 2 * MARGIN, H - 2 * MARGIN
    esc = min(cw / im.width, ch / im.height)
    nueva = (max(1, int(im.width * esc)), max(1, int(im.height * esc)))
    im = im.resize(nueva, Image.LANCZOS)

    lienzo = Image.new("RGB", (W, H), BG)
    lienzo.paste(im, ((W - nueva[0]) // 2, (H - nueva[1]) // 2))

    if preview:
        lienzo.save(preview)
        print("preview ->", preview)

    px = lienzo.load()
    out = os.path.join(os.path.dirname(__file__), "..", "LogoMsximus.h")
    with open(out, "w", encoding="utf-8") as f:
        f.write("// LogoMsximus.h - GENERADO por tools/make_logo_c6.py. NO EDITAR A MANO.\n")
        f.write("// Logo de arranque del MSXimus para el LCD del C6 (240x240, RGB565).\n")
        f.write("// Fuente: %s\n" % os.path.basename(src))
        f.write("#pragma once\n#include <stdint.h>\n\n")
        f.write("#define LOGO_W %d\n#define LOGO_H %d\n\n" % (W, H))
        f.write("static const uint16_t LOGO_MSXIMUS[%d] PROGMEM = {\n" % (W * H))
        n = 0
        for y in range(H):
            for x in range(W):
                r, g, b = px[x, y]
                f.write("0x%04X," % to_rgb565(r, g, b))
                n += 1
                if n % 16 == 0:
                    f.write("\n")
        f.write("};\n")
    print("generado ->", os.path.normpath(out))
    print("tamano   -> %d bytes de flash" % (W * H * 2))


if __name__ == "__main__":
    main()
