import sys
from PIL import Image

a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    print(f"TAMANOS DISTINTOS: {a.size} vs {b.size}")
    sys.exit(1)
pa, pb = a.load(), b.load()
w, h = a.size
diff = 0
rows = {}
for y in range(h):
    for x in range(w):
        if pa[x, y] != pb[x, y]:
            diff += 1
            rows[y] = rows.get(y, 0) + 1
print(f"pixels distintos: {diff} de {w*h} ({100.0*diff/(w*h):.3f}%)")
for y in sorted(rows):
    print(f"  fila {y}: {rows[y]} px")
