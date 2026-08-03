#!/usr/bin/env bash
# Valida el DFA incremental del catalogo contra el json de Python usando la
# pagina REAL cacheada (tsx2rom/companion/cache/cat_A_0.json). Correr en WSL.
cd "$(dirname "$0")"
CAT=/mnt/c/Users/alber/proyectosAI/msx/tsx2rom/companion/cache/cat_A_0.json

g++ -std=c++11 -O2 -Wall -Wextra -o verify_catalog verify_catalog.cpp ../tsxcatalog.cpp || exit 1
mkdir -p out
./verify_catalog "$CAT" > out/cat_cpp.tsv 2> out/cat_cpp.n
cat out/cat_cpp.n

python3 - "$CAT" > out/cat_py.tsv <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
w = sys.stdout.buffer
for e in d["files"]:
    # truncado por BYTES UTF-8 (igual que el DFA, que corta a 95 bytes)
    name = e["labels"]["TOSEC.NAME"].encode("utf-8")[:95]
    size = int(e["file"]["fileSize"].replace(".", ""))
    load = e.get("labels", {}).get("TSX.LOAD", "")
    cmd = 1 if "BLOAD" in load else (0 if "RUN" in load else 2)
    w.write(name + f"\t{size}\t{cmd}\n".encode())
PYEOF

if diff -q out/cat_cpp.tsv out/cat_py.tsv >/dev/null; then
  echo "PASS: DFA byte-a-byte == Python json ($(wc -l < out/cat_cpp.tsv) entradas)"
  exit 0
else
  echo "FAIL: diferencias:"
  diff out/cat_cpp.tsv out/cat_py.tsv | head -12
  exit 1
fi
