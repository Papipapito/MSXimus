#!/usr/bin/env python3
# analiza_sprite_yjk.py - compara los volcados de tb_sprite_yjk_vdp.sv (sprite_8.txt = SCREEN 8, sprite_11.txt = SCREEN 10/11,
# sprite_12.txt = SCREEN 12): la posicion de los sprites respecto de las columnas del fondo (x = 64 sobre A = 0 y x = 192 sobre A = 1)
# ha de ser la MISMA que en SCREEN 8, los dos sprites han de verse (8 pixeles, color propio) y el fondo YJK no puede perder pixeles.
# Uso: analiza_sprite_yjk.py [dir de los volcados]      Salida: 0 = todo bien, 1 = fallo
import sys, collections, os

def leer(path):
    lines, cur = [], None
    for ln in open(path):
        ln = ln.split()
        if not ln:
            continue
        if ln[0] == 'L':
            cur = []
            lines.append(cur)
        elif cur is not None:
            cur.append((int(ln[0]), ln[1]))
    return lines

def runs(line):
    # [(inicio, rgb)] sin el negro (borde / fuera del frame)
    return [(a, c) for a, c in line if c != '000000']

def analiza(path):
    lines = [l for l in leer(path) if l]
    sig = collections.Counter(tuple(l) for l in lines)
    # lineas con fondo: las mas frecuentes con al menos 5 tramos de color
    cand = [(n, s) for s, n in sig.items() if len(runs(s)) >= 5]
    if not cand:
        return None
    cand.sort(key=lambda t: -t[0])
    bg = cand[0][1]
    spl = [(n, s) for n, s in cand[1:] if s != bg]
    spr = spl[0][1] if spl else None
    return bg, spr, cand

def pixeles(bg, spr, w):
    rb, rs = runs(bg), runs(spr)
    return rb, rs

def informe(nombre, path):
    r = analiza(path)
    if r is None:
        print('  %s: sin lineas de fondo' % nombre)
        return None
    bg, spr, cand = r
    rb = runs(bg)
    # tramos del fondo: [0] fondo A, [1] columna A, [2] fondo A, [3] fondo B, [4] columna B, [5] fondo B (en SCREEN 10/11 los de la derecha son paleta)
    res = {}
    # ancho de pixel: la columna de 4 pixeles
    fin = lambda i: (rb[i + 1][0] if i + 1 < len(rb) else None)
    colA, colB = rb[1], rb[4]
    wA = (fin(1) - colA[0]) / 4.0
    wB = (fin(4) - colB[0]) / 4.0
    w = wA
    res['w'] = w
    res['inicio'] = rb[0][0] / w
    res['colA'] = colA[0] / w
    res['colB'] = colB[0] / w
    if spr is None:
        res['spA'] = res['spB'] = None
        print('  %s: ancho de pixel %.1f celdas, imagen desde el pixel %.1f, columnas del fondo en %.1f y %.1f, NO HAY lineas con sprite'
              % (nombre, w, res['inicio'], res['colA'], res['colB']))
        return res
    colores_bg = set(c for _, c in rb)
    rs = [(a, c) for a, c in spr if c != '000000']
    # tramos de sprite: colores que no estan en el fondo
    sp = []
    for i, (a, c) in enumerate(rs):
        if c not in colores_bg:
            fin_i = rs[i + 1][0] if i + 1 < len(rs) else a
            sp.append((a, c, fin_i - a))
    res['sp'] = [(a / w, c, l / w) for a, c, l in sp]
    print('  %s: ancho de pixel %.1f celdas, imagen desde el pixel %.1f, columnas del fondo en %.1f y %.1f; sprites (inicio, color, ancho en pixeles): %s'
          % (nombre, w, res['inicio'], res['colA'], res['colB'],
             ', '.join('(%.1f, %s, %.1f)' % t for t in res['sp']) if res['sp'] else 'NINGUNO'))
    return res

def main():
    d = sys.argv[1] if len(sys.argv) > 1 else '.'
    rr = {}
    for m, n in ((8, 'SCREEN 8 '), (11, 'SCREEN 10/11'), (12, 'SCREEN 12')):
        p = os.path.join(d, 'sprite_%d.txt' % m)
        if os.path.exists(p):
            rr[m] = informe(n, p)
    ok = True
    ref = rr.get(8)
    if not ref or not ref.get('sp') or len(ref['sp']) < 2:
        print('FAIL: la referencia de SCREEN 8 no tiene sus dos sprites')
        return 1
    dA8 = ref['sp'][0][0] - ref['colA']
    dB8 = ref['sp'][1][0] - ref['colB']
    print('  SCREEN 8 (referencia): el sprite empieza %.1f pixeles respecto de su columna de fondo (izquierda) y %.1f (derecha)' % (dA8, dB8))
    for m, n in ((11, 'SCREEN 10/11'), (12, 'SCREEN 12')):
        r = rr.get(m)
        if not r:
            continue
        if not r.get('sp') or len(r['sp']) < 2:
            print('FAIL %s: faltan sprites (%d visibles de 2)' % (n, len(r.get('sp') or [])))
            ok = False
            continue
        dA = r['sp'][0][0] - r['colA']
        dB = r['sp'][1][0] - r['colB']
        anchos = [t[2] for t in r['sp'][:2]]
        desp = r['colA'] - ref['colA']
        print('  %s: sprite %.1f / %.1f pixeles respecto de sus columnas (SCREEN 8: %.1f / %.1f); fondo desplazado %.1f pixeles respecto de SCREEN 8; anchos %s'
              % (n, dA, dB, dA8, dB8, desp, anchos))
        if abs(dA - dA8) > 0.01 or abs(dB - dB8) > 0.01:
            print('FAIL %s: el sprite no esta alineado con el fondo como en SCREEN 8' % n)
            ok = False
        if any(abs(a - 8.0) > 0.01 for a in anchos):
            print('FAIL %s: los sprites no miden 8 pixeles' % n)
            ok = False
    print('TB_OK' if ok else 'TB_FAIL')
    return 0 if ok else 1

sys.exit(main())
