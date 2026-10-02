#!/usr/bin/env python3
"""mxupd.py - ficheros de actualizacion del MSXimus 60K/138K (.UPD) para MXUPDATE.COM (V3.8, 01/10/2026).

Un .UPD lleva lo que hay que grabar en la flash SPI de la FPGA, por segmentos: el bitstream en 0x000000, el pack de
la BIOS en 0x400000 y, en los "completos", las ondas del OPL4 (YRW801, 2 MB) en 0x500000 (138K: 0x800000 y 0x900000).
El bloque de ajustes (0x480000 / 0x880000) nunca va en un .UPD: lo borra MXUPDATE /R. Se puede hacer uno solo con el
pack (cambiar de idioma o de Nextor en un minuto) o solo con el bitstream.

Formato (little endian):
    0   8   "MXUPD1", 1Ah, 0
    8   16  placa ("console60k", "console138k"), con ceros
    24  16  version ("3.8.0")
    40  16  variante ("nextor214", "nextor3", "nextor214-en", "nextor3-en", o "core" sin pack)
    56  1   numero de segmentos (1..4)
    57  7   ceros
    64  16n segmentos: direccion en la flash, tamano, CRC-32, desplazamiento en el fichero (u32 cada uno)
    ..  4   CRC-32 de todo lo anterior
    datos de cada segmento en su desplazamiento (alineado a 256)
El CRC-32 es el de siempre (zlib, polinomio EDB88320). MXUPDATE comprueba la cabecera y los CRC del fichero ANTES de
borrar nada, y despues relee la flash entera y vuelve a comprobarlos.

Uso:
    python tools/mxupd.py crear -o MSXIMUS.UPD --placa console60k --version 3.8.0 --variante nextor214 \\
        --bitstream msximus.fs --pack pack_bios_msximus.bin [--onda yrw801.bin]
    python tools/mxupd.py info MSXIMUS.UPD
    python tools/mxupd.py publicar --dir <carpeta del servidor> --placa console60k --version 3.8.0 \
        --bitstream msximus.fs --packs <bios-msxnano-msximus>/packs/msximus [--onda yrw801.bin] [--notas "..."]

publicar deja en <dir>/tang60k/ (o tang138k/) los cuatro .UPD (Nextor 2.1.4 / 3 x castellano / ingles) y el
manifiesto.txt que lee MXUPDATE /N:
    MSXIMUS-UPD 1
    placa=console60k
    version=3.8.0
    notas=...                      (opcional, solo cosas para el usuario)
    imagen=<variante> <fichero> <tamano>
    completa=<variante> <fichero> <tamano>   (con --onda: core + pack + ondas; los que baja MXUPDATE /N /R)
"""
import argparse
import os
import struct
import sys
import zlib

MAGIA = b"MXUPD1\x1a\x00"
PLACAS = {
    # placa: (IDCODE del chip en el bitstream, limite del bitstream, direccion del pack)
    "console60k": (0x0001481B, 0x400000, 0x400000),
    "console138k": (0x0001081B, 0x800000, 0x800000),
}
PACK_TAM = 0x80000
ONDA_OFF = 0x100000             # las ondas van 1 MB detras del pack
ONDA_TAM = 0x200000


def leer_bitstream(ruta):
    d = open(ruta, "rb").read()
    if ruta.lower().endswith(".fs"):
        bits = "".join(l.strip() for l in d.decode("ascii").splitlines() if l.strip() and not l.startswith("//"))
        if len(bits) % 8:
            sys.exit("%s: %d bits, no es un numero entero de bytes" % (ruta, len(bits)))
        d = bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))
    return d


def idcode(bs):
    i = bs.find(b"\xa5\xc3")
    if i < 0 or bs[i + 2:i + 6] != b"\x06\x00\x00\x00":
        return None
    return struct.unpack(">I", bs[i + 6:i + 10])[0]


def crear(a):
    if a.placa not in PLACAS:
        sys.exit("placa desconocida: %s" % a.placa)
    ident, lim_bs, dir_pack = PLACAS[a.placa]
    segs = []
    if a.bitstream:
        bs = leer_bitstream(a.bitstream)
        if idcode(bs) != ident:
            sys.exit("el bitstream no es de %s (IDCODE %s)" % (a.placa, hex(idcode(bs) or 0)))
        if len(bs) > lim_bs:
            sys.exit("bitstream de %d bytes: no cabe antes de 0x%X" % (len(bs), lim_bs))
        segs.append((0x000000, bs))
    if a.pack:
        pk = open(a.pack, "rb").read()
        if len(pk) > PACK_TAM:
            sys.exit("pack de %d bytes: pisaria los ajustes" % len(pk))
        segs.append((dir_pack, pk))
    if getattr(a, "onda", None):
        ond = open(a.onda, "rb").read()
        if len(ond) > ONDA_TAM:
            sys.exit("ondas de %d bytes: mas de 2 MB" % len(ond))
        segs.append((dir_pack + ONDA_OFF, ond))
    if not segs:
        sys.exit("nada que grabar")
    for campo in (a.placa, a.version, a.variante):
        if len(campo.encode()) > 15:
            sys.exit("demasiado largo: %s" % campo)
    cab_len = 64 + 16 * len(segs) + 4
    off = (cab_len + 255) & ~255
    tabla = b""
    datos = []
    for direc, d in segs:
        tabla += struct.pack("<IIII", direc, len(d), zlib.crc32(d) & 0xFFFFFFFF, off)
        datos.append((off, d))
        off = (off + len(d) + 255) & ~255
    cab = (MAGIA + a.placa.encode().ljust(16, b"\0") + a.version.encode().ljust(16, b"\0") +
           a.variante.encode().ljust(16, b"\0") + bytes([len(segs)]) + bytes(7) + tabla)
    cab += struct.pack("<I", zlib.crc32(cab) & 0xFFFFFFFF)
    out = bytearray(cab)
    for o, d in datos:
        out += bytes(o - len(out)) + d
    open(a.o, "wb").write(out)
    info(a.o)


def info(ruta):
    d = open(ruta, "rb").read()
    if d[:8] != MAGIA:
        sys.exit("%s: no es un .UPD" % ruta)
    n = d[56]
    cab = d[:64 + 16 * n]
    ok = struct.unpack("<I", d[64 + 16 * n:68 + 16 * n])[0] == zlib.crc32(cab) & 0xFFFFFFFF
    z = lambda b: b.rstrip(b"\0").decode()   # noqa: E731
    print("%s: %s %s %s, %d bytes, cabecera %s" % (ruta, z(d[8:24]), z(d[24:40]), z(d[40:56]), len(d),
                                                    "bien" if ok else "MAL"))
    todo = ok
    for i in range(n):
        direc, tam, crc, off = struct.unpack("<IIII", d[64 + 16 * i:80 + 16 * i])
        bien = zlib.crc32(d[off:off + tam]) & 0xFFFFFFFF == crc
        todo &= bien
        print("  0x%06X  %8d bytes  CRC %08X  (fichero +0x%X) %s" % (direc, tam, crc, off, "bien" if bien else "MAL"))
    return todo


VARIANTES = [   # variante, carpeta y pack en bios-msxnano-msximus/packs/msximus, nombre corto
    ("nextor214", "nextor-2.1.4", "pack_bios_msximus.bin", "n214_es"),
    ("nextor3", "nextor-3.0.0-beta1", "pack_bios_msximus_nextor3.bin", "n3_es"),
    ("nextor214-en", "nextor-2.1.4", "pack_bios_msximus_en.bin", "n214_en"),
    ("nextor3-en", "nextor-3.0.0-beta1", "pack_bios_msximus_en_nextor3.bin", "n3_en"),
]


def publicar(a):
    sub = "tang138k" if a.placa == "console138k" else "tang60k"
    dst = os.path.join(a.dir, sub)
    os.makedirs(dst, exist_ok=True)
    if a.notas and len(a.notas) > 60:
        sys.exit("notas de mas de 60 caracteres")
    man = ["MSXIMUS-UPD 1", "placa=" + a.placa, "version=" + a.version]
    if a.notas:
        man.append("notas=" + a.notas)
    for var, carpeta, pack, corto in VARIANTES:
        nombre = "%s_%s.upd" % (a.version.replace(".", ""), corto)
        a2 = argparse.Namespace(o=os.path.join(dst, nombre), placa=a.placa, version=a.version, variante=var,
                                bitstream=a.bitstream, pack=os.path.join(a.packs, carpeta, pack), onda=None)
        crear(a2)
        man.append("imagen=%s %s %d" % (var, nombre, os.path.getsize(a2.o)))
    if a.onda:                                                  # los completos, para MXUPDATE /N /R
        for var, carpeta, pack, corto in VARIANTES:
            nombre = "%s_%s_full.upd" % (a.version.replace(".", ""), corto)
            a2 = argparse.Namespace(o=os.path.join(dst, nombre), placa=a.placa, version=a.version, variante=var,
                                    bitstream=a.bitstream, pack=os.path.join(a.packs, carpeta, pack), onda=a.onda)
            crear(a2)
            man.append("completa=%s %s %d" % (var, nombre, os.path.getsize(a2.o)))
    open(os.path.join(dst, "manifiesto.txt"), "w", newline="\n").write("\n".join(man) + "\n")
    print("manifiesto:", os.path.join(dst, "manifiesto.txt"))


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="orden", required=True)
    c = s.add_parser("crear")
    c.add_argument("-o", required=True)
    c.add_argument("--placa", required=True)
    c.add_argument("--version", required=True)
    c.add_argument("--variante", required=True)
    c.add_argument("--bitstream")
    c.add_argument("--pack")
    c.add_argument("--onda")
    i = s.add_parser("info")
    i.add_argument("fichero")
    u = s.add_parser("publicar")
    u.add_argument("--dir", required=True)
    u.add_argument("--placa", required=True)
    u.add_argument("--version", required=True)
    u.add_argument("--bitstream", required=True)
    u.add_argument("--packs", required=True)
    u.add_argument("--onda")
    u.add_argument("--notas")
    a = p.parse_args()
    if a.orden == "crear":
        crear(a)
    elif a.orden == "publicar":
        publicar(a)
    else:
        sys.exit(0 if info(a.fichero) else 1)


if __name__ == "__main__":
    main()
