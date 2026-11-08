#!/usr/bin/env python3
"""banco_mxu.py - banco de MXUPDATE.COM (02/10/2026): el .COM de verdad en un Z80 emulado (kosarev/z80, en el WSL:
python3 -m pip install --user --break-system-packages z80) con un MSX-DOS de imitacion (consola, _OPEN/_CREATE/
_READ/_WRITE/_SEEK/_CLOSE/_TERM, _GENV PROGRAM, _DELETE y _RENAME sobre ficheros en memoria) y el puente de la flash (fpga/src/flash_bridge.v) sobre
16 MB, con la flash de un 60K, un 138K o un MSXnano. Prueba la tabla de placas: que cada .UPD solo entra en la suya,
que el pack y el core quedan byte a byte, que /R borra los ajustes de la placa (pack + 512 KB) y nada mas.
17/10/2026 (MXUPDATE 1.3): la 138K con su flash de verdad, una W25Q64 de 8 MB (la direccion da la vuelta: 0x800000 es
0x000000, el bitstream) y el mapa nuevo (pack 0x500000, ajustes 0x580000, ondas 0x600000); sus .UPD los hace
tools/mxupd.py (crear), con el bitstream de la 138K de --bs138 (.fs o .bin) o, sin el, uno de imitacion de 5,1 MB.
Un .UPD de la 138K con el mapa viejo (pack 0x800000, ondas 0x900000) tiene que salir rechazado sin tocar la flash.

    python3 banco_mxu.py --com ../mxupdate.com --upd60 PACK_ES.UPD --updnano NANO.UPD --updnanopack NANOPACK.UPD
        [--bs138 msximus138.fs]
"""
import contextlib
import io
import tempfile
import argparse
import re
import random
import shutil
import struct
import sys
import zlib

import os
import z80

from red_mxu import Unapi, Web

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.dont_write_bytecode = True                            # sin __pycache__ en tools/
import mxupd                                             # noqa: E402  (tools/mxupd.py: los .UPD de la 138K)

FRAME = 71590
TPA = 0xD600
PROGRAMA = "A:\\FPGA\\MXUPDATE.COM"


class Puente:
    """El de bios-msxnano-msximus/tools/actualizar_tb/banco.py (flash_bridge.v), con la flash en un bytearray."""

    def __init__(self, flash, presente=True, ajeno=0):
        self.f, self.presente, self.ajeno = flash, presente, ajeno
        self.sel = self.a2 = self.a1 = self.modo = self.ocupado = self.espera = self.ptr = 0
        self.pbuf = bytearray()
        self.nprog = self.nborr = 0
        self.errores = []

    def dir(self):
        # la flash solo mira los bits de direccion que tiene: en la W25Q64 (8 MB) 0x800000 vuelve a ser 0x000000
        return ((self.a2 << 16) | (self.a1 << 8)) % len(self.f)

    def out(self, p, v):
        if p == 0x40:
            self.sel = v
            return
        if not self.presente or self.sel != 0x4D:
            return
        if p == 0x41:
            self.a2 = v
        elif p == 0x42:
            self.a1 = v
        elif p == 0x43:
            if v in (1, 2) and (self.modo or self.ocupado):
                self.errores.append("orden %d con el puente ocupado" % v)
            if v == 1:
                b = self.dir() & ~0xFFF
                self.f[b:b + 4096] = b"\xff" * 4096
                self.nborr += 1
                self.ocupado = 3
            elif v == 2:
                self.modo, self.pdir, self.pbuf, self.espera = 2, self.dir(), bytearray(), 1
                self.nprog += 1
            elif v == 3:
                self.modo, self.ptr, self.espera = 3, self.dir(), 2
            elif v == 0:
                self.modo = 0
        elif p == 0x44:
            if self.modo != 2 or self.espera:
                self.errores.append("dato sin pedir")
                return
            self.pbuf.append(v)
            if len(self.pbuf) == 256:
                for i, b in enumerate(self.pbuf):
                    self.f[(self.pdir + i) % len(self.f)] &= b
                self.modo, self.ocupado = 0, 2

    def inp(self, p):
        if p == 0x40:
            return 0xB2 if (self.presente and self.sel == 0x4D) else (~self.sel) & 0xFF
        if not self.presente or self.sel != 0x4D:
            return 0xFF
        if p == 0x41:
            st = 0xA0
            if self.ajeno:
                self.ajeno -= 1
                st |= 8
            if self.ocupado:
                self.ocupado -= 1
                st |= 1
            if self.modo in (2, 3):
                if self.espera:
                    self.espera -= 1
                    st |= 1
                else:
                    st |= 2 if self.modo == 2 else 4
            return st
        if p == 0x44 and self.modo == 3:
            v = self.f[self.ptr]
            self.ptr = (self.ptr + 1) % len(self.f)
            return v
        if p == 0x4E:
            return 0x00
        return 0xFF


class Dos:
    def __init__(self, com, args, ficheros, puente, teclas, version=0x38, web=None):
        self.m = m = z80.Z80Machine()
        self.f = dict((k.upper(), bytearray(v)) for k, v in ficheros.items())
        self.h = {}
        self.pu, self.teclas, self.version = puente, list(teclas), version
        self.salida = []
        self.fin = None
        self.programa = PROGRAMA                          # la variable PROGRAM de MSX-DOS 2
        m.set_memory_block(0x0100, com)
        m.set_memory_block(0x0005, b"\xc3" + struct.pack("<H", TPA))
        m.set_memory_block(0xF36B, b"\xc9")               # SETRAM del MSX-DOS (lo llama el arranque de MSXgl)
        isr = bytes([0xF5, 0xE5, 0x2A, 0x9E, 0xFC, 0x23, 0x22, 0x9E, 0xFC, 0xE1, 0xF1, 0xFB, 0xED, 0x4D])
        m.set_memory_block(0x0038, isr)
        cola = (" " + args).encode("ascii")
        m.set_memory_block(0x0080, bytes([len(cola)]) + cola + b"\r")
        m.set_breakpoint(0x0005)
        m.set_breakpoint(0x0000)
        m.set_input_callback(lambda p: self.entrada(p & 0xFF))
        m.set_output_callback(lambda p, v: self.pu.out(p & 0xFF, v) if 0x40 <= (p & 0xFF) <= 0x4F else None)
        m.sp = TPA - 2
        m.set_memory_block(TPA - 2, b"\x00\x00")         # ret -> 0000h = acaba
        arr = bytes([0xF3, 0xED, 0x56, 0xFB, 0xC3, 0x00, 0x01])   # di / im 1 / ei / jp 0100h
        m.set_memory_block(0xF000, arr)
        m.pc = 0xF000
        self.red = Unapi(self, web) if web else None

    def entrada(self, p):
        if 0x40 <= p <= 0x4F:
            return self.pu.inp(p)
        return {0x2F: self.version, 0x29: 0x00}.get(p, 0xFF)

    def cadena(self, a):
        s = bytearray()
        while self.m.memory[a]:
            s.append(self.m.memory[a])
            a += 1
        return s.decode("ascii").upper()

    def bdos(self):
        m = self.m
        c = m.c
        if c == 0x02:
            self.salida.append(chr(m.e))
        elif c in (0x01, 0x08):
            if not self.teclas:
                self.fin = "espera una tecla"
                return
            m.a = ord(self.teclas.pop(0))
        elif c in (0x43, 0x44):                            # _OPEN / _CREATE
            n = self.cadena(m.de)
            if c == 0x44:
                self.f[n] = bytearray()
            if n not in self.f:
                m.a = 0xD7                                 # .NOFIL
            else:
                h = max(self.h, default=4) + 1
                self.h[h] = [n, 0]
                m.b, m.a = h, 0
        elif c == 0x45:
            self.h.pop(m.b, None)
            m.a = 0
        elif c in (0x48, 0x49):                            # _READ / _WRITE
            n, pos = self.h[m.b]
            d = self.f[n]
            if c == 0x48:
                trozo = bytes(d[pos:pos + m.hl])
                m.set_memory_block(m.de, trozo)
                self.h[m.b][1] += len(trozo)
                m.hl, m.a = len(trozo), (0 if trozo else 0xC7)
            else:
                trozo = bytes(m.memory[m.de:m.de + m.hl])
                d[pos:pos + len(trozo)] = trozo
                self.h[m.b][1] += len(trozo)
                m.a = 0
        elif c == 0x6B:                                    # _GENV: solo PROGRAM
            v = (self.programa if self.cadena(m.hl) == "PROGRAM" else "").encode("ascii") + b"\0"
            m.set_memory_block(m.de, v)
            m.a = 0
        elif c == 0x4D:                                    # _DELETE
            m.a = 0 if self.f.pop(self.cadena(m.de), None) is not None else 0xD7
        elif c == 0x4E:                                    # _RENAME: el nombre nuevo, sin ruta
            n = self.cadena(m.de)
            if n not in self.f:
                m.a = 0xD7
            else:
                corte = max(n.rfind("\\"), n.rfind(":")) + 1
                self.f[n[:corte] + self.cadena(m.hl)] = self.f.pop(n)
                m.a = 0
        elif c == 0x4A:                                    # _SEEK desde el principio
            pos = (m.de << 16) | m.hl
            self.h[m.b][1] = pos if m.a == 0 else self.h[m.b][1] + pos
            m.a = 0
        elif c in (0x62, 0x00):
            self.fin = "fin %d" % (m.b if c == 0x62 else 0)
            return
        else:
            self.salida.append("[BDOS %02Xh?]" % c)
            m.a = 0
        m.pc = m.memory[m.sp] | (m.memory[m.sp + 1] << 8)
        m.sp += 2

    def corre(self, cuadros=400000):
        m = self.m
        m.ticks_to_stop = FRAME
        for _ in range(cuadros):
            ev = m.run()
            if ev & 1:
                if m.pc == 0x0000:
                    self.fin = "fin (ret)"
                    return
                if self.red and self.red.atiende(m.pc):
                    m.pc = m.memory[m.sp] | (m.memory[m.sp + 1] << 8)
                    m.sp += 2
                    continue
                self.bdos()
                if self.fin:
                    return
                continue
            if ev & 4:
                m.on_handle_active_int()
                m.ticks_to_stop = FRAME
        self.fin = "se ha pasado de tiempo"

    def texto(self):
        return "".join(self.salida).replace("\r", "")


# ---- casos -----------------------------------------------------------------------------------------------------
def segmentos(upd):
    return [struct.unpack("<IIII", upd[64 + 16 * i:80 + 16 * i]) for i in range(upd[56])]


def flash(bitstream4k, pack, ajustes, tam=0x1000000, ondas=None):
    rnd = random.Random(7)
    f = bytearray(b"\xff" * tam)
    f[0:4096] = bitstream4k
    f[4096:0x100000] = rnd.randbytes(0x100000 - 4096)
    f[pack:pack + 0x80000] = rnd.randbytes(0x80000)
    f[ajustes:ajustes + 16] = b"AB" + bytes(range(1, 15))
    if ondas is not None:                                  # las ondas del OPL4 de antes (2 MB)
        f[ondas:ondas + 0x200000] = rnd.randbytes(0x200000)
    return f


def upd_crudo(placa, segs, version="3.7.0", variante="nextor214"):
    """Un .UPD hecho a mano, con direcciones que mxupd.py ya no da (el mapa viejo de la 138K)."""
    cab_len = 64 + 16 * len(segs) + 4
    off = (cab_len + 255) & ~255
    tabla, datos = b"", []
    for direc, d in segs:
        tabla += struct.pack("<IIII", direc, len(d), zlib.crc32(d) & 0xFFFFFFFF, off)
        datos.append((off, d))
        off = (off + len(d) + 255) & ~255
    cab = (b"MXUPD1\x1a\x00" + placa.encode().ljust(16, b"\0") + version.encode().ljust(16, b"\0") +
           variante.encode().ljust(16, b"\0") + bytes([len(segs)]) + bytes(7) + tabla)
    cab += struct.pack("<I", zlib.crc32(cab) & 0xFFFFFFFF)
    out = bytearray(cab)
    for o, d in datos:
        out += bytes(o - len(out)) + d
    return bytes(out)


def upd_mxupd(tmp, nombre, placa, bitstream=None, pack=None, onda=None, variante="nextor214"):
    """Un .UPD hecho con tools/mxupd.py crear (el de verdad), sin su informe en pantalla."""
    a = argparse.Namespace(o=os.path.join(tmp, nombre), placa=placa, version="3.8.4", variante=variante,
                           bitstream=bitstream, pack=pack, onda=onda)
    with contextlib.redirect_stdout(io.StringIO()):
        mxupd.crear(a)
    return open(a.o, "rb").read()


def esperado(antes, upd, borrar=None):
    e = bytearray(antes)
    for d, t, c, o in segmentos(upd):
        fin = (d + t + 0xFFF) & ~0xFFF
        e[d:fin] = b"\xff" * (fin - d)
        e[d:d + t] = upd[o:o + t]
    if borrar is not None:
        e[borrar:borrar + 4096] = b"\xff" * 4096
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--com", required=True)
    ap.add_argument("--upd60", required=True, help=".UPD del 60K (solo el pack basta)")
    ap.add_argument("--updnano", required=True, help=".UPD del MSXnano con core y pack")
    ap.add_argument("--updnanopack", required=True, help=".UPD del MSXnano solo con el pack")
    ap.add_argument("--web-nano", help="carpeta msxnano/ de mxupd.py publicar (manifiesto + .upd)")
    ap.add_argument("--web-60k", help="carpeta tang60k/ de mxupd.py publicar (con --onda)")
    ap.add_argument("--bs138", help="bitstream de la 138K con el mapa de 8 MB (.fs o .bin); sin el, uno de imitacion")
    a = ap.parse_args()
    com = open(a.com, "rb").read()
    u60 = open(a.upd60, "rb").read()
    unano = open(a.updnano, "rb").read()
    unpack = open(a.updnanopack, "rb").read()
    s0 = [s for s in segmentos(unano) if s[0] == 0][0]
    bs_nano = unano[s0[3]:s0[3] + 4096]
    bs_60 = bytearray(bs_nano)                            # el mismo, con el IDCODE del 60K y del 138K
    i = bs_60.find(b"\x00\x00\x08\x1b")
    bs_60[i:i + 4] = b"\x00\x01\x48\x1b"
    bs_138 = bytearray(bs_60)
    bs_138[i:i + 4] = b"\x00\x01\x08\x1b"
    malo = bytearray(unano)
    malo[s0[3] + 5000] ^= 1
    nano = lambda: flash(bs_nano, 0x200000, 0x280000)
    c60 = lambda: flash(bs_60, 0x400000, 0x480000)
    c138 = lambda: flash(bs_138, 0x500000, 0x580000, 0x800000, 0x600000)   # W25Q64 de 8 MB, el mapa nuevo
    # ---- los .UPD de la 138K: los del mapa nuevo con tools/mxupd.py, los del viejo a mano ----
    tmp = tempfile.mkdtemp(prefix="banco_mxu_")
    rnd = random.Random(138)
    ruta_bs138 = a.bs138
    if not ruta_bs138:                                    # de imitacion, del tamano del dado 5519 (5.122.344 bytes)
        ruta_bs138 = os.path.join(tmp, "bs138.bin")
        open(ruta_bs138, "wb").write(bytes(bs_138) + rnd.randbytes(5122344 - len(bs_138)))
    ruta_pack138 = os.path.join(tmp, "pack138.bin")
    open(ruta_pack138, "wb").write(rnd.randbytes(0x80000))
    ruta_onda138 = os.path.join(tmp, "yrw801.bin")
    open(ruta_onda138, "wb").write(rnd.randbytes(0x200000))
    u138 = upd_mxupd(tmp, "core.upd", "console138k", ruta_bs138, ruta_pack138)
    u138full = upd_mxupd(tmp, "full.upd", "console138k", ruta_bs138, ruta_pack138, ruta_onda138)
    u138pack = upd_mxupd(tmp, "pack.upd", "console138k", pack=ruta_pack138)
    u138ondas = upd_mxupd(tmp, "ondas.upd", "console138k", onda=ruta_onda138, variante="ondas")    # 1.4: solo las ondas
    u60ondas = upd_mxupd(tmp, "ondas60.upd", "console60k", onda=ruta_onda138, variante="ondas")
    d0, t0, _, o0 = segmentos(u138)[0]
    bs138 = u138[o0:o0 + t0]
    pk138 = open(ruta_pack138, "rb").read()
    on138 = open(ruta_onda138, "rb").read()
    u138_viejo = upd_crudo("console138k", [(0x800000, pk138)])
    u138_viejo_full = upd_crudo("console138k", [(0, bs138), (0x800000, pk138), (0x900000, on138)])
    u138_grande = upd_crudo("console138k", [(0, bs138 + bytes(0x501000 - len(bs138)))])
    def mxupd_rechaza(**k):
        try:
            upd_mxupd(tmp, "no.upd", "console138k", **k)
        except SystemExit:
            return True
        return False
    ruta_grande = os.path.join(tmp, "grande.bin")
    open(ruta_grande, "wb").write(bs138 + bytes(0x500001 - len(bs138)))
    tabla = [
        ("mxupd.py: la 138K con el bitstream en 0, el pack en 0x500000 y las ondas en 0x600000",
         [s[0] for s in segmentos(u138full)] == [0, 0x500000, 0x600000] and d0 == 0),
        ("mxupd.py: el bitstream de la 138K (%d bytes%s) cabe antes del pack" % (
            len(bs138), ", " + os.path.basename(a.bs138) if a.bs138 else ", de imitacion"), len(bs138) <= 0x500000),
        ("mxupd.py: no hace un .UPD de la 138K con un bitstream de mas de 0x500000 bytes",
         mxupd_rechaza(bitstream=ruta_grande)),
    ]
    shutil.rmtree(tmp, ignore_errors=True)                # todo esta ya en memoria
    casos = [
        # nombre, flash, puente, argumentos, ficheros, teclas, version del core, texto, flash esperada
        ("60K: el pack", c60, {}, "PACK.UPD", {"PACK.UPD": u60}, "S", 0x38, "Listo", lambda f: esperado(f, u60)),
        ("nano: core + pack", nano, {"ajeno": 100}, "NANO.UPD", {"NANO.UPD": unano}, "S", 0x21, "Listo",
         lambda f: esperado(f, unano)),
        ("nano: /R con solo el pack (borra 0x280000)", nano, {}, "NANOPACK.UPD /R", {"NANOPACK.UPD": unpack}, "S",
         0x21, "Ajustes borrados", lambda f: esperado(f, unpack, 0x280000)),
        ("nano: el nombre por defecto (MSXNANO.UPD)", nano, {}, "", {"MSXNANO.UPD": unpack}, "S", 0x21, "Listo",
         lambda f: esperado(f, unpack)),
        ("60K: el nombre por defecto (MSXIMUS.UPD)", c60, {}, "", {"MSXIMUS.UPD": u60}, "S", 0x38, "Listo",
         lambda f: esperado(f, u60)),
        ("nano sin nombre y solo el MSXIMUS.UPD del 60K: pregunta, no", nano, {}, "", {"MSXIMUS.UPD": u60}, "N",
         0x21, "No encuentro MSXNANO.UPD", None),
        ("138K sin nombre y sin fichero: pregunta, no", c138, {}, "", {}, "N", 0x38, "No encuentro MSX138K.UPD",
         None),
        ("nano sin nombre: el MSXIMUS.UPD del menu si es del nano", nano, {}, "", {"MSXIMUS.UPD": unpack}, "S",
         0x21, "Listo", lambda f: esperado(f, unpack)),
        ("/C sin nombre: el que haya (MSXNANO.UPD)", nano, {"presente": False}, "/C", {"MSXNANO.UPD": unano}, "",
         0x21, "Fichero correcto", None),
        ("nano con un .UPD del 60K", nano, {}, "PACK.UPD", {"PACK.UPD": u60}, "S", 0x21, "para otra placa", None),
        ("60K con un .UPD del nano", c60, {}, "NANO.UPD", {"NANO.UPD": unano}, "S", 0x38, "para otra placa", None),
        ("138K con un .UPD del 60K", c138, {}, "PACK.UPD", {"PACK.UPD": u60}, "S", 0x38, "para otra placa", None),
        ("nano: fichero danado", nano, {}, "NANO.UPD", {"NANO.UPD": bytes(malo)}, "S", 0x21, "no es valido", None),
        ("nano: contesta que no", nano, {}, "NANO.UPD", {"NANO.UPD": unano}, "N", 0x21, "No se ha tocado", None),
        ("sin puente", nano, {"presente": False}, "NANO.UPD", {"NANO.UPD": unano}, "S", 0x21, "MSXnano 2.1.1",
         None),
        ("/C de un .UPD del nano (sin puente)", nano, {"presente": False}, "NANO.UPD /C", {"NANO.UPD": unano}, "",
         0x21, "Fichero correcto", None),
        ("138K: la placa en pantalla", c138, {}, "PACK.UPD /C", {"PACK.UPD": u60}, "", 0x38, "Fichero correcto",
         None),
        ("/? la ayuda (sin puente)", nano, {"presente": False}, "/?", {}, "", 0x21, "esta ayuda", None),
        ("/h la ayuda (con un .UPD al lado: no lo toca)", nano, {}, "/h", {"MSXNANO.UPD": unano}, "", 0x21,
         "/H /?", None),
        # ---- la 138K con el mapa de 8 MB (MXUPDATE 1.3) ----
        ("138K: core + pack, nombre por defecto (MSX138K.UPD: 0 y 0x500000)", c138, {}, "",
         {"MSX138K.UPD": u138}, "S", 0x38, "Listo", lambda f: esperado(f, u138)),
        ("138K: solo el pack (0x500000)", c138, {}, "PACK.UPD", {"PACK.UPD": u138pack}, "S", 0x38, "Listo",
         lambda f: esperado(f, u138pack)),
        ("138K sin nombre: el MSXIMUS.UPD del menu si es de la 138K", c138, {}, "", {"MSXIMUS.UPD": u138pack}, "S",
         0x38, "Listo", lambda f: esperado(f, u138pack)),
        ("138K: /R completa (ondas en 0x600000, borra los ajustes de 0x580000)", c138, {}, "FULL.UPD /R",
         {"FULL.UPD": u138full}, "S", 0x38, "Ajustes borrados", lambda f: esperado(f, u138full, 0x580000)),
        ("138K: .UPD con el pack en 0x800000 (mapa viejo): rechazado", c138, {}, "VIEJO.UPD",
         {"VIEJO.UPD": u138_viejo}, "S", 0x38, "no es valido", None),
        ("138K: /R con un completo del mapa viejo (0x800000, ondas 0x900000): rechazado", c138, {}, "VIEJO.UPD /R",
         {"VIEJO.UPD": u138_viejo_full}, "S", 0x38, "no es valido", None),
        ("138K: bitstream de 0x501000 bytes (pisaria el pack): rechazado", c138, {}, "GRANDE.UPD",
         {"GRANDE.UPD": u138_grande}, "S", 0x38, "no es valido", None),
        ("/C de un .UPD de la 138K del mapa viejo (sin puente): no valido", nano, {"presente": False}, "VIEJO.UPD /C",
         {"VIEJO.UPD": u138_viejo}, "", 0x21, "no es valido", None),
        ("60K con un .UPD de la 138K", c60, {}, "CORE.UPD", {"CORE.UPD": u138}, "S", 0x38, "para otra placa", None),
    ]
    # ---- la red: /N contra msx.barcelona (TLS) y /S contra el PC ----
    red = []
    ver = re.search(rb"MXUPDATE (\d+(?:\.\d+)+) - ", com).group(1)
    com99 = com.replace(b"MXUPDATE " + ver + b" - ", b"MXUPDATE 9.9 - ")
    def mxu(version, binario):
        man = ("MSXIMUS-UPD 1\nplaca=mxupdate\nversion=%s\nimagen=mxupdate MXUPDATE.COM %d\n"
               "completa=mxupdate MXUPDATE.COM %d\n" % (version, len(binario), len(binario))).encode()
        return {"/wp-content/ota/mxupdate/manifiesto.txt": man, "/wp-content/ota/mxupdate/MXUPDATE.COM": binario}
    def programa_es(binario, una_vez):
        def mira(d):
            mal = []
            if bytes(d.f.get(PROGRAMA.upper(), b"")) != binario:
                mal.append("%s no es el esperado" % PROGRAMA)
            if "A:\\FPGA\\MXUPDATE.NEW" in d.f:
                mal.append("se ha quedado MXUPDATE.NEW")
            n = d.texto().count("actualizando MXUPDATE")
            if n != una_vez:
                mal.append("'actualizando MXUPDATE' sale %d veces" % n)
            return mal
        return mira
    def web_de(carpeta, prefijo):
        return dict((prefijo + n, open(os.path.join(carpeta, n), "rb").read()) for n in os.listdir(carpeta))
    if a.web_nano:
        wn = lambda **k: Web(web_de(a.web_nano, "/wp-content/ota/msxnano/"), **k)
        fn = os.path.join(a.web_nano, "211_n214_es.upd")
        un_web = open(fn, "rb").read()
        red += [
            ("red nano: /N, certificado validado", nano, {}, "/N", {}, "\rSS", 0x21, "Listo",
             lambda f: esperado(f, un_web), wn(), "valida"),
            ("red nano: /N, el ESP no puede validar (aviso y sin validar)", nano, {}, "/N", {}, "\rSS", 0x21,
             "certificado sin validar", lambda f: esperado(f, un_web), wn(tls="sinvalidar"), "sinvalidar"),
            ("red nano: /N sin nada en la web (HTTP 404)", nano, {}, "/N", {}, "", 0x21,
             "Sin actualizaciones para esta placa (HTTP 404)", None, Web({}), "valida"),
            ("red nano: /N sin TLS en el ESP (nunca en claro)", nano, {}, "/N", {}, "", 0x21,
             "Sin conexion", None, wn(tls="no"), "nunca80"),
            ("red nano: /N, la descarga se corta", nano, {}, "/N", {}, "\rS", 0x21, "se ha cortado", None,
             wn(corta="/wp-content/ota/msxnano/211_n214_es.upd"), "valida"),
            ("red nano: sin nombre ni fichero, pregunta y baja (en MSXNANO.UPD)", nano, {}, "", {}, "S\rSS", 0x21,
             "en MSXNANO.UPD", lambda f: esperado(f, un_web), wn(), "valida"),
            ("red nano: MXUPDATE 9.9 en la web: se actualiza, se relanza y graba", nano, {}, "/N",
             {PROGRAMA: com}, "\rSS", 0x21, "se vuelve a lanzar", lambda f: esperado(f, un_web),
             Web(dict(web_de(a.web_nano, "/wp-content/ota/msxnano/"), **mxu("9.9", com99))), "valida",
             programa_es(com99, 1)),
            ("red nano: la web dice 9.9 pero el .COM no lo es: no se cambia y sigue", nano, {}, "/N",
             {PROGRAMA: com}, "\rSS", 0x21, "No se ha podido actualizar MXUPDATE", lambda f: esperado(f, un_web),
             Web(dict(web_de(a.web_nano, "/wp-content/ota/msxnano/"), **mxu("9.9", com))), "valida",
             programa_es(com, 1)),
            ("red nano: la misma version en la web: nada", nano, {}, "/N", {PROGRAMA: com}, "\rSS", 0x21,
             "Listo", lambda f: esperado(f, un_web),
             Web(dict(web_de(a.web_nano, "/wp-content/ota/msxnano/"), **mxu(ver.decode(), com))), "valida",
             programa_es(com, 0)),
        ]
    if a.web_60k:
        w6 = lambda **k: Web(web_de(a.web_60k, "/wp-content/ota/tang60k/"), **k)
        man = open(os.path.join(a.web_60k, "manifiesto.txt")).read()
        nfull = [l.split()[1] for l in man.splitlines() if l.startswith("completa=nextor214 ")][0]
        full = open(os.path.join(a.web_60k, nfull), "rb").read()
        red += [
            ("red 60K: /N /R (completa: core + pack + ondas, borra 0x480000)", c60, {}, "/N /R", {}, "\rSS", 0x38,
             "Ajustes borrados", lambda f: esperado(f, full, 0x480000), w6(), "valida"),
        ]
    # la 138K en la web (tang138k/), con los .UPD de mxupd.py: /N /R baja el completo y lo graba en 0, 0x500000 y 0x600000
    man138 = ("MSXIMUS-UPD 1\nplaca=console138k\nversion=3.8.4\nimagen=nextor214 384_n214_es.upd %d\n"
              "ondas=ondas 384_ondas.upd %d\ncompleta=nextor214 384_n214_es_full.upd %d\n"
              % (len(u138), len(u138ondas), len(u138full))).encode()
    w138 = {"/wp-content/ota/tang138k/manifiesto.txt": man138, "/wp-content/ota/tang138k/384_n214_es.upd": u138,
            "/wp-content/ota/tang138k/384_n214_es_full.upd": u138full, "/wp-content/ota/tang138k/384_ondas.upd": u138ondas}
    w138_sin = dict(w138)                                 # el mismo manifiesto, sin la linea ondas=
    w138_sin["/wp-content/ota/tang138k/manifiesto.txt"] = b"".join(
        l + b"\n" for l in man138.split(b"\n") if l and not l.startswith(b"ondas="))
    man60 = ("MSXIMUS-UPD 1\nplaca=console60k\nversion=3.8.4\nimagen=nextor214 384_n214_es.upd %d\n"
             "ondas=ondas 384_ondas.upd %d\n" % (len(u60), len(u60ondas))).encode()
    w60 = {"/wp-content/ota/tang60k/manifiesto.txt": man60, "/wp-content/ota/tang60k/384_n214_es.upd": u60,
           "/wp-content/ota/tang60k/384_ondas.upd": u60ondas}
    c138_sin = lambda: flash(bs_138, 0x500000, 0x580000, 0x800000, None)    # recien grabada: las ondas en blanco
    c60_sin = lambda: flash(bs_60, 0x400000, 0x480000, 0x800000, None)

    def sin_oferta(d):                                    # no se ofrece lo que no hace falta
        return ["ha ofrecido las ondas"] if "no tiene las ondas" in d.texto() else []
    def con_oferta(d):
        return [] if "no tiene las ondas" in d.texto() else ["no ha ofrecido las ondas"]
    def baja_ondas(d):                                    # /O deja ONDAS.UPD y no pregunta por variantes ni por Nextor
        mal = [] if any("ONDAS.UPD" in str(k).upper() for k in d.f) else ["no esta ONDAS.UPD"]
        return mal + (["pregunta por Nextor"] if "Nextor" in d.texto() else [])
    red += [
        ("red 138K: /N /R (completa de tang138k/: ondas en 0x600000, borra 0x580000)", c138, {}, "/N /R", {},
         "\rSS", 0x38, "Ajustes borrados", lambda f: esperado(f, u138full, 0x580000), Web(dict(w138)), "valida"),
        # ---- 1.4: las ondas del OPL4 solas, por la red ----
        ("red 138K: /O solo las ondas (ONDAS.UPD a 0x600000; core, pack y ajustes intactos)", c138_sin, {}, "/O", {},
         "S", 0x38, "Listo", lambda f: esperado(f, u138ondas), Web(dict(w138)), "valida", baja_ondas),
        ("red 138K: /O con las ondas ya grabadas: las sustituye", c138, {}, "/O", {},
         "S", 0x38, "Listo", lambda f: esperado(f, u138ondas), Web(dict(w138)), "valida"),
        ("red 138K: /O, contesta que no", c138_sin, {}, "/O", {}, "N", 0x38, "No se ha tocado nada", None,
         Web(dict(w138)), "valida"),
        ("red 138K: /O y el manifiesto no ofrece ondas", c138_sin, {}, "/O", {}, "", 0x38, "no ofrece las ondas", None,
         Web(dict(w138_sin)), "valida"),
        ("red 138K: /N con las ondas en blanco: core + pack y luego, si, las ondas", c138_sin, {}, "/N", {},
         "\rSSSS", 0x38, "Listo", lambda f: esperado(esperado(f, u138), u138ondas), Web(dict(w138)), "valida",
         con_oferta),
        ("red 138K: /N con las ondas en blanco: core + pack y las ondas, no", c138_sin, {}, "/N", {},
         "\rSSN", 0x38, "Listo", lambda f: esperado(f, u138), Web(dict(w138)), "valida", con_oferta),
        ("red 138K: /N con las ondas ya grabadas: no las ofrece", c138, {}, "/N", {},
         "\rSS", 0x38, "Listo", lambda f: esperado(f, u138), Web(dict(w138)), "valida", sin_oferta),
        ("red 138K: /N /R con las ondas en blanco: la completa ya las lleva, sin oferta", c138_sin, {}, "/N /R", {},
         "\rSS", 0x38, "Ajustes borrados", lambda f: esperado(f, u138full, 0x580000), Web(dict(w138)), "valida",
         sin_oferta),
        ("red 138K: /N con las ondas en blanco pero el manifiesto no las ofrece: no pregunta", c138_sin, {}, "/N", {},
         "\rSS", 0x38, "Listo", lambda f: esperado(f, u138), Web(dict(w138_sin)), "valida", sin_oferta),
        ("red 60K: /O solo las ondas (0x500000)", c60_sin, {}, "/O", {}, "S", 0x38, "Listo",
         lambda f: esperado(f, u60ondas), Web(dict(w60)), "valida"),
    ]
    for x in red:
        casos.append(x)
    bien = 0
    for nombre, ok in tabla:                              # sin Z80: lo que da tools/mxupd.py para la 138K
        print("%s %s" % ("OK  " if ok else "MAL ", nombre))
        bien += bool(ok)
    for caso_ in casos:
        nombre, fl, pkw, args, fich, teclas, ver, espera, ok = caso_[:9]
        web, regla = (caso_[9], caso_[10]) if len(caso_) > 9 else (None, None)
        extra = caso_[11] if len(caso_) > 11 else None
        antes = fl()
        f = bytearray(antes)
        pu = Puente(f, **pkw)
        d = Dos(com, args, fich, pu, list(teclas), ver, web)
        d.corre()
        txt = d.texto()
        fallos = []
        if web:
            ap_ = web.aperturas
            if any(x[1] != 443 for x in ap_):
                fallos.append("conexion que no es TLS: %s" % ap_)
            if regla == "valida" and not all(x[2] & 8 for x in ap_):
                fallos.append("alguna conexion sin verificar: %s" % ap_)
            if regla == "valida" and "certificado sin validar" in txt:
                fallos.append("aviso de certificado con el certificado bueno")
            if regla == "sinvalidar" and txt.count("certificado sin validar") != 1:
                fallos.append("el aviso sale %d veces" % txt.count("certificado sin validar"))
            if any(x[3] not in (None, "msx.barcelona") for x in ap_):
                fallos.append("SNI equivocado: %s" % ap_)
            # 1.5: toda peticion (manifiesto, .UPD, YRW801 y autoactualizacion) va en HTTP/1.0 con
            # "User-Agent: MXUPDATE/<version> (<placa>)"; la placa es la de la carpeta pedida
            ver_ = re.search(rb"MXUPDATE ([0-9.]+) - ", com).group(1).decode()
            for lin_, host_, tls_, ua_ in web.pedidas:
                carp_ = lin_.split()[1].split("/")[-2]
                if ua_ != "MXUPDATE/%s (%s)" % (ver_, {"tang60k": "console60k", "tang138k": "console138k"}.get(carp_, carp_)):
                    fallos.append("User-Agent de %r: %r" % (lin_, ua_))
                if not lin_.endswith(" HTTP/1.0"):
                    fallos.append("la peticion no es HTTP/1.0: %r" % lin_)
        if espera not in txt:
            fallos.append("falta en pantalla: %r" % espera)
        if ok:
            e = ok(antes)
            if f != e:
                k = next(j for j in range(len(f)) if f[j] != e[j])
                fallos.append("flash distinta en 0x%06X (%02X, se esperaba %02X)" % (k, f[k], e[k]))
        elif f != antes:
            fallos.append("la flash ha cambiado y no debia")
        fallos += pu.errores
        if extra:
            fallos += extra(d)
        print("%s %s  [%s; %d borrados, %d paginas]" % ("OK  " if not fallos else "MAL ", nombre, d.fin, pu.nborr,
                                                        pu.nprog))
        if fallos:
            for x in fallos:
                print("      " + x)
            print("\n".join("      | " + l for l in txt.split("\n")))
        bien += not fallos
    total = len(tabla) + len(casos)
    print("%d de %d bien" % (bien, total))
    if os.environ.get("VER"):
        print(txt)
    sys.exit(0 if bien == total else 1)


if __name__ == "__main__":
    main()
