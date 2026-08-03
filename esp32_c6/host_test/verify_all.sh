#!/usr/bin/env bash
# Verifica tsx2cvs.cpp byte-exacto contra la referencia Python (tsx2rom):
#   Python: tsx -> CVT1 (tsx2msx --tape) -> CVS1 (mkstream.py)
#   C++:    tsx -> CVS1 (tsx2cvs)
# y compara. Corre en WSL/Linux desde host_test/.
cd "$(dirname "$0")"
TSXDIR=/mnt/c/Users/alber/proyectosAI/msx/tsx2rom
MKSTREAM=/mnt/c/Users/alber/proyectosAI/msx/MSXnano-cinta/tools/tsx_stream_sim/mkstream.py

g++ -std=c++11 -O2 -Wall -Wextra -o verify verify.cpp ../tsx2cvs.cpp || exit 1
echo "=== compilado OK ==="
mkdir -p out
PASS=0; FAIL=0
shopt -s nullglob
for f in "$TSXDIR"/test/tsx/*.tsx "$TSXDIR"/companion/cache/*.tsx; do
  base=$(basename "$f" .tsx)
  # referencia Python
  rm -rf /tmp/cvtref /tmp/cvsref; mkdir -p /tmp/cvtref /tmp/cvsref
  (cd "$TSXDIR" && python3 tsx2msx.py "$f" --tape -o /tmp/cvtref >/dev/null 2>&1)
  if ! python3 "$MKSTREAM" "/tmp/cvtref/$base.cvt" /tmp/cvsref >/dev/null 2>&1; then
    echo "SKIP (python no convierte): $base"; continue
  fi
  python3 - <<'PY'
hexf = open("/tmp/cvsref/stream.hex").read().split()
open("/tmp/cvsref/ref.cvs", "wb").write(bytes(int(h, 16) for h in hexf))
PY
  if ! ./verify "$f" "out/$base.cvs" >/dev/null 2>&1; then
    echo "FAIL (c++ devolvio error): $base"; FAIL=$((FAIL+1)); continue
  fi
  if cmp -s "out/$base.cvs" /tmp/cvsref/ref.cvs; then
    echo "PASS byte-exacto: $base ($(stat -c%s "out/$base.cvs") B)"; PASS=$((PASS+1))
  else
    echo "FAIL byte-DIFF: $base"; FAIL=$((FAIL+1))
  fi
done
echo "=== resultado: $PASS pass, $FAIL fail ==="
[ "$FAIL" = 0 ] && [ "$PASS" -gt 0 ]
