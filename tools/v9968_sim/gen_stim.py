#!/usr/bin/env python3
"""Convierte el log de watchpoints (openMSX V9958) en un fichero de ops de
puerto para el banco de replay tb_bootreplay.sv.

Formato de salida (una op por linea):
  W <p> <hex>   escritura al puerto p (1=0x99, 2=0x9A, 3=0x9B)
  R             lectura unica del puerto 0x99 (descartar valor)
  P <ms>       poll: leer 0x99 hasta bit0==0; <ms> = duracion real V9958 en ms
                (para calibrar el timeout); si expira -> CUELGUE
  G <us>        pausa de <us> microsegundos
  M <texto>     marcador (se imprime en el log de sim)

Reglas:
- Ventanas de tiempo --win a,b (repetible). Entre ventanas se emite un PRIME:
  los pares W99 necesarios para reconstruir el estado de registros (0..27,
  32..45, y R#17) en el arranque de la ventana siguiente. R#46 JAMAS se emite
  en el prime.
- Lecturas R99 con S#2 seleccionado y CE=0 -> P ; CE=1 -> R.
- Runs de R consecutivas se colapsan a <=3; P consecutivas a 1 (se suma ms).
- dt > 2ms entre eventos -> G 200.
"""
import sys, re, argparse

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("out")
    ap.add_argument("--win", action="append", required=True,
                    help="a,b ventana en segundos (repetible)")
    args = ap.parse_args()
    wins = []
    for w in args.win:
        a, b = w.split(",")
        wins.append((float(a), float(b)))
    wins.sort()

    re_w99 = re.compile(r"^W99 ([0-9a-f]{2}) pc=([0-9a-f]{4}) t=([\d.]+)")
    re_w9a = re.compile(r"^W9A ([0-9a-f]{2}) t=([\d.]+)")
    re_w9b = re.compile(r"^W9B ([0-9a-f]{2})(?: pc=([0-9a-f]{4}))? t=([\d.]+)")
    re_r99 = re.compile(r"^R99 s(\d+)=([0-9a-f?]{2}) pc=([0-9a-f]{4}) t=([\d.]+)")

    regs = [None]*64          # estado de registros decodificado
    latch = None
    ind_ptr = None
    ind_ai = False
    ops = []                  # (tipo, ...) crudo antes de colapsar
    cur_win = -1              # indice de ventana activa (-1 = fuera)
    last_t = None
    n_in = 0

    def which_win(t):
        for i, (a, b) in enumerate(wins):
            if a <= t <= b:
                return i
        return -1

    def prime(tag):
        ops.append(("M", f"PRIME {tag}"))
        # una lectura de 0x99 resetea el latch de pares del DUT por si la
        # ventana anterior corto a mitad de par
        ops.append(("R",))
        # modo / control / scroll / bancos — todo lo que el motor y el
        # interface miran; el orden respeta que R#17 fija el puntero indirecto
        for r in list(range(0, 16)) + [18, 19, 20, 21, 22, 23, 25, 26, 27] \
                 + list(range(32, 46)) + [17]:
            v = regs[r]
            if v is not None:
                ops.append(("W", 1, v))
                ops.append(("W", 1, 0x80 | r))

    def reg_write(r, v):
        regs[r] = v

    def emit_gap(t):
        # conserva los huecos reales de 0.1-2 ms (el solape comando-nuevo vs
        # comando-en-curso depende de ellos); los largos (>2 ms, motor ocioso)
        # se comprimen a 200 us
        if last_t is None:
            return
        dt = t - last_t
        if dt > 0.002:
            ops.append(("G", 200))
        elif dt >= 0.0001:
            ops.append(("G", int(dt * 1e6)))

    with open(args.log) as f:
        for line in f:
            m = re_w99.match(line)
            if m:
                v = int(m.group(1), 16); t = float(m.group(3))
                # decodificado de estado (siempre, este o no en ventana)
                if latch is None:
                    latch = v
                    was_second = False
                else:
                    if v & 0x80:
                        r = v & 0x3F
                        if r == 17:
                            ind_ptr = latch & 0x3F
                            ind_ai = (latch & 0x80) == 0
                        if r != 46:
                            reg_write(r, latch)
                    was_second = True
                    latch = None
                w = which_win(t)
                if w >= 0:
                    if w != cur_win:
                        prime(f"win{w} t={t:.4f}")
                        cur_win = w
                        last_t = t
                        if was_second:
                            # segundo byte de un par cortado por el borde de la
                            # ventana: su primer byte no se emitio; se salta (el
                            # prime ya reconstruyo el registro)
                            n_in += 1
                            continue
                    emit_gap(t)
                    ops.append(("W", 1, v))
                    last_t = t
                n_in += 1
                continue
            m = re_r99.match(line)
            if m:
                sp = int(m.group(1)); sv = m.group(2); t = float(m.group(4))
                latch = None
                w = which_win(t)
                if w >= 0:
                    if w != cur_win:
                        prime(f"win{w} t={t:.4f}")
                        cur_win = w
                        last_t = t
                    emit_gap(t)
                    if sp == 2 and sv != "??" and (int(sv, 16) & 1) == 0:
                        ops.append(("P", t))
                    else:
                        ops.append(("R",))
                    last_t = t
                continue
            m = re_w9b.match(line)
            if m:
                v = int(m.group(1), 16); t = float(m.group(3))
                if ind_ptr is not None:
                    if ind_ptr != 46:
                        reg_write(ind_ptr, v)
                    p_now = ind_ptr
                    if ind_ai:
                        ind_ptr = (ind_ptr + 1) & 0x3F
                w = which_win(t)
                if w >= 0:
                    if w != cur_win:
                        prime(f"win{w} t={t:.4f}")
                        cur_win = w
                        last_t = t
                    emit_gap(t)
                    ops.append(("W", 3, v))
                    last_t = t
                continue
            m = re_w9a.match(line)
            if m:
                v = int(m.group(1), 16); t = float(m.group(2))
                w = which_win(t)
                if w >= 0 and w == cur_win:
                    ops.append(("W", 2, v))
                    last_t = t
                continue

    # ---- colapso de runs (absorbiendo los G intercalados del poll loop) ----
    def scan_run(i, kind):
        # devuelve (fin_exclusivo, n_kind, t_ultimo) del run kind|G que
        # empieza en i; el run termina en el ULTIMO kind (no absorbe colas G)
        j = i
        last_k = i
        n = 0
        t_last = None
        while j < len(ops) and ops[j][0] in (kind, "G"):
            if ops[j][0] == kind:
                last_k = j
                n += 1
                if kind == "P":
                    t_last = ops[j][1]
            j += 1
        return last_k + 1, n, t_last

    out = []
    i = 0
    n_r_drop = 0
    n_p_fold = 0
    while i < len(ops):
        op = ops[i]
        if op[0] == "R":
            j, n, _ = scan_run(i, "R")
            keep = min(3, n)
            out.extend([("R",)] * keep)
            n_r_drop += n - keep
            i = j
        elif op[0] == "P":
            j, n, t_last = scan_run(i, "P")
            dur_ms = max(1.0, (t_last - op[1]) * 1000.0 + 1.0)
            out.append(("P", dur_ms))
            n_p_fold += n - 1
            i = j
        else:
            out.append(op)
            i += 1

    # ---- colapso de iteraciones de poll con flip de R#15 ----
    # patron tipico: [W1 02, W1 8f, R, W1 00, W1 8f] repetido cientos de veces
    # (con G intercalados). Se colapsa toda repeticion consecutiva de una
    # 5-tupla (ignorando G) que contenga exactamente una R, dejando 2 copias.
    def tuple_at(k, idxs):
        return tuple(out[x] for x in idxs[k:k+5])

    idxs = [x for x in range(len(out)) if out[x][0] != "G"]
    drop = set()
    n_iter_drop = 0
    k = 0
    while k + 5 <= len(idxs):
        t0 = tuple_at(k, idxs)
        if sum(1 for o in t0 if o[0] == "R") == 1 and \
           sum(1 for o in t0 if o[0] == "W") == 4:
            reps = 1
            while k + (reps + 1) * 5 <= len(idxs) and \
                  tuple_at(k + reps * 5, idxs) == t0:
                reps += 1
            if reps > 2:
                # se conservan las 2 primeras; del resto se borra todo el
                # rango (incluidos los G intercalados)
                a = idxs[k + 2 * 5]
                b = idxs[k + reps * 5 - 1]
                for x in range(a, b + 1):
                    drop.add(x)
                n_iter_drop += reps - 2
                k += reps * 5
                continue
        k += 1
    out = [o for x, o in enumerate(out) if x not in drop]

    with open(args.out, "w") as f:
        for op in out:
            if op[0] == "W":
                f.write(f"W {op[1]} {op[2]:02x}\n")
            elif op[0] == "R":
                f.write("R\n")
            elif op[0] == "P":
                f.write(f"P {max(1, int(round(op[1])))}\n")
            elif op[0] == "G":
                f.write(f"G {op[1]}\n")
            elif op[0] == "M":
                f.write(f"M {op[1].replace(' ', '_')}\n")
    nw = sum(1 for o in out if o[0] == "W")
    np_ = sum(1 for o in out if o[0] == "P")
    print(f"{args.out}: {len(out)} ops (W={nw} P={np_} "
          f"R_drop={n_r_drop} P_fold={n_p_fold} iter_drop={n_iter_drop}) "
          f"de {n_in} eventos")

if __name__ == "__main__":
    main()
