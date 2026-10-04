"""novedades.py — mira en GitHub si hay una version de MSX SD Maker mas nueva que esta: la ultima release publicada de
Papipapito/SD_Maker (su etiqueta, vX.Y). Sin red, o si GitHub no contesta, no pasa nada: devuelve None."""
import json
import re
import urllib.request

from . import VERSION

API = "https://api.github.com/repos/Papipapito/SD_Maker/releases/latest"
PAGINA = "https://github.com/Papipapito/SD_Maker/releases/latest"


def numeros(v):
    """'v1.10' -> (1, 10): para comparar versiones por numeros y no por texto."""
    return tuple(int(x) for x in re.findall(r"\d+", v))


def ultima(espera=5):
    """(version, url de la release) de la ultima publicada en GitHub, o None si no se puede saber."""
    try:
        pet = urllib.request.Request(API, headers={"Accept": "application/vnd.github+json",
                                                   "User-Agent": "MSXsdmaker/" + VERSION})
        with urllib.request.urlopen(pet, timeout=espera) as r:
            d = json.load(r)
        return d["tag_name"].lstrip("vV"), d.get("html_url") or PAGINA
    except Exception:
        return None


def hay_nueva(espera=5):
    """(version, url) si la ultima publicada es mayor que esta; si no, o sin red, None."""
    u = ultima(espera)
    if u and numeros(u[0]) > numeros(VERSION):
        return u
    return None
