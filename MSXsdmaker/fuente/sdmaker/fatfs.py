"""fatfs.py — sistemas de ficheros FAT16 y FAT32 para tarjetas del MSX, sin dependencias.

FAT16: la geometria es la del FDISK de Nextor (kernel/bank5/fdisk2.c, CalculateFatFileSystemParametersFat16), byte a
byte: 1 sector reservado, 2 FAT, 512 entradas de raiz, cluster de 2 KB a 64 KB segun el tamano, como mucho 65524
clusters. El sector de arranque es el suyo (EB FE 90, "NEXTOR20", medio F0).
FAT32: la receta de Microsoft (fatgen103): 32 sectores reservados (o mas, para que los datos empiecen alineados a
4 MB), FSInfo en el 1 y copia del arranque en el 6. Ni Nextor 2.1.4 ni 3.0 beta 1 leen FAT32: es para el menu del
MSXimus (ROM y DSK) y la MSX Pico.

El arbol de ficheros se escribe con nombres 8.3 (lo que ve MSX-DOS) y, cuando hace falta, entradas de nombre largo
(las que lee el menu y Windows). Los clusters de cada fichero y directorio son contiguos."""
import struct
import time
import zlib

SECTOR = 512
EOC16 = 0xFFFF
EOC32 = 0x0FFFFFFF
FAT16_MAX_CLUSTERS = 65524
VALIDOS_83 = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'()-@^_`{}~")


class TarjetaLlena(Exception):
    pass


class Geometria:
    def __init__(self, tipo, total, reservados, spc, spf, raiz_entradas, clusters):
        self.tipo = tipo                    # 16 o 32
        self.total = total                  # sectores que ocupa el sistema de ficheros
        self.reservados = reservados
        self.nfats = 2
        self.spc = spc                      # sectores por cluster
        self.spf = spf                      # sectores por FAT
        self.raiz_entradas = raiz_entradas  # FAT16: 512; FAT32: 0 (la raiz es una cadena de clusters)
        self.raiz_sectores = raiz_entradas * 32 // SECTOR
        self.clusters = clusters
        self.lba_fat = reservados
        self.lba_raiz = reservados + 2 * spf
        self.lba_datos = self.lba_raiz + self.raiz_sectores
        self.cluster_bytes = spc * SECTOR

    def lba_cluster(self, c):
        return self.lba_datos + (c - 2) * self.spc

    def __repr__(self):
        return "FAT%d %d sectores, %d KB/cluster, %d clusters, FAT de %d sectores" % (
            self.tipo, self.total, self.cluster_bytes // 1024, self.clusters, self.spf)


def geometria_fat16_nextor(sectores_particion):
    """CalculateFatFileSystemParametersFat16 del FDISK de Nextor, tal cual (tamano en K = sectores / 2)."""
    size_k = sectores_particion // 2
    if size_k <= 32768:
        raise ValueError("una FAT16 de Nextor ha de pasar de 32 MB")
    size_m = size_k >> 10
    pw = 7
    for limite, p in ((128, 2), (256, 3), (512, 4), (1024, 5), (2048, 6)):
        if size_m <= limite:
            pw = p
            break
    datos = size_k * 2 - 32 - 1
    clusters = datos >> pw
    spf = (clusters + 2) >> 8
    if (clusters + 2) & 0xFF:
        spf += 1
    clusters = (datos - 2 * spf) >> pw
    datos = clusters << pw
    if clusters > FAT16_MAX_CLUSTERS:
        dif = clusters - FAT16_MAX_CLUSTERS
        clusters = FAT16_MAX_CLUSTERS
        spf = 256
        datos -= dif << pw
    total = datos + 1 + spf * 2 + 32
    return Geometria(16, total, 1, 1 << pw, spf, 512, clusters)


def geometria_fat32(sectores, lba_inicio):
    """FAT32 con la tabla de tamanos de cluster de Microsoft y los datos alineados a 4 MB en la tarjeta."""
    if sectores <= 16777216:        # <= 8 GB: 4 KB
        spc = 8
    elif sectores <= 33554432:      # <= 16 GB: 8 KB
        spc = 16
    elif sectores <= 67108864:      # <= 32 GB: 16 KB
        spc = 32
    else:                           # mas: 32 KB
        spc = 64
    while True:
        reservados = 32
        spf = -(-(sectores - reservados) // ((256 * spc + 2) // 2))
        extra = (-(lba_inicio + reservados + 2 * spf)) % 8192
        reservados += extra
        clusters = (sectores - reservados - 2 * spf) // spc
        if clusters >= 65525 or spc == 1:
            break
        spc //= 2
    if clusters < 65525:
        raise ValueError("la particion es demasiado pequena para FAT32")
    return Geometria(32, sectores, reservados, spc, spf, 0, clusters)


def etiqueta_11(texto):
    t = "".join(c if c.upper() in VALIDOS_83 or c == " " else "_" for c in texto.upper())[:11]
    return t.ljust(11).encode("ascii")


def sector_arranque(g, etiqueta, serie, ocultos):
    b = bytearray(SECTOR)
    if g.tipo == 16:
        b[0:3] = b"\xEB\xFE\x90"
        b[3:11] = b"NEXTOR20"
        struct.pack_into("<HBHBHHBHHHI", b, 11, SECTOR, g.spc, g.reservados, 2, g.raiz_entradas,
                         g.total if g.total < 65536 else 0, 0xF0, g.spf, 63, 255, ocultos)
        struct.pack_into("<I", b, 32, g.total if g.total >= 65536 else 0)
        struct.pack_into("<BBBI", b, 36, 0x80, 0, 0x29, serie)
        b[43:54] = etiqueta_11(etiqueta)
        b[54:62] = b"FAT16   "
    else:
        b[0:3] = b"\xEB\x58\x90"
        b[3:11] = b"MSWIN4.1"
        struct.pack_into("<HBHBHHBHHHI", b, 11, SECTOR, g.spc, g.reservados, 2, 0, 0, 0xF8, 0, 63, 255, ocultos)
        struct.pack_into("<IIHHIHH", b, 32, g.total, g.spf, 0, 0, 2, 1, 6)
        struct.pack_into("<BBBI", b, 64, 0x80, 0, 0x29, serie)
        b[71:82] = etiqueta_11(etiqueta)
        b[82:90] = b"FAT32   "
    b[510:512] = b"\x55\xAA"
    return bytes(b)


def sector_fsinfo(libres, siguiente):
    b = bytearray(SECTOR)
    struct.pack_into("<I", b, 0, 0x41615252)
    struct.pack_into("<III", b, 484, 0x61417272, libres, siguiente)
    struct.pack_into("<I", b, 508, 0xAA550000)
    return bytes(b)


# ------------------------------------------------------------------ nombres 8.3 y nombres largos
def _fecha_hora(t):
    lt = time.localtime(t)
    if lt.tm_year < 1980:
        return 0x21, 0
    fecha = ((lt.tm_year - 1980) << 9) | (lt.tm_mon << 5) | lt.tm_mday
    hora = (lt.tm_hour << 11) | (lt.tm_min << 5) | (lt.tm_sec // 2)
    return fecha, hora


def _partir(nombre):
    if "." in nombre.strip("."):
        base, ext = nombre.rsplit(".", 1)
    else:
        base, ext = nombre, ""
    return base, ext


def _es_83_exacto(base, ext):
    return (1 <= len(base) <= 8 and len(ext) <= 3 and "." not in base and
            all(c.upper() in VALIDOS_83 for c in base + ext))


def nombre_corto(nombre, usados):
    """-> (11 bytes del nombre corto, bits NT de minusculas, necesita nombre largo). usados = nombres cortos ya
    asignados en el directorio (se actualiza)."""
    base, ext = _partir(nombre)
    if _es_83_exacto(base, ext):
        corto = (base.upper().ljust(8) + ext.upper().ljust(3)).encode("ascii")
        if corto not in usados:
            usados.add(corto)
            if all(p == p.upper() or p == p.lower() for p in (base, ext)):
                # todo mayusculas o todo minusculas: basta el 8.3 con los bits NT de minusculas (como Windows)
                nt = (0x08 if base != base.upper() else 0) | (0x10 if ext != ext.upper() else 0)
                return corto, nt, False
            # "Telnet.com": el corto es el exacto en mayusculas (MSX-DOS lo encuentra con TELNET) y el largo da el caso
            return corto, 0, True
    limpio = "".join(c for c in base.upper() if c not in " .")
    limpio = "".join(c if c in VALIDOS_83 else "_" for c in limpio) or "_"
    e = "".join(c if c in VALIDOS_83 else "_" for c in ext.upper().replace(" ", ""))[:3]
    for n in range(1, 1000000):
        suf = "~%d" % n
        corto = (limpio[:8 - len(suf)] + suf).ljust(8) + e.ljust(3)
        corto = corto.encode("ascii")
        if corto not in usados:
            usados.add(corto)
            return corto, 0, True
    raise TarjetaLlena("demasiados nombres parecidos en un directorio")


def suma_lfn(corto):
    s = 0
    for c in corto:
        s = (((s & 1) << 7) + (s >> 1) + c) & 0xFF
    return s


def entradas_lfn(nombre, corto):
    u = nombre.encode("utf-16-le")
    if len(nombre) > 255:
        raise ValueError("nombre demasiado largo: " + nombre)
    trozos = -(-len(nombre) // 13)
    u += b"\x00\x00" if len(nombre) % 13 else b""
    u = u.ljust(trozos * 26, b"\xFF")
    s = suma_lfn(corto)
    out = []
    for i in range(trozos, 0, -1):
        c = u[(i - 1) * 26:i * 26]
        e = bytearray(32)
        e[0] = i | (0x40 if i == trozos else 0)
        e[1:11] = c[0:10]
        e[11] = 0x0F
        e[13] = s
        e[14:26] = c[10:22]
        e[28:32] = c[22:26]
        out.append(bytes(e))
    return out


def entrada_dir(corto, atributo, cluster, tamano, mtime, nt=0):
    e = bytearray(32)
    e[0:11] = corto
    if e[0] == 0xE5:
        e[0] = 0x05
    e[11] = atributo
    e[12] = nt
    fecha, hora = _fecha_hora(mtime)
    struct.pack_into("<BHHHHHHHI", e, 13, 0, hora, fecha, fecha, cluster >> 16, hora, fecha, cluster & 0xFFFF, tamano)
    return bytes(e)


# ------------------------------------------------------------------ el arbol
class Nodo:
    """Fichero (datos o ruta de origen) o directorio (hijos). nombre = el que se ve en Windows."""
    def __init__(self, nombre, es_dir=False, origen=None, datos=None, mtime=None):
        self.nombre = nombre
        self.es_dir = es_dir
        self.origen = origen
        self.datos = datos
        self.mtime = mtime if mtime is not None else time.time()
        self.hijos = []
        self.cluster = 0
        self.tamano = 0

    def leer(self):
        if self.datos is not None:
            return self.datos
        with open(self.origen, "rb") as f:
            return f.read()

    def hijo(self, nombre):
        for h in self.hijos:
            if h.nombre.upper() == nombre.upper():
                return h
        return None


class Volumen:
    """Formatea una particion y, si se le da un arbol, lo escribe. dispositivo.escribir(lba, bytes)."""

    def __init__(self, dispositivo, lba, g, etiqueta, serie, ocultos=None, progreso=None):
        self.dev = dispositivo
        self.lba = lba
        self.g = g
        self.etiqueta = etiqueta
        self.serie = serie
        self.ocultos = lba if ocultos is None else ocultos
        self.progreso = progreso or (lambda *a: None)
        self.fat = {}
        self.siguiente = 2
        self.crc = {}          # ruta -> (crc32, tamano): para verificar despues

    def _reservar(self, n):
        if n == 0:
            return 0
        primero = self.siguiente
        if primero + n > self.g.clusters + 2:
            raise TarjetaLlena("no cabe en la particion")
        for c in range(primero, primero + n - 1):
            self.fat[c] = c + 1
        self.fat[primero + n - 1] = EOC16 if self.g.tipo == 16 else EOC32
        self.siguiente += n
        return primero

    def _clusters(self, nbytes):
        return -(-nbytes // self.g.cluster_bytes)

    def _entradas(self, d, es_raiz):
        """Entradas de d con los clusters ya puestos (d.hijos tienen .cluster/.tamano)."""
        usados = set()
        out = []
        if es_raiz:
            out.append(entrada_dir(etiqueta_11(self.etiqueta), 0x08, 0, 0, time.time()))
        else:
            padre = d.padre.cluster if d.padre is not None else 0
            out.append(entrada_dir(b".          ", 0x10, d.cluster, 0, d.mtime))
            out.append(entrada_dir(b"..         ", 0x10, padre, 0, d.mtime))
        for h in d.hijos:
            corto, nt, largo = nombre_corto(h.nombre, usados)
            if largo:
                out.extend(entradas_lfn(h.nombre, corto))
            out.append(entrada_dir(corto, 0x10 if h.es_dir else 0x20, h.cluster, 0 if h.es_dir else h.tamano,
                                   h.mtime, nt))
        return out

    def _contar(self, d, es_raiz):
        usados = set()
        n = 1 if es_raiz else 2
        for h in d.hijos:
            corto, nt, largo = nombre_corto(h.nombre, usados)
            n += 1 + (-(-len(h.nombre) // 13) if largo else 0)
        return n

    def _asignar(self, d, es_raiz, ruta):
        """Reserva los clusters del directorio d (salvo la raiz FAT16) y de todo lo que cuelga de el."""
        n = self._contar(d, es_raiz)
        if es_raiz and self.g.tipo == 16:
            if n > self.g.raiz_entradas:
                raise TarjetaLlena("la raiz no admite mas de %d entradas" % self.g.raiz_entradas)
        else:
            d.cluster = self._reservar(max(1, self._clusters(n * 32)))
        for h in d.hijos:
            h.padre = None if es_raiz else d
            if h.es_dir:
                continue
            h.tamano = len(h.leer()) if h.datos is not None else _tamano(h.origen)
            h.cluster = self._reservar(self._clusters(h.tamano))
        for h in d.hijos:
            if h.es_dir:
                self._asignar(h, False, ruta + "/" + h.nombre)

    def formatear(self, raiz=None):
        g = self.g
        raiz = raiz or Nodo("", es_dir=True)
        raiz.padre = None
        if g.tipo == 32:
            raiz.cluster = 0
        self._asignar(raiz, True, "")
        self._escribir_arbol(raiz, True, "")
        # FAT: las dos copias enteras (lo no usado a cero)
        ancho = 2 if g.tipo == 16 else 4
        fat = bytearray(g.spf * SECTOR)
        if g.tipo == 16:
            struct.pack_into("<HH", fat, 0, 0xFFF0, 0xFFFF)
        else:
            struct.pack_into("<II", fat, 0, 0x0FFFFFF8, 0x0FFFFFFF)
        for c, v in self.fat.items():
            struct.pack_into("<H" if ancho == 2 else "<I", fat, c * ancho, v)
        for k in range(2):
            self._escribir_grande(self.lba + g.lba_fat + k * g.spf, bytes(fat))
        # arranque (y en FAT32 FSInfo + copias)
        arr = sector_arranque(g, self.etiqueta, self.serie, self.ocultos)
        if g.tipo == 32:
            libres = g.clusters - (self.siguiente - 2)
            fsi = sector_fsinfo(libres, self.siguiente)
            cero = bytes(SECTOR)
            if g.reservados > 8:     # la zona reservada que alinea los datos, a cero
                self._escribir_grande(self.lba + 8, bytes((g.reservados - 8) * SECTOR))
            self.dev.escribir(self.lba, arr + fsi + cero * 4 + arr + fsi)
        else:
            self.dev.escribir(self.lba, arr)
        return self.siguiente - 2

    def _escribir_grande(self, lba, datos, trozo=1 << 20):
        for i in range(0, len(datos), trozo):
            self.dev.escribir(lba + i // SECTOR, datos[i:i + trozo])

    def _escribir_arbol(self, d, es_raiz, ruta):
        g = self.g
        ent = b"".join(self._entradas(d, es_raiz))
        if es_raiz and g.tipo == 16:
            self.dev.escribir(self.lba + g.lba_raiz, ent.ljust(g.raiz_sectores * SECTOR, b"\x00"))
        else:
            n = self._clusters(max(len(ent), 1))
            self._escribir_grande(self.lba + g.lba_cluster(d.cluster), ent.ljust(n * g.cluster_bytes, b"\x00"))
        for h in d.hijos:
            r = ruta + "/" + h.nombre
            if h.es_dir:
                self._escribir_arbol(h, False, r)
                continue
            if h.tamano:
                datos = h.leer()
                self.crc[r] = (zlib.crc32(datos), len(datos))
                relleno = self._clusters(len(datos)) * g.cluster_bytes
                self._escribir_grande(self.lba + g.lba_cluster(h.cluster), datos.ljust(relleno, b"\x00"))
            else:
                self.crc[r] = (0, 0)
            self.progreso(r)


def _tamano(ruta):
    import os
    return os.path.getsize(ruta)
