#!/usr/bin/env python3
# dbg_shim_reader.py — lector de la telemetria del shim V9968 (_121diag).
# La FPGA emite por el USB-UART (COM11, 115200): "D <miss> <bka> <bkb>\r\n"
# cada 250ms (hex32). Este lector muestra los contadores y sus TASAS:
#   miss/s  = misses de bg (ventana+cache) por segundo
#   bkA/s   = completaciones del canal A (wv2) por segundo
#   bkB/s   = completaciones del canal B (wv3) por segundo
# Diagnostico: SC8 limpio ~ miss/s≈0, bkA/s≈bkB/s≈1.4M (fills parejos).
#   inanicion del arbitro -> miss/s alto y bkA+bkB muy por debajo de 2.8M
#   canal B muerto        -> bkB/s ≈ 0
#   CDC corrupto          -> tasas sanas pero pantalla mal (=> siguiente ronda)
import sys, time
import serial

port = sys.argv[1] if len(sys.argv) > 1 else "COM11"
ser = serial.Serial(port, 115200, timeout=2)
print(f"escuchando {port} @115200 (Ctrl+C para salir)")
prev = None
prev_t = None
while True:
    ln = ser.readline().decode("ascii", "replace").strip()
    if not ln.startswith("D "):
        if ln:
            print(f"(otra linea: {ln[:60]})")
        continue
    try:
        parts = ln.split()
        miss, bka, bkb = (int(x, 16) for x in parts[1:4])
    except Exception:
        print(f"(malformada: {ln[:60]})")
        continue
    now = time.time()
    if prev is not None:
        dt = now - prev_t
        dm = (miss - prev[0]) & 0xFFFFFFFF
        da = (bka - prev[1]) & 0xFFFFFFFF
        db = (bkb - prev[2]) & 0xFFFFFFFF
        print(f"miss={miss:10d} (+{dm/dt:9.0f}/s)  "
              f"bkA={bka:10d} (+{da/dt:9.0f}/s)  "
              f"bkB={bkb:10d} (+{db/dt:9.0f}/s)")
    else:
        print(f"miss={miss} bkA={bka} bkB={bkb} (primera muestra)")
    prev = (miss, bka, bkb)
    prev_t = now
