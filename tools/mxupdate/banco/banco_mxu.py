#!/usr/bin/env python3
"""banco_mxu.py - banco de MXUPDATE.COM (02/10/2026): el .COM de verdad en un Z80 emulado (kosarev/z80, en el WSL:
python3 -m pip install --user --break-system-packages z80) con un MSX-DOS de imitacion (consola, _OPEN/_CREATE/
_READ/_WRITE/_SEEK/_CLOSE/_TERM sobre ficheros en memoria) y el puente de la flash (fpga/src/flash_bridge.v) sobre
16 MB, con la flash de un 60K, un 138K o un MSXnano. Prueba la tabla de placas: que cada .UPD solo entra en la suya,
que el pack y el core quedan byte a byte, que /R borra los ajustes de la placa (pack + 512 KB) y nada mas.

    python3 banco_mxu.py --com ../mxupdate.com --upd60 PACK_ES.UPD --updnano NANO.UPD --updnanopack NANOPACK.UPD
"""
import argparse
import random
import struct
import sys

import os
import z80

from red_mxu import Unapi, Web

FRAME = 71590
TPA = 0xD600


class Puente:
    """El de bios-msxnano-msximus/tools/actualizar_tb/banco.py (flash_bridge.v), con la flash en un bytearray."""

    def __init__(self, flash, presente=True, ajeno=0):
        self.f, self.presente, self.ajeno = flash, presente, ajeno
        self.sel = self.a2 = self.a1 = self.modo = self.ocupado = self.espera = self.ptr = 0
        self.pbuf = bytearray()
        self.nprog = self.nborr = 0
        self.errores = []

    def dir(self):
        return (self.a2 << 16) | (self.a1 << 8)

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
                    self.f[self.pdir + i] &= b
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
            self.ptr += 1
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


def flash(bitstream4k, pack, ajustes):
    rnd = random.Random(7)
    f = bytearray(b"\xff" * 0x1000000)
    f[0:4096] = bitstream4k
    f[4096:0x100000] = rnd.randbytes(0x100000 - 4096)
    f[pack:pack + 0x80000] = rnd.randbytes(0x80000)
    f[ajustes:ajustes + 16] = b"AB" + bytes(range(1, 15))
    return f


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
    c138 = lambda: flash(bs_138, 0x800000, 0x880000)
    casos = [
        # nombre, flash, puente, argumentos, ficheros, teclas, version del core, texto, flash esperada
        ("60K: el pack", c60, {}, "PACK.UPD", {"PACK.UPD": u60}, "S", 0x38, "Listo", lambda f: esperado(f, u60)),
        ("nano: core + pack", nano, {"ajeno": 100}, "NANO.UPD", {"NANO.UPD": unano}, "S", 0x21, "Listo",
         lambda f: esperado(f, unano)),
        ("nano: /R con solo el pack (borra 0x280000)", nano, {}, "NANOPACK.UPD /R", {"NANOPACK.UPD": unpack}, "S",
         0x21, "Ajustes borrados", lambda f: esperado(f, unpack, 0x280000)),
        ("nano: el nombre por defecto (MSXIMUS.UPD)", nano, {}, "", {"MSXIMUS.UPD": unpack}, "S", 0x21, "Listo",
         lambda f: esperado(f, unpack)),
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
    ]
    # ---- la red: /N contra msx.barcelona (TLS) y /S contra el PC ----
    red = []
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
    for x in red:
        casos.append(x)
    bien = 0
    for caso_ in casos:
        nombre, fl, pkw, args, fich, teclas, ver, espera, ok = caso_[:9]
        web, regla = (caso_[9], caso_[10]) if len(caso_) > 9 else (None, None)
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
        print("%s %s  [%s; %d borrados, %d paginas]" % ("OK  " if not fallos else "MAL ", nombre, d.fin, pu.nborr,
                                                        pu.nprog))
        if fallos:
            for x in fallos:
                print("      " + x)
            print("\n".join("      | " + l for l in txt.split("\n")))
        bien += not fallos
    print("%d de %d bien" % (bien, len(casos)))
    if os.environ.get("VER"):
        print(txt)
    sys.exit(0 if bien == len(casos) else 1)


if __name__ == "__main__":
    main()
