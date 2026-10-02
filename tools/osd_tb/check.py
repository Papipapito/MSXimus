#!/usr/bin/env python3
"""check.py - banco del OSD con color de la V3.8 (tb_osd.sv).

Genera unas ordenes como las del firmware del BL616 (borrar, tablas de atributos por fila, texto con atributos, glifos
y una fila "a la antigua" con el bit 7 = hi), las manda al RTL (iosys_bl616 + textdisp + DPX9B de Gowin) por la UART
y compara pixel a pixel el overlay que sale con el que pinta este modelo. Deja ref.png y rtl.png al lado.
Uso: python tools/osd_tb/check.py
"""
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, ".."))
import osd_fuente as F          # noqa: E402
import gen_iosys_bram as G      # noqa: E402

C = F.C
U = F.unicode_a_codigo()


def A(fo, ti):
    return (C[fo] << 4) | C[ti]


def trama(cmd, params=b""):
    n = 1 + len(params)
    return bytes([0xAA, n >> 8, n & 0xFF, cmd]) + bytes(params)


def txt(s):
    return bytes(U.get(ch, ord(ch)) for ch in s)


def ordenes():
    o = b""
    o += trama(0x08, b"\x01")                                       # overlay encendido
    for fila in range(28):                                          # borrar como overlay_clear()
        o += trama(0x04, bytes([0, fila])) + trama(0x05, b" " * 32)
    # cabecera: fila 0 en azul, fila 1 borde suave
    o += trama(0x11, bytes([0, A("AZUL", "BLANCO"), A("AZUL", "AMARILLO"), A("AZUL", "CIAN"), A("NOCHE", "AZUL")]))
    o += trama(0x11, bytes([1, A("NOCHE", "AZUL"), 0, 0, 0]))
    o += trama(0x10, b"\x00") + trama(0x04, bytes([0, 0])) + trama(0x05, b" " * 32)
    o += trama(0x10, b"\x01") + trama(0x04, bytes([1, 0])) + trama(0x05, txt("★"))
    o += trama(0x10, b"\x00") + trama(0x04, bytes([3, 0])) + trama(0x05, txt("MSXimus 60K"))
    o += trama(0x10, b"\x02") + trama(0x04, bytes([26, 0])) + trama(0x05, txt("3.8"))
    o += trama(0x10, b"\x00") + trama(0x04, bytes([0, 1])) + trama(0x05, txt("▀" * 32))
    # cuerpo: titulo de seccion, etiqueta gris y valor blanco, verde y una pastilla
    for f in range(2, 28):
        o += trama(0x11, bytes([f, A("NOCHE", "GRIS"), A("NOCHE", "BLANCO"), A("NOCHE", "CIAN"), A("NOCHE", "VERDE")]))
    o += trama(0x10, b"\x02") + trama(0x04, bytes([1, 3])) + trama(0x05, txt("Tarjeta SD ─────────────"))
    o += trama(0x10, b"\x00") + trama(0x04, bytes([2, 4])) + trama(0x05, txt("Estado"))
    o += trama(0x10, b"\x03") + trama(0x04, bytes([12, 4])) + trama(0x05, txt("✓ lista · SDHC"))
    o += trama(0x10, b"\x01") + trama(0x04, bytes([2, 5])) + trama(0x05, txt("Z80 5,37 MHz  ñáéíóú ¿°"))
    o += trama(0x11, bytes([7, A("NOCHE", "AMARILLO"), A("AMARILLO", "NEGRO"), A("NOCHE", "BLANCO"), A("NOCHE", "GRIS")]))
    o += trama(0x10, b"\x00") + trama(0x04, bytes([2, 7])) + trama(0x05, txt("◖"))
    o += trama(0x10, b"\x01") + trama(0x05, txt("F12"))
    o += trama(0x10, b"\x00") + trama(0x05, txt("◗"))
    o += trama(0x10, b"\x02") + trama(0x05, txt(" Salir"))
    o += trama(0x10, b"\x03") + trama(0x04, bytes([2, 9])) + trama(0x05, txt("╭──────╮│▌▊█▎╰╯⚠✗►●♪▣▤▄"))
    # firmware antiguo: la tabla de las filas 20-27 se queda la de fabrica y se escribe con el bit 7 = hi
    o += trama(0x10, b"\x00")
    o += trama(0x11, bytes([20] + G.F.ATRIB_DEFECTO))
    o += trama(0x04, bytes([3, 20])) + trama(0x05, b"Normal ") + trama(0x05, bytes(c | 0x80 for c in b"HI"))
    # una fila que se escribe mas alla de la columna 31 (se corta como siempre)
    o += trama(0x04, bytes([28, 22])) + trama(0x05, b"ABCDEFG")
    return o


def modelo(o):
    mem = G.memoria()
    cx = cy = 0
    atr = 0
    i = 0
    while i < len(o):
        assert o[i] == 0xAA
        n = (o[i + 1] << 8) | o[i + 2]
        cmd, p = o[i + 3], o[i + 4:i + 3 + n]
        i += 3 + n
        if cmd == 0x04:
            cx, cy = p[0], p[1]
        elif cmd == 0x05:
            for c in p:
                if cx < 32:
                    a = ((atr >> 1) << 1) | (atr & 1) | (c >> 7)
                    mem[(cy & 31) * 32 + (cx & 31)] = (a << 7) | (c & 0x7F)
                    cx += 1
        elif cmd == 0x10:
            atr = p[0] & 3
        elif cmd == 0x11:
            for k in range(4):
                mem[0x380 + (p[0] & 31) * 4 + k] = p[1 + k]
    pal_t = [F.bgr555(t) for _, t, _ in F.PALETA]
    pal_f = [F.bgr555(fo) for _, _, fo in F.PALETA]
    pix = []
    for y in range(224):
        for x in range(256):
            cel = mem[(y >> 3) * 32 + (x >> 3)]
            fila = mem[0x400 + (cel & 0x7F) * 8 + (y & 7)]
            ent = mem[0x380 + (y >> 3) * 4 + (cel >> 7)]
            pix.append(pal_t[ent & 15] if (fila >> (x & 7)) & 1 else pal_f[ent >> 4])
    return pix


def png(pix, nombre):
    try:
        from PIL import Image
    except ImportError:
        return
    im = Image.new("RGB", (256, 224))
    im.putdata([((v & 31) << 3, ((v >> 5) & 31) << 3, ((v >> 10) & 31) << 3) for v in pix])
    im.resize((768, 672), Image.NEAREST).save(os.path.join(AQUI, nombre))


def main():
    o = ordenes()
    with open(os.path.join(AQUI, "cmds.hex"), "w") as f:
        f.write("\n".join("%02x" % b for b in o) + "\n")
    ref = modelo(o)
    png(ref, "ref.png")
    ruta = "/mnt/" + AQUI[0].lower() + AQUI[2:].replace("\\", "/")
    r = subprocess.run(["wsl.exe", "-d", "Ubuntu-24.04", "bash", "-lc", "cd '%s' && bash run.sh %d" % (ruta, len(o))],
                       capture_output=True, text=True, env=dict(os.environ, MSYS_NO_PATHCONV="1"))
    print(r.stdout[-2000:], r.stderr[-2000:])
    rtl = [int(l, 16) for l in open(os.path.join(AQUI, "pix.txt")) if l.strip()]
    png(rtl, "rtl.png")
    assert len(rtl) == 256 * 224, len(rtl)
    dif = [(k % 256, k // 256) for k in range(len(ref)) if ref[k] != rtl[k]]
    print("bytes de ordenes: %d; pixeles distintos: %d" % (len(o), len(dif)))
    if dif:
        print("primeros:", dif[:12])
        sys.exit(1)


if __name__ == "__main__":
    main()
