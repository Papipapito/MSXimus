#!/usr/bin/env python3
# horno.py — progreso de una horneada de Gowin (los 3 clones de mkclones).
#
#   python tools/horno.py <dir_de_la_horneada>          # en vivo, refresca cada 10 s
#   python tools/horno.py <dir_de_la_horneada> --once   # una foto y salir
#
# <dir> es el que se paso a mkclones.sh (contiene bx_c1/bx_c2/bx_c3).
# Lee los build.log y mapea el ULTIMO hito visto a un % de TIEMPO real
# (calibrado con horneadas de esta placa: la sintesis es ~1/5 del total y
# la fase 3 del placement es el tramo largo). ETA = total tipico * lo que
# falta, corregido con el ritmo real del clon mas adelantado.
import sys, os, time, re

TOTAL_TIPICO_S = 35 * 60          # horneada tipica de 3 clones en paralelo

# (patron_en_el_log, fraccion_de_tiempo_acumulada, nombre corto)
HITOS = [
    ("Running parser",                     0.01, "parser"),
    ("[5%] Running netlist conversion",    0.03, "sintesis: netlist"),
    ("[25%] Optimizing Phase 2",           0.06, "sintesis: optimiza"),
    ("[55%] Inferring Phase 3",            0.10, "sintesis: inferencia"),
    ("[90%] Tech-Mapping Phase 4",         0.16, "sintesis: mapeo"),
    ("[100%] Generate report",             0.20, "sintesis LISTA"),
    ("Running placement",                  0.22, "placement: arranca"),
    ("[10%] Placement Phase 0",            0.25, "placement F0"),
    ("[20%] Placement Phase 1",            0.30, "placement F1"),
    ("[30%] Placement Phase 2",            0.35, "placement F2 (el tramo LARGO)"),
    ("[50%] Placement Phase 3",            0.75, "placement F3 hecha"),
    ("[60%] Routing Phase 0",              0.78, "rutado F0"),
    ("[70%] Routing Phase 1",              0.81, "rutado F1"),
    ("[80%] Routing Phase 2",              0.85, "rutado F2"),
    ("[90%] Routing Phase 3",              0.88, "rutado F3"),
    ("Running timing analysis",            0.90, "analisis de timing"),
    ("Generate bit",                       0.96, "generando bitstream"),
]

def estado_clon(d):
    log = os.path.join(d, "fpga", "build.log")
    fs  = os.path.join(d, "fpga", "impl", "pnr", "project.fs")
    if os.path.exists(fs):
        return 1.0, "HORNEADA OK (.fs listo)", None
    if not os.path.exists(log):
        return 0.0, "sin arrancar", None
    frac, nombre = 0.0, "arrancando"
    try:
        with open(log, "r", errors="replace") as f:
            txt = f.read()
        for pat, fr, nom in HITOS:
            if pat in txt:
                frac, nombre = fr, nom
        err = len(re.findall(r"^ERROR", txt, re.M))
        if err:
            return frac, f"*** {err} ERROR(ES) *** ({nombre})", None
    except OSError:
        pass
    return frac, nombre, os.path.getmtime(log)

def barra(frac, ancho=26):
    n = int(frac * ancho)
    return "#" * n + "." * (ancho - n)

def foto(base):
    clones = [os.path.join(base, f"bx_c{i}") for i in (1, 2, 3)]
    t0 = min((os.path.getctime(os.path.join(c, "fpga")) for c in clones
              if os.path.exists(os.path.join(c, "fpga"))), default=time.time())
    trans = time.time() - t0
    print(f"\n=== HORNO {os.path.basename(base)} — {int(trans//60)}m{int(trans%60):02d}s en el horno ===")
    fmin = 1.0
    for i, c in enumerate(clones, 1):
        frac, nombre, _ = estado_clon(c)
        fmin = min(fmin, frac)
        eta = ""
        if 0 < frac < 1.0:
            # ETA con el ritmo real: si llevamos 'trans' para 'frac', el resto
            # a ese ritmo; acotado por el total tipico para no alucinar al inicio
            est = max(trans / max(frac, 0.05), TOTAL_TIPICO_S)
            resta = int(est * (1.0 - frac))
            eta = f"  ~{resta//60}m{resta%60:02d}s restantes"
        print(f"  c{i}  [{barra(frac)}] {int(frac*100):3d}%  {nombre}{eta}")
    return fmin >= 1.0

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    base = sys.argv[1]
    una = "--once" in sys.argv
    while True:
        listo = foto(base)
        if listo:
            print("  >>> Las tres fuera del horno. Toca el gate de timing.")
            break
        if una:
            break
        time.sleep(10)
