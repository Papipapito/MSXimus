#!/usr/bin/env python3
# Modelo v2 con las direcciones REALES del colector (fórmula de
# vdp_sprite_info_collect.v) para mi setup mode3 de peor caso:
#   sprite p, linea fuente yl -> patron en 0x8000 + p*2048 + yl*128
#   atributo2 del plano p     -> 0x10000 + p*8 + 4
# Cache 4096 lineas direct-mapped. tag = addr[17:14].

def cidx_current(a):
    v = a >> 2
    return (v & 0xFFF) ^ (((v >> 14) & 1) << 11)          # ^ addr[16]<<11

def cidx_fix14(a):
    v = a >> 2
    return (v & 0xFFF) ^ (((v >> 14) & 1) << 11) ^ (((v >> 12) & 1) << 10)  # + addr[14]<<10

def tag(a):
    return (a >> 14) & 0xF

def attr_addr(p):        # atributo2
    return 0x10000 + p*8 + 4

def pat_addr(p, yl):     # patron izquierdo (dcha = +4)
    return 0x8000 + p*2048 + yl*128

def line_ws(yl, n=16):
    a = []
    for p in range(n):
        a.append(attr_addr(p))
        a.append(pat_addr(p, yl))
        a.append(pat_addr(p, yl) + 4)
    return a

def sim_refetch(idxfn, passes=8, yl=5):
    # magnificacion: la MISMA scanline (mismo yl) se re-pide 'passes' veces.
    # Con working set que cabe sin conflictos -> 2o pase en adelante = 0 miss.
    slots = {}
    conf = 0
    for _ in range(passes):
        for a in line_ws(yl):
            i = idxfn(a); t = tag(a)
            if i in slots and slots[i] != t:
                conf += 1
            slots[i] = t
    return conf

def sim_sweep(idxfn, ylmax=32):
    slots = {}
    conf = 0
    for yl in range(ylmax):
        for a in line_ws(yl):
            i = idxfn(a); t = tag(a)
            if i in slots and slots[i] != t:
                conf += 1
            slots[i] = t
    return conf

# indices unicos usados por 1 scanline
for name, fn in [("ACTUAL", cidx_current), ("FIX addr[14]", cidx_fix14)]:
    ws = line_ws(5)
    idxs = [fn(a) for a in ws]
    print(f"{name:14s}: 1 scanline: {len(ws)} accesos -> {len(set(idxs))} indices distintos"
          f"  (colisiones estructurales: {len(ws)-len(set(idxs))})")

print()
for name, fn in [("ACTUAL", cidx_current), ("FIX addr[14]", cidx_fix14)]:
    print(f"{name:14s}: re-fetch 8x misma linea = {sim_refetch(fn)} conflictos "
          f"(0 = working set cabe, magnificacion = todo hits)")

print()
for name, fn in [("ACTUAL", cidx_current), ("FIX addr[14]", cidx_fix14)]:
    print(f"{name:14s}: barrido yl 0..31 = {sim_sweep(fn)} conflictos totales")

print()
print("=== detalle: que sprites colisionan con el hash ACTUAL ===")
ws = line_ws(5)
from collections import defaultdict
buckets = defaultdict(list)
for a in ws:
    buckets[cidx_current(a)].append(a)
for i, addrs in sorted(buckets.items()):
    if len(addrs) > 1:
        print(f"  index 0x{i:03x}: " + ", ".join(f"0x{a:05x}(tag{tag(a)})" for a in addrs))
