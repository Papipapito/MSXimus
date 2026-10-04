"""contenido.py — que se copia a la particion de arranque y el AUTOEXEC.BAT que lo arranca.

Las fuentes son las carpetas de sd/ de este repositorio (o, en el .exe, las que lleva dentro):
  base/               lo comun de las SD del MSXimus (MM, UTIL, WIFI, FONTS, musica...)
  nextor-2.1.4/       NEXTOR.SYS + COMMAND2.COM + bin/ (herramientas de Nextor 2)
  nextor-3.0.0-beta2/ NEXTOR.SYS + COMMAND3.COM + bin/ (herramientas de Nextor 3)
  extras/             lo de la SD de la MSX Pico que no estaba en base (SOFARUN, hub, mapper, IA, indev.com) y FPGA
                      (MXUPDATE.COM, que actualiza el core del MSXimus 60K/138K y del MSXnano desde MSX-DOS y, por
                      WiFi, se actualiza el mismo)
El AUTOEXEC.BAT de base/ no se copia: se genera (PATH, alias y MAPDRV segun lo elegido y las particiones creadas)."""
import os
import sys

from .fatfs import Nodo

SISTEMAS = {
    "nextor214": ("Nextor 2.1.4", "nextor-2.1.4", None),
    "nextor3": ("Nextor 3.0 beta 2", "nextor-3.0.0-beta2", None),
    "msxdos": ("MSX-DOS básico (MSXDOS2.SYS + COMMAND2.COM, y MSXDOS.SYS + COMMAND.COM)", "nextor-2.1.4",
               ["MSXDOS2.SYS", "COMMAND2.COM", "MSXDOS.SYS", "COMMAND.COM"]),
    "ninguno": ("Ninguno (solo formatear)", None, None),
}

# (clave, texto, [origenes relativos a sd/], carpetas del PATH, carpetas vacias que necesita)
GRUPOS = [
    ("sofarun", "SofaRun (lanzador de ROM, DSK y cintas)", ["extras/SOFARUN"], ["SOFARUN"], ["SAVES", "SETTINGS"]),
    ("mm", "Multi Mente (gestor de ficheros)", ["base/MM"], ["MM"], []),
    ("util", "Utilidades (UTIL: 120 programas)", ["base/UTIL"], ["UTIL"], []),
    ("wifi", "Red WiFi / UNAPI (WIFI: hget, ftp, telnet, sntp...)", ["base/WIFI"], ["WIFI"], []),
    ("fonts", "Fuentes de pantalla (FONTS)", ["base/FONTS"], [], []),
    ("musica", "Música (reproductores de MoonBlaster, VGM...)", ["base/musica"], ["musica"], []),
    ("hub", "HUB (gestor de paquetes msxhub.com)", ["extras/hub"], ["hub"], []),
    ("ia", "IA (cliente de chat con IA; las claves van en IA\\ia.cfg)", ["extras/IA"], ["IA"], []),
    ("varios", "mapper e indev", ["extras/mapper", "extras/indev.com"], ["mapper"], []),
    ("fpga", "Herramientas FPGA (MXUPDATE: actualizar MSXimus 60K/138K y MSXnano)", ["extras/FPGA"], ["FPGA"], []),
]
SIEMPRE = ["FHUNT", "TMP"]      # FHUNT: el menu descarga del File-Hunter ahi y NO puede crear carpetas

# Opciones del AUTOEXEC con Nextor 3 (beta 2, COMMAND3.COM); con Nextor 2.1.4 y MSX-DOS no se usan.
#   yenslash: YENSLASH ON, la orden INTERNA de COMMAND3.COM (desde la beta 2): barra invertida en vez de yen. La
#             orden interna tiene preferencia sobre el YENSLASH.COM de UTIL, y sin parametros solo dice el estado.
#   bufinsert: SET BUFINSERT=ON, la linea de ordenes empieza en modo insercion.
#   dirk: "" = lo de Nextor 3 (tamanos en K desde 10K); "0" = como MSX-DOS 2 (bytes; los totales en K).
#   btm: AUTOEXEC.BTM en vez de AUTOEXEC.BAT (COMMAND3.COM lo carga entero: admite GOTO, GOSUB, RETURN y END).
OPCIONES_N3 = {"yenslash": True, "bufinsert": False, "dirk": "", "btm": False}


def opciones_n3(opciones=None):
    o = dict(OPCIONES_N3)
    o.update(opciones or {})
    if o["dirk"] not in ("", "0"):
        raise ValueError("DIRK: \"\" o \"0\"")
    return o


def nombre_autoexec(sistema, opciones=None):
    return "AUTOEXEC.BTM" if sistema == "nextor3" and opciones_n3(opciones)["btm"] else "AUTOEXEC.BAT"
EXCLUIR_EXT = (".bak", ".tmp")
EXCLUIR = {"ruvector.db", "thumbs.db", "desktop.ini", "autoexec.bat", "autoexec.btm", "nextor.emu", "_nextor.psf"}


def carpeta_sd():
    """El contenido de la SD: el que lleva dentro el .exe; o MSXSDMAKER_SD; o la carpeta sd/ junto a MSXsdmaker.py."""
    if getattr(sys, "_MEIPASS", None):
        return os.path.join(sys._MEIPASS, "sd")
    aqui = os.path.dirname(os.path.abspath(__file__))
    for c in (os.environ.get("MSXSDMAKER_SD"), os.path.join(aqui, "..", "sd")):
        if c and os.path.isdir(os.path.join(c, "base")):
            return os.path.normpath(c)
    raise FileNotFoundError("no encuentro el contenido de la SD (carpeta sd/ con base/, nextor-2.1.4/...)")


def _excluido(nombre):
    n = nombre.lower()
    return n.startswith(".") or n in EXCLUIR or n.endswith(EXCLUIR_EXT)


def _asegurar_dir(padre, nombre):
    d = padre.hijo(nombre)
    if d is None:
        d = Nodo(nombre, es_dir=True)
        padre.hijos.append(d)
    return d


def _meter(padre, ruta, nombre=None):
    """Copia ruta (fichero o carpeta) dentro de padre; un fichero con el mismo nombre (sin mayusculas) se sustituye."""
    nombre = nombre or os.path.basename(ruta)
    if _excluido(nombre):
        return
    if os.path.isdir(ruta):
        d = _asegurar_dir(padre, nombre)
        d.mtime = os.path.getmtime(ruta)
        for n in sorted(os.listdir(ruta), key=str.upper):
            _meter(d, os.path.join(ruta, n))
    else:
        viejo = padre.hijo(nombre)
        if viejo is not None:
            padre.hijos.remove(viejo)
        padre.hijos.append(Nodo(nombre, origen=ruta, mtime=os.path.getmtime(ruta)))


def arbol(sistema, grupos, particiones, raiz_sd=None, opciones=None):
    """Nodo raiz de la particion de arranque. particiones = cuantas hay en la tarjeta (para el MAPDRV); opciones = las
    de Nextor 3 (OPCIONES_N3)."""
    sd = raiz_sd or carpeta_sd()
    raiz = Nodo("", es_dir=True)
    nombre, carpeta, lista = SISTEMAS[sistema]
    if carpeta:
        base = os.path.join(sd, carpeta)
        if lista:
            for f in lista:
                _meter(raiz, os.path.join(base, f))
        else:
            for n in sorted(os.listdir(base), key=str.upper):
                _meter(raiz, os.path.join(base, n))
    for clave, _, origenes, _, vacias in GRUPOS:
        if clave not in grupos:
            continue
        for o in origenes:
            _meter(raiz, os.path.join(sd, *o.split("/")))
        for v in vacias:
            _asegurar_dir(raiz, v)
    if sistema != "ninguno":
        for v in SIEMPRE:
            _asegurar_dir(raiz, v)
        raiz.hijos.append(Nodo(nombre_autoexec(sistema, opciones),
                               datos=autoexec(sistema, grupos, particiones, raiz, opciones)))
    return raiz


def autoexec(sistema, grupos, particiones, raiz, opciones=None):
    """AUTOEXEC.BAT o .BTM (CRLF y ^Z al final, como los de MSX-DOS 2). %1 = unidad de arranque."""
    n3 = sistema == "nextor3"
    o = opciones_n3(opciones)
    def hay(*ruta):
        n = raiz
        for p in ruta:
            n = n.hijo(p) if n else None
        return n is not None

    path = ["A:\\"]
    if hay("bin"):
        path.append("%1\\BIN")
    for clave, _, _, carpetas, _ in GRUPOS:
        if clave in grupos:
            path += ["%1\\" + c for c in carpetas]
    L = ["PATH " + ";".join(path), "SET TIMEZONE=+02:00", "mode 80",
         'ALIAS .BAS = "BASIC "', 'ALIAS .ASC = "BASIC "']
    if "wifi" in grupos:
        L.append("sntp pool.ntp.org /v")
    L.append("set temp %1\\TMP")
    if "mm" in grupos:
        L.append("set MM=%1\\MM")
    if "sofarun" in grupos:
        L += ["alias .ROM srom", "alias .DSK sri"]
    if n3:
        if o["yenslash"]:
            L.append("YENSLASH ON")
        if o["bufinsert"]:
            L.append("SET BUFINSERT=ON")
        if o["dirk"]:
            L.append("SET DIRK=" + o["dirk"])
    elif hay("UTIL", "YENSLASH.COM"):
        L.append("yenslash")
    if hay("FONTS", "ISO-LAT1.FNT"):
        L.append("SET FONT0808=%1\\FONTS\\ISO-LAT1.FNT")
    if hay("UTIL", "LOGIN.COM"):
        L.append("echo Type LOGIN to show system info (not for MSX1!)")
    if hay("UTIL", "DI.COM"):
        L.append("echo Type DI for DIR with long filenames")
    if "sofarun" in grupos:
        L.append("echo Type SR to start Sofarun")
    if "mm" in grupos:
        L.append("echo Type MM to start Multi Mente")
    if "hub" in grupos:
        L.append("echo Type HUBG to start HUB Gui or HUB to CLI")
    if hay("WIFI", "FH.COM") or hay("UTIL", "FH.COM"):
        L.append("echo Type FH to FileHunter Download")
    mapdrv = hay("bin", "MAPDRV.COM") or hay("UTIL", "MAPDRV.COM")
    if particiones > 1:
        letras = "CDEFGHI"[:particiones - 1]
        L.append("echo")
        if mapdrv:
            L.append("echo Maped Units " + ",".join(letras))
            for i, u in enumerate(letras):
                L.append("mapdrv %s: %d 1 0" % (u.lower(), i + 2))
        else:
            L.append("echo Partitions 2-%d: map them with CALL MAPDRV from BASIC" % particiones)
    return ("\r\n".join(L) + "\r\n").encode("ascii") + b"\x1a"


def resumen(raiz):
    """(ficheros, bytes) del arbol."""
    nf = nb = 0
    pila = [raiz]
    while pila:
        d = pila.pop()
        for h in d.hijos:
            if h.es_dir:
                pila.append(h)
            else:
                nf += 1
                nb += len(h.datos) if h.datos is not None else os.path.getsize(h.origen)
    return nf, nb
