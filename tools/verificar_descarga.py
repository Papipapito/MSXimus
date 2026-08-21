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

RITMO = None      # sectores/s, para traducir separaciones a segundos (--ritmo)
VOLCAR = False    # --volcar: hexdump de los sectores malos

def pinta(b):
    """Que PINTA tiene el sector: distinguir basura de RAM, FAT o directorio."""
    if len(set(b)) <= 2: return "casi uniforme"
    # entrada de directorio FAT: 16 registros de 32 B, byte 11 = atributos
    if sum(1 for i in range(0, 512, 32) if b[i+11] in (0x0F, 0x10, 0x20, 0x00)) >= 14:
        return "PINTA DE DIRECTORIO"
    # sector de FAT: palabras de 16 bits pequenas y en su mayoria crecientes
    w = [b[i] | (b[i+1] << 8) for i in range(0, 512, 2)]
    cre = sum(1 for i in range(len(w)-1) if 0 < w[i+1] - w[i] <= 2)
    if cre > 180: return "PINTA DE FAT"
    if sum(1 for c in b if 32 <= c < 127) > 460: return "TEXTO ASCII"
    return "datos"

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
        print("  posiciones (TODAS):")
        for k in range(0, len(idxs), 14):
            print("     " + " ".join("%5d" % v for v in idxs[k:k+14]))
        print("  separaciones (TODAS):")
        for k in range(0, len(sep), 14):
            print("     " + " ".join("%5d" % v for v in sep[k:k+14]))
        base = min(sep)
        # un hueco doble/triple es el MISMO periodo con un disparo perdido:
        # normalizar antes de juzgar si es regular
        norm = [x / round(x / base) for x in sep if round(x / base) >= 1]
        disp = (max(norm) - min(norm)) / (sum(norm) / len(norm))
        print("  periodo normalizado (los huecos dobles cuentan como 2): %.1f sectores"
              % (sum(norm) / len(norm)))
        print("  dispersion: %.1f%% -> %s" % (100 * disp,
              "REGULAR: es un contador o un RELOJ, no ruido" if disp < 0.15 else "irregular"))
        if RITMO:
            print("  a %.1f sectores/s eso son %.2f s entre fallos"
                  % (RITMO, (sum(norm) / len(norm)) / RITMO))
        print("  reparto: %d de %d fallos en la PRIMERA mitad del fichero"
              % (sum(1 for v in idxs if v < (n // 512) // 2), len(idxs)))

    # el resto del fichero, esta desplazado?
    sanos = n // 512 - len(malos)
    print("  el resto del fichero: %d sectores byte a byte identicos -> %s" % (sanos,
          "NO hay desplazamiento, el stream llego entero" if sanos else "revisar a mano"))

    # de donde sale lo que hay en los sectores malos
    todos = {ref[i:i+512]: i // 512 for i in range(0, len(ref), 512)}
    mios  = {mio[i:i+512]: i // 512 for i in range(0, len(mio), 512)}
    print("  QUE HAY EN CADA SECTOR MALO:")
    for sec, a, b in malos[:20]:
        uni = ("512 x %02X" % b[0]) if len(set(b)) == 1 else pinta(b)
        if len(set(b)) <= 2:
            ori = "uniforme: no dice de donde viene"
        elif b in todos:
            dist = sec - todos[b]
            ori = "REPETIDO: es el sector %d del original (%+d, %s)" % (
                todos[b], -dist,
                "multiplo de 128 = 64 KB" if dist % 128 == 0 else "sin alinear")
        else:
            ori = "AJENO: no esta en el original"
        # lo que TENIA que haber ahi, aparece en otro sitio del fichero recibido?
        otro = ""
        if len(set(a)) > 2 and a in mios and mios[a] != sec:
            otro = "  [!] lo esperado aparece en el sector %d del tuyo" % mios[a]
        esp = ("512 x %02X" % a[0]) if len(set(a)) == 1 else "datos"
        print("    sector %-5d esperaba %-9s recibio %-16s %s%s" % (sec, esp, uni, ori, otro))
    if len(malos) > 20: print("    ... y %d mas" % (len(malos) - 20))

    if VOLCAR:
        # Los BYTES del sector malo. Es lo unico que distingue de donde sale:
        #   nombres de fichero  -> se colo el array del navegador (ENT_ARRAY)
        #   "HTTP/1.1", "type:" -> se colo el parser de cabeceras
        #   FF / E5 / 00        -> nunca se escribio, es resto del formateo
        #   trozos del fichero  -> se escribio dos veces o en el LBA de al lado
        for sec, a, b in malos[:4]:
            print()
            print("  --- SECTOR %d, primeros 160 bytes de lo RECIBIDO ---" % sec)
            for k in range(0, 160, 16):
                t = b[k:k+16]
                print("   %04X  %-47s  |%s|" % (k, " ".join("%02x" % c for c in t),
                      "".join(chr(c) if 32 <= c < 127 else "." for c in t)))
            print("  --- y lo que TENIA que haber (para comparar) ---")
            for k in range(0, 48, 16):
                t = a[k:k+16]
                print("   %04X  %-47s  |%s|" % (k, " ".join("%02x" % c for c in t),
                      "".join(chr(c) if 32 <= c < 127 else "." for c in t)))
    print()
    print("  LECTURA. Que NO hay desplazamiento esta demostrado arriba: el stream")
    print("  llego entero y el problema es del almacenamiento, no del enlace. Que el")
    print("  contenido sea AJENO deja tres posibilidades, y hay que distinguirlas:")
    print("    a) el sector nunca se escribio y conserva lo de antes (FF = flash")
    print("       borrada, E5 = formateo MSX-DOS, o restos de otro fichero);")
    print("    b) se escribio en un LBA equivocado (mirar la marca [!] de arriba);")
    print("    c) se escribio bien pero el sistema de ficheros lee mal -- cadena de")
    print("       clusteres tocada. PASAR chkdsk ANTES de sacar conclusiones.")

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit("uso: verificar_descarga.py <fichero> [mas ficheros o comodines]")
    if "--ritmo" in args:
        i = args.index("--ritmo")
        RITMO = float(args[i+1]); del args[i:i+2]
    if "--volcar" in args:
        args.remove("--volcar"); VOLCAR = True
    ficheros = []
    for a in args:
        g = glob.glob(a)
        ficheros.extend(g if g else [a])
    # Un mismo fichero puede aparecer dos veces: por su nombre largo y por su
    # alias 8.3 (ALESTE~2.ROM). En una tarjeta sana eso NO deberia pasar, asi
    # que se avisa en vez de callarlo: es sintoma de directorio tocado.
    vistos, unicos = {}, []
    for f in ficheros:
        try:
            st = os.stat(f); clave = (st.st_dev, st.st_ino)
        except OSError:
            unicos.append(f); continue
        if clave in vistos and st.st_ino:
            print("AVISO: %s es EL MISMO fichero que %s (dos entradas de"
                  % (os.path.basename(f), os.path.basename(vistos[clave])))
            print("       directorio para un solo fichero -- alias 8.3). No lo repito.")
            continue
        vistos[clave] = f
        unicos.append(f)
    for f in unicos:
        verificar(f)
