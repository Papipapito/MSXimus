#!/usr/bin/env python3
"""
alias_idx.py - Busqueda EXHAUSTIVA de una funcion de indice para la sc-cache del
shim que separe las DOS escenas a la vez.

POR QUE EXISTE. La sc-cache indexa con
    c_idx13(v) = { v[12]^v[14], v[11]^v[13], v[10:0] }      tag = v[15:12]
(v = direccion de PALABRA de 32 bits = byte/4). Con eso, en la demo V9968DM la
SAT y una linea de los patrones caen en la MISMA entrada con tags DISTINTOS y se
desalojan mutuamente cada scanline. Es la familia del bug _151, que se arreglo
para las direcciones de la ru66 y no cubre estas.

⚠️ EL ERROR QUE INVALIDO EL PRIMER ANALISIS, y que este script corrige: se dio por
supuesto que en LAS DOS escenas base[8:7]=0 y por tanto la SAT ocupaba 128 B. Es
FALSO para la ru66. Segun vdp_cpu_interface.v el R#5 entra en base[14:7], asi que
    ru66     R#5=0x03, R#11=0x02 -> base = 0x10180 -> base[8:7] = 0b11
    V9968DM  R#5=0xEC, R#11=0x00 -> base = 0x07600 -> base[8:7] = 0b00
y la mascara de vdp_sprite_select_visible_planes.v:136 es
    (base[8:7] & plane[5:4])
=> en la ru66 NO anula plane[5:4] y la SAT ocupa 256 B (64 palabras);
   en el V9968DM SI lo anula y ocupa 128 B (32 palabras).
Con la huella mala, la busqueda "solo una candidata sirve" no valia.

CRITERIO DE VALIDEZ de una funcion candidata:
  1. BIYECTIVA con el tag: (idx, tag) -> v unica, por enumeracion de las 65536
     palabras. Si no, habria falsos aciertos = datos corruptos.
  2. Conserva idx == v en 0x0000-0x1FFF (garantia _117 del shim).
  3. CERO colisiones SAT<->SPT vivas en LAS DOS escenas.
"""

# ---------------------------------------------------------------------------
#  Geometria, sacada del RTL (no supuesta)
# ---------------------------------------------------------------------------
def sat_words(r5, r11, planes):
    """Palabras que ocupa la SAT en modo 3.
    vdp_sprite_select_visible_planes.v:136 y vdp_sprite_info_collect.v:277:
      addr = {base[17:9], (base[8:7] & plane[5:4]), plane[3:0], 3'd0}  (+4 el 2o)
    """
    base = (r11 << 15) | (r5 << 7)
    hi   = base >> 9                      # base[17:9]
    m    = (base >> 7) & 3                # base[8:7]
    out = set()
    for p in planes:
        a = (hi << 9) | (((m & (p >> 4)) & 3) << 7) | ((p & 15) << 3)
        out.add(a >> 2)                   # byte -> palabra
        out.add((a + 4) >> 2)
    return out


def spt_words(r6, pats, yls, page=0):
    """byte = SPT + page*32768 + pat[7:4]*2048 + yl*128 + pat[3:0]*8 + {0|4}"""
    spt = r6 << 11
    out = set()
    for p in pats:
        for yl in yls:
            a = spt + page * 32768 + ((p >> 4) & 15) * 2048 + yl * 128 + (p & 15) * 8
            out.add(a >> 2)
            out.add((a + 4) >> 2)
    return out


# ---------------------------------------------------------------------------
#  Candidatas: idx de 13 bits a partir de v de 16 bits, tag = v[15:12]
# ---------------------------------------------------------------------------
def bit(v, n): return (v >> n) & 1

CANDIDATAS = {
    # la ACTUAL (_151)
    "actual":  lambda v: ((bit(v,12) ^ bit(v,14)) << 12) | ((bit(v,11) ^ bit(v,13)) << 11) | (v & 0x7FF),
    # la que se propuso antes (B1)
    "B1":      lambda v: ((bit(v,12) ^ bit(v,13)) << 12) | ((bit(v,11) ^ bit(v,14)) << 11) | (v & 0x7FF),
    "B2":      lambda v: ((bit(v,12) ^ bit(v,15)) << 12) | ((bit(v,11) ^ bit(v,13)) << 11) | (v & 0x7FF),
    # mezclas que meten mas bits altos en el indice
    "C1":      lambda v: ((bit(v,12) ^ bit(v,14) ^ bit(v,15)) << 12) | ((bit(v,11) ^ bit(v,13)) << 11) | (v & 0x7FF),
    "C2":      lambda v: ((bit(v,12) ^ bit(v,13)) << 12) | ((bit(v,11) ^ bit(v,14) ^ bit(v,15)) << 11) | (v & 0x7FF),
    "C3":      lambda v: ((bit(v,12) ^ bit(v,15)) << 12) | ((bit(v,11) ^ bit(v,14)) << 11) | (v & 0x7FF),
    "C4":      lambda v: ((bit(v,12) ^ bit(v,13) ^ bit(v,15)) << 12) | ((bit(v,11) ^ bit(v,14)) << 11) | (v & 0x7FF),
    # tambien plegando el bit 10 (mueve la huella dentro de la pagina)
    "D1":      lambda v: ((bit(v,12) ^ bit(v,14)) << 12) | ((bit(v,11) ^ bit(v,13)) << 11) | ((bit(v,10) ^ bit(v,15)) << 10) | (v & 0x3FF),
}


def valida(f):
    """(1) biyectiva con el tag, (2) identidad en 0x0000-0x1FFF"""
    vistos = set()
    for v in range(1 << 16):
        k = (f(v), (v >> 12) & 15)
        if k in vistos:
            return False, "NO biyectiva (falsos aciertos)"
        vistos.add(k)
    for v in range(0x2000):
        if f(v) != v:
            return False, "rompe la identidad en 0x0000-0x1FFF (garantia _117)"
    return True, "ok"


def colisiones(f, sat, spt):
    """Palabras de la SPT que caen en un indice ocupado por la SAT con OTRO tag."""
    ocup = {}
    for v in sat:
        ocup.setdefault(f(v), set()).add((v >> 12) & 15)
    n = 0
    ejemplos = []
    for v in spt:
        i = f(v)
        if i in ocup and ((v >> 12) & 15) not in ocup[i]:
            n += 1
            if len(ejemplos) < 3:
                ejemplos.append("v=0x%04X (byte 0x%05X) -> idx %d" % (v, v << 2, i))
    return n, ejemplos


# ---------------------------------------------------------------------------
def main():
    # ⚠️ LA HUELLA DE LA SPT DEPENDE DEL SZ DE CADA PLANO, y no verlo hace
    # SOBRECONTAR muchisimo. La altura FUENTE de un sprite es 16<<SZ, asi que yl
    # solo recorre ese rango: SZ=3 -> 0..127, SZ=1 -> 0..31, SZ=0 -> 0..15.
    # Enumerar todos los patrones contra yl 0..127 mete combinaciones que NUNCA
    # se piden, y entonces salen "colisiones" que no existen en la escena.
    # (Datos de tools/v9968_sim/sprite3_ru66_setup.svh:18-23.)
    ru_sat = sat_words(0x03, 0x02, range(26))
    ru_spt = set()
    ru_spt |= spt_words(0x10, range(8),        range(128))   # conejos, SZ=3
    ru_spt |= spt_words(0x10, [129],           range(16))    # sombras, SZ=0
    ru_spt |= spt_words(0x10, range(144, 158), range(32))    # mensaje, SZ=1
    ru_spt |= spt_words(0x10, [128],           range(16))    # ventana, SZ=0

    # V9968DM: R#5=0xEC R#11=0, 13 planos, patrones 0..12, TODOS SZ=3 (yl 0..127)
    dm_sat = sat_words(0xEC, 0x00, range(13))
    dm_spt = spt_words(0x18, range(13), range(128))

    print("HUELLAS (palabras de 32 bits):")
    print("  ru66     SAT %3d palabras (%d bytes)   SPT %5d" % (len(ru_sat), len(ru_sat) * 4, len(ru_spt)))
    print("  V9968DM  SAT %3d palabras (%d bytes)   SPT %5d" % (len(dm_sat), len(dm_sat) * 4, len(dm_spt)))
    print()
    print("%-8s %-10s %-12s %-12s" % ("cand.", "valida", "colis.ru66", "colis.V9968DM"))
    print("-" * 50)
    for nom, f in CANDIDATAS.items():
        ok, why = valida(f)
        if not ok:
            print("%-8s %-10s  %s" % (nom, "NO", why))
            continue
        cr, er = colisiones(f, ru_sat, ru_spt)
        cd, ed = colisiones(f, dm_sat, dm_spt)
        marca = "  <<< SIRVE" if (cr == 0 and cd == 0) else ""
        print("%-8s %-10s %-12d %-12d%s" % (nom, "si", cr, cd, marca))
        if cd and ed:
            print("         ej. V9968DM: %s" % ed[0])
        if cr and er:
            print("         ej. ru66   : %s" % er[0])


if __name__ == "__main__":
    main()
