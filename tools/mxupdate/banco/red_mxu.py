#!/usr/bin/env python3
"""red_mxu.py - la red de MXUPDATE /N en el banco (02/10/2026): un ESP32 con UNAPI TCP/IP de imitacion y una web.

Engancha a la maquina de banco_mxu.Dos el EXTBIO (#FFCA: una implementacion "TCP/IP" en ROM) y el CALSLT (#001C)
hacia ella, e implementa con los registros de la especificacion TCP/IP UNAPI lo que usa network.h: DNS_Q/DNS_S,
TCP_OPEN (con TLS y "verificar certificado" en los flags, +11/+12 = nombre para el SNI), TCP_STATE, TCP_SEND,
TCP_FLUSH, TCP_RCV (de 700 en 700, como el ESP que entrega menos de lo pedido), TCP_CLOSE/ABORT y GET_IPINFO.
La web contesta HTTP/1.1 con Content-Length; lo que no tiene, 404. tls: 'ok' (valida), 'sinvalidar' (el ESP no
puede validar: rechaza el TCP_OPEN con verificar y acepta sin), 'no' (ni TLS).
"""
import struct

ESP = 0x7000
IP_WEB = [217, 160, 0, 128]


class Web:
    def __init__(self, paginas, tls="ok", corta=None):
        self.paginas = paginas            # ruta -> bytes
        self.tls = tls
        self.corta = corta                # ruta cuya respuesta se corta a la mitad
        self.aperturas = []               # (ip, puerto, flags, nombre SNI, aceptada)
        self.pedidas = []


class Conexion:
    def __init__(self, web, tls, host):
        self.web, self.tls, self.host = web, tls, host
        self.peticion = bytearray()
        self.pendiente = bytearray()
        self.servida = False

    def recibe_peticion(self, d):
        self.peticion += d
        if b"\r\n\r\n" not in self.peticion or self.servida:
            return
        linea = self.peticion.split(b"\r\n")[0].decode()
        cab = dict(l.split(": ", 1) for l in self.peticion.decode().split("\r\n")[1:] if ": " in l)
        ruta = linea.split()[1]
        self.web.pedidas.append((linea, cab.get("Host"), self.tls))
        if ruta in self.web.paginas:
            cuerpo = self.web.paginas[ruta]
            r = b"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: %d\r\n\r\n" % len(cuerpo)
            r += cuerpo
            if self.web.corta == ruta:
                r = r[:len(r) // 2]
        else:
            cuerpo = b"<html>404</html>"
            r = b"HTTP/1.1 404 Not Found\r\nContent-Length: %d\r\n\r\n" % len(cuerpo) + cuerpo
        self.pendiente += r
        self.servida = True


class Unapi:
    def __init__(self, dos, web):
        self.d, self.web = dos, web
        self.conex = {}
        self.dns = None
        m = dos.m
        m.set_breakpoint(0xFFCA)
        m.set_breakpoint(0x001C)

    def atiende(self, pc):
        m = self.d.m
        if pc == 0xFFCA:
            if m.de == 0x2222:
                if m.a == 0xFF:
                    m.hl = 0                                   # sin RAM helper
                elif m.a == 0:
                    arg = bytes(m.memory[0xF847:0xF84D])
                    m.b = 1 if arg == b"TCP/IP" else 0
                elif m.a == 1:
                    m.a, m.b, m.hl = 0x8F, 0xFF, ESP           # en ROM: por CALSLT
            return True
        if pc == 0x001C and m.ix == ESP:
            self.funcion(m.a)
            return True
        return False

    def funcion(self, f):
        m, mem = self.d.m, self.d.m.memory
        if f == 2:                                             # GET_IPINFO
            m.a, m.l, m.h, m.e, m.d = 0, 192, 168, 2, 99
        elif f == 6:                                           # DNS_Q
            n = self.d.cadena(m.hl).lower()
            self.dns = IP_WEB if n == "msx.barcelona" else None
            m.a, m.b = (0, 0) if self.dns else (0x0E, 0)
        elif f == 7:                                           # DNS_S
            if self.dns:
                m.a, m.b, m.c = 0, 2, 0
                m.l, m.h, m.e, m.d = self.dns
            else:
                m.a, m.b = 0x0E, 0
        elif f == 13:                                          # TCP_OPEN
            p = bytes(mem[m.hl:m.hl + 13])
            ip, puerto, flags = list(p[0:4]), struct.unpack("<H", p[4:6])[0], p[10]
            host = self.d.cadena(struct.unpack("<H", p[11:13])[0]).lower() if flags & 4 else None
            ok = True
            if flags & 4:
                if self.web.tls == "no" or (self.web.tls == "sinvalidar" and flags & 8):
                    ok = False
            self.web.aperturas.append((ip, puerto, flags, host, ok))
            if not ok:
                m.a = 0x0C                                     # ERR_CONN_REFUSED (por ejemplo)
                return
            n = max(self.conex, default=0) + 1
            self.conex[n] = Conexion(self.web, bool(flags & 4), host)
            m.a, m.b = 0, n
        elif f in (14, 15):                                    # TCP_CLOSE / TCP_ABORT
            self.conex.pop(m.b, None)
            m.a = 0
        elif f == 16:                                          # TCP_STATE
            c = self.conex.get(m.b)
            if not c:
                m.a = 0x0B                                     # ERR_NO_CONN
                return
            fin = c.servida and not c.pendiente
            m.a, m.b, m.c = 0, (7 if fin else 4), 0            # 4 = ESTABLISHED, 7 = CLOSE-WAIT
            m.hl, m.de, m.ix = min(len(c.pendiente), 4096), 0, 1024   # lo que el ESP tiene en su bufer
        elif f == 17:                                          # TCP_SEND
            c = self.conex[m.b]
            c.recibe_peticion(bytes(mem[m.de:m.de + m.hl]))
            m.a = 0
        elif f == 19:                                          # TCP_FLUSH
            m.a = 0
        elif f == 18:                                          # TCP_RCV
            c = self.conex[m.b]
            n = min(m.hl, len(c.pendiente), 700)
            m.set_memory_block(m.de, bytes(c.pendiente[:n]))
            del c.pendiente[:n]
            m.a, m.bc, m.hl = 0, n, 0
        else:
            self.d.salida.append("[UNAPI %d?]" % f)
            m.a = 1
