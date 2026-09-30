"""verificar.py — relee la tarjeta con un lector FAT independiente del escritor y compara con lo que se quiso escribir:
la tabla de particiones, el sector de arranque de cada particion y el contenido (CRC32) de cada fichero."""
import struct
import zlib

from . import particiones

SECTOR = 512


class LectorFat:
    def __init__(self, dev, lba):
        self.dev = dev
        self.lba = lba
        b = dev.leer(lba)
        if b[510:512] != b"\x55\xAA":
            raise ValueError("sin firma 55AA en el sector de arranque")
        (bps, self.spc, res, nfats, raiz_ent, tot16, _media, fat16, _spt, _heads, _ocultos, tot32) = \
            struct.unpack_from("<HBHBHHBHHHII", b, 11)
        if bps != SECTOR:
            raise ValueError("sector de %d bytes" % bps)
        self.fat32 = fat16 == 0
        self.spf = struct.unpack_from("<I", b, 36)[0] if self.fat32 else fat16
        self.raiz_cluster = struct.unpack_from("<I", b, 44)[0] if self.fat32 else 0
        self.lba_fat = lba + res
        self.lba_raiz = self.lba_fat + nfats * self.spf
        self.raiz_sectores = raiz_ent * 32 // SECTOR
        self.lba_datos = self.lba_raiz + self.raiz_sectores
        self.total = tot16 or tot32
        self._fat = None

    def fat(self):
        if self._fat is None:
            self._fat = self.dev.leer(self.lba_fat, self.spf)
        return self._fat

    def _cadena(self, c):
        f = self.fat()
        out = []
        while 2 <= c < (0x0FFFFFF8 if self.fat32 else 0xFFF8) and len(out) < 1 << 22:
            out.append(c)
            c = struct.unpack_from("<I", f, c * 4)[0] & 0x0FFFFFFF if self.fat32 else struct.unpack_from("<H", f, c * 2)[0]
        return out

    def _leer_clusters(self, c, tamano=None):
        datos = bytearray()
        for k in self._cadena(c):
            datos += self.dev.leer(self.lba_datos + (k - 2) * self.spc, self.spc)
        return bytes(datos if tamano is None else datos[:tamano])

    def _dir(self, c):
        if c == 0 and not self.fat32:
            return self.dev.leer(self.lba_raiz, self.raiz_sectores)
        return self._leer_clusters(c or self.raiz_cluster)

    def listar(self, c=0, ruta=""):
        """{ruta: (crc32, tamano)} de todos los ficheros, con el nombre largo o el corto con sus minusculas."""
        out = {}
        largo = []
        d = self._dir(c)
        for i in range(0, len(d), 32):
            e = d[i:i + 32]
            if e[0] == 0:
                break
            if e[0] == 0xE5:
                largo = []
                continue
            if e[11] == 0x0F:
                trozo = e[1:11] + e[14:26] + e[28:32]
                largo.insert(0, trozo.decode("utf-16-le").split("\x00")[0].replace("￿", ""))
                continue
            if e[11] & 0x08:
                largo = []
                continue
            base = e[0:8].decode("ascii").rstrip()
            ext = e[8:11].decode("ascii").rstrip()
            if e[12] & 0x08:
                base = base.lower()
            if e[12] & 0x10:
                ext = ext.lower()
            nombre = "".join(largo) if largo else base + ("." + ext if ext else "")
            largo = []
            if nombre in (".", ".."):
                continue
            cl = struct.unpack_from("<H", e, 26)[0] | (struct.unpack_from("<H", e, 20)[0] << 16 if self.fat32 else 0)
            tam = struct.unpack_from("<I", e, 28)[0]
            r = ruta + "/" + nombre
            if e[11] & 0x10:
                out.update(self.listar(cl, r))
            else:
                datos = self._leer_clusters(cl, tam) if tam else b""
                out[r] = (zlib.crc32(datos), len(datos))
        return out


def comprobar(dev, plan, volumenes):
    """Lista de textos de error (vacia = todo bien)."""
    errores = []
    tabla = particiones.leer_tabla(lambda lba: dev.leer(lba))
    esperado = [(p.numero, p.tipo, p.lba, p.sectores) for p in plan]
    if tabla != esperado:
        errores.append("la tabla de particiones leida no es la escrita: %r" % tabla)
    for p, v in zip(plan, volumenes):
        try:
            lector = LectorFat(dev, p.lba)
        except ValueError as e:
            errores.append("particion %d: %s" % (p.numero, e))
            continue
        leido = lector.listar()
        if leido != v.crc:
            falta = sorted(set(v.crc) - set(leido))
            sobra = sorted(set(leido) - set(v.crc))
            mal = sorted(r for r in set(v.crc) & set(leido) if v.crc[r] != leido[r])
            errores.append("particion %d: faltan %s, sobran %s, distintos %s" % (p.numero, falta[:5], sobra[:5], mal[:5]))
    return errores
