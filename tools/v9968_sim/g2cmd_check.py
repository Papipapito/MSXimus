#!/usr/bin/env python3
"""g2cmd_check.py — comandos del V9968 en modo "byte" (SCREEN 2 con R#25 CMD=1) y regresion de los modos de
mapa de bits, sobre tb_g2cmd.sv (Icarus, WSL).

  python3 g2cmd_check.py <dir_rtl_nuevo> [<dir_rtl_viejo>] [--cases N] [--keep]

1. SCREEN 2 + CMD: HMMM / HMMV / YMMM contra un modelo de bytes (direccionado como SCREEN 8: 256 bytes por
   linea, 1 pixel por byte). Con el RTL de antes del 27/09 HMMM copiaba un byte si y otro no.
2. Si se da un RTL viejo: N casos aleatorios en SCREEN 5/6/7/8 (HMMV/HMMM/YMMM/LMMV/LMMM/LINE, alta velocidad
   y velocidad V9938, DIX/DIY) han de dar volcados IDENTICOS bit a bit en los dos RTL.
Sale 0 si todo pasa.
"""
import os, random, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TB = os.path.join(HERE, "tb_g2cmd.sv")
MODE_BIT = {2: 1, 5: 3, 6: 4, 7: 5, 8: 6}
CMD = {"HMMV": 0xC0, "HMMM": 0xD0, "YMMM": 0xE0, "LMMV": 0x80, "LMMM": 0x90, "LINE": 0x70}


def build(rtl, out):
    exe = os.path.join(out, "tb_" + os.path.basename(rtl.rstrip("/")) + "_%d.vvp" % random.randrange(1 << 30))
    subprocess.run(["iverilog", "-g2012", "-o", exe, TB,
                    os.path.join(rtl, "vdp_command.v"), os.path.join(rtl, "vdp_command_cache.v")], check=True)
    return exe


def run(exe, out, screen, init, cmds, cmden=1, hs=1, tag="c"):
    fi = os.path.join(out, tag + "_init.hex")
    fc = os.path.join(out, tag + "_cmds.txt")
    fd = os.path.join(out, tag + "_dump.hex")
    with open(fi, "w") as f:
        for addr in sorted(init):
            f.write("@%05x\n%02x\n" % (addr, init[addr]))
    with open(fc, "w") as f:
        for reg, val in cmds:
            f.write("W %d %02x\n" % (reg, val))
            if reg == 46:
                f.write("E\n")
    r = subprocess.run(["vvp", "-n", exe, "+mode=%d" % MODE_BIT[screen], "+cmden=%d" % cmden, "+hs=%d" % hs,
                        "+init=" + fi, "+cmds=" + fc, "+dump=" + fd], capture_output=True, text=True)
    if "TIMEOUT" in r.stdout:
        print(r.stdout.strip())
    with open(fd) as f:
        return bytes(int(l, 16) for l in f)


def regs(sx=0, sy=0, dx=0, dy=0, nx=1, ny=1, clr=0, arg=0, cmd=0xD0):
    return [(32, sx & 255), (33, sx >> 8), (34, sy & 255), (35, sy >> 8), (36, dx & 255), (37, dx >> 8),
            (38, dy & 255), (39, dy >> 8), (40, nx & 255), (41, nx >> 8), (42, ny & 255), (43, ny >> 8),
            (44, clr), (45, arg), (46, cmd)]


def byte_model(init, ops):
    """Modelo del modo byte (SCREEN 8): direccion = y*256 + x. Sin DIX/DIY."""
    m = dict(init)
    for op, p in ops:
        if op == "HMMV":
            for y in range(p["ny"]):
                for x in range(p["nx"]):
                    m[((p["dy"] + y) & 1023) * 256 + ((p["dx"] + x) & 255)] = p["clr"]
        elif op == "HMMM":
            for y in range(p["ny"]):
                for x in range(p["nx"]):
                    m[((p["dy"] + y) & 1023) * 256 + ((p["dx"] + x) & 255)] = \
                        m.get(((p["sy"] + y) & 1023) * 256 + ((p["sx"] + x) & 255), 0)
        elif op == "YMMM":       # X de origen y destino = DX; copia desde DX hasta el final de la linea
            for y in range(p["ny"]):
                for x in range(p["dx"], 256):
                    m[((p["dy"] + y) & 1023) * 256 + x] = m.get(((p["sy"] + y) & 1023) * 256 + x, 0)
    return m


def check_screen2(exe, out):
    fails = 0
    # 1. el caso del aviso: 01 09 0F 17 copiados con HMMM a la linea de abajo
    init = {0: 0x01, 1: 0x09, 2: 0x0F, 3: 0x17}
    d = run(exe, out, 2, init, regs(sx=0, sy=0, dx=0, dy=1, nx=4, ny=1, cmd=CMD["HMMM"]), tag="s2a")
    got = d[0x100:0x104].hex(" ")
    ok = got == "01 09 0f 17"
    print("SCREEN 2 + CMD, HMMM 4 bytes ->", got, "OK" if ok else "MAL (esperado 01 09 0f 17)")
    fails += not ok
    # 2. casos aleatorios HMMV/HMMM/YMMM contra el modelo de bytes
    rnd = random.Random(2709)
    for k in range(12):
        init = {rnd.randrange(0x10000): rnd.randrange(256) for _ in range(400)}
        op = ["HMMV", "HMMM", "YMMM"][k % 3]
        p = dict(sx=rnd.randrange(200), sy=rnd.randrange(60), dx=rnd.randrange(200), dy=64 + rnd.randrange(60),
                 nx=1 + rnd.randrange(48), ny=1 + rnd.randrange(12), clr=rnd.randrange(256))
        for y in range(16):     # origen con contenido para que el modelo tenga algo que copiar
            for x in range(64):
                init[(p["sy"] + y) * 256 + ((p["sx"] + x) & 255)] = rnd.randrange(256)
        want = byte_model(init, [(op, p)])
        d = run(exe, out, 2, init, regs(cmd=CMD[op], **p), hs=k & 1, tag="s2r%d" % k)
        bad = [a for a in range(0x20000) if d[a] != want.get(a, 0)]
        ok = not bad
        print("  %s nx=%d ny=%d hs=%d -> %s" % (op, p["nx"], p["ny"], k & 1,
              "OK" if ok else "MAL en %d bytes (primero %05x: %02x, modelo %02x)" %
              (len(bad), bad[0], d[bad[0]], want.get(bad[0], 0))))
        fails += not ok
    return fails


def regression(exe_new, exe_old, out, n):
    rnd = random.Random(1234)
    fails = 0
    for k in range(n):
        screen = [5, 6, 7, 8][k % 4]
        op = list(CMD)[k % len(CMD)]
        init = {rnd.randrange(0x20000): rnd.randrange(256) for _ in range(3000)}
        arg = rnd.choice([0x00, 0x04, 0x08, 0x0C]) if op != "LINE" else rnd.choice([0x00, 0x01, 0x04, 0x05])
        p = dict(sx=rnd.randrange(512), sy=rnd.randrange(256), dx=rnd.randrange(512), dy=rnd.randrange(256),
                 nx=1 + rnd.randrange(80), ny=1 + rnd.randrange(16), clr=rnd.randrange(256), arg=arg,
                 cmd=CMD[op] | (rnd.randrange(3) if op in ("LMMV", "LMMM", "LINE") else 0))
        hs = k & 1
        # 30/09 (upstream HRA ef12ee3): con DIY el ORIGEN de LMMM/HMMM/YMMM tambien corta en Y = 0. Si SY llega a 0
        # antes de acabar NY (y antes que DY), el RTL nuevo copia SY+1 filas: es lo que hace el viejo con NY = SY+1.
        pb = dict(p)
        if op in ("HMMM", "YMMM", "LMMM") and (arg & 0x08) and p["sy"] + 1 < min(p["ny"], p["dy"] + 1):
            pb["ny"] = p["sy"] + 1
        a = run(exe_new, out, screen, init, regs(**p), hs=hs, tag="rn")
        b = run(exe_old, out, screen, init, regs(**pb), hs=hs, tag="ro")
        same = a == b
        if not same:
            diff = [i for i in range(len(a)) if a[i] != b[i]]
            print("  DIFIERE caso %d: SCREEN %d %s nx=%d ny=%d hs=%d arg=%02x, %d bytes (primero %05x)" %
                  (k, screen, op, p["nx"], p["ny"], hs, arg, len(diff), diff[0]))
        fails += not same
    print("Regresion SCREEN 5-8: %d casos, %d diferencias" % (n, fails))
    return fails


def check_diy(exe_new, exe_old, out):
    """30/09 (upstream HRA ef12ee3): LMMM/HMMM/YMMM con DIY = 1 y el origen pegado arriba (SY < NY-1). El RTL nuevo ha
    de copiar SOLO SY+1 filas (openMSX: clipNY_2) = el RTL viejo con NY = SY+1; y ha de DIFERIR del viejo con el NY
    entero (que seguia copiando desde filas envueltas por debajo de Y = 0)."""
    rnd = random.Random(3009)
    fails = changed = 0
    n = 0
    for screen in (5, 6, 7, 8):
        for op in ("HMMM", "YMMM", "LMMM"):
            for hs in (0, 1):
                init = {rnd.randrange(0x20000): rnd.randrange(256) for _ in range(3000)}
                sy = rnd.randrange(7)
                p = dict(sx=rnd.randrange(200), sy=sy, dx=rnd.randrange(200), dy=100 + rnd.randrange(80),
                         nx=1 + rnd.randrange(60), ny=sy + 2 + rnd.randrange(8), clr=rnd.randrange(256),
                         arg=rnd.choice([0x08, 0x0C]), cmd=CMD[op] | (rnd.randrange(3) if op == "LMMM" else 0))
                a = run(exe_new, out, screen, init, regs(**p), hs=hs, tag="dn")
                b = run(exe_old, out, screen, init, regs(**dict(p, ny=sy + 1)), hs=hs, tag="do")
                c = run(exe_old, out, screen, init, regs(**p), hs=hs, tag="dq")
                n += 1
                changed += a != c
                if a != b:
                    diff = [i for i in range(len(a)) if a[i] != b[i]]
                    print("  DIY MAL: SCREEN %d %s sy=%d ny=%d hs=%d arg=%02x, %d bytes (primero %05x)" %
                          (screen, op, sy, p["ny"], hs, p["arg"], len(diff), diff[0]))
                    fails += 1
    print("DIY con el origen arriba: %d casos, %d mal; en %d el RTL viejo (NY entero) daba otra cosa" % (n, fails, changed))
    return fails


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    n = 60
    if "--cases" in sys.argv:
        n = int(sys.argv[sys.argv.index("--cases") + 1])
        args = [a for a in args if a != str(n)]
    out = tempfile.mkdtemp(prefix="g2cmd_")
    exe_new = build(args[0], out)
    fails = check_screen2(exe_new, out)
    if len(args) > 1:
        exe_old = build(args[1], out)
        fails += regression(exe_new, exe_old, out, n)
        fails += check_diy(exe_new, exe_old, out)
    if "--keep" not in sys.argv:
        subprocess.run(["rm", "-rf", out])
    print("RESULTADO:", "TODO OK" if fails == 0 else "%d FALLOS" % fails)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
