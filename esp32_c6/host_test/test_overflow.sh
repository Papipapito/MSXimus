#!/usr/bin/env bash
# Prueba que el fix de overflow de 32 bits (bloques 0x4B/0x35 con longitud u32
# gigante) se rechaza limpiamente en vez de desbordar, y que una cinta valida
# sigue convirtiendo OK. verify devuelve 1 en error, 0 en exito.
cd "$(dirname "$0")"
TSXDIR=/mnt/c/Users/alber/proyectosAI/msx/tsx2rom

g++ -std=c++11 -O2 -Wall -Wextra -o verify verify.cpp ../tsx2cvs.cpp || exit 1

python3 - <<'PY'
import struct
# 0x4B con len=0xFFFFFFFF
open("/tmp/evil_4b.tsx","wb").write(
    b"ZXTape!\x1a" + bytes([1,20]) + b"\x4B" + struct.pack("<I",0xFFFFFFFF) + b"\x00"*32)
# 0x35 con len u32 gigante
open("/tmp/evil_35.tsx","wb").write(
    b"ZXTape!\x1a" + bytes([1,20]) + b"\x35" + b"X"*0x10 + struct.pack("<I",0xFFFFFFF0) + b"\x00"*8)
PY

fail=0
run() {   # $1=fichero  $2=rc esperado  $3=etiqueta
    ./verify "$1" /tmp/out.cvs >/dev/null 2>/tmp/msg
    rc=$?
    msg=$(cat /tmp/msg)
    if [ "$rc" = "$2" ]; then echo "OK  $3 (rc=$rc) $msg"
    else echo "FAIL $3 (rc=$rc, esperaba $2) $msg"; fail=1; fi
}

run /tmp/evil_4b.tsx 1 "0x4B len=0xFFFFFFFF -> rechazado"
run /tmp/evil_35.tsx 1 "0x35 len=0xFFFFFFF0 -> rechazado"
run "$TSXDIR/test/tsx/amc.tsx" 0 "amc.tsx valido -> convierte"
run "$TSXDIR/test/tsx/007.tsx" 0 "007.tsx valido -> convierte"

exit $fail
