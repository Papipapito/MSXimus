"""particiones.py — como se reparte la tarjeta y los sectores de tabla de particiones (MBR y EBR).

FAT16 (2 GB o 4 GB): la disposicion del FDISK de Nextor (kernel/bank5/fdisk2.c, CreatePartition): el MBR en el sector
0 con "NEXTOR20"; la particion 1 PRIMARIA, activa, tipo 0Eh, empezando en el sector 1; y si hay mas, la entrada 2 del
MBR es una EXTENDIDA (0Fh) que las contiene como logicas, cada una con su EBR delante (EBR + 1 sector = particion).
Asi Nextor numera 1 = la primaria y 2, 3... = las logicas (MAPDRV X: 2 1 0...), y el menu del MSXimus las recorre
con TAB. Unica diferencia con el FDISK: el enlace de cada EBR a la siguiente logica cuenta tambien el sector del EBR
(lo estandar); el FDISK pone solo el tamano de la particion. Nextor no mira ese campo; Windows y Linux si.
FAT32: una sola particion 0Ch que empieza en el sector 8192 (4 MB, como el formateador de la SD Association)."""
import struct

GB2 = 2048 * 1024 * 2          # sectores de una particion de 2 GB del FDISK (2048 MB)
GB4 = 4096 * 1024 * 2          # 4 GB = el maximo de una FAT16 de Nextor
MAX_PARTICIONES = 8            # el menu del MSXimus ve 8 (PART_TBL); Nextor mapea las 9 primeras al arrancar
MIN_RESTO = 64 * 1024 * 2      # una particion de sobrante ha de tener al menos 64 MB
TIPO_FAT16 = 0x0E
TIPO_FAT32 = 0x0C
TIPO_EXT = 0x0F


class Particion:
    def __init__(self, numero, lba, sectores, tipo, activa=False, lba_ebr=None):
        self.numero = numero        # 1..N, la numeracion de MAPDRV
        self.lba = lba              # primer sector del sistema de ficheros
        self.sectores = sectores    # sectores de la entrada de la tabla
        self.tipo = tipo
        self.activa = activa
        self.lba_ebr = lba_ebr      # sector de su EBR (logicas) o None (primaria)

    @property
    def bytes(self):
        return self.sectores * 512

    def __repr__(self):
        return "P%d %s LBA %d, %d sectores (%.2f GB)" % (self.numero, "FAT32" if self.tipo == TIPO_FAT32 else "FAT16",
                                                          self.lba, self.sectores, self.sectores / 2097152)


def maximo_fat16(sectores_disco, tam):
    """Cuantas particiones de tam sectores caben con la disposicion de Nextor (1 + tam la primera, 1 + tam el resto)."""
    if sectores_disco < 1 + tam:
        return 0
    return min(MAX_PARTICIONES, 1 + (sectores_disco - 1 - tam) // (1 + tam))


def planificar(sectores_disco, esquema, n=1, resto=False, tam=None):
    """esquema: 'fat16-2g', 'fat16-4g' o 'fat32'. n: cuantas particiones FAT16. resto: una ultima con lo que sobre
    (hasta 4 GB). tam: tamano de particion en sectores (solo para pruebas con imagenes pequenas)."""
    if esquema == "fat32":
        if sectores_disco < 8192 + 2 * 65536:
            raise ValueError("tarjeta demasiado pequena para FAT32")
        return [Particion(1, 8192, sectores_disco - 8192, TIPO_FAT32, activa=True)]
    tam = tam or (GB2 if esquema == "fat16-2g" else GB4)
    maximo = maximo_fat16(sectores_disco, tam)
    if maximo == 0 and n == 1 and sectores_disco >= 1 + MIN_RESTO:
        # 1.1: una tarjeta (o imagen) mas pequena que una particion entera -- las de "2 GB" tienen menos de 2 GiB --:
        # una sola particion con toda la tarjeta, como hace el FDISK de Nextor. Antes no dejaba hacer ninguna FAT16.
        return [Particion(1, 1, min(GB4, sectores_disco - 1), TIPO_FAT16, activa=True)]
    if n < 1 or n > maximo:
        raise ValueError("caben de 1 a %d particiones de ese tamano" % maximo)
    tamanos = [tam] * n
    usado = 1 + tam + (n - 1) * (1 + tam)
    sobra = sectores_disco - usado
    if resto and n < MAX_PARTICIONES and sobra >= 1 + MIN_RESTO:
        tamanos.append(min(GB4, sobra - 1))
    partes = [Particion(1, 1, tamanos[0], TIPO_FAT16, activa=True)]
    siguiente = 1 + tamanos[0]
    for i, t in enumerate(tamanos[1:], start=2):
        partes.append(Particion(i, siguiente + 1, t, TIPO_FAT16, lba_ebr=siguiente))
        siguiente += 1 + t
    return partes


def sin_usar(sectores_disco, partes):
    fin = max(p.lba + p.sectores for p in partes)
    return sectores_disco - fin


def _chs(lba):
    c, r = divmod(lba, 255 * 63)
    h, s = divmod(r, 63)
    if c > 1023:
        return b"\xFE\xFF\xFF"
    return bytes([h, ((c >> 2) & 0xC0) | (s + 1), c & 0xFF])


def _entrada(b, i, activa, tipo, inicio, cuenta, base=0):
    """base = sector desde el que se cuenta 'inicio' (0 en el MBR; el del EBR o el de la extendida en las logicas).
    El CHS se calcula con la posicion absoluta."""
    o = 446 + 16 * i
    b[o] = 0x80 if activa else 0
    b[o + 1:o + 4] = _chs(base + inicio)
    b[o + 4] = tipo
    b[o + 5:o + 8] = _chs(base + inicio + cuenta - 1)
    struct.pack_into("<II", b, o + 8, inicio, cuenta)


def sectores_tabla(sectores_disco, partes, firma):
    """[(lba, 512 bytes)] del MBR y de los EBR."""
    mbr = bytearray(512)
    if partes[0].tipo == TIPO_FAT16:
        mbr[0:3] = b"\xEB\xFE\x90"
        mbr[3:11] = b"NEXTOR20"
    struct.pack_into("<I", mbr, 440, firma)
    p1 = partes[0]
    _entrada(mbr, 0, p1.activa, p1.tipo, p1.lba, p1.sectores)
    out = [(0, mbr)]
    logicas = partes[1:]
    if logicas:
        ext_ini = logicas[0].lba_ebr
        ext_fin = logicas[-1].lba + logicas[-1].sectores
        _entrada(mbr, 1, False, TIPO_EXT, ext_ini, ext_fin - ext_ini)
        for k, p in enumerate(logicas):
            ebr = bytearray(512)
            _entrada(ebr, 0, False, p.tipo, p.lba - p.lba_ebr, p.sectores, base=p.lba_ebr)
            if k + 1 < len(logicas):
                q = logicas[k + 1]
                _entrada(ebr, 1, False, TIPO_EXT, q.lba_ebr - ext_ini, 1 + q.sectores, base=ext_ini)
            ebr[510:512] = b"\x55\xAA"
            out.append((p.lba_ebr, ebr))
    for _, s in out:
        s[510:512] = b"\x55\xAA"
    return [(lba, bytes(s)) for lba, s in out]


def leer_tabla(leer_sector):
    """Lee el MBR (y la cadena de EBR) de una tarjeta: [(numero, tipo, lba, sectores)]. leer_sector(lba) -> 512 B."""
    mbr = leer_sector(0)
    if mbr[510:512] != b"\x55\xAA":
        return []
    out = []
    ext = None
    for i in range(4):
        o = 446 + 16 * i
        tipo = mbr[o + 4]
        ini, cuenta = struct.unpack_from("<II", mbr, o + 8)
        if tipo in (0x05, 0x0F):
            ext = ini
        elif tipo:
            out.append((len(out) + 1, tipo, ini, cuenta))
    visto = set()
    ebr_lba = ext
    while ebr_lba is not None and ebr_lba not in visto and len(out) < 64:
        visto.add(ebr_lba)
        e = leer_sector(ebr_lba)
        if e[510:512] != b"\x55\xAA":
            break
        tipo = e[446 + 4]
        ini, cuenta = struct.unpack_from("<II", e, 446 + 8)
        if tipo:
            out.append((len(out) + 1, tipo, ebr_lba + ini, cuenta))
        t2 = e[462 + 4]
        i2, _ = struct.unpack_from("<II", e, 462 + 8)
        ebr_lba = ext + i2 if t2 in (0x05, 0x0F) else None
    return out


NOMBRES_TIPO = {0x01: "FAT12", 0x04: "FAT16", 0x06: "FAT16", 0x0E: "FAT16", 0x0B: "FAT32", 0x0C: "FAT32",
                0x07: "NTFS/exFAT", 0x83: "Linux", 0xEE: "GPT"}
