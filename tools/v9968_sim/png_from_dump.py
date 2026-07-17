#!/usr/bin/env python3
# png_from_dump.py — reconstruye el frame volcado por tb_screen5 (lineas "L"
# como marcador de hsync, un pixel RRGGBB hex por linea) y lo guarda como PNG.
import sys
try:
    from PIL import Image
except ImportError:
    sys.exit("pip install pillow")

src = sys.argv[1] if len(sys.argv) > 1 else 's5_frame.txt'
dst = sys.argv[2] if len(sys.argv) > 2 else 'v9968_screen5.png'

rows, cur = [], []
for ln in open(src):
    ln = ln.strip()
    if ln == 'L':
        if cur: rows.append(cur)
        cur = []
    elif len(ln) == 6:
        cur.append((int(ln[0:2],16), int(ln[2:4],16), int(ln[4:6],16)))
if cur: rows.append(cur)

rows = [r for r in rows if len(r) > 8]
if not rows:
    sys.exit("sin lineas activas en el volcado")
w = max(len(r) for r in rows)
h = len(rows)
img = Image.new('RGB', (w, h))
for y, r in enumerate(rows):
    for x, px in enumerate(r):
        img.putpixel((x, y), px)
img.save(dst)
print(f"{dst}: {w}x{h} ({len(rows)} lineas activas)")
