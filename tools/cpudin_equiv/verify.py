# Equivalencia FORMAL del mux de lectura de la CPU (cpu_din): la cadena antigua
# contra el arbol por grupos. Extrae los dos bloques de sus top.v, los mete en dos
# modulos combinacionales con TODAS las senales como entradas (anchos sacados de
# las declaraciones del propio top.v) y los `define reales del fichero, y yosys
# demuestra con miter + SAT que dan el mismo byte para cualquier combinacion.
#
#   git show <commit viejo>:fpga/top.v > /tmp/top_viejo.v
#   python verify.py /tmp/top_viejo.v fpga/top.v [+DEF ...] [-DEF ...]
#     +DEF = `define extra (p.ej. +DISABLE_BOOT_MENU); -DEF = `undef
# Luego, segunda opinion: 200.000 vectores aleatorios en Icarus. Necesita WSL
# Ubuntu-24.04 con iverilog y ~/oss-cad-suite/bin/yosys. Sale 0 si todo cuadra.
# (29/09/2026, arbol de cpu_din del MSXnano 2.1 y el MSXimus 3.7.4.)
import os, re, subprocess, sys, tempfile

HERE = os.path.join(tempfile.gettempdir(), 'cpudin_equiv')   # .v generados, fuera del repo
os.makedirs(HERE, exist_ok=True)
old_p, new_p = sys.argv[1], sys.argv[2]
extra = sys.argv[3:]

KW = set('''always begin end wire reg assign if else case endcase posedge negedge or and not
            module endmodule input output inout localparam parameter signed integer default'''.split())

def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', ' ', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)

def lines_of(p):
    return open(p, encoding='latin-1').read().replace('\r\n', '\n').split('\n')

def old_block(L):
    for i, l in enumerate(L):
        if re.match(r'\s*always @ \(posedge clk_54m\) begin\s*$', l) and re.match(r'\s*cpu_din <=', L[i + 1]):
            j = next(k for k in range(i + 1, len(L)) if L[k].strip() == 'end')
            return i, L[i:j + 1]
    raise SystemExit('no encuentro la cadena de cpu_din')

def new_block(L):
    a = next((i for i, l in enumerate(L) if '// ---- cpu_din:' in l), None)
    if a is None:
        return old_block(L)
    i = next(k for k in range(a, len(L)) if re.match(r'\s*always @ \(posedge clk_54m\) begin', L[k]))
    j = next(k for k in range(i + 1, len(L)) if L[k].strip() == 'end')
    return a, L[a:j + 1]

def preamble(L, upto):
    d = [l.strip() for l in L[:upto] if re.match(r'\s*`(define|undef|ifdef|ifndef|else|elsif|endif)\b', l)]
    depth = 0
    for l in d:
        if re.match(r'`(ifdef|ifndef)', l): depth += 1
        if l.startswith('`endif'): depth -= 1
    if depth:
        raise SystemExit('el bloque esta dentro de un `ifdef abierto (%d): revisar a mano' % depth)
    return d

Lo, Ln = lines_of(old_p), lines_of(new_p)
io, ob = old_block(Lo)
inn, nb = new_block(Ln)
mod = lambda L: next(k for k, l in enumerate(L) if l.startswith('module top'))
pre = preamble(Lo, mod(Lo))   # todos los `define estan antes de 'module top'
if preamble(Ln, mod(Ln)) != pre:
    raise SystemExit('los `define de los dos ficheros no coinciden')
for e in extra:
    pre.append(('`define %s' if e[0] == '+' else '`undef %s') % e[1:])

# anchos: declaraciones del top.v nuevo (y localparams para evaluar [N-1:0])
full = strip_comments('\n'.join(Ln))
lp = {m.group(1): m.group(2) for m in re.finditer(r'localparam\s+(?:\[[^\]]*\]\s*)?(\w+)\s*=\s*([^;,]+)', full)}
def ev(x):
    x = x.strip()
    for k, v in lp.items():
        x = re.sub(r'\b%s\b' % k, '(%s)' % v, x)
    x = re.sub(r"\d*'[dD](\d+)", r'\1', x)
    return int(eval(x, {}, {}))
width = {}
def rng_w(rng):
    if not rng:
        return 1
    try:
        hi, lo = rng[1:-1].split(':')
        return abs(ev(hi) - ev(lo)) + 1
    except Exception:
        return None
for m in re.finditer(r'localparam\s+(\[[^\]]*\])?\s*(\w+)\s*=', full):
    w = rng_w(m.group(1)) if m.group(1) else 32
    if w: width.setdefault(m.group(2), w)
for m in re.finditer(r'\b(?:input|output|inout|wire|reg)\b(?:\s+(?:wire|reg|signed))*\s*(\[[^\]]+\])?\s*', full):
    w = rng_w(m.group(1))
    k, depth, cur, parts = m.end(), 0, '', []
    while k < len(full) and not (full[k] in ';)' and depth == 0):
        ch = full[k]
        if ch in '{([': depth += 1
        if ch in '})]': depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur); cur = ''
        else:
            cur += ch
        k += 1
    parts.append(cur)
    for p in parts:
        n = re.match(r'\s*([A-Za-z_]\w*)', p)
        if n and n.group(1) not in KW and w is not None:
            width.setdefault(n.group(1), w)

def idents(block):
    s = strip_comments('\n'.join(block))
    s = '\n'.join(l for l in s.split('\n') if not l.strip().startswith('`'))
    s = re.sub(r"\d*'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+", ' ', s)
    return {t for t in re.findall(r'\b[A-Za-z_]\w*\b', s) if t not in KW}

local = {'cpu_din'} | {t for t in idents(nb) if re.match(r'g\d+_(hit|val)$', t)}
ins = sorted((idents(ob) | idents(nb)) - local)
falt = [n for n in ins if n not in width]
if falt:
    print('AVISO: sin declaracion encontrada, 8 bits por defecto:', falt)

def body(block):
    t = '\n'.join(block)
    t = re.sub(r'always @ \(posedge clk_54m\) begin', 'always @* begin', t)
    return t.replace('cpu_din <=', 'cpu_din =')

ports = ',\n'.join('    input [%d:0] %s' % (width.get(n, 8) - 1, n) for n in ins)
src = '\n'.join(pre) + '\n'
for name, blk in (('cpudin_old', ob), ('cpudin_new', nb)):
    src += 'module %s(\n%s,\n    output reg [7:0] cpu_din);\n%s\nendmodule\n\n' % (name, ports, body(blk))
tag = os.path.basename(os.path.dirname(os.path.dirname(os.path.abspath(new_p)))) + ''.join(extra)
vf = os.path.join(HERE, 'eq_%s.v' % tag)
open(vf, 'w', encoding='latin-1').write(src)
wsl = lambda p: '/mnt/' + p[0].lower() + p[2:].replace('\\', '/')
ys = ('read_verilog -sv %s; proc; opt_clean; '
      'miter -equiv -flatten -make_assert cpudin_old cpudin_new miter; hierarchy -top miter; '
      'sat -verify -prove-asserts miter' % wsl(vf))
r = subprocess.run(['wsl', '-d', 'Ubuntu-24.04', '--', '/home/albert/oss-cad-suite/bin/yosys', '-q', '-p', ys],
                   capture_output=True, text=True, errors='replace')
out = r.stdout + r.stderr
ok = r.returncode == 0 and 'FAIL' not in out
print('%-34s entradas=%d  items viejo=%d  -> %s' % (tag, len(ins), sum('?' in l for l in ob),
                                                     'EQUIVALENTES (SAT)' if ok else 'DIFERENTES / ERROR'))
if not ok:
    print(out[-3000:])

# Segunda opinion, por simulacion (Icarus): vectores aleatorios con cada condicion de
# 1 bit cierta 1 de cada 16 veces (varias a la vez: ejercita la prioridad).
N = 200000
tb = ['module tb;'] + ['  reg [%d:0] %s;' % (width.get(n, 8) - 1, n) for n in ins]
tb += ['  wire [7:0] o_old, o_new;',
       '  cpudin_old u0(%s, .cpu_din(o_old));' % ', '.join('.%s(%s)' % (n, n) for n in ins),
       '  cpudin_new u1(%s, .cpu_din(o_new));' % ', '.join('.%s(%s)' % (n, n) for n in ins),
       '  integer k, err;', '  initial begin', '    err = 0;',
       '    for (k = 0; k < %d; k = k + 1) begin' % N]
for n in ins:
    w = width.get(n, 8)
    rnd1 = '($urandom % 16 != 0)' if n.endswith('_n') else '($urandom % 16 == 0)'   # _n: activo bajo
    tb.append('      %s = %s;' % (n, rnd1 if w == 1 else '{$urandom, $urandom}'))
tb += ['      #1;', '      if (o_old !== o_new) begin err = err + 1;',
       '        if (err < 4) $display("DIFF k=%0d viejo=%h nuevo=%h", k, o_old, o_new); end',
       '    end', '    $display("RANDOM %0d vectores, %0d diferencias", k, err);', '    $finish;',
       '  end', 'endmodule']
tf = os.path.join(HERE, 'tb_%s.v' % tag)
open(tf, 'w').write('\n'.join(tb) + '\n')
sim = '/tmp/cpudin_%s' % re.sub(r'\W', '_', tag)
r = subprocess.run(['wsl', '-d', 'Ubuntu-24.04', '--', 'bash', '-c',
                    'iverilog -g2012 -o %s %s %s && vvp -n %s' % (sim, wsl(vf), wsl(tf), sim)],
                   capture_output=True, text=True, errors='replace')
m = re.search(r'RANDOM (\d+) vectores, (\d+) diferencias', r.stdout)
sok = bool(m) and m.group(2) == '0'
print('%-34s Icarus: %s' % ('', m.group(0) if m else 'ERROR\n' + (r.stdout + r.stderr)[-2000:]))
sys.exit(0 if (ok and sok) else 1)
