#!/usr/bin/env python3
# verificar_descarga.py -- comprueba una descarga del File-Hunter contra el
# ORIGINAL, y si no cuadra dice EXACTAMENTE que sectores estan mal y con que.
#
#   python tools\verificar_descarga.py "E:\FHUNT\Loquesea [1234].rom"
#   python tools\verificar_descarga.py E:\FHUNT\*.rom
#
# POR QUE NO BASTA EL CRC. El CRC dice "esta mal" y ya. Lo que hizo falta para
# cazar el bug del 21/08 fue mirar el DIBUJO del error, y son tres preguntas:
#
#   1. Cuantos sectores fallan y CADA CUANTO. Un espaciado regular es un
#      contador o un temporizador; uno aleatorio es ruido.
#   2. Si el resto del fichero esta DESPLAZADO. Si lo esta, se perdieron bytes
#      del stream; si no lo esta, el stream llego entero y el problema es de
#      escritura. Esto solo lo distingue una comparacion byte a byte.
#   3. QUE hay en el sector malo. Si es contenido que no existe en el fichero
#      bueno (FF de flash borrada, E5 de formateo MSX-DOS, restos de otro
#      fichero), esa escritura no llego al medio.
#
# La API da CRC32 desde el 07/08 y busca por el numero del corchete del nombre,
# asi que cualquier fichero bajado sirve de caso de prueba sin necesidad de un
# dump bueno guardado en el PC.
import sys, os, re, zlib, glob, urllib.request, urllib.parse

HOST = "http://api.file-hunter.com"
TIPOS = {".rom":"rom", ".dsk":"dsk", ".cas":"cas", ".vgm":"vgm"}

def url_de(tipo, busca, idx):
    return "%s/MSXnano.php?base=1BA0&type=%s&msx=&char=%s&download=%d" % (
        HOST, tipo, urllib.parse.quote(busca, safe=''), idx)

def pide(tipo, busca, idx, solo_meta):
    """Devuelve (meta, cuerpo). Con solo_meta corta tras la primera linea."""
    r = urllib.request.urlopen(url_de(tipo, busca, idx), timeout=300)
    buf = b""
    while b"\n" not in buf and len(buf) < 1024:
        c = r.read(64)
        if not c: break
        buf += c
    if b"\n" not in buf:
        r.close(); return None, None
    meta, resto = buf.split(b"\n", 1)
    meta = meta.decode('latin1')
    if not meta.startswith("type:") or ",name:" not in meta:
        r.close(); return None, None          # indice fuera de rango: devuelve el listado
    if solo_meta:
        r.close(); return meta, None
    cuerpo = resto + r.read()
    r.close()
    return meta, cuerpo

def campo(meta, clave):
    i = meta.find(clave)
    if i < 0: return None
    j = meta.find(",", i)
    return meta[i+len(clave): (j if j >= 0 else len(meta))]

def nombre_de(meta):
    # REGLA DE ORO: name: es SIEMPRE el ultimo campo (los nombres llevan comas)
    i = meta.find(",name:")
    return meta[i+6:] if i >= 0 else None

def buscar(local):
    base = os.path.basename(local)
    tipo = TIPOS.get(os.path.splitext(base)[1].lower(), "rom")
    ids = re.findall(r"\[(\d{2,6})\]", base)
    consultas = list(reversed(ids)) or [re.sub(r"[\[\(].*", "", base).strip()[:24]]
    for q in consultas:
        for idx in range(0, 40):
            try: meta, _ = pide(tipo, q, idx, True)
            except Exception: break
            if meta is None: break            # se acabaron los resultados
            if nombre_de(meta) == base:
                return tipo, q, idx, meta
    return None, None, None, None

def verificar(local):
    base = os.path.basename(local)
    print("=" * 78); print(base)
    try: mio = open(local, 'rb').read()
    except OSError as e: print("  NO SE PUEDE LEER: %s" % e); return
    tipo, q, idx, meta = buscar(local)
    if meta is None:
        print("  no lo encuentro en la API (probado type=%s). Nombre cambiado?" %
              TIPOS.get(os.path.splitext(base)[1].lower(), "rom"))
        print("  CRC32 local: %08x  (%d bytes)" % (zlib.crc32(mio) & 0xffffffff, len(mio)))
        return
    crc_api = campo(meta, "crc:")
    tam_api = campo(meta, "size:")
    crc_mio = "%08x" % (zlib.crc32(mio) & 0xffffffff)
    print("  API: type=%s char=%s idx=%d  size=%s crc=%s" % (tipo, q, idx, tam_api, crc_api))
    print("  tuyo: %d bytes  crc=%s" % (len(mio), crc_mio))
    if tam_api and int(tam_api) != len(mio):
        print("  AVISO: EL TAMANO NO CUADRA (%s contra %d)" % (tam_api, len(mio)))
    if crc_api and crc_api == crc_mio:
        print("  LIMPIO -- el fichero es correcto"); return
    if not crc_api:
        print("  la API no dio crc: para este item; comparando byte a byte")
    print("  NO CUADRA -- bajando el original para ver el dibujo del error")
    _, ref = pide(tipo, q, idx, False)
    if ref is None: print("  no he podido bajar el original"); return

    n = min(len(ref), len(mio))
    malos = []
    for s in range(0, n, 512):
        a, b = ref[s:s+512], mio[s:s+512]
        if a != b: malos.append((s // 512, a, b))
    print("  sectores de 512 distintos: %d de %d" % (len(malos), (n + 511) // 512))

    idxs = [m[0] for m in malos]
    if len(idxs) > 1:
        sep = [idxs[i+1] - idxs[i] for i in range(len(idxs)-1)]
        reg = max(sep) - min(sep) <= max(3, min(sep) // 20)
        print("  posiciones: %s" % (idxs[:12] + (["..."] if len(idxs) > 12 else [])))
        print("  separaciones: %s   -> %s" % (sep[:12],
              "REGULAR (contador o temporizador, no ruido)" if reg else "irregular"))

    # el resto del fichero, esta desplazado?
    sanos = n // 512 - len(malos)
    print("  el resto del fichero: %d sectores byte a byte identicos -> %s" % (sanos,
          "NO hay desplazamiento, el stream llego entero" if sanos else "revisar a mano"))

    # de donde sale lo que hay en los sectores malos
    todos = {ref[i:i+512] for i in range(0, len(ref), 512)}
    for sec, a, b in malos[:6]:
        uni = ("512 x %02X" % b[0]) if len(set(b)) == 1 else "datos"
        ori = "REPETIDO del propio fichero" if b in todos else "AJENO: no existe en el original"
        esp = ("512 x %02X" % a[0]) if len(set(a)) == 1 else "datos"
        print("    sector %-5d esperaba %-9s recibio %-9s  %s" % (sec, esp, uni, ori))
    if len(malos) > 6: print("    ... y %d mas" % (len(malos) - 6))
    print()
    print("  LECTURA: contenido AJENO = esa escritura no llego a la tarjeta y el")
    print("  sector conservo lo que ya habia (FF flash borrada, E5 formateo MSX-DOS,")
    print("  restos de otro fichero). No es perdida de datos: es escritura perdida.")

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit("uso: verificar_descarga.py <fichero> [mas ficheros o comodines]")
    ficheros = []
    for a in args:
        g = glob.glob(a)
        ficheros.extend(g if g else [a])
    for f in ficheros:
        verificar(f)
